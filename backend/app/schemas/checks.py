from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class CheckCreateRequest(BaseModel):
    payload: dict[str, Any]
    home_city: str = ""
    dest_city: str = ""
    mode: str = "pre_trip"
    parent_check_id: int | None = None
    trip_id: int | None = None
    remind_in_hours: int | None = Field(default=None, ge=1, le=24 * 14)
    attach_active_trip: bool = True


class CheckListItem(BaseModel):
    id: int
    created_at: datetime | None = None
    mode: str
    home_city: str
    dest_city: str
    forecast_summary: str
    engine: str
    parent_check_id: int | None = None
    trip_id: int | None = None
    remind_at: datetime | None = None


class CheckDetail(CheckListItem):
    payload: dict[str, Any]


# trip_id already on CheckListItem


class RemindRequest(BaseModel):
    hours: int = Field(default=48, ge=1, le=24 * 14)


class ChatMessageOut(BaseModel):
    id: int
    role: str
    text: str
    created_at: datetime | None = None

    model_config = {"from_attributes": True}


class ChatPostRequest(BaseModel):
    text: str = Field(min_length=1, max_length=2000)


class ChatPostResponse(BaseModel):
    user_message: ChatMessageOut
    assistant_message: ChatMessageOut


class CheckInRequest(BaseModel):
    dryness: int = Field(ge=1, le=5, description="1=норма … 5=очень сухо")
    oiliness: int = Field(ge=1, le=5)
    calmness: int = Field(ge=1, le=5, description="1=спокойно … 5=раздражено")
    redness: int = Field(ge=1, le=5)
    note: str = Field(default="", max_length=500)


class CheckInOut(BaseModel):
    id: int
    check_id: int
    dryness: int
    oiliness: int
    calmness: int
    redness: int
    note: str
    advice: str
    revised_check_id: int | None = None
    revised_payload: dict[str, Any] | None = None
    suggest_sos: bool = False
    created_at: datetime | None = None

    model_config = {"from_attributes": True}
