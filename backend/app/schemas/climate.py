from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


class ClimateProfileIn(BaseModel):
    """Onboarding + accumulated personal random intercept (PDF §7 / §8.1)."""

    cold_bias: float = Field(0.0, ge=-2.0, le=2.0)
    heat_bias: float = Field(0.0, ge=-2.0, le=2.0)
    activity: Literal["low", "moderate", "high"] = "moderate"
    age_band: Literal["under_30", "30_50", "over_50", "unknown"] = "unknown"
    sex: Literal["female", "male", "other", "unknown"] = "unknown"
    # Day-1 priors (questionnaire → fixed effects; feedback still owns u_i)
    dress_bias: Literal["lighter", "typical", "warmer"] = "typical"
    acclimation: Literal["long", "recent", "temporary", "unknown"] = "unknown"
    vignette_sensation: Literal["cold", "ok", "warm", "unknown"] = "unknown"
    feedback_offset: float = Field(0.0, ge=-5.0, le=5.0)
    feedback_count: int = Field(0, ge=0, le=10_000)
    habits: list[str] = Field(default_factory=list, max_length=12)
    allergies: list[str] = Field(default_factory=list, max_length=12)
    leave_hour: int = Field(8, ge=0, le=23)
    return_hour: int = Field(19, ge=0, le=23)


class ClimateTodayRequest(BaseModel):
    city: str = Field(..., min_length=1, max_length=80)
    lat: float | None = None
    lon: float | None = None
    profile: ClimateProfileIn = Field(default_factory=ClimateProfileIn)
    lang: Literal["ru", "en"] = "ru"
    shade: bool = False
    client_key: str = Field("anon", max_length=64)


class ClothingItem(BaseModel):
    item: str
    layer: Literal["base", "mid", "outer", "accessories"] = "mid"
    clo: float | None = None
    catalog_id: str | None = None


class CareItem(BaseModel):
    item: str
    reason: str
    catalog_id: str | None = None


class HourlySensation(BaseModel):
    time: str
    hour_label: str
    utci_c: float
    sensation: int
    sensation_label: str
    temp_c: float | None = None
    wind_ms: float | None = None
    precip_mm: float | None = None


class SupportIndicesOut(BaseModel):
    pet_c: float | None = None
    heat_index_c: float | None = None
    humidex_c: float | None = None
    wind_chill_c: float | None = None
    ireq_clo: float
    met_w_m2: float


class FeedbackWindow(BaseModel):
    moment: Literal["leave", "return", "anytime"]
    leave_hour: int
    return_hour: int
    prompt: str


class ClimateTodayResponse(BaseModel):
    city: str
    temp_c: float | None = None
    humidity: float | None = None
    wind_ms: float | None = None
    uv: float | None = None
    shortwave_wm2: float | None = None
    elevation_m: float | None = None
    utci_c: float
    utci_stress: str
    personal_utci_c: float
    sensation: int = Field(..., ge=-3, le=3)
    sensation_label: str
    confidence: Literal["low", "medium", "high"] = "medium"
    calibration_note: str
    explanation: str = ""
    spare_layer: bool = False
    spare_layer_note: str = ""
    model_spread_c: float | None = None
    support: SupportIndicesOut
    place_offset_c: float = 0.0
    random_intercept_c: float = 0.0
    clothing: list[ClothingItem] = Field(default_factory=list)
    care: list[CareItem] = Field(default_factory=list)
    appearance_risk: int = Field(0, ge=0, le=3)
    appearance_note: str = ""
    hours: list[HourlySensation] = Field(default_factory=list)
    feedback_window: FeedbackWindow | None = None
    why: list[str] = Field(default_factory=list)
    disclaimer: str
    source: str = "open-meteo"
    provider: str = "mixed_ordinal_utci_v1"
    llm_used: bool = False


class ClimateFeedbackRequest(BaseModel):
    city: str = Field(..., min_length=1, max_length=80)
    lat: float | None = None
    lon: float | None = None
    predicted_sensation: int = Field(..., ge=-3, le=3)
    actual_sensation: int = Field(..., ge=-3, le=3)
    worn_tier: Literal["lighter", "as_advised", "warmer"] = "as_advised"
    look_preserved: Literal["yes", "no", "na"] = "na"
    moment: Literal["leave", "return", "anytime"] = "anytime"
    predicted_utci_c: float | None = None
    client_key: str = Field("anon", max_length=64)


class ClimateFeedbackResponse(BaseModel):
    ok: bool = True
    suggested_feedback_offset_delta: float = 0.0
    place_offset_delta: float = 0.0
    feedback_offset: float | None = None
    feedback_count: int = 0
    message: str = ""


class ClimatePlanRequest(BaseModel):
    text: str = Field(..., min_length=3, max_length=500)
    city: str = Field(..., min_length=1, max_length=80)
    lat: float | None = None
    lon: float | None = None
    profile: ClimateProfileIn = Field(default_factory=ClimateProfileIn)
    lang: Literal["ru", "en"] = "ru"
    client_key: str = Field("anon", max_length=64)


class ClimatePlanParsed(BaseModel):
    activity: Literal["low", "moderate", "high"]
    duration_hours: float | None = None
    formality: Literal["casual", "smart", "formal", "unknown"] = "unknown"
    outdoor: bool = True
    summary: str
    source: Literal["llm", "rules"] = "rules"


class ClimatePlanResponse(BaseModel):
    parsed: ClimatePlanParsed
    today: ClimateTodayResponse


class ClimateAccountProfile(BaseModel):
    """Persisted per-user climate onboarding + calibration."""

    onboarded: bool = False
    city_name: str = "Москва"
    city_country: str = "Россия"
    city_country_code: str = "RU"
    lat: float | None = None
    lon: float | None = None
    cold_bias: float = 0.0
    heat_bias: float = 0.0
    activity: Literal["low", "moderate", "high"] = "moderate"
    age_band: Literal["under_30", "30_50", "over_50", "unknown"] = "unknown"
    sex: Literal["female", "male", "other", "unknown"] = "unknown"
    dress_bias: Literal["lighter", "typical", "warmer"] = "typical"
    acclimation: Literal["long", "recent", "temporary", "unknown"] = "unknown"
    vignette_sensation: Literal["cold", "ok", "warm", "unknown"] = "unknown"
    feedback_offset: float = 0.0
    feedback_count: int = 0
    habits: list[str] = Field(default_factory=list)
    allergies: list[str] = Field(default_factory=list)
    skin_note: str = ""
    leave_hour: int = 8
    return_hour: int = 19
    client_key: str = "anon"
