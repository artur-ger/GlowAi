from __future__ import annotations

import json
from datetime import date, datetime
from typing import Any, Literal

from app.core.config import settings
from app.schemas.analyze import (
    AnalyzeResponse,
    CareStep,
    ClimateSummary,
    PackingItem,
    SkinAssessment,
)
from app.services.llm import LlmError, generate_json

Mode = Literal["pre_trip", "sos", "return_home"]

DISCLAIMER = (
    "GlowAi не является медицинским сервисом и не ставит диагноз. "
    "При ожогах, инфекции, сильной боли или аллергии обратитесь к врачу."
)

SYSTEM_PROMPT = """
Ты — ассистент travel-skincare продукта GlowAi для путешественников.
Верни ТОЛЬКО JSON-объект со структурой:
{
  "skin_summary": "string",
  "skin_concerns": ["string"],
  "confidence": "low|medium|high",
  "forecast_summary": "1-2 предложения про кожу и климат",
  "why_reasons": ["почему такой план"],
  "care_plan": [{"step": 1, "title": "...", "detail": "..."}],
  "packing_kit": [{"item": "...", "action": "take|skip", "reason": "..."}],
  "product_hints": ["категория средства, без брендов"],
  "follow_up_hint": "что проверить через 48-72 часа"
}
Правила:
- Не ставь медицинский диагноз.
- Учитывай mode: pre_trip | sos | return_home.
- Учитывай owned_items (уже есть) и avoid_items (избегать): не советуй брать дубликаты; avoid → skip/не вводить.
- План: 3-6 коротких шагов на русском. Для return_home — адаптация к домашнему климату на 3–5 дней.
- packing_kit: 4-7 пунктов. Без брендов.
""".strip()

_OWNED_ALIASES: dict[str, tuple[str, ...]] = {
    "spf": ("spf", "солнц"),
    "cleanser": ("cleanser", "очищ", "умыва"),
    "moisturizer": ("увлажн", "moisturizer", "крем", "гель"),
    "mist": ("mist", "термальн", "спрей"),
    "retinoid": ("ретиноид", "retin", "третиноин"),
    "acids": ("кислот", "acid", "aha", "bha"),
    "spot": ("точечн", "ниацинамид", "spot"),
}


def _split_csv(value: str) -> list[str]:
    return [p.strip() for p in (value or "").split(",") if p.strip()]


def _parse_iso_date(value: str) -> date | None:
    text = (value or "").strip()
    if not text:
        return None
    try:
        return datetime.strptime(text[:10], "%Y-%m-%d").date()
    except ValueError:
        return None


def _trip_days(trip_start: str, trip_end: str) -> int | None:
    start = _parse_iso_date(trip_start)
    end = _parse_iso_date(trip_end)
    if start is None or end is None:
        return None
    days = (end - start).days + 1
    return days if days > 0 else None


def _normalize_token(text: str) -> str:
    return text.strip().lower()


def _matches_owned(item_name: str, owned: list[str]) -> str | None:
    low = _normalize_token(item_name)
    for raw in owned:
        key = _normalize_token(raw)
        aliases = _OWNED_ALIASES.get(key, (key,))
        if any(a in low for a in aliases):
            return raw
    return None


def _apply_inventory(
    kit: list[PackingItem],
    *,
    owned: list[str],
    avoid: list[str],
) -> list[PackingItem]:
    out: list[PackingItem] = []
    for item in kit:
        hit = _matches_owned(item.item, owned)
        if hit and item.action == "take":
            out.append(
                PackingItem(
                    item=item.item,
                    action="skip",
                    reason=f"Уже есть в кейсе («{hit}») — дубликат не нужен.",
                )
            )
            continue
        avoid_hit = _matches_owned(item.item, avoid)
        if avoid_hit and item.action == "take":
            out.append(
                PackingItem(
                    item=item.item,
                    action="skip",
                    reason=f"В списке «избегать» («{avoid_hit}»).",
                )
            )
            continue
        out.append(item)
    for a in avoid:
        label = a.strip()
        if not label:
            continue
        if any(_matches_owned(i.item, [label]) for i in out):
            continue
        out.append(
            PackingItem(
                item=f"Не вводить: {label}",
                action="skip",
                reason="Отмечено пользователем как «избегать» на поездку.",
            )
        )
    return out


def _build_why_reasons(
    *,
    climate: ClimateSummary,
    skin_type: str,
    concerns: str,
    trip_days: int | None,
    mode: Mode,
    owned: list[str],
    avoid: list[str],
) -> list[str]:
    reasons: list[str] = []
    if mode == "return_home":
        reasons.append("Режим возврата домой: адаптация кожи к привычному климату после поездки.")
    if climate.delta_temp_c is not None:
        reasons.append(
            f"Разница температуры: {climate.delta_temp_c:+.0f}°C "
            f"({climate.home_temp_c:.0f}° → {climate.destination_temp_c:.0f}°)."
            if climate.home_temp_c is not None and climate.destination_temp_c is not None
            else f"Сдвиг температуры: {climate.delta_temp_c:+.0f}°C."
        )
    if climate.delta_humidity is not None:
        reasons.append(f"Сдвиг влажности: {climate.delta_humidity:+.0f}%.")
    if climate.destination_uv is not None:
        reasons.append(f"UV на целевом месте: {climate.destination_uv:.1f}.")
    if skin_type:
        reasons.append(f"Тип кожи: {skin_type}.")
    if concerns:
        reasons.append(f"Запрос: {concerns}.")
    if owned:
        reasons.append(f"Уже в кейсе: {', '.join(owned[:6])}.")
    if avoid:
        reasons.append(f"Избегать: {', '.join(avoid[:6])}.")
    if trip_days is not None and mode == "pre_trip":
        reasons.append(f"Длительность поездки: {trip_days} дн.")
    for risk in climate.risks[:2]:
        reasons.append(f"Климат-риск: {risk}.")
    seen: set[str] = set()
    out: list[str] = []
    for r in reasons:
        if r not in seen:
            seen.add(r)
            out.append(r)
    return out[:7]


def _build_packing_kit(
    *,
    climate: ClimateSummary,
    concerns: str,
    trip_days: int | None,
    mode: Mode,
) -> list[PackingItem]:
    if mode == "return_home":
        kit = [
            PackingItem(
                item="Привычный домашний cleanser",
                action="take",
                reason="Вернитесь к знакомой базе на 3–5 дней.",
            ),
            PackingItem(
                item="Домашний moisturizer",
                action="take",
                reason="Подстройте плотность под домашний климат.",
            ),
            PackingItem(
                item="SPF на первые дни дома",
                action="take",
                reason="Кожа после отпуска часто чувствительнее к UV.",
            ),
            PackingItem(
                item="Новые активы сразу после прилёта",
                action="skip",
                reason="Дайте 3–5 дней на стабилизацию барьера.",
            ),
            PackingItem(
                item="Отпускные «тяжёлые» масла/маски каждый день",
                action="skip",
                reason="Дома обычно достаточно более лёгкой рутины.",
            ),
        ]
        return kit

    kit: list[PackingItem] = [
        PackingItem(
            item="Мини cleanser",
            action="take",
            reason="База рутины в дороге, меньше места в чемодане.",
        ),
        PackingItem(
            item="Увлажняющий крем/гель travel-size",
            action="take",
            reason="Акклиматизация и сухой воздух самолёта/отеля.",
        ),
        PackingItem(
            item="SPF для лица",
            action="take",
            reason="Ключевой элемент travel-ухода при смене UV.",
        ),
        PackingItem(
            item="Полноразмерные банки >100 мл",
            action="skip",
            reason="Тяжело возить и часто избыточно на короткий срок.",
        ),
        PackingItem(
            item="Новые сильные кислоты / ретиноид «с нуля»",
            action="skip",
            reason="В поездке выше риск раздражения на фоне климата.",
        ),
    ]
    if climate.destination_uv is not None and climate.destination_uv >= 6:
        kit.append(
            PackingItem(
                item="Головной убор / защита от солнца",
                action="take",
                reason="Высокий UV на направлении.",
            )
        )
    if (climate.delta_humidity or 0) <= -15:
        kit.append(
            PackingItem(
                item="Термальная вода / hydrating mist",
                action="take",
                reason="Падение влажности — быстрая поддержка комфорта кожи.",
            )
        )
    if "акне" in concerns.lower() or "жирн" in concerns.lower():
        kit.append(
            PackingItem(
                item="Точечное средство (ниацинамид)",
                action="take",
                reason="По запросу на воспаления/блеск без агрессивных новинок.",
            )
        )
    if trip_days is not None and trip_days <= 4:
        kit.append(
            PackingItem(
                item="Полный домашний набор из 8+ средств",
                action="skip",
                reason="На короткий срок достаточно 3–5 мини-форматов.",
            )
        )
    return kit


def _forecast_summary(
    *,
    mode: Mode,
    climate: ClimateSummary,
    trip_days: int | None,
) -> str:
    if mode == "sos":
        return (
            f"SOS-сценарий для {climate.destination_city}: сначала успокаиваем кожу, "
            "затем короткий план без новых агрессивных активов."
        )
    if mode == "return_home":
        return (
            f"Возврат: {climate.home_city} → дом ({climate.destination_city}). "
            "План на 3–5 дней адаптации к домашнему климату без резких активов."
        )
    days = f" на {trip_days} дн." if trip_days else ""
    risk = climate.risks[0] if climate.risks else "умеренный климатический сдвиг"
    return (
        f"Прогноз кожи к поездке {climate.home_city} → {climate.destination_city}{days}: "
        f"{risk}. Ниже — план и travel-kit."
    )


def _care_plan_for_mode(mode: Mode, climate: ClimateSummary) -> list[CareStep]:
    if mode == "return_home":
        return [
            CareStep(
                step=1,
                title="День 1–2: стабилизация",
                detail="Только cleanser + moisturizer + SPF. Без новых кислот и ретиноидов.",
            ),
            CareStep(
                step=2,
                title="День 3–4: оценка",
                detail="Если спокойно — верните 1 привычный актив в половину дозы.",
            ),
            CareStep(
                step=3,
                title="День 5: домашний ритм",
                detail="Вернитесь к обычной рутине, если нет стянутости/покраснения.",
            ),
            CareStep(
                step=4,
                title="Вода и сон",
                detail="После перелёта важнее режим, чем «лечение» кожи новыми средствами.",
            ),
        ]
    care_plan = [
        CareStep(
            step=1,
            title="Очищение",
            detail="Мягкое очищение утром и вечером без агрессивных скрабов в первые дни.",
        ),
        CareStep(
            step=2,
            title="Увлажнение",
            detail=(
                "Плотнее увлажняйте при сухом сдвиге климата; лёгкий гель — при росте влажности."
                if (climate.delta_humidity or 0) < 0
                else "Лёгкая увлажняющая текстура, чтобы не перегружать кожу во влажном климате."
            ),
        ),
        CareStep(
            step=3,
            title="Защита",
            detail="SPF 30+ каждые 2–3 часа на солнце; в самолёте у окна — тоже актуально.",
        ),
    ]
    if mode == "sos":
        care_plan.insert(
            0,
            CareStep(
                step=0,
                title="SOS сейчас",
                detail="Успокойте кожу: прохладный компресс, без новых кислот/ретиноидов 48 часов.",
            ),
        )
        care_plan = [
            CareStep(step=i + 1, title=s.title, detail=s.detail) for i, s in enumerate(care_plan)
        ]
    return care_plan


def _rule_based_plan(
    *,
    mode: Mode,
    climate: ClimateSummary,
    skin_type: str,
    concerns: str,
    trip_start: str,
    trip_end: str,
    owned_items: str = "",
    avoid_items: str = "",
) -> AnalyzeResponse:
    concern_list = _split_csv(concerns)
    owned = _split_csv(owned_items)
    avoid = _split_csv(avoid_items)
    if not concern_list and climate.risks:
        concern_list = climate.risks[:2]
    days = _trip_days(trip_start, trip_end)
    why = _build_why_reasons(
        climate=climate,
        skin_type=skin_type,
        concerns=concerns,
        trip_days=days,
        mode=mode,
        owned=owned,
        avoid=avoid,
    )
    kit = _apply_inventory(
        _build_packing_kit(climate=climate, concerns=concerns, trip_days=days, mode=mode),
        owned=owned,
        avoid=avoid,
    )
    care_plan = _care_plan_for_mode(mode, climate)
    product_hints = [
        "мягкий cleanser без SLS",
        "moisturizer с церамидами или гиалуроновой кислотой",
        "mineral или hybrid SPF",
    ]
    if "акне" in concerns.lower() or "воспален" in concerns.lower():
        product_hints.append("точечное средство с ниацинамидом")

    follow = {
        "pre_trip": "Через 48–72 часа сделайте check-in: сухость / блеск / спокойствие / краснота.",
        "sos": "Если за 24–48 часов хуже — упростите рутину и при сильных симптомах к врачу.",
        "return_home": "На 3–5 день дома отметьте check-in: вернулась ли кожа к обычному состоянию.",
    }[mode]

    summary_mode = {
        "pre_trip": "адаптация к климату поездки",
        "sos": "SOS на месте",
        "return_home": "возврат к домашнему климату",
    }[mode]

    return AnalyzeResponse(
        mode=mode,
        climate=climate,
        skin=SkinAssessment(
            summary=(
                f"По анкете: тип кожи «{skin_type or 'не указан'}». "
                f"Режим: {summary_mode}. Запрос: {concerns or 'климат'}."
            ),
            concerns=concern_list or ["акклиматизация"],
            confidence="low",
            engine="rule_based",
        ),
        care_plan=care_plan,
        packing_list=[i.item for i in kit if i.action == "take"],
        packing_kit=kit,
        product_hints=product_hints,
        why_reasons=why,
        forecast_summary=_forecast_summary(mode=mode, climate=climate, trip_days=days),
        trip_start=trip_start or None,
        trip_end=trip_end or None,
        trip_days=days,
        follow_up_hint=follow,
        disclaimer=DISCLAIMER,
        provider="rule_based",
        owned_items=owned,
        avoid_items=avoid,
    )


async def build_analyze_response(
    *,
    mode: Mode,
    climate: ClimateSummary,
    skin_type: str,
    concerns: str,
    trip_start: str,
    trip_end: str,
    photo_bytes: bytes | None,
    photo_mime: str,
    owned_items: str = "",
    avoid_items: str = "",
) -> AnalyzeResponse:
    days = _trip_days(trip_start, trip_end)
    owned = _split_csv(owned_items)
    avoid = _split_csv(avoid_items)
    user_payload = {
        "mode": mode,
        "skin_type": skin_type,
        "concerns": concerns,
        "owned_items": owned,
        "avoid_items": avoid,
        "trip_start": trip_start,
        "trip_end": trip_end,
        "trip_days": days,
        "climate": climate.model_dump(),
    }
    try:
        data = await generate_json(
            system_prompt=SYSTEM_PROMPT,
            user_text=json.dumps(user_payload, ensure_ascii=False),
            image_bytes=photo_bytes,
            image_mime=photo_mime,
        )
        return _from_llm_json(
            mode=mode,
            climate=climate,
            data=data,
            has_photo=bool(photo_bytes),
            trip_start=trip_start,
            trip_end=trip_end,
            trip_days=days,
            skin_type=skin_type,
            concerns=concerns,
            owned=owned,
            avoid=avoid,
        )
    except LlmError:
        if not settings.llm_allow_rule_based_fallback and settings.llm_api_key:
            raise
        return _rule_based_plan(
            mode=mode,
            climate=climate,
            skin_type=skin_type,
            concerns=concerns,
            trip_start=trip_start,
            trip_end=trip_end,
            owned_items=owned_items,
            avoid_items=avoid_items,
        )


def _from_llm_json(
    *,
    mode: Mode,
    climate: ClimateSummary,
    data: dict[str, Any],
    has_photo: bool,
    trip_start: str,
    trip_end: str,
    trip_days: int | None,
    skin_type: str,
    concerns: str,
    owned: list[str],
    avoid: list[str],
) -> AnalyzeResponse:
    care_raw = data.get("care_plan") or []
    care_plan: list[CareStep] = []
    for idx, item in enumerate(care_raw):
        if not isinstance(item, dict):
            continue
        care_plan.append(
            CareStep(
                step=int(item.get("step") or idx + 1),
                title=str(item.get("title") or f"Шаг {idx + 1}"),
                detail=str(item.get("detail") or ""),
            )
        )
    if not care_plan:
        care_plan = _care_plan_for_mode(mode, climate)

    confidence = str(data.get("confidence") or "medium").lower()
    if confidence not in {"low", "medium", "high"}:
        confidence = "medium"

    skin_concerns = data.get("skin_concerns") or []
    if not isinstance(skin_concerns, list):
        skin_concerns = [str(skin_concerns)]

    kit_raw = data.get("packing_kit") or []
    kit: list[PackingItem] = []
    for item in kit_raw:
        if not isinstance(item, dict):
            continue
        action = str(item.get("action") or "take").lower()
        if action not in {"take", "skip"}:
            action = "take"
        kit.append(
            PackingItem(
                item=str(item.get("item") or ""),
                action=action,  # type: ignore[arg-type]
                reason=str(item.get("reason") or ""),
            )
        )
    if not kit:
        kit = _build_packing_kit(
            climate=climate, concerns=concerns, trip_days=trip_days, mode=mode
        )
    kit = _apply_inventory(kit, owned=owned, avoid=avoid)

    why = [str(x) for x in (data.get("why_reasons") or []) if str(x).strip()]
    if not why:
        why = _build_why_reasons(
            climate=climate,
            skin_type=skin_type,
            concerns=concerns,
            trip_days=trip_days,
            mode=mode,
            owned=owned,
            avoid=avoid,
        )

    forecast = str(data.get("forecast_summary") or "").strip()
    if not forecast:
        forecast = _forecast_summary(mode=mode, climate=climate, trip_days=trip_days)

    return AnalyzeResponse(
        mode=mode,
        climate=climate,
        skin=SkinAssessment(
            summary=str(data.get("skin_summary") or "Анализ выполнен."),
            concerns=[str(c) for c in skin_concerns],
            confidence=confidence,  # type: ignore[arg-type]
            engine="llm_vision" if has_photo else "llm",
        ),
        care_plan=care_plan,
        packing_list=[i.item for i in kit if i.action == "take"],
        packing_kit=kit,
        product_hints=[str(x) for x in (data.get("product_hints") or [])],
        why_reasons=why,
        forecast_summary=forecast,
        trip_start=trip_start or None,
        trip_end=trip_end or None,
        trip_days=trip_days,
        follow_up_hint=str(
            data.get("follow_up_hint") or "Через 48–72 часа сделайте structured check-in."
        ),
        disclaimer=DISCLAIMER,
        provider=settings.llm_provider or "openai_compatible",
        owned_items=owned,
        avoid_items=avoid,
    )
