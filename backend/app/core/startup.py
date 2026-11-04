from __future__ import annotations

import logging
import sys

from app.core.config import get_settings
from app.services.mailer import smtp_configured

logger = logging.getLogger(__name__)

_WEAK_JWT = {
    "",
    "dev-change-me-glowai-jwt",
    "change-me",
    "secret",
    "jwt-secret",
}


def validate_runtime_settings() -> None:
    """Fail fast in prod; warn in dev."""
    settings = get_settings()
    weak_jwt = settings.jwt_secret.strip() in _WEAK_JWT or len(settings.jwt_secret.strip()) < 24

    if settings.is_prod:
        errors: list[str] = []
        if weak_jwt:
            errors.append("JWT_SECRET слишком слабый или дефолтный — задайте длинный случайный секрет")
        if settings.require_smtp_in_prod and not smtp_configured():
            errors.append("SMTP не настроен (SMTP_HOST/SMTP_USER/SMTP_FROM) — в prod нужны письма verify/reset")
        if settings.cors_origins.strip() in ("", "*"):
            errors.append("CORS_ORIGINS=* запрещён в prod — укажите явные origin'ы")
        if errors:
            for e in errors:
                logger.error("PROD GATE: %s", e)
            print("GlowAi prod gate failed:\n- " + "\n- ".join(errors), file=sys.stderr)
            raise SystemExit(2)
        logger.info("prod gate OK (JWT/SMTP/CORS)")
        return

    if weak_jwt:
        logger.warning("JWT_SECRET is weak/default — OK for local only")
    if not smtp_configured():
        logger.info("SMTP off — verify/reset codes exposed only when APP_ENV!=prod")
