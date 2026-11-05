from __future__ import annotations

import asyncio
import logging
import re
from datetime import datetime
from typing import Any

import httpx
from sqlalchemy.orm import Session

from app.db.models import ClimateFeedbackEvent, ClimatePlaceOffset
from app.schemas.climate import (
    CareItem,
    ClimateFeedbackRequest,
    ClimateFeedbackResponse,
    ClimatePlanParsed,
    ClimatePlanResponse,
    ClimateProfileIn,
    ClimateTodayResponse,
    ClothingItem,
    FeedbackWindow,
    HourlySensation,
    SupportIndicesOut,
)
from app.services import climate_llm
from app.services.mixed_ordinal import (
    feedback_random_delta,
    place_static_prior,
    predict as mixed_predict,
)
from app.services.thermal_indices import clothing_rows_for_clo, compute_support
from app.services.utci import compute_utci
from app.services.weather import geocode_city

logger = logging.getLogger(__name__)

_DISCLAIMER_RU = (
    "Рекомендации по комфорту на базе UTCI + смешанной порядковой модели, не медицинские советы. "
    "GlowAi не является медицинской услугой и не ставит диагноз."
)
_DISCLAIMER_EN = (
    "Comfort guidance based on UTCI + mixed ordinal model — not medical advice. "
    "GlowAi is not a medical service and does not diagnose."
)

_LABELS_RU = {
    -3: "очень холодно",
    -2: "холодно",
    -1: "прохладно",
    0: "комфортно",
    1: "тепло",
    2: "жарко",
    3: "очень жарко",
}
_LABELS_EN = {
    -3: "very cold",
    -2: "cold",
    -1: "cool",
    0: "comfortable",
    1: "warm",
    2: "hot",
    3: "very hot",
}


def _as_float(value: object) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _labels(lang: str) -> dict[int, str]:
    return _LABELS_EN if lang == "en" else _LABELS_RU


def place_key(lat: float, lon: float) -> str:
    return f"{round(lat, 2)}_{round(lon, 2)}"


def clothing_from_ireq(ireq_clo: float, lang: str) -> list[ClothingItem]:
    rows = clothing_rows_for_clo(ireq_clo, lang)
    return [
        ClothingItem(item=label, layer=layer, clo=clo_i, catalog_id=cid)  # type: ignore[arg-type]
        for cid, label, layer, clo_i in rows
    ]


def look_fail_boost(
    db: Session | None,
    *,
    client_key: str,
    city: str,
    lat: float | None,
    lon: float | None,
) -> int:
    """Extra appearance risk from recent look_preserved=no in the same place."""
    if db is None or not client_key:
        return 0
    rows = (
        db.query(ClimateFeedbackEvent)
        .filter(ClimateFeedbackEvent.client_key == client_key[:64])
        .filter(ClimateFeedbackEvent.look_preserved == "no")
        .order_by(ClimateFeedbackEvent.id.desc())
        .limit(8)
        .all()
    )
    fails = 0
    city_l = (city or "").strip().lower()
    for ev in rows:
        same_city = bool(city_l and (ev.city or "").strip().lower() == city_l)
        same_place = False
        if lat is not None and lon is not None and ev.lat is not None and ev.lon is not None:
            same_place = abs(float(ev.lat) - lat) < 0.2 and abs(float(ev.lon) - lon) < 0.2
        if same_city or same_place:
            fails += 1
    if fails >= 2:
        return 2
    if fails == 1:
        return 1
    return 0


def care_for(
    *,
    utci_c: float,
    uv: float | None,
    wind: float | None,
    humidity: float | None,
    precip: float | None,
    lang: str,
    allergies: list[str] | None = None,
    habits: list[str] | None = None,
    appearance_risk: int = 0,
    look_boost: int = 0,
) -> list[CareItem]:
    ru = lang != "en"
    allergies = [a.lower() for a in (allergies or [])]
    habits = [h.lower() for h in (habits or [])]
    out: list[CareItem] = []

    def add(cid: str, item_ru: str, item_en: str, reason_ru: str, reason_en: str) -> None:
        out.append(
            CareItem(
                item=item_ru if ru else item_en,
                reason=reason_ru if ru else reason_en,
                catalog_id=cid,
            )
        )

    if uv is not None and uv >= 5:
        add("spf", "Солнцезащитный крем SPF 30+", "SPF 30+", "UV ≥ 5", "UV≥5")
    if wind is not None and wind >= 8:
        add("wind_balm", "Бальзам / барьер от ветра", "Wind balm / barrier", "ветер ≥ 8 м/с", "wind≥8 m/s")
    if humidity is not None and humidity <= 35:
        add("moisturizer", "Увлажняющее средство", "Moisturizer", "влажность ≤ 35%", "RH≤35%")
    if precip is not None and precip >= 0.2:
        add("rain_gear", "Дождевик / зонт", "Rain jacket / umbrella", "осадки", "precipitation")
    if utci_c >= 32:
        add("water", "Вода / электролиты", "Water / electrolytes", "тепловой стресс UTCI", "heat stress")
    if utci_c <= 0:
        add("lip_balm", "Бальзам для губ", "Lip balm", "холодной стресс UTCI", "cold stress")
    if utci_c >= 26 and (humidity or 0) >= 60:
        add("repellent", "Репеллент (если актуально)", "Insect repellent (if local)", "тепло и влажность", "warm humid")
    if appearance_risk >= 2 or look_boost >= 1:
        add(
            "hood_fixative",
            "Капюшон / фиксатор для укладки",
            "Hood / hair fixative",
            "риск для образа / прошлый «образ не сохранился»"
            if look_boost
            else "риск для образа",
            "look risk / prior look not preserved" if look_boost else "look risk",
        )
    if look_boost >= 2:
        add(
            "compact_kit",
            "Мини-набор: салфетки + фиксатор",
            "Compact kit: wipes + fixative",
            "повторный сбой образа в этом городе",
            "repeat look fail in this city",
        )
    if any("пыльц" in a or "pollen" in a for a in allergies):
        add(
            "moisturizer",
            "Барьерный крем (пыльца)",
            "Barrier cream (pollen)",
            "аллергия: пыльца",
            "allergy: pollen",
        )
    if any("солн" in a or "sun" in a for a in allergies):
        add("spf", "SPF / защита от солнца", "SPF / sun barrier", "фоточувствительность", "sun sensitivity")
    if any("спорт" in h or "run" in h or "бег" in h for h in habits):
        add("water", "Вода на выход", "Water for outing", "привычка: спорт", "habit: sport")
    if not out:
        add("basic_moist", "Базовое увлажнение", "Basic moisturizer", "базовый уход", "routine")
    # de-dupe by catalog_id keeping first
    seen: set[str] = set()
    deduped: list[CareItem] = []
    for c in out:
        key = c.catalog_id or c.item
        if key in seen:
            continue
        seen.add(key)
        deduped.append(c)
    return deduped


def appearance_risk(
    *,
    wind: float | None,
    humidity: float | None,
    utci_c: float,
    uv: float | None,
    precip: float | None,
    lang: str,
) -> tuple[int, str]:
    score = 0
    if wind is not None and wind >= 7:
        score += 1
    if wind is not None and wind >= 12:
        score += 1
    if humidity is not None and humidity >= 75:
        score += 1
    if utci_c >= 32:
        score += 1
    if uv is not None and uv >= 7:
        score += 1
    if precip is not None and precip >= 0.5:
        score += 1
    score = min(3, score)
    notes = {
        0: ("low look risk", "низкий риск для образа"),
        1: ("watch hair / light makeup", "следите за укладкой и лёгким макияжем"),
        2: ("wind/rain/humidity may spoil look", "ветер/дождь/влажность могут испортить образ"),
        3: ("high risk — fixative, hood, compact kit", "высокий риск — фиксатор, капюшон, мини-набор"),
    }
    en_n, ru_n = notes[score]
    return score, ru_n if lang != "en" else en_n


async def _forecast_bundle(lat: float, lon: float) -> dict[str, Any]:
    url = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude": lat,
        "longitude": lon,
        "current": (
            "temperature_2m,relative_humidity_2m,wind_speed_10m,"
            "uv_index,shortwave_radiation,precipitation"
        ),
        "hourly": (
            "temperature_2m,relative_humidity_2m,wind_speed_10m,"
            "shortwave_radiation,precipitation,uv_index"
        ),
        "forecast_hours": 24,
        "wind_speed_unit": "ms",
        "timezone": "auto",
    }
    async with httpx.AsyncClient(timeout=25.0) as client:
        response = await client.get(url, params=params)
        response.raise_for_status()
        primary = response.json()
        params2 = dict(params)
        params2["models"] = "gfs_seamless"
        try:
            r2 = await client.get(url, params=params2)
            r2.raise_for_status()
            secondary = r2.json()
        except Exception:
            logger.exception("secondary weather model failed")
            secondary = None
        elevation = _as_float(primary.get("elevation"))
    return {"primary": primary, "secondary": secondary, "elevation": elevation}


def _model_spread_c(primary: dict[str, Any], secondary: dict[str, Any] | None) -> float | None:
    if not secondary:
        return None
    t1 = _as_float((primary.get("current") or {}).get("temperature_2m"))
    t2 = _as_float((secondary.get("current") or {}).get("temperature_2m"))
    if t1 is None or t2 is None:
        return None
    return round(abs(t1 - t2), 1)


def _load_place_offset(db: Session | None, key: str, elevation_m: float | None) -> float:
    prior = place_static_prior(elevation_m=elevation_m)
    if db is None:
        return prior
    row = db.query(ClimatePlaceOffset).filter(ClimatePlaceOffset.place_key == key).one_or_none()
    if row is None:
        return prior
    return prior + float(row.offset_c)


def _feedback_window(profile: ClimateProfileIn, lang: str) -> FeedbackWindow:
    now_h = datetime.now().hour
    leave_h = profile.leave_hour
    return_h = profile.return_hour
    # ±1 hour window around leave/return
    if abs((now_h - leave_h + 24) % 24) <= 1 or abs((leave_h - now_h + 24) % 24) <= 1:
        moment = "leave"
        prompt = (
            "Feedback now: leaving home"
            if lang == "en"
            else "Сейчас окно фидбека: выход из дома"
        )
    elif abs((now_h - return_h + 24) % 24) <= 1 or abs((return_h - now_h + 24) % 24) <= 1:
        moment = "return"
        prompt = (
            "Feedback now: returning home"
            if lang == "en"
            else "Сейчас окно фидбека: возвращение"
        )
    else:
        moment = "anytime"
        prompt = (
            "Rate how it felt when you were outside"
            if lang == "en"
            else "Оцените, как ощущалось на улице"
        )
    return FeedbackWindow(
        moment=moment,  # type: ignore[arg-type]
        leave_hour=leave_h,
        return_hour=return_h,
        prompt=prompt,
    )


def build_hours(
    primary: dict[str, Any],
    *,
    profile: ClimateProfileIn,
    lang: str,
    shade: bool,
    place_offset: float,
) -> list[HourlySensation]:
    hourly = primary.get("hourly") or {}
    times = hourly.get("time") or []
    temps = hourly.get("temperature_2m") or []
    rhs = hourly.get("relative_humidity_2m") or []
    winds = hourly.get("wind_speed_10m") or []
    sws = hourly.get("shortwave_radiation") or []
    precs = hourly.get("precipitation") or []
    labels = _labels(lang)
    out: list[HourlySensation] = []
    for i, ts in enumerate(times[:24]):
        tdb = _as_float(temps[i] if i < len(temps) else None)
        rh = _as_float(rhs[i] if i < len(rhs) else None)
        wind = _as_float(winds[i] if i < len(winds) else None)
        sw = _as_float(sws[i] if i < len(sws) else None)
        precip = _as_float(precs[i] if i < len(precs) else None)
        if tdb is None or rh is None or wind is None:
            continue
        u = compute_utci(tdb_c=tdb, rh=rh, wind_10m_ms=wind, shortwave_wm2=sw, shade=shade)
        pred = mixed_predict(
            utci_c=u.utci_c,
            wind_ms=wind,
            rh=rh,
            profile=profile,
            place_intercept=place_offset,
        )
        try:
            hour_label = datetime.fromisoformat(ts).strftime("%H:%M")
        except ValueError:
            hour_label = ts[-5:] if len(ts) >= 5 else ts
        out.append(
            HourlySensation(
                time=ts,
                hour_label=hour_label,
                utci_c=round(pred.latent, 1),
                sensation=pred.sensation,
                sensation_label=labels[pred.sensation],
                temp_c=tdb,
                wind_ms=wind,
                precip_mm=precip,
            )
        )
    return out


async def build_today(
    *,
    city: str,
    lat: float | None,
    lon: float | None,
    profile: ClimateProfileIn,
    lang: str,
    shade: bool = False,
    client_key: str = "anon",
    db: Session | None = None,
) -> ClimateTodayResponse:
    if lat is not None and lon is not None:
        resolved_lat, resolved_lon, name = float(lat), float(lon), city.strip()
    else:
        resolved_lat, resolved_lon, name = await geocode_city(city)

    bundle = await _forecast_bundle(resolved_lat, resolved_lon)
    primary = bundle["primary"]
    elevation = bundle.get("elevation")
    current = primary.get("current") or {}
    tdb = _as_float(current.get("temperature_2m"))
    rh = _as_float(current.get("relative_humidity_2m"))
    wind = _as_float(current.get("wind_speed_10m"))
    uv = _as_float(current.get("uv_index"))
    sw = _as_float(current.get("shortwave_radiation"))
    precip = _as_float(current.get("precipitation"))
    if tdb is None or rh is None or wind is None:
        raise ValueError("incomplete weather current for UTCI")

    utci = compute_utci(
        tdb_c=tdb, rh=rh, wind_10m_ms=wind, shortwave_wm2=sw, shade=shade
    )
    pkey = place_key(resolved_lat, resolved_lon)
    place_off = _load_place_offset(db, pkey, elevation if isinstance(elevation, float) else None)
    pred = mixed_predict(
        utci_c=utci.utci_c,
        wind_ms=wind,
        rh=rh,
        profile=profile,
        place_intercept=place_off,
    )
    labels = _labels(lang)
    support = compute_support(
        tdb_c=tdb,
        rh=rh,
        wind_10m_ms=wind,
        tmrt_c=utci.tmrt_c,
        activity=profile.activity,
    )
    spread = _model_spread_c(primary, bundle.get("secondary"))
    # Index disagreement as uncertainty signal
    index_spread = None
    if support.pet_c is not None:
        index_spread = abs(support.pet_c - utci.utci_c)
    spare = bool(
        (spread is not None and spread >= 2.5)
        or (wind is not None and wind >= 10)
        or (index_spread is not None and index_spread >= 4.0)
    )
    if lang == "en":
        spare_note = (
            "Models / indices disagree or wind is strong — take a spare layer."
            if spare
            else ""
        )
        calib = (
            f"Personal calibration from {profile.feedback_count} ratings (mixed ordinal uᵢ)"
            if profile.feedback_count >= 3
            else "Starter estimate — mixed model without full personal calibration yet"
        )
    else:
        spare_note = (
            "Модели/индексы расходятся или сильный ветер — возьмите запасной слой."
            if spare
            else ""
        )
        calib = (
            f"Личная калибровка по {profile.feedback_count} оценкам (смешанная модель uᵢ)"
            if profile.feedback_count >= 3
            else "Стартовая оценка — смешанная модель без полной личной калибровки"
        )

    conf: str = "high" if utci.in_range and profile.feedback_count >= 5 else (
        "medium" if utci.in_range else "low"
    )
    if spread is not None and spread >= 3:
        conf = "low"
    if index_spread is not None and index_spread >= 5:
        conf = "low"

    risk, risk_note = appearance_risk(
        wind=wind, humidity=rh, utci_c=pred.latent, uv=uv, precip=precip, lang=lang
    )
    look_boost = look_fail_boost(
        db,
        client_key=client_key,
        city=name,
        lat=resolved_lat,
        lon=resolved_lon,
    )
    if look_boost:
        risk = min(3, risk + look_boost)
        if lang == "en":
            risk_note = f"{risk_note}; boosted after look not preserved"
        else:
            risk_note = f"{risk_note}; усилено после «образ не сохранился»"
    clothing = clothing_from_ireq(support.ireq_clo, lang)
    care = care_for(
        utci_c=pred.latent,
        uv=uv,
        wind=wind,
        humidity=rh,
        precip=precip,
        lang=lang,
        allergies=profile.allergies,
        habits=profile.habits,
        appearance_risk=risk,
        look_boost=look_boost,
    )

    why = [
        f"UTCI {utci.utci_c:.1f}°C ({utci.stress_category})",
        f"PET≈{support.pet_c:.1f}°C" if support.pet_c is not None else "PET n/a",
        f"IREQ≈{support.ireq_clo:.2f} clo (met {support.met_w_m2:.0f} W/m²)",
        f"Tmrt≈{utci.tmrt_c:.1f}°C · v10={wind:.1f} m/s · RH={rh:.0f}%",
        f"uᵢ={pred.random_intercept:+.2f} · place={place_off:+.2f}",
    ]
    if support.wind_chill_c is not None:
        why.append(f"wind chill {support.wind_chill_c:.1f}°C")
    if support.heat_index_c is not None:
        why.append(f"heat index {support.heat_index_c:.1f}°C")
    if support.humidex_c is not None and tdb >= 20:
        why.append(f"humidex {support.humidex_c:.1f}")
    if spread is not None:
        why.append(
            f"model spread {spread}°C" if lang == "en" else f"разброс моделей {spread}°C"
        )

    llm_used = False
    explanation = climate_llm.rule_explanation(
        lang=lang,
        sensation_label=labels[pred.sensation],
        utci_c=utci.utci_c,
        pet_c=support.pet_c,
        ireq_clo=support.ireq_clo,
        confidence=conf,
    )
    # LLM is optional polish — never block the comfort core (>2.5s → rules).
    try:
        llm_ex = await asyncio.wait_for(
            climate_llm.llm_explain(
                lang=lang,
                sensation_label=labels[pred.sensation],
                utci_c=utci.utci_c,
                pet_c=support.pet_c,
                ireq_clo=support.ireq_clo,
                confidence=conf,
                why=why,
            ),
            timeout=2.5,
        )
        if llm_ex:
            explanation = llm_ex
            llm_used = True
    except Exception:
        logger.info("llm explain skipped/timeout")
    try:
        filtered = await asyncio.wait_for(
            climate_llm.llm_filter_whitelist(
                lang=lang,
                clothing=clothing,
                care=care,
                scenario=f"sensation={labels[pred.sensation]}; ireq={support.ireq_clo}",
            ),
            timeout=2.5,
        )
        if filtered:
            clothing, care = filtered
            llm_used = True
    except Exception:
        logger.info("llm whitelist skipped/timeout")

    return ClimateTodayResponse(
        city=name,
        temp_c=tdb,
        humidity=rh,
        wind_ms=wind,
        uv=uv,
        shortwave_wm2=sw,
        elevation_m=elevation if isinstance(elevation, float) else None,
        utci_c=utci.utci_c,
        utci_stress=utci.stress_category,
        personal_utci_c=round(pred.latent, 1),
        sensation=pred.sensation,
        sensation_label=labels[pred.sensation],
        confidence=conf,  # type: ignore[arg-type]
        calibration_note=calib,
        explanation=explanation,
        spare_layer=spare,
        spare_layer_note=spare_note,
        model_spread_c=spread,
        support=SupportIndicesOut(
            pet_c=support.pet_c,
            heat_index_c=support.heat_index_c,
            humidex_c=support.humidex_c,
            wind_chill_c=support.wind_chill_c,
            ireq_clo=support.ireq_clo,
            met_w_m2=support.met_w_m2,
        ),
        place_offset_c=round(place_off, 3),
        random_intercept_c=round(pred.random_intercept, 3),
        clothing=clothing,
        care=care,
        appearance_risk=risk,
        appearance_note=risk_note,
        hours=build_hours(
            primary, profile=profile, lang=lang, shade=shade, place_offset=place_off
        ),
        feedback_window=_feedback_window(profile, lang),
        why=why,
        disclaimer=_DISCLAIMER_EN if lang == "en" else _DISCLAIMER_RU,
        source="open-meteo",
        provider="mixed_ordinal_utci_v1",
        llm_used=llm_used,
    )


def apply_feedback(
    body: ClimateFeedbackRequest,
    *,
    db: Session | None = None,
) -> ClimateFeedbackResponse:
    delta = feedback_random_delta(
        predicted_sensation=body.predicted_sensation,
        actual_sensation=body.actual_sensation,
        worn_tier=body.worn_tier,
    )
    place_delta = 0.0
    residual_steps = body.actual_sensation - body.predicted_sensation
    if abs(residual_steps) >= 1 and body.lat is not None and body.lon is not None:
        place_delta = max(-0.4, min(0.4, residual_steps * 0.15))
        if db is not None:
            key = place_key(float(body.lat), float(body.lon))
            row = (
                db.query(ClimatePlaceOffset)
                .filter(ClimatePlaceOffset.place_key == key)
                .one_or_none()
            )
            if row is None:
                db.add(
                    ClimatePlaceOffset(
                        place_key=key, offset_c=place_delta, n_samples=1, city=body.city[:120]
                    )
                )
            else:
                n = max(1, int(row.n_samples))
                row.offset_c = (float(row.offset_c) * n + place_delta) / (n + 1)
                row.n_samples = n + 1
                row.city = body.city[:120]
    return ClimateFeedbackResponse(
        ok=True,
        suggested_feedback_offset_delta=round(delta, 3),
        place_offset_delta=round(place_delta, 3),
        feedback_count=0,
        message="Apply uᵢ delta on client; place offset stored server-side",
    )


def parse_plan_text(text: str, lang: str) -> ClimatePlanParsed:
    raw = text.lower()
    activity: str = "moderate"
    if any(k in raw for k in ("спорт", "бег", "пробеж", "run", "jog", "bike", "велосипед", "тренир")):
        activity = "high"
    elif any(k in raw for k in ("прогул", "walk", "кофе", "сид", "офис", "cafe")):
        activity = "low"

    formality: str = "unknown"
    if any(k in raw for k in ("свадьб", "wedding", "галстук", "костюм", "formal", "выпускн")):
        formality = "formal"
    elif any(k in raw for k in ("smart", "дело", "встреч", "интервью")):
        formality = "smart"
    elif any(k in raw for k in ("casual", "просто", "прогул")):
        formality = "casual"

    outdoor = not any(k in raw for k in ("в помещении", "indoor", "в зале", "дома"))
    hours = None
    m = re.search(r"(\d+[.,]?\d*)\s*(час|часа|часов|h|hr|hours)", raw)
    if m:
        hours = float(m.group(1).replace(",", "."))

    summary = (
        f"activity={activity}, formality={formality}, outdoor={outdoor}"
        if lang == "en"
        else f"активность={activity}, формальность={formality}, улица={outdoor}"
    )
    return ClimatePlanParsed(
        activity=activity,  # type: ignore[arg-type]
        duration_hours=hours,
        formality=formality,  # type: ignore[arg-type]
        outdoor=outdoor,
        summary=summary,
        source="rules",
    )


async def build_plan_advice(
    *,
    text: str,
    city: str,
    lat: float | None,
    lon: float | None,
    profile: ClimateProfileIn,
    lang: str,
    client_key: str = "anon",
    db: Session | None = None,
) -> ClimatePlanResponse:
    parsed = None
    try:
        parsed = await asyncio.wait_for(climate_llm.llm_parse_plan(text, lang), timeout=3.0)
    except Exception:
        logger.info("llm plan parse skipped/timeout")
    if parsed is None:
        parsed = parse_plan_text(text, lang)
    else:
        parsed = parsed.model_copy(update={"source": "llm"})
    adjusted = profile.model_copy(update={"activity": parsed.activity})
    today = await build_today(
        city=city,
        lat=lat,
        lon=lon,
        profile=adjusted,
        lang=lang,
        shade=not parsed.outdoor,
        client_key=client_key,
        db=db,
    )
    if parsed.formality == "formal" and lang != "en":
        today.clothing.insert(
            0,
            ClothingItem(
                item="Учтите дресс-код: слой под пиджак/платье",
                layer="mid",
                clo=0.3,
                catalog_id="dress_code",
            ),
        )
    elif parsed.formality == "formal":
        today.clothing.insert(
            0,
            ClothingItem(
                item="Mind dress code under jacket/dress",
                layer="mid",
                clo=0.3,
                catalog_id="dress_code",
            ),
        )
    return ClimatePlanResponse(parsed=parsed, today=today)
