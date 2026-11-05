from __future__ import annotations

from app.db.models import ClimateUserProfile, User
from app.schemas.climate import ClimateAccountProfile


def _split(csv: str) -> list[str]:
    return [p.strip() for p in (csv or "").split(",") if p.strip()]


def _join(items: list[str] | None, *, limit: int = 500) -> str:
    if not items:
        return ""
    return ", ".join(x.strip() for x in items if x.strip())[:limit]


def ensure_row(user: User) -> ClimateUserProfile:
    if user.climate_profile is not None:
        return user.climate_profile
    row = ClimateUserProfile(user_id=user.id, onboarded=False)
    user.climate_profile = row
    return row


def to_out(user: User, row: ClimateUserProfile) -> ClimateAccountProfile:
    return ClimateAccountProfile(
        onboarded=bool(row.onboarded),
        city_name=row.city_name or "Москва",
        city_country=row.city_country or "Россия",
        city_country_code=row.city_country_code or "RU",
        lat=row.lat,
        lon=row.lon,
        cold_bias=float(row.cold_bias or 0),
        heat_bias=float(row.heat_bias or 0),
        activity=row.activity or "moderate",  # type: ignore[arg-type]
        age_band=row.age_band or "unknown",  # type: ignore[arg-type]
        sex=row.sex or "unknown",  # type: ignore[arg-type]
        feedback_offset=float(row.feedback_offset or 0),
        feedback_count=int(row.feedback_count or 0),
        habits=_split(row.habits_csv),
        allergies=_split(row.allergies_csv),
        skin_note=row.skin_note or "",
        leave_hour=int(row.leave_hour if row.leave_hour is not None else 8),
        return_hour=int(row.return_hour if row.return_hour is not None else 19),
        client_key=f"u{user.id}",
    )


def apply_put(row: ClimateUserProfile, body: ClimateAccountProfile) -> None:
    row.onboarded = bool(body.onboarded)
    row.city_name = body.city_name.strip()[:120] or "Москва"
    row.city_country = body.city_country.strip()[:120] or "Россия"
    row.city_country_code = body.city_country_code.strip()[:8] or "RU"
    row.lat = body.lat
    row.lon = body.lon
    row.cold_bias = float(body.cold_bias)
    row.heat_bias = float(body.heat_bias)
    row.activity = body.activity
    row.age_band = body.age_band
    row.sex = body.sex
    row.feedback_offset = max(-5.0, min(5.0, float(body.feedback_offset)))
    row.feedback_count = max(0, int(body.feedback_count))
    row.habits_csv = _join(body.habits)
    row.allergies_csv = _join(body.allergies)
    row.skin_note = (body.skin_note or "")[:120]
    row.leave_hour = int(body.leave_hour)
    row.return_hour = int(body.return_hour)
