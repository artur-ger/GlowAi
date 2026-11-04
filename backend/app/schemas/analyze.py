from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


class ClimateSummary(BaseModel):
    home_city: str
    destination_city: str
    home_temp_c: float | None = None
    destination_temp_c: float | None = None
    home_humidity: float | None = None
    destination_humidity: float | None = None
    home_uv: float | None = None
    destination_uv: float | None = None
    delta_temp_c: float | None = None
    delta_humidity: float | None = None
    risks: list[str] = Field(default_factory=list)
    source: str = "open-meteo"
    # current | forecast | seasonal_proxy
    window: str = "current"
    window_note: str = ""


class SkinAssessment(BaseModel):
    summary: str
    concerns: list[str] = Field(default_factory=list)
    confidence: Literal["low", "medium", "high"] = "medium"
    engine: Literal["llm_vision", "llm", "rule_based"] = "rule_based"


class CareStep(BaseModel):
    step: int
    title: str
    detail: str


class PackingItem(BaseModel):
    item: str
    action: Literal["take", "skip"] = "take"
    reason: str = ""


class AnalyzeResponse(BaseModel):
    mode: Literal["pre_trip", "sos", "return_home"]
    climate: ClimateSummary
    skin: SkinAssessment
    care_plan: list[CareStep]
    packing_list: list[str] = Field(default_factory=list)
    packing_kit: list[PackingItem] = Field(default_factory=list)
    product_hints: list[str]
    why_reasons: list[str] = Field(default_factory=list)
    forecast_summary: str = ""
    trip_start: str | None = None
    trip_end: str | None = None
    trip_days: int | None = None
    follow_up_hint: str
    disclaimer: str
    provider: str
    owned_items: list[str] = Field(default_factory=list)
    avoid_items: list[str] = Field(default_factory=list)
