from __future__ import annotations

import base64
import json
import logging
import re
from typing import Any

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)


class LlmError(RuntimeError):
    pass


def _endpoint(base_url: str) -> str:
    normalized = base_url.rstrip("/")
    if normalized.endswith("/v1"):
        return f"{normalized}/chat/completions"
    if "/openai" in normalized:
        return f"{normalized}/chat/completions"
    return f"{normalized}/chat/completions"


async def generate_json(
    *,
    system_prompt: str,
    user_text: str,
    image_bytes: bytes | None = None,
    image_mime: str = "image/jpeg",
) -> dict[str, Any]:
    provider = (settings.llm_provider or "rule_based").strip().lower()
    if provider == "rule_based" or not settings.llm_api_key:
        raise LlmError("LLM not configured")

    content: list[dict[str, Any]] = [{"type": "text", "text": user_text}]
    if image_bytes:
        b64 = base64.b64encode(image_bytes).decode("ascii")
        content.append(
            {
                "type": "image_url",
                "image_url": {"url": f"data:{image_mime};base64,{b64}"},
            }
        )

    payload = {
        "model": settings.llm_model,
        "temperature": 0.2,
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": content},
        ],
    }
    headers = {
        "Authorization": f"Bearer {settings.llm_api_key}",
        "Content-Type": "application/json",
    }

    try:
        async with httpx.AsyncClient(timeout=settings.llm_timeout_seconds) as client:
            response = await client.post(_endpoint(settings.llm_base_url), headers=headers, json=payload)
    except httpx.TimeoutException as exc:
        raise LlmError("LLM timeout") from exc
    except httpx.HTTPError as exc:
        raise LlmError(f"LLM HTTP error: {exc}") from exc

    if response.status_code >= 400:
        raise LlmError(f"LLM rejected: HTTP {response.status_code} {response.text[:300]}")

    data = response.json()
    choices = data.get("choices") or []
    if not choices:
        raise LlmError("LLM empty choices")
    message = choices[0].get("message") or {}
    raw = message.get("content")
    if not isinstance(raw, str) or not raw.strip():
        raise LlmError("LLM empty content")
    return _parse_json_object(raw)


def _parse_json_object(raw: str) -> dict[str, Any]:
    text = raw.strip()
    try:
        data = json.loads(text)
        if isinstance(data, dict):
            return data
    except json.JSONDecodeError:
        pass
    match = re.search(r"\{.*\}", text, flags=re.DOTALL)
    if not match:
        raise LlmError("LLM response is not JSON object")
    data = json.loads(match.group(0))
    if not isinstance(data, dict):
        raise LlmError("LLM JSON is not an object")
    return data
