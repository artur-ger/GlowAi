from __future__ import annotations

import logging
import secrets
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session


from app.core.config import settings
from app.core.rate_limit import auth_limiter, client_key
from app.core.security import create_access_token, get_current_user, hash_password, verify_password
from app.db.models import User
from app.db.session import get_db
from app.schemas.auth import (
    ForgotPasswordRequest,
    LoginRequest,
    RegisterPendingResponse,
    RegisterRequest,
    ResendCodeRequest,
    ResetPasswordRequest,
    TokenResponse,
    UserOut,
    VerifyEmailRequest,
)
from app.services.mailer import send_reset_code, send_verify_code

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])
logger = logging.getLogger(__name__)


def _new_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def _issue_verify_code(user: User) -> str:
    code = _new_code()
    user.email_verify_code = code
    user.email_verify_expires = datetime.now(UTC) + timedelta(minutes=30)
    user.email_verified = False
    return code


def _issue_reset_code(user: User) -> str:
    code = _new_code()
    user.reset_code = code
    user.reset_expires = datetime.now(UTC) + timedelta(minutes=30)
    return code


def _aware(dt: datetime | None) -> datetime | None:
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt


def _token_for(user: User) -> TokenResponse:
    token = create_access_token(user_id=user.id, email=user.email)
    return TokenResponse(access_token=token, user=UserOut.model_validate(user))


def _pending(email: str, message: str, *, code: str, email_sent: bool) -> RegisterPendingResponse:
    return RegisterPendingResponse(
        email=email,
        verification_required=True,
        message=message,
        email_sent=email_sent,
        dev_verify_code=code if settings.expose_dev_codes else None,
    )


@router.post("/register", response_model=RegisterPendingResponse)
def register(
    body: RegisterRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> RegisterPendingResponse:
    auth_limiter.check(f"auth:{client_key(request)}")
    if not body.accept_terms:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Нужно принять условия использования и политику ПДн",
        )
    email = body.email.lower().strip()
    exists = db.scalar(select(User).where(User.email == email))
    if exists:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email уже зарегистрирован")
    user = User(
        email=email,
        password_hash=hash_password(body.password),
        display_name=(body.display_name or "").strip() or email.split("@")[0],
        email_verified=False,
        terms_accepted_at=datetime.now(UTC),
    )
    code = _issue_verify_code(user)
    db.add(user)
    db.commit()
    try:
        sent = send_verify_code(email, code)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Не удалось отправить письмо: {exc}") from exc
    logger.info("verify code for %s (sent=%s)", email, sent)
    msg = (
        "Код отправлен на email. Введите его для завершения регистрации."
        if sent
        else "Код сформирован. SMTP не настроен — в пилоте смотрите код на экране / в логах."
    )
    return _pending(email, msg, code=code, email_sent=sent)


@router.post("/verify-email", response_model=TokenResponse)
def verify_email(body: VerifyEmailRequest, db: Session = Depends(get_db)) -> TokenResponse:
    email = body.email.lower().strip()
    code = body.code.strip()
    user = db.scalar(select(User).where(User.email == email))
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Пользователь не найден")
    if user.email_verified:
        return _token_for(user)
    if not user.email_verify_code or user.email_verify_code != code:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Неверный код подтверждения")
    expires = _aware(user.email_verify_expires)
    if expires is None or expires < datetime.now(UTC):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Код истёк — запросите новый")
    user.email_verified = True
    user.email_verify_code = None
    user.email_verify_expires = None
    db.commit()
    db.refresh(user)
    return _token_for(user)


@router.post("/resend-code", response_model=RegisterPendingResponse)
def resend_code(body: ResendCodeRequest, db: Session = Depends(get_db)) -> RegisterPendingResponse:
    email = body.email.lower().strip()
    user = db.scalar(select(User).where(User.email == email))
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Пользователь не найден")
    if user.email_verified:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email уже подтверждён")
    code = _issue_verify_code(user)
    db.commit()
    try:
        sent = send_verify_code(email, code)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Не удалось отправить письмо: {exc}") from exc
    return _pending(
        email,
        "Новый код сформирован." + (" Письмо отправлено." if sent else ""),
        code=code,
        email_sent=sent,
    )


@router.post("/forgot-password", response_model=RegisterPendingResponse)
def forgot_password(
    body: ForgotPasswordRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> RegisterPendingResponse:
    auth_limiter.check(f"auth:{client_key(request)}")
    email = body.email.lower().strip()
    user = db.scalar(select(User).where(User.email == email))
    # Do not reveal whether email exists in prod messaging; still return 200 shape
    if user is None:
        return RegisterPendingResponse(
            email=email,
            verification_required=True,
            message="Если аккаунт существует, код сброса будет отправлен.",
            email_sent=False,
            dev_verify_code=None,
        )
    code = _issue_reset_code(user)
    db.commit()
    try:
        sent = send_reset_code(email, code)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Не удалось отправить письмо: {exc}") from exc
    return _pending(
        email,
        "Код сброса пароля сформирован." + (" Письмо отправлено." if sent else " SMTP выключен — код в пилоте на экране."),
        code=code,
        email_sent=sent,
    )


@router.post("/reset-password", response_model=TokenResponse)
def reset_password(body: ResetPasswordRequest, db: Session = Depends(get_db)) -> TokenResponse:
    email = body.email.lower().strip()
    user = db.scalar(select(User).where(User.email == email))
    if user is None or not user.reset_code or user.reset_code != body.code.strip():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Неверный код сброса")
    expires = _aware(user.reset_expires)
    if expires is None or expires < datetime.now(UTC):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Код сброса истёк")
    user.password_hash = hash_password(body.new_password)
    user.reset_code = None
    user.reset_expires = None
    user.email_verified = True  # proves mailbox control
    user.email_verify_code = None
    user.email_verify_expires = None
    db.commit()
    db.refresh(user)
    return _token_for(user)


@router.post("/login", response_model=TokenResponse)
def login(
    body: LoginRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> TokenResponse:
    auth_limiter.check(f"auth:{client_key(request)}")
    email = body.email.lower().strip()
    user = db.scalar(select(User).where(User.email == email))
    if user is None or not verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Неверный email или пароль")
    if not user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Подтвердите email кодом из письма.",
        )
    return _token_for(user)


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)) -> UserOut:
    return UserOut.model_validate(user)


@router.delete("/me", status_code=204)
def delete_me(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> None:
    db.delete(user)
    db.commit()
    return None
