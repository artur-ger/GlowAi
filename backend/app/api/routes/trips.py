from __future__ import annotations

from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.db.models import Trip, User
from app.db.session import get_db
from app.schemas.trips import DailyTipOut, TripCreate, TripOut, TripStatusUpdate
from app.services.daily_tip import tip_from_climate
from app.services.weather import build_climate_summary

router = APIRouter(prefix="/api/v1/trips", tags=["trips"])


def _suggested_next(trip: Trip) -> str:
    today = date.today()
    start = None
    end = None
    try:
        if trip.trip_start:
            start = datetime.strptime(trip.trip_start[:10], "%Y-%m-%d").date()
        if trip.trip_end:
            end = datetime.strptime(trip.trip_end[:10], "%Y-%m-%d").date()
    except ValueError:
        pass

    if trip.status == "done":
        return "Поездка закрыта. Можно начать новую."
    if trip.status == "return_home":
        return "Сделайте план «Возврат домой» и check-in на 3–5 день."
    if trip.status == "on_site":
        return "Смотрите daily tip и при ухудшении — SOS / check-in."
    if start and today >= start and (end is None or today <= end):
        return "Похоже, вы уже на месте — переключите статус в «На месте»."
    if end and today > end:
        return "Даты поездки прошли — пора статус «Возврат домой»."
    return "До поездки: сохраните план и поставьте напоминание 48ч."


def _to_out(trip: Trip) -> TripOut:
    return TripOut(
        id=trip.id,
        home_city=trip.home_city,
        dest_city=trip.dest_city,
        home_lat=trip.home_lat,
        home_lon=trip.home_lon,
        dest_lat=trip.dest_lat,
        dest_lon=trip.dest_lon,
        trip_start=trip.trip_start or "",
        trip_end=trip.trip_end or "",
        status=trip.status,
        latest_check_id=trip.latest_check_id,
        is_active=trip.is_active,
        created_at=trip.created_at,
        updated_at=trip.updated_at,
        suggested_next=_suggested_next(trip),
    )


def _deactivate_others(db: Session, user_id: int, keep_id: int | None = None) -> None:
    rows = db.scalars(select(Trip).where(Trip.user_id == user_id, Trip.is_active.is_(True))).all()
    for t in rows:
        if keep_id is not None and t.id == keep_id:
            continue
        t.is_active = False


@router.get("", response_model=list[TripOut])
def list_trips(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[TripOut]:
    rows = db.scalars(select(Trip).where(Trip.user_id == user.id).order_by(Trip.id.desc())).all()
    return [_to_out(t) for t in rows]


@router.get("/active", response_model=TripOut | None)
def active_trip(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> TripOut | None:
    trip = db.scalar(
        select(Trip).where(Trip.user_id == user.id, Trip.is_active.is_(True)).order_by(Trip.id.desc())
    )
    return _to_out(trip) if trip else None


@router.post("", response_model=TripOut, status_code=201)
def create_trip(
    body: TripCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> TripOut:
    if body.set_active:
        _deactivate_others(db, user.id)
    trip = Trip(
        user_id=user.id,
        home_city=body.home_city.strip(),
        dest_city=body.dest_city.strip(),
        home_lat=body.home_lat,
        home_lon=body.home_lon,
        dest_lat=body.dest_lat,
        dest_lon=body.dest_lon,
        trip_start=(body.trip_start or "").strip(),
        trip_end=(body.trip_end or "").strip(),
        status=body.status,
        latest_check_id=body.latest_check_id,
        is_active=body.set_active,
    )
    db.add(trip)
    db.commit()
    db.refresh(trip)
    return _to_out(trip)


@router.patch("/{trip_id}/status", response_model=TripOut)
def update_status(
    trip_id: int,
    body: TripStatusUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> TripOut:
    trip = db.scalar(select(Trip).where(Trip.id == trip_id, Trip.user_id == user.id))
    if trip is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Поездка не найдена")
    trip.status = body.status
    if body.status == "done":
        trip.is_active = False
    else:
        trip.is_active = True
        _deactivate_others(db, user.id, keep_id=trip.id)
    db.commit()
    db.refresh(trip)
    return _to_out(trip)


@router.post("/{trip_id}/activate", response_model=TripOut)
def activate_trip(
    trip_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> TripOut:
    trip = db.scalar(select(Trip).where(Trip.id == trip_id, Trip.user_id == user.id))
    if trip is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Поездка не найдена")
    _deactivate_others(db, user.id, keep_id=trip.id)
    trip.is_active = True
    if trip.status == "done":
        trip.status = "on_site"
    db.commit()
    db.refresh(trip)
    return _to_out(trip)


@router.get("/{trip_id}/daily-tip", response_model=DailyTipOut)
async def daily_tip(
    trip_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> DailyTipOut:
    trip = db.scalar(select(Trip).where(Trip.id == trip_id, Trip.user_id == user.id))
    if trip is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Поездка не найдена")

    if trip.status == "return_home":
        city, lat, lon = trip.home_city, trip.home_lat, trip.home_lon
    else:
        city, lat, lon = trip.dest_city, trip.dest_lat, trip.dest_lon

    climate = await build_climate_summary(
        city or "город",
        city or "город",
        home_lat=lat,
        home_lon=lon,
        dest_lat=lat,
        dest_lon=lon,
        mode="sos",
    )
    return DailyTipOut(
        trip_id=trip.id,
        city=city,
        temp_c=climate.destination_temp_c,
        humidity=climate.destination_humidity,
        uv=climate.destination_uv,
        tip=tip_from_climate(climate, status=trip.status),
        window=climate.window,
    )
