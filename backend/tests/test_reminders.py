from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from app.core import config as config_mod
from app.core.security import hash_password
from app.db import session as session_mod
from app.db.models import SkinCheck, User
from app.services.reminders import process_due_reminders


def test_process_due_marks_sent_without_smtp(client, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SMTP_HOST", "")
    monkeypatch.setenv("SMTP_USER", "")
    monkeypatch.setenv("SMTP_FROM", "")
    config_mod.get_settings.cache_clear()

    _ = client
    db = session_mod.SessionLocal()
    try:
        user = User(
            email="remind@glow.ai",
            password_hash=hash_password("secret12"),
            display_name="R",
            email_verified=True,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        check = SkinCheck(
            user_id=user.id,
            mode="pre_trip",
            home_city="Москва",
            dest_city="Анталия",
            forecast_summary="x",
            engine="rule_based",
            payload_json="{}",
            remind_at=datetime.now(UTC) - timedelta(hours=1),
        )
        db.add(check)
        db.commit()
        cid = check.id
    finally:
        db.close()

    stats = process_due_reminders()
    assert stats["processed"] >= 1

    db = session_mod.SessionLocal()
    try:
        row = db.get(SkinCheck, cid)
        assert row is not None
        assert row.remind_sent_at is not None
    finally:
        db.close()
