from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any

import bcrypt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.models import User
from app.db.session import get_db

_bearer = HTTPBearer(auto_error=False)


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))
    except ValueError:
        return False


def create_access_token(*, user_id: int, email: str) -> str:
    expire = datetime.now(UTC) + timedelta(hours=settings.jwt_expire_hours)
    payload: dict[str, Any] = {
        "sub": str(user_id),
        "email": email,
        "exp": expire,
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def _user_from_bearer(
    creds: HTTPAuthorizationCredentials | None,
    db: Session,
    *,
    required: bool,
) -> User | None:
    if creds is None or not creds.credentials:
        if required:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Нужен Bearer token")
        return None
    try:
        data = jwt.decode(creds.credentials, settings.jwt_secret, algorithms=["HS256"])
        user_id = int(data.get("sub") or 0)
    except (JWTError, TypeError, ValueError) as exc:
        if required:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Неверный токен") from exc
        return None
    user = db.scalar(select(User).where(User.id == user_id))
    if user is None and required:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Пользователь не найден")
    return user


def get_current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    user = _user_from_bearer(creds, db, required=True)
    assert user is not None
    return user


def get_optional_user(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User | None:
    return _user_from_bearer(creds, db, required=False)
