from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field


class ProfileOut(BaseModel):
    id: int
    email: str
    display_name: str
    email_verified: bool = False
    skin_type: str = ""
    concerns: list[str] = Field(default_factory=list)
    owned_items: list[str] = Field(default_factory=list)
    avoid_items: list[str] = Field(default_factory=list)
    created_at: datetime | None = None


class ProfileUpdate(BaseModel):
    display_name: str | None = Field(default=None, max_length=120)
    skin_type: str | None = Field(default=None, max_length=64)
    concerns: list[str] | None = None
    owned_items: list[str] | None = None
    avoid_items: list[str] | None = None
