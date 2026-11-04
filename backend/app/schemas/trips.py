from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


TripStatus = Literal["pre_trip", "on_site", "return_home", "done"]


class TripCreate(BaseModel):
    home_city: str = Field(min_length=1, max_length=120)
    dest_city: str = Field(min_length=1, max_length=120)
    home_lat: float | None = None
    home_lon: float | None = None
    dest_lat: float | None = None
    dest_lon: float | None = None
    trip_start: str = ""
    trip_end: str = ""
    status: TripStatus = "pre_trip"
    latest_check_id: int | None = None
    set_active: bool = True


class TripStatusUpdate(BaseModel):
    status: TripStatus


class TripOut(BaseModel):
    id: int
    home_city: str
    dest_city: str
    home_lat: float | None = None
    home_lon: float | None = None
    dest_lat: float | None = None
    dest_lon: float | None = None
    trip_start: str = ""
    trip_end: str = ""
    status: str
    latest_check_id: int | None = None
    is_active: bool = True
    created_at: datetime | None = None
    updated_at: datetime | None = None
    suggested_next: str = ""

    model_config = {"from_attributes": True}


class DailyTipOut(BaseModel):
    trip_id: int | None = None
    city: str
    temp_c: float | None = None
    humidity: float | None = None
    uv: float | None = None
    tip: str
    window: str = "current"
