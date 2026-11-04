from __future__ import annotations

import asyncio
import logging
from datetime import UTC, datetime

from sqlalchemy import select

from app.core.config import settings
from app.db import session as session_mod
from app.db.models import SkinCheck, User
from app.services.mailer import send_followup_reminder

logger = logging.getLogger(__name__)


def process_due_reminders(*, limit: int = 50) -> dict[str, int]:
    """Send emails for due reminders once; mark remind_sent_at after attempt."""
    sent = 0
    skipped = 0
    failed = 0
    db = session_mod.SessionLocal()
    try:
        now = datetime.now(UTC)
        rows = db.scalars(
            select(SkinCheck)
            .where(
                SkinCheck.remind_at.is_not(None),
                SkinCheck.remind_at <= now,
                SkinCheck.remind_sent_at.is_(None),
            )
            .order_by(SkinCheck.remind_at.asc())
            .limit(limit)
        ).all()
        for check in rows:
            user = db.get(User, check.user_id)
            if user is None or not user.email:
                skipped += 1
                check.remind_sent_at = now
                continue
            try:
                ok = send_followup_reminder(
                    user.email,
                    check.dest_city or "поездка",
                    check.id,
                )
                check.remind_sent_at = now
                if ok:
                    sent += 1
                else:
                    # SMTP off — still mark sent so we don't loop forever; in-app /due remains.
                    skipped += 1
            except Exception:
                logger.exception("remind send failed check=%s", check.id)
                failed += 1
                # Retry later: do not set remind_sent_at
        db.commit()
    finally:
        db.close()
    return {"sent": sent, "skipped": skipped, "failed": failed, "processed": sent + skipped + failed}


async def reminder_loop(stop: asyncio.Event) -> None:
    interval = max(30, int(settings.remind_poll_seconds))
    logger.info("reminder loop started (every %ss)", interval)
    while not stop.is_set():
        try:
            stats = await asyncio.to_thread(process_due_reminders)
            if stats["processed"]:
                logger.info("reminders tick %s", stats)
        except Exception:
            logger.exception("reminder loop tick failed")
        try:
            await asyncio.wait_for(stop.wait(), timeout=interval)
        except TimeoutError:
            continue
    logger.info("reminder loop stopped")
