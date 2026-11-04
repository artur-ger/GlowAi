from __future__ import annotations

import logging
import smtplib
from email.message import EmailMessage

from app.core.config import settings

logger = logging.getLogger(__name__)


def smtp_configured() -> bool:
    from app.core.config import get_settings

    s = get_settings()
    return bool(s.smtp_host and s.smtp_from and s.smtp_user)


def send_email(*, to: str, subject: str, body: str) -> bool:
    """Send plain-text email. Returns True if sent, False if SMTP not configured."""
    s = settings
    from app.core.config import get_settings

    s = get_settings()
    if not (s.smtp_host and s.smtp_from and s.smtp_user):
        logger.info("SMTP not configured; skip send to %s subject=%s", to, subject)
        return False
    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = s.smtp_from
    msg["To"] = to
    msg.set_content(body)
    try:
        with smtplib.SMTP(s.smtp_host, s.smtp_port, timeout=20) as smtp:
            if s.smtp_use_tls:
                smtp.starttls()
            if s.smtp_user:
                smtp.login(s.smtp_user, s.smtp_password)
            smtp.send_message(msg)
        logger.info("email sent to %s (%s)", to, subject)
        return True
    except Exception:
        logger.exception("email send failed to %s", to)
        raise


def send_verify_code(email: str, code: str) -> bool:
    return send_email(
        to=email,
        subject="GlowAi — код подтверждения email",
        body=(
            f"Ваш код подтверждения GlowAi: {code}\n\n"
            "Код действует 30 минут.\n"
            "Если вы не регистрировались — просто игнорируйте письмо.\n"
        ),
    )


def send_reset_code(email: str, code: str) -> bool:
    return send_email(
        to=email,
        subject="GlowAi — сброс пароля",
        body=(
            f"Код для сброса пароля GlowAi: {code}\n\n"
            "Код действует 30 минут.\n"
            "Если вы не запрашивали сброс — игнорируйте письмо.\n"
        ),
    )


def send_followup_reminder(email: str, dest_city: str, check_id: int) -> bool:
    return send_email(
        to=email,
        subject="GlowAi — пора оценить кожу после поездки",
        body=(
            f"Напоминание: прошло время follow-up по направлению «{dest_city}» "
            f"(проверка #{check_id}).\n"
            "Откройте GlowAi → Профиль → повторите оценку или напишите в чат, "
            "как изменилось состояние кожи.\n\n"
            "GlowAi не является медицинским сервисом.\n"
        ),
    )
