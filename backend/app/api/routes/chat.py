from __future__ import annotations

import json
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.rate_limit import InMemoryRateLimiter
from app.core.security import get_current_user
from app.db.models import ChatMessage, SkinCheck, User
from app.db.session import get_db
from app.schemas.checks import ChatMessageOut, ChatPostRequest, ChatPostResponse
from app.services.chat_followup import reply_about_check

router = APIRouter(prefix="/api/v1/checks", tags=["chat"])
_chat_burst = InMemoryRateLimiter(max_calls=20, per_seconds=60.0)


def _owned_check(db: Session, user: User, check_id: int) -> SkinCheck:
    check = db.scalar(select(SkinCheck).where(SkinCheck.id == check_id, SkinCheck.user_id == user.id))
    if check is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Проверка не найдена")
    return check


@router.get("/{check_id}/messages", response_model=list[ChatMessageOut])
def list_messages(
    check_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[ChatMessageOut]:
    _owned_check(db, user, check_id)
    rows = db.scalars(
        select(ChatMessage)
        .where(ChatMessage.check_id == check_id)
        .order_by(ChatMessage.id.asc())
    ).all()
    return [ChatMessageOut.model_validate(r) for r in rows]


@router.post("/{check_id}/messages", response_model=ChatPostResponse)
async def post_message(
    check_id: int,
    body: ChatPostRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ChatPostResponse:
    _chat_burst.check(f"chat:{user.id}")
    check = _owned_check(db, user, check_id)

    since = datetime.now(UTC) - timedelta(days=1)
    day_count = db.scalar(
        select(func.count())
        .select_from(ChatMessage)
        .join(SkinCheck, SkinCheck.id == ChatMessage.check_id)
        .where(
            SkinCheck.user_id == user.id,
            ChatMessage.role == "user",
            ChatMessage.created_at >= since,
        )
    ) or 0
    if int(day_count) >= settings.chat_max_messages_per_day:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Лимит чата: {settings.chat_max_messages_per_day} сообщений в сутки",
        )

    text = body.text.strip()
    user_msg = ChatMessage(check_id=check.id, role="user", text=text)
    db.add(user_msg)
    db.commit()
    db.refresh(user_msg)

    try:
        payload = json.loads(check.payload_json)
    except json.JSONDecodeError:
        payload = {}
    history_rows = db.scalars(
        select(ChatMessage)
        .where(ChatMessage.check_id == check.id)
        .order_by(ChatMessage.id.desc())
        .limit(12)
    ).all()
    history = [{"role": m.role, "text": m.text} for m in reversed(history_rows)]

    try:
        reply = await reply_about_check(
            user_text=text,
            check_payload=payload if isinstance(payload, dict) else {},
            history=history,
        )
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Ошибка чата: {exc}") from exc

    assistant = ChatMessage(check_id=check.id, role="assistant", text=reply)
    db.add(assistant)
    db.commit()
    db.refresh(assistant)

    return ChatPostResponse(
        user_message=ChatMessageOut.model_validate(user_msg),
        assistant_message=ChatMessageOut.model_validate(assistant),
    )
