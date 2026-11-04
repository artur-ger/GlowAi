from __future__ import annotations

from typing import Literal

from fastapi import APIRouter, File, Form, HTTPException, Request, UploadFile

from app.core.rate_limit import analyze_limiter, client_key
from app.schemas.analyze import AnalyzeResponse
from app.services.planner import build_analyze_response
from app.services.weather import build_climate_summary

router = APIRouter(prefix="/api/v1", tags=["analyze"])


def _opt_float(value: str | None) -> float | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    try:
        return float(text)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=f"Некорректная координата: {value}") from exc


@router.post("/analyze", response_model=AnalyzeResponse)
async def analyze(
    request: Request,
    home_city: str = Form(...),
    destination_city: str = Form(...),
    skin_type: str = Form(""),
    concerns: str = Form(""),
    trip_start: str = Form(""),
    trip_end: str = Form(""),
    mode: Literal["pre_trip", "sos", "return_home"] = Form("pre_trip"),
    home_lat: str = Form(""),
    home_lon: str = Form(""),
    dest_lat: str = Form(""),
    dest_lon: str = Form(""),
    owned_items: str = Form(""),
    avoid_items: str = Form(""),
    photo: UploadFile | None = File(None),
) -> AnalyzeResponse:
    analyze_limiter.check(client_key(request))

    if not home_city.strip() or not destination_city.strip():
        raise HTTPException(status_code=422, detail="home_city и destination_city обязательны")

    photo_bytes: bytes | None = None
    photo_mime = "image/jpeg"
    if photo is not None and photo.filename:
        photo_bytes = await photo.read()
        if len(photo_bytes) > 8 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="Фото больше 8 МБ")
        photo_mime = photo.content_type or "image/jpeg"

    # return_home: климат «откуда были» → «домой»
    climate_home = home_city.strip()
    climate_dest = destination_city.strip()
    c_home_lat, c_home_lon = _opt_float(home_lat), _opt_float(home_lon)
    c_dest_lat, c_dest_lon = _opt_float(dest_lat), _opt_float(dest_lon)
    weather_mode = mode
    if mode == "return_home":
        climate_home, climate_dest = climate_dest, climate_home
        c_home_lat, c_dest_lat = c_dest_lat, c_home_lat
        c_home_lon, c_dest_lon = c_dest_lon, c_home_lon
        weather_mode = "sos"  # актуальная погода для адаптации сейчас

    try:
        climate = await build_climate_summary(
            climate_home,
            climate_dest,
            home_lat=c_home_lat,
            home_lon=c_home_lon,
            dest_lat=c_dest_lat,
            dest_lon=c_dest_lon,
            trip_start=trip_start.strip() if mode == "pre_trip" else "",
            trip_end=trip_end.strip() if mode == "pre_trip" else "",
            mode=weather_mode,
        )
        if mode == "return_home":
            climate.window_note = (
                f"Возврат домой: сравнение климата поездки ({climate.home_city}) "
                f"→ дом ({climate.destination_city}). {climate.window_note}"
            ).strip()
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Ошибка климатических данных: {exc}") from exc

    try:
        return await build_analyze_response(
            mode=mode,
            climate=climate,
            skin_type=skin_type.strip(),
            concerns=concerns.strip(),
            trip_start=trip_start.strip(),
            trip_end=trip_end.strip(),
            photo_bytes=photo_bytes,
            photo_mime=photo_mime,
            owned_items=owned_items.strip(),
            avoid_items=avoid_items.strip(),
        )
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Ошибка построения плана: {exc}") from exc
