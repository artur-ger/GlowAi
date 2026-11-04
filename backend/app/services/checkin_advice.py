from __future__ import annotations

import copy
from typing import Any


DISCLAIMER = (
    "GlowAi не является медицинским сервисом и не ставит диагноз. "
    "При ожогах, инфекции, сильной боли или аллергии обратитесь к врачу."
)


def advice_from_scores(
    *,
    dryness: int,
    oiliness: int,
    calmness: int,
    redness: int,
    note: str = "",
    check_payload: dict[str, Any] | None = None,
) -> str:
    """Structured 48–72h check-in → short coaching reply (rule-based, no LLM required)."""
    tips: list[str] = []
    if dryness >= 4:
        tips.append("Усильте увлажнение и барьер; не добавляйте новые кислоты.")
    if oiliness >= 4:
        tips.append("Упростите рутину: мягкое очищение, лёгкий увлажнитель, SPF.")
    if calmness >= 4 or redness >= 4:
        tips.append("Приоритет — успокоение (пантенол/центелла), без скрабов и сильных активов 48 ч.")
    if dryness <= 2 and oiliness <= 2 and calmness <= 2 and redness <= 2:
        tips.append("Кожа выглядит адаптированной — держите базовый travel-план без новинок.")
    if not tips:
        tips.append("Продолжайте базовый план: очищение → увлажнение → SPF.")

    dest = ""
    if isinstance(check_payload, dict):
        climate = check_payload.get("climate") or {}
        if isinstance(climate, dict):
            dest = str(climate.get("destination_city") or "")

    head = "Check-in принят."
    if dest:
        head = f"Check-in по направлению «{dest}» принят."
    note_line = f" Вы отметили: {note.strip()}." if note.strip() else ""
    return f"{head}{note_line}\n\n" + "\n".join(f"• {t}" for t in tips[:4]) + f"\n\n{DISCLAIMER}"


def needs_sos(*, dryness: int, oiliness: int, calmness: int, redness: int) -> bool:
    return max(dryness, oiliness, calmness, redness) >= 4


def revise_payload_from_checkin(
    parent_payload: dict[str, Any],
    *,
    dryness: int,
    oiliness: int,
    calmness: int,
    redness: int,
    note: str = "",
) -> dict[str, Any]:
    """Build an updated analyze-like payload after structured check-in."""
    data = copy.deepcopy(parent_payload) if parent_payload else {}
    sos = needs_sos(dryness=dryness, oiliness=oiliness, calmness=calmness, redness=redness)
    mode = "sos" if sos else str(data.get("mode") or "pre_trip")
    if mode not in {"pre_trip", "sos", "return_home"}:
        mode = "sos" if sos else "pre_trip"

    concerns: list[str] = []
    if dryness >= 4:
        concerns.append("Сухость")
    if oiliness >= 4:
        concerns.append("Жирный блеск")
    if calmness >= 4:
        concerns.append("Раздражение")
    if redness >= 4:
        concerns.append("Покраснение")
    if not concerns:
        concerns.append("Акклиматизация")

    care_plan = [
        {
            "step": 1,
            "title": "После check-in: упростить",
            "detail": "Оставьте cleanser + moisturizer + SPF на 48 часов, без новых активов.",
        },
        {
            "step": 2,
            "title": "Поддержать барьер",
            "detail": (
                "Больше увлажнения и меньше пены."
                if dryness >= 4
                else "Лёгкие текстуры, если растёт блеск."
            ),
        },
        {
            "step": 3,
            "title": "SPF без пропусков",
            "detail": "Даже в городе — кожа после смены климата чувствительнее.",
        },
    ]
    if sos:
        care_plan.insert(
            0,
            {
                "step": 0,
                "title": "SOS по check-in",
                "detail": "Сильные симптомы: пауза кислот/ретиноида, прохлада, при ухудшении — к врачу.",
            },
        )
        for i, step in enumerate(care_plan):
            step["step"] = i + 1

    why = [
        f"Check-in: сухость {dryness}/5, блеск {oiliness}/5, раздражение {calmness}/5, краснота {redness}/5.",
    ]
    if note.strip():
        why.append(f"Заметка: {note.strip()}")
    if sos:
        why.append("Оценки высокие — план переведён в SOS-ветку.")

    skin = data.get("skin") if isinstance(data.get("skin"), dict) else {}
    data.update(
        {
            "mode": mode,
            "skin": {
                "summary": (
                    f"Обновление после check-in. "
                    f"Базовый план скорректирован под текущие ощущения"
                    f"{' (SOS)' if sos else ''}."
                ),
                "concerns": concerns,
                "confidence": skin.get("confidence") or "medium",
                "engine": "rule_based",
            },
            "care_plan": care_plan,
            "why_reasons": why + [str(x) for x in (data.get("why_reasons") or [])[:2]],
            "forecast_summary": (
                "План обновлён по structured check-in 48–72ч."
                + (" Рекомендуем режим SOS." if sos else "")
            ),
            "follow_up_hint": "Если через сутки хуже — чат follow-up или повторный SOS-анализ.",
            "provider": "rule_based",
            "checkin_revision": True,
        }
    )
    return data
