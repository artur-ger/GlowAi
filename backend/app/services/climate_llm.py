"""LLM roles for climate consultant (PDF §9) — never computes sensation.

Tasks: plan parse, explanation, pick from clothing/care whitelist.
Profile/weather PII stays out of prompts; only anonymized scenario tokens.
"""

from __future__ import annotations

import logging
from typing import Any

from app.schemas.climate import CareItem, ClimatePlanParsed, ClothingItem
from app.services.llm import LlmError, generate_json

logger = logging.getLogger(__name__)

_CLOTHING_WHITELIST = {
    "thermal_base",
    "insulated_mid",
    "winter_parka",
    "cold_accessories",
    "warm_knit",
    "insulated_jacket",
    "closed_shoes",
    "long_sleeve",
    "sweater_fleece",
    "light_jacket",
    "tee_shirt",
    "spare_light",
    "light_tee",
    "sun_hat",
    "minimal",
    "shade_hat",
}

_CARE_WHITELIST = {
    "spf",
    "wind_balm",
    "moisturizer",
    "rain_gear",
    "water",
    "lip_balm",
    "repellent",
    "basic_moist",
    "hood_fixative",
}


async def llm_parse_plan(text: str, lang: str) -> ClimatePlanParsed | None:
    try:
        data = await generate_json(
            system_prompt=(
                "You extract outing plan structure as JSON only. "
                "Keys: activity (low|moderate|high), duration_hours (number|null), "
                "formality (casual|smart|formal|unknown), outdoor (bool), summary (short). "
                "No medical advice. No personal data."
            ),
            user_text=f"lang={lang}\nplan={text[:400]}",
        )
    except LlmError:
        return None
    except Exception:
        logger.exception("llm plan parse failed")
        return None
    try:
        act = data.get("activity") or "moderate"
        if act not in ("low", "moderate", "high"):
            act = "moderate"
        form = data.get("formality") or "unknown"
        if form not in ("casual", "smart", "formal", "unknown"):
            form = "unknown"
        dur = data.get("duration_hours")
        duration = float(dur) if isinstance(dur, (int, float)) else None
        return ClimatePlanParsed(
            activity=act,  # type: ignore[arg-type]
            duration_hours=duration,
            formality=form,  # type: ignore[arg-type]
            outdoor=bool(data.get("outdoor", True)),
            summary=str(data.get("summary") or "")[:200],
        )
    except Exception:
        logger.exception("llm plan parse schema failed")
        return None


async def llm_explain(
    *,
    lang: str,
    sensation_label: str,
    utci_c: float,
    pet_c: float | None,
    ireq_clo: float,
    confidence: str,
    why: list[str],
) -> str | None:
    try:
        data = await generate_json(
            system_prompt=(
                "Explain outdoor comfort advice in 2 short sentences. JSON: "
                '{"explanation":"..."}. No medicine. Use only given numbers.'
            ),
            user_text=(
                f"lang={lang}; sensation={sensation_label}; utci={utci_c}; "
                f"pet={pet_c}; ireq_clo={ireq_clo}; confidence={confidence}; "
                f"why={'; '.join(why[:5])}"
            ),
        )
        text = str(data.get("explanation") or "").strip()
        return text[:400] if text else None
    except LlmError:
        return None
    except Exception:
        logger.exception("llm explain failed")
        return None


async def llm_filter_whitelist(
    *,
    lang: str,
    clothing: list[ClothingItem],
    care: list[CareItem],
    scenario: str,
) -> tuple[list[ClothingItem], list[CareItem]] | None:
    """Ask LLM to reorder/subset only from provided whitelist items."""
    cloth_payload = [{"item": c.item, "layer": c.layer, "clo": c.clo} for c in clothing]
    care_payload = [{"item": c.item, "reason": c.reason} for c in care]
    try:
        data = await generate_json(
            system_prompt=(
                "You may ONLY pick items from the provided clothing and care lists. "
                "Return JSON {clothing:[...], care:[...]} same shape. "
                "Do not invent product brands or medicines."
            ),
            user_text=(
                f"lang={lang}; scenario={scenario[:120]}; "
                f"clothing={cloth_payload}; care={care_payload}"
            ),
        )
    except LlmError:
        return None
    except Exception:
        logger.exception("llm whitelist filter failed")
        return None

    try:
        allowed_c = {c.item for c in clothing}
        allowed_k = {c.item for c in care}
        new_c: list[ClothingItem] = []
        for row in data.get("clothing") or []:
            if not isinstance(row, dict):
                continue
            item = str(row.get("item") or "")
            if item not in allowed_c:
                continue
            src = next(x for x in clothing if x.item == item)
            new_c.append(src)
        new_k: list[CareItem] = []
        for row in data.get("care") or []:
            if not isinstance(row, dict):
                continue
            item = str(row.get("item") or "")
            if item not in allowed_k:
                continue
            src = next(x for x in care if x.item == item)
            new_k.append(src)
        if not new_c:
            new_c = clothing
        if not new_k:
            new_k = care
        return new_c, new_k
    except Exception:
        logger.exception("llm whitelist apply failed")
        return None


def rule_explanation(
    *,
    lang: str,
    sensation_label: str,
    utci_c: float,
    pet_c: float | None,
    ireq_clo: float,
    confidence: str,
) -> str:
    if lang == "en":
        pet = f", PET≈{pet_c:.1f}°C" if pet_c is not None else ""
        return (
            f"You will likely feel {sensation_label} (UTCI {utci_c:.1f}°C{pet}). "
            f"Required insulation ≈{ireq_clo:.2f} clo; confidence {confidence}."
        )
    pet = f", PET≈{pet_c:.1f}°C" if pet_c is not None else ""
    return (
        f"Ощущение «{sensation_label}» (UTCI {utci_c:.1f}°C{pet}). "
        f"Нужная теплоизоляция ≈{ireq_clo:.2f} clo; уверенность {confidence}."
    )
