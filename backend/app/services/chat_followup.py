from __future__ import annotations

import json
from typing import Any

from app.core.config import settings
from app.services.llm import LlmError, generate_json

DISCLAIMER = (
    "GlowAi не является медицинским сервисом и не ставит диагноз. "
    "При ожогах, инфекции, сильной боли или аллергии обратитесь к врачу."
)

SYSTEM_PROMPT = """
Ты — ассистент travel-skincare GlowAi. Пользователь обсуждает состояние кожи
после/во время поездки относительно уже выданного плана ухода.
Верни ТОЛЬКО JSON:
{
  "reply": "короткий ответ на русском (2-6 предложений)",
  "tips": ["до 3 коротких советов категории ухода, без брендов"]
}
Правила:
- Не ставь медицинский диагноз и не называй болезни.
- Опирайся на климат маршрута и выданный план.
- Если симптомы звучат как срочные (сильная боль, инфекция, ожог) — мягко направь к врачу.
- Без назначений рецептурных препаратов.
""".strip()


def _rule_reply(user_text: str) -> str:
    lower = user_text.lower()
    if any(w in lower for w in ("жж", "ожог", "гной", "температур", "отёк", "отек")):
        return (
            "Похоже на ситуацию, где лучше очно обратиться к врачу. "
            "Пока избегайте новых активных средств и агрессивного солнца. " + DISCLAIMER
        )
    if any(w in lower for w in ("сух", "стяну")):
        return (
            "Если кожа стала суше в поездке — усильте лёгкое увлажнение и не добавляйте "
            "новые кислоты первые дни. SPF по-прежнему важен. " + DISCLAIMER
        )
    if any(w in lower for w in ("жирн", "блеск", "воспален", "прыщ")):
        return (
            "При росте блеска/воспалений упростите рутину: мягкое очищение, лёгкий увлажнитель, SPF. "
            "Новые активные средства лучше не вводить в поездке. " + DISCLAIMER
        )
    return (
        "Зафиксируйте изменения и продолжайте базовый travel-план: очищение → увлажнение → SPF. "
        "Если станет хуже за 48 часов — пересмотрите нагрузку активами. " + DISCLAIMER
    )


async def reply_about_check(
    *,
    user_text: str,
    check_payload: dict[str, Any],
    history: list[dict[str, str]],
) -> str:
    context = {
        "user_message": user_text,
        "check": {
            "mode": check_payload.get("mode"),
            "climate": check_payload.get("climate"),
            "why_reasons": check_payload.get("why_reasons"),
            "care_plan": check_payload.get("care_plan"),
            "forecast_summary": check_payload.get("forecast_summary"),
            "skin": check_payload.get("skin"),
        },
        "recent_messages": history[-8:],
        "disclaimer": DISCLAIMER,
    }
    try:
        data = await generate_json(
            system_prompt=SYSTEM_PROMPT,
            user_text=json.dumps(context, ensure_ascii=False),
        )
        reply = str(data.get("reply") or "").strip()
        tips = data.get("tips") if isinstance(data.get("tips"), list) else []
        tip_lines = [f"• {t}" for t in tips if str(t).strip()][:3]
        parts = [reply] if reply else []
        if tip_lines:
            parts.append("Подсказки:\n" + "\n".join(tip_lines))
        parts.append(DISCLAIMER)
        text = "\n\n".join(parts).strip()
        if text:
            return text
    except LlmError:
        if not settings.llm_allow_rule_based_fallback:
            raise
    return _rule_reply(user_text)
