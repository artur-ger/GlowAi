from __future__ import annotations

import pytest

from app.core import config as config_mod
from app.core.startup import validate_runtime_settings


def test_prod_gate_rejects_weak_jwt(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_ENV", "prod")
    monkeypatch.setenv("JWT_SECRET", "dev-change-me-glowai-jwt")
    monkeypatch.setenv("CORS_ORIGINS", "https://example.com")
    monkeypatch.setenv("SMTP_HOST", "smtp.example.com")
    monkeypatch.setenv("SMTP_USER", "u")
    monkeypatch.setenv("SMTP_FROM", "GlowAi <noreply@example.com>")
    config_mod.get_settings.cache_clear()
    with pytest.raises(SystemExit) as ei:
        validate_runtime_settings()
    assert ei.value.code == 2


def test_prod_gate_cleanup_restores_dev(monkeypatch: pytest.MonkeyPatch) -> None:
    # Ensure later tests see SMTP off / app_env=dev after previous monkeypatches.
    monkeypatch.setenv("APP_ENV", "dev")
    monkeypatch.setenv("JWT_SECRET", "test-secret-glowai-long-enough-32b")
    monkeypatch.setenv("CORS_ORIGINS", "*")
    monkeypatch.setenv("SMTP_HOST", "")
    monkeypatch.setenv("SMTP_USER", "")
    monkeypatch.setenv("SMTP_FROM", "")
    config_mod.get_settings.cache_clear()
    config_mod.settings = config_mod.get_settings()
    validate_runtime_settings()
