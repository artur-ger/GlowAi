from __future__ import annotations

import json
from datetime import UTC, datetime, timedelta
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.db.models import SkinCheck, SkinCheckIn, Trip, User
from app.db.session import get_db
from app.schemas.checks import (
    CheckCreateRequest,
    CheckDetail,
    CheckInOut,
    CheckInRequest,
    CheckListItem,
    RemindRequest,
)
from app.services.checkin_advice import advice_from_scores, needs_sos, revise_payload_from_checkin
from app.services.mailer import send_followup_reminder

router = APIRouter(prefix="/api/v1/checks", tags=["checks"])


def _engine_from_payload(payload: dict[str, Any]) -> str:
    skin = payload.get("skin") or {}
    if isinstance(skin, dict) and skin.get("engine"):
        return str(skin["engine"])
    return str(payload.get("provider") or "rule_based")


def _summary_from_payload(payload: dict[str, Any]) -> str:
    return str(payload.get("forecast_summary") or "")[:500]


def _owned_check(db: Session, user: User, check_id: int) -> SkinCheck:
    check = db.scalar(select(SkinCheck).where(SkinCheck.id == check_id, SkinCheck.user_id == user.id))
    if check is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Проверка не найдена")
    return check


def _to_detail(check: SkinCheck, payload: dict[str, Any] | None = None) -> CheckDetail:
    if payload is None:
        try:
            raw = json.loads(check.payload_json)
            payload = raw if isinstance(raw, dict) else {}
        except json.JSONDecodeError:
            payload = {}
    return CheckDetail(
        id=check.id,
        created_at=check.created_at,
        mode=check.mode,
        home_city=check.home_city,
        dest_city=check.dest_city,
        forecast_summary=check.forecast_summary,
        engine=check.engine,
        parent_check_id=check.parent_check_id,
        trip_id=check.trip_id,
        remind_at=check.remind_at,
        payload=payload or {},
    )


def _to_list_item(r: SkinCheck) -> CheckListItem:
    return CheckListItem(
        id=r.id,
        created_at=r.created_at,
        mode=r.mode,
        home_city=r.home_city,
        dest_city=r.dest_city,
        forecast_summary=r.forecast_summary,
        engine=r.engine,
        parent_check_id=r.parent_check_id,
        trip_id=r.trip_id,
        remind_at=r.remind_at,
    )


def _ensure_trip_for_check(
    db: Session,
    user: User,
    *,
    home: str,
    dest: str,
    mode: str,
    check_id: int,
    trip_id: int | None,
    attach_active: bool,
    payload: dict[str, Any],
) -> int | None:
    if trip_id is not None:
        trip = db.scalar(select(Trip).where(Trip.id == trip_id, Trip.user_id == user.id))
        if trip is None:
            raise HTTPException(status_code=404, detail="Поездка не найдена")
        trip.latest_check_id = check_id
        if mode == "sos":
            trip.status = "on_site"
        elif mode == "return_home":
            trip.status = "return_home"
        elif mode == "pre_trip" and trip.status == "done":
            trip.status = "pre_trip"
        trip.is_active = True
        others = db.scalars(
            select(Trip).where(Trip.user_id == user.id, Trip.is_active.is_(True), Trip.id != trip.id)
        ).all()
        for t in others:
            t.is_active = False
        return trip.id

    if not attach_active:
        return None

    active = db.scalar(
        select(Trip).where(Trip.user_id == user.id, Trip.is_active.is_(True)).order_by(Trip.id.desc())
    )
    status = "pre_trip"
    if mode == "sos":
        status = "on_site"
    elif mode == "return_home":
        status = "return_home"

    trip_start = str(payload.get("trip_start") or "")
    trip_end = str(payload.get("trip_end") or "")
    climate = payload.get("climate") if isinstance(payload.get("climate"), dict) else {}

    if active and active.home_city == home and active.dest_city == dest:
        active.latest_check_id = check_id
        active.status = status
        return active.id

    if active:
        active.is_active = False

    trip = Trip(
        user_id=user.id,
        home_city=home,
        dest_city=dest,
        home_lat=(climate.get("home_lat") if isinstance(climate.get("home_lat"), (int, float)) else None),
        home_lon=(climate.get("home_lon") if isinstance(climate.get("home_lon"), (int, float)) else None),
        dest_lat=(
            climate.get("destination_lat")
            if isinstance(climate.get("destination_lat"), (int, float))
            else None
        ),
        dest_lon=(
            climate.get("destination_lon")
            if isinstance(climate.get("destination_lon"), (int, float))
            else None
        ),
        trip_start=trip_start,
        trip_end=trip_end,
        status=status,
        latest_check_id=check_id,
        is_active=True,
    )
    db.add(trip)
    db.flush()
    return trip.id


@router.post("", response_model=CheckDetail, status_code=201)
def create_check(
    body: CheckCreateRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CheckDetail:
    payload = body.payload
    climate = payload.get("climate") if isinstance(payload.get("climate"), dict) else {}
    home = body.home_city or str(climate.get("home_city") or "")
    dest = body.dest_city or str(climate.get("destination_city") or "")
    mode = body.mode or str(payload.get("mode") or "pre_trip")
    parent_id = body.parent_check_id
    if parent_id is not None:
        _owned_check(db, user, parent_id)
    remind_at = None
    if body.remind_in_hours:
        remind_at = datetime.now(UTC) + timedelta(hours=body.remind_in_hours)
    check = SkinCheck(
        user_id=user.id,
        parent_check_id=parent_id,
        mode=mode,
        home_city=home,
        dest_city=dest,
        forecast_summary=_summary_from_payload(payload),
        engine=_engine_from_payload(payload),
        payload_json=json.dumps(payload, ensure_ascii=False),
        remind_at=remind_at,
        remind_sent_at=None,
    )
    db.add(check)
    db.flush()
    trip_id = _ensure_trip_for_check(
        db,
        user,
        home=home,
        dest=dest,
        mode=mode,
        check_id=check.id,
        trip_id=body.trip_id,
        attach_active=body.attach_active_trip,
        payload=payload if isinstance(payload, dict) else {},
    )
    check.trip_id = trip_id
    # Persist skin memory from payload if present
    skin = payload.get("skin") if isinstance(payload.get("skin"), dict) else {}
    if payload.get("owned_items"):
        owned = payload.get("owned_items")
        if isinstance(owned, list):
            user.owned_items_csv = ", ".join(str(x) for x in owned)[:500]
    if payload.get("avoid_items"):
        avoid = payload.get("avoid_items")
        if isinstance(avoid, list):
            user.avoid_items_csv = ", ".join(str(x) for x in avoid)[:500]
    db.commit()
    db.refresh(check)
    return _to_detail(check, payload)


@router.get("", response_model=list[CheckListItem])
def list_checks(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[CheckListItem]:
    rows = db.scalars(
        select(SkinCheck).where(SkinCheck.user_id == user.id).order_by(SkinCheck.id.desc())
    ).all()
    return [_to_list_item(r) for r in rows]


@router.get("/due", response_model=list[CheckListItem])
def list_due_checks(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[CheckListItem]:
    now = datetime.now(UTC)
    rows = db.scalars(
        select(SkinCheck)
        .where(
            SkinCheck.user_id == user.id,
            SkinCheck.remind_at.is_not(None),
            SkinCheck.remind_at <= now,
        )
        .order_by(SkinCheck.remind_at.asc())
    ).all()
    return [_to_list_item(r) for r in rows]


@router.get("/{check_id}", response_model=CheckDetail)
def get_check(
    check_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CheckDetail:
    return _to_detail(_owned_check(db, user, check_id))


@router.delete("/{check_id}", status_code=204)
def delete_check(
    check_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    check = _owned_check(db, user, check_id)
    db.delete(check)
    db.commit()
    return None


@router.post("/{check_id}/remind", response_model=CheckDetail)
def set_reminder(
    check_id: int,
    body: RemindRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CheckDetail:
    check = _owned_check(db, user, check_id)
    check.remind_at = datetime.now(UTC) + timedelta(hours=body.hours)
    check.remind_sent_at = None
    db.commit()
    db.refresh(check)
    return _to_detail(check)


@router.post("/{check_id}/remind/send", response_model=dict[str, object])
def send_reminder_now(
    check_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, object]:
    check = _owned_check(db, user, check_id)
    try:
        sent = send_followup_reminder(user.email, check.dest_city or "поездка", check.id)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Не удалось отправить напоминание: {exc}") from exc
    if check.remind_at is None:
        check.remind_at = datetime.now(UTC)
        db.commit()
    return {"sent": sent, "check_id": check.id, "email": user.email}


@router.post("/{check_id}/checkin", response_model=CheckInOut, status_code=201)
def create_checkin(
    check_id: int,
    body: CheckInRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CheckInOut:
    check = _owned_check(db, user, check_id)
    try:
        payload = json.loads(check.payload_json)
    except json.JSONDecodeError:
        payload = {}
    if not isinstance(payload, dict):
        payload = {}

    advice = advice_from_scores(
        dryness=body.dryness,
        oiliness=body.oiliness,
        calmness=body.calmness,
        redness=body.redness,
        note=body.note,
        check_payload=payload,
    )
    revised = revise_payload_from_checkin(
        payload,
        dryness=body.dryness,
        oiliness=body.oiliness,
        calmness=body.calmness,
        redness=body.redness,
        note=body.note,
    )
    child = SkinCheck(
        user_id=user.id,
        trip_id=check.trip_id,
        parent_check_id=check.id,
        mode=str(revised.get("mode") or "sos"),
        home_city=check.home_city,
        dest_city=check.dest_city,
        forecast_summary=_summary_from_payload(revised),
        engine=_engine_from_payload(revised),
        payload_json=json.dumps(revised, ensure_ascii=False),
    )
    db.add(child)
    db.flush()

    row = SkinCheckIn(
        check_id=check.id,
        dryness=body.dryness,
        oiliness=body.oiliness,
        calmness=body.calmness,
        redness=body.redness,
        note=(body.note or "").strip(),
        advice=advice,
        revised_check_id=child.id,
    )
    db.add(row)
    check.remind_at = None
    if check.trip_id:
        trip = db.get(Trip, check.trip_id)
        if trip and trip.user_id == user.id:
            trip.latest_check_id = child.id
            if needs_sos(
                dryness=body.dryness,
                oiliness=body.oiliness,
                calmness=body.calmness,
                redness=body.redness,
            ):
                trip.status = "on_site"
    db.commit()
    db.refresh(row)
    return CheckInOut(
        id=row.id,
        check_id=row.check_id,
        dryness=row.dryness,
        oiliness=row.oiliness,
        calmness=row.calmness,
        redness=row.redness,
        note=row.note,
        advice=row.advice,
        revised_check_id=row.revised_check_id,
        revised_payload=revised,
        suggest_sos=needs_sos(
            dryness=body.dryness,
            oiliness=body.oiliness,
            calmness=body.calmness,
            redness=body.redness,
        ),
        created_at=row.created_at,
    )


@router.get("/{check_id}/checkins", response_model=list[CheckInOut])
def list_checkins(
    check_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[CheckInOut]:
    _owned_check(db, user, check_id)
    rows = db.scalars(
        select(SkinCheckIn).where(SkinCheckIn.check_id == check_id).order_by(SkinCheckIn.id.desc())
    ).all()
    return [
        CheckInOut(
            id=r.id,
            check_id=r.check_id,
            dryness=r.dryness,
            oiliness=r.oiliness,
            calmness=r.calmness,
            redness=r.redness,
            note=r.note,
            advice=r.advice,
            revised_check_id=r.revised_check_id,
            suggest_sos=needs_sos(
                dryness=r.dryness, oiliness=r.oiliness, calmness=r.calmness, redness=r.redness
            ),
            created_at=r.created_at,
        )
        for r in rows
    ]
