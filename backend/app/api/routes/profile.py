from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.db.models import User
from app.db.session import get_db
from app.schemas.profile import ProfileOut, ProfileUpdate

router = APIRouter(prefix="/api/v1/profile", tags=["profile"])


def _split(csv: str) -> list[str]:
    return [p.strip() for p in (csv or "").split(",") if p.strip()]


def _join(items: list[str] | None) -> str:
    if not items:
        return ""
    return ", ".join(x.strip() for x in items if x.strip())[:500]


def _to_out(user: User) -> ProfileOut:
    return ProfileOut(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        email_verified=user.email_verified,
        skin_type=user.skin_type or "",
        concerns=_split(user.concerns_csv),
        owned_items=_split(user.owned_items_csv),
        avoid_items=_split(user.avoid_items_csv),
        created_at=user.created_at,
    )


@router.get("/me", response_model=ProfileOut)
def get_profile(user: User = Depends(get_current_user)) -> ProfileOut:
    return _to_out(user)


@router.patch("/me", response_model=ProfileOut)
def patch_profile(
    body: ProfileUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ProfileOut:
    if body.display_name is not None:
        user.display_name = body.display_name.strip()
    if body.skin_type is not None:
        user.skin_type = body.skin_type.strip()
    if body.concerns is not None:
        user.concerns_csv = _join(body.concerns)
    if body.owned_items is not None:
        user.owned_items_csv = _join(body.owned_items)
    if body.avoid_items is not None:
        user.avoid_items_csv = _join(body.avoid_items)
    db.commit()
    db.refresh(user)
    return _to_out(user)
