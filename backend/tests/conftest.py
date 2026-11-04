from __future__ import annotations

import os

# Use in-memory-ish file db for tests before app imports settings cache.
os.environ["DATABASE_URL"] = "sqlite:///./test_glowai.db"
os.environ.setdefault("JWT_SECRET", "test-secret-glowai-long-enough-32b")
os.environ.setdefault("LLM_PROVIDER", "rule_based")
os.environ["LLM_API_KEY"] = ""
os.environ["REMIND_WORKER_ENABLED"] = "false"
os.environ.setdefault("APP_ENV", "dev")
os.environ["SMTP_HOST"] = ""
os.environ["SMTP_USER"] = ""
os.environ["SMTP_FROM"] = ""
os.environ["SMTP_PASSWORD"] = ""

from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

# Reset settings cache after env patch
from app.core import config as config_mod

config_mod.get_settings.cache_clear()
config_mod.settings = config_mod.get_settings()

from app.db import session as session_mod
from app.db.models import Base
from app.main import app

_engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(bind=_engine, autoflush=False, autocommit=False)
Base.metadata.create_all(bind=_engine)

session_mod.engine = _engine
session_mod.SessionLocal = TestingSessionLocal


def override_get_db() -> Generator[Session, None, None]:
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[session_mod.get_db] = override_get_db


@pytest.fixture()
def client() -> Generator[TestClient, None, None]:
    Base.metadata.drop_all(bind=_engine)
    Base.metadata.create_all(bind=_engine)
    with TestClient(app) as c:
        yield c
