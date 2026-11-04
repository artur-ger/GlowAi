from __future__ import annotations

import logging
from datetime import date, datetime, timedelta
from statistics import mean
from typing import Any

import httpx

from app.core.config import settings
from app.schemas.analyze import ClimateSummary

logger = logging.getLogger(__name__)

# Open-Meteo forecast daily horizon is typically ~16 days.
_FORECAST_HORIZON_DAYS = 16


async def _geocode_open_meteo(city: str) -> tuple[float, float, str] | None:
    url = "https://geocoding-api.open-meteo.com/v1/search"
    params = {"name": city, "count": 1, "language": "ru", "format": "json"}
    async with httpx.AsyncClient(timeout=20.0) as client:
        response = await client.get(url, params=params)
        response.raise_for_status()
        data = response.json()
    results = data.get("results") or []
    if not results:
        return None
    item = results[0]
    name = item.get("name") or city
    return float(item["latitude"]), float(item["longitude"]), str(name)


async def _geocode_google(city: str) -> tuple[float, float, str] | None:
    if not settings.google_maps_api_key:
        return None
    url = "https://maps.googleapis.com/maps/api/geocode/json"
    params = {"address": city, "key": settings.google_maps_api_key, "language": "ru"}
    async with httpx.AsyncClient(timeout=20.0) as client:
        response = await client.get(url, params=params)
        response.raise_for_status()
        data = response.json()
    results = data.get("results") or []
    if not results:
        return None
    loc = results[0]["geometry"]["location"]
    name = results[0].get("formatted_address") or city
    return float(loc["lat"]), float(loc["lng"]), str(name)


async def geocode_city(city: str) -> tuple[float, float, str]:
    for resolver in (_geocode_google, _geocode_open_meteo):
        try:
            hit = await resolver(city)
            if hit is not None:
                return hit
        except Exception:
            logger.exception("Geocode failed via %s for %s", resolver.__name__, city)
    raise ValueError(f"Не удалось найти город: {city}")


async def _resolve_place(
    city: str,
    *,
    lat: float | None,
    lon: float | None,
) -> tuple[float, float, str]:
    """Coords from client skip re-geocoding (stable climate for Анталья/Antalya)."""
    if lat is not None and lon is not None:
        return float(lat), float(lon), city.strip() or "место"
    return await geocode_city(city)


def _as_float(value: object) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _parse_iso_date(value: str | None) -> date | None:
    text = (value or "").strip()
    if not text:
        return None
    try:
        return datetime.strptime(text[:10], "%Y-%m-%d").date()
    except ValueError:
        return None


def _avg(values: list[float | None]) -> float | None:
    nums = [v for v in values if v is not None]
    if not nums:
        return None
    return round(float(mean(nums)), 1)


def _from_daily_payload(data: dict[str, Any]) -> dict[str, float | None]:
    daily = data.get("daily") or {}
    tmax = [_as_float(v) for v in (daily.get("temperature_2m_max") or [])]
    tmin = [_as_float(v) for v in (daily.get("temperature_2m_min") or [])]
    temps: list[float | None] = []
    for hi, lo in zip(tmax, tmin, strict=False):
        if hi is not None and lo is not None:
            temps.append((hi + lo) / 2.0)
        elif hi is not None:
            temps.append(hi)
        elif lo is not None:
            temps.append(lo)
    humidity = [_as_float(v) for v in (daily.get("relative_humidity_2m_mean") or [])]
    if not any(v is not None for v in humidity):
        humidity = [_as_float(v) for v in (daily.get("relative_humidity_2m_max") or [])]
    uv = [_as_float(v) for v in (daily.get("uv_index_max") or [])]
    return {
        "temp": _avg(temps),
        "humidity": _avg(humidity),
        "uv": _avg(uv),
    }


async def _current_snapshot(lat: float, lon: float) -> dict[str, float | None]:
    url = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude": lat,
        "longitude": lon,
        "current": "temperature_2m,relative_humidity_2m,uv_index",
        "timezone": "auto",
    }
    async with httpx.AsyncClient(timeout=20.0) as client:
        response = await client.get(url, params=params)
        response.raise_for_status()
        data = response.json()
    current = data.get("current") or {}
    return {
        "temp": _as_float(current.get("temperature_2m")),
        "humidity": _as_float(current.get("relative_humidity_2m")),
        "uv": _as_float(current.get("uv_index")),
    }


async def _daily_forecast_range(
    lat: float, lon: float, start: date, end: date
) -> dict[str, float | None]:
    url = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude": lat,
        "longitude": lon,
        "start_date": start.isoformat(),
        "end_date": end.isoformat(),
        "daily": "temperature_2m_max,temperature_2m_min,relative_humidity_2m_mean,uv_index_max",
        "timezone": "auto",
    }
    async with httpx.AsyncClient(timeout=25.0) as client:
        response = await client.get(url, params=params)
        response.raise_for_status()
        data = response.json()
    return _from_daily_payload(data)


async def _archive_range(
    lat: float, lon: float, start: date, end: date
) -> dict[str, float | None]:
    url = "https://archive-api.open-meteo.com/v1/archive"
    params = {
        "latitude": lat,
        "longitude": lon,
        "start_date": start.isoformat(),
        "end_date": end.isoformat(),
        "daily": "temperature_2m_max,temperature_2m_min,relative_humidity_2m_mean,uv_index_max",
        "timezone": "auto",
    }
    async with httpx.AsyncClient(timeout=25.0) as client:
        response = await client.get(url, params=params)
        response.raise_for_status()
        data = response.json()
    return _from_daily_payload(data)


def _shift_year(d: date, years: int) -> date:
    try:
        return d.replace(year=d.year + years)
    except ValueError:
        # Feb 29 → Feb 28
        return d.replace(month=2, day=28, year=d.year + years)


async def _metrics_for_window(
    lat: float,
    lon: float,
    *,
    trip_start: date | None,
    trip_end: date | None,
    prefer_current: bool,
) -> tuple[dict[str, float | None], str, str]:
    """
    Returns (metrics, window_kind, window_note).
    window_kind: current | forecast | seasonal_proxy
    """
    today = date.today()
    if prefer_current or trip_start is None or trip_end is None:
        snap = await _current_snapshot(lat, lon)
        return (
            snap,
            "current",
            "актуальная погода сейчас (режим SOS / без дат)",
        )

    start = trip_start
    end = trip_end if trip_end >= trip_start else trip_start
    # Cap window length for API sanity
    if (end - start).days > 21:
        end = start + timedelta(days=21)

    horizon_end = today + timedelta(days=_FORECAST_HORIZON_DAYS)
    if start >= today and end <= horizon_end:
        data = await _daily_forecast_range(lat, lon, start, end)
        return (
            data,
            "forecast",
            f"прогноз Open-Meteo на даты поездки {start.isoformat()} → {end.isoformat()}",
        )

    # Far future or past: same calendar days previous year (seasonal proxy)
    proxy_start = _shift_year(start, -1)
    proxy_end = _shift_year(end, -1)
    # Archive needs completed days — if last year still "in future" relative to API, go -2y
    if proxy_end >= today - timedelta(days=2):
        proxy_start = _shift_year(start, -2)
        proxy_end = _shift_year(end, -2)
    data = await _archive_range(lat, lon, proxy_start, proxy_end)
    return (
        data,
        "seasonal_proxy",
        (
            f"сезонный ориентир по архиву {proxy_start.isoformat()} → {proxy_end.isoformat()} "
            f"(аналог дат поездки {start.isoformat()} → {end.isoformat()})"
        ),
    )


def _climate_risks(
    *,
    delta_temp: float | None,
    delta_humidity: float | None,
    dest_uv: float | None,
) -> list[str]:
    risks: list[str] = []
    if delta_temp is not None and delta_temp >= 8:
        risks.append("резкое потепление — риск обезвоживания и жирного блеска")
    if delta_temp is not None and delta_temp <= -8:
        risks.append("похолодание — риск сухости и стянутости")
    if delta_humidity is not None and delta_humidity <= -20:
        risks.append("падение влажности — усилить увлажнение и барьер")
    if delta_humidity is not None and delta_humidity >= 20:
        risks.append("рост влажности — риск воспалений и тяжести средств")
    if dest_uv is not None and dest_uv >= 6:
        risks.append("высокий UV — обязателен SPF и повторные нанесения")
    if not risks:
        risks.append("умеренный климатический сдвиг — лёгкая адаптация рутины")
    return risks


async def build_climate_summary(
    home_city: str,
    destination_city: str,
    *,
    home_lat: float | None = None,
    home_lon: float | None = None,
    dest_lat: float | None = None,
    dest_lon: float | None = None,
    trip_start: str = "",
    trip_end: str = "",
    mode: str = "pre_trip",
) -> ClimateSummary:
    home_lat_r, home_lon_r, home_name = await _resolve_place(
        home_city, lat=home_lat, lon=home_lon
    )
    dest_lat_r, dest_lon_r, dest_name = await _resolve_place(
        destination_city, lat=dest_lat, lon=dest_lon
    )

    start = _parse_iso_date(trip_start)
    end = _parse_iso_date(trip_end)
    prefer_current = (mode or "").strip().lower() == "sos"

    home, home_kind, home_note = await _metrics_for_window(
        home_lat_r,
        home_lon_r,
        trip_start=start,
        trip_end=end,
        prefer_current=True,  # home baseline = сейчас у пользователя
    )
    dest, dest_kind, dest_note = await _metrics_for_window(
        dest_lat_r,
        dest_lon_r,
        trip_start=start,
        trip_end=end,
        prefer_current=prefer_current,
    )

    delta_temp = None
    if home["temp"] is not None and dest["temp"] is not None:
        delta_temp = round(dest["temp"] - home["temp"], 1)
    delta_humidity = None
    if home["humidity"] is not None and dest["humidity"] is not None:
        delta_humidity = round(dest["humidity"] - home["humidity"], 1)

    used_client_coords = all(
        v is not None for v in (home_lat, home_lon, dest_lat, dest_lon)
    )
    source = "open-meteo"
    if used_client_coords:
        source += "+client-coords"
    elif settings.google_maps_api_key:
        source += "+google-geocode"
    source += f"+{dest_kind}"

    window_note = (
        f"Дом: {home_note}. Направление: {dest_note}."
        if dest_kind != home_kind
        else dest_note
    )

    return ClimateSummary(
        home_city=home_name,
        destination_city=dest_name,
        home_temp_c=home["temp"],
        destination_temp_c=dest["temp"],
        home_humidity=home["humidity"],
        destination_humidity=dest["humidity"],
        home_uv=home["uv"],
        destination_uv=dest["uv"],
        delta_temp_c=delta_temp,
        delta_humidity=delta_humidity,
        risks=_climate_risks(
            delta_temp=delta_temp,
            delta_humidity=delta_humidity,
            dest_uv=dest["uv"],
        ),
        source=source,
        window=dest_kind,
        window_note=window_note,
    )
