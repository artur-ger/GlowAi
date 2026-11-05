from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.security import get_current_user, get_optional_user
from app.db.models import ClimateFeedbackEvent, User
from app.db.session import get_db
from app.schemas.climate import (
    ClimateAccountProfile,
    ClimateFeedbackRequest,
    ClimateFeedbackResponse,
    ClimatePlanRequest,
    ClimatePlanResponse,
    ClimateTodayRequest,
    ClimateTodayResponse,
)
from app.services import climate_profile as climate_profile_svc
from app.services.sensation import apply_feedback, build_plan_advice, build_today

router = APIRouter(prefix="/api/v1/climate", tags=["climate"])


@router.get("/profile", response_model=ClimateAccountProfile)
def get_climate_profile(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ClimateAccountProfile:
    row = climate_profile_svc.ensure_row(user)
    db.add(row)
    db.commit()
    db.refresh(user)
    return climate_profile_svc.to_out(user, row)


@router.put("/profile", response_model=ClimateAccountProfile)
def put_climate_profile(
    body: ClimateAccountProfile,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ClimateAccountProfile:
    row = climate_profile_svc.ensure_row(user)
    climate_profile_svc.apply_put(row, body)
    db.add(row)
    db.commit()
    db.refresh(user)
    assert user.climate_profile is not None
    return climate_profile_svc.to_out(user, user.climate_profile)


@router.post("/today", response_model=ClimateTodayResponse)
async def climate_today(
    body: ClimateTodayRequest,
    db: Session = Depends(get_db),
) -> ClimateTodayResponse:
    city = body.city.strip()
    if not city:
        raise HTTPException(status_code=422, detail="city is required")
    try:
        return await build_today(
            city=city,
            lat=body.lat,
            lon=body.lon,
            profile=body.profile,
            lang=body.lang,
            shade=body.shade,
            client_key=body.client_key,
            db=db,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"weather/UTCI failed: {exc}") from exc


@router.post("/feedback", response_model=ClimateFeedbackResponse)
async def climate_feedback(
    body: ClimateFeedbackRequest,
    db: Session = Depends(get_db),
    user: User | None = Depends(get_optional_user),
) -> ClimateFeedbackResponse:
    result = apply_feedback(body, db=db)
    client_key = body.client_key[:64]
    if user is not None:
        client_key = f"u{user.id}"
        row = climate_profile_svc.ensure_row(user)
        new_offset = float(row.feedback_offset or 0) + result.suggested_feedback_offset_delta
        row.feedback_offset = max(-5.0, min(5.0, new_offset))
        row.feedback_count = int(row.feedback_count or 0) + 1
        db.add(row)
        result.feedback_count = row.feedback_count
        result.feedback_offset = float(row.feedback_offset)
        result.suggested_feedback_offset_delta = round(
            result.suggested_feedback_offset_delta, 3
        )
        result.message = f"Stored; feedback_offset={row.feedback_offset:.3f}"
    event = ClimateFeedbackEvent(
        client_key=client_key,
        city=body.city.strip()[:120],
        lat=body.lat,
        lon=body.lon,
        predicted_sensation=body.predicted_sensation,
        actual_sensation=body.actual_sensation,
        worn_tier=body.worn_tier,
        look_preserved=body.look_preserved,
        moment=body.moment,
        predicted_utci_c=body.predicted_utci_c,
        offset_delta=result.suggested_feedback_offset_delta,
    )
    db.add(event)
    db.commit()
    if user is None:
        count = (
            db.query(ClimateFeedbackEvent)
            .filter(ClimateFeedbackEvent.client_key == client_key)
            .count()
        )
        result.feedback_count = count
        result.message = "Stored; apply suggested_feedback_offset_delta on client"
    return result


@router.post("/plan", response_model=ClimatePlanResponse)
async def climate_plan(
    body: ClimatePlanRequest,
    db: Session = Depends(get_db),
) -> ClimatePlanResponse:
    try:
        return await build_plan_advice(
            text=body.text,
            city=body.city.strip(),
            lat=body.lat,
            lon=body.lon,
            profile=body.profile,
            lang=body.lang,
            client_key=body.client_key,
            db=db,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"plan advice failed: {exc}") from exc
