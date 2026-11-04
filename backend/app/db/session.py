from __future__ import annotations

from collections.abc import Generator
from pathlib import Path

from sqlalchemy import create_engine, event, text
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import settings
from app.db.models import Base

_url = settings.database_url
if _url.startswith("sqlite:///"):
    raw = _url.removeprefix("sqlite:///")
    if raw and raw != ":memory:":
        Path(raw).parent.mkdir(parents=True, exist_ok=True)

connect_args = {"check_same_thread": False} if _url.startswith("sqlite") else {}
engine = create_engine(_url, connect_args=connect_args, future=True)

if _url.startswith("sqlite"):

    @event.listens_for(engine, "connect")
    def _sqlite_pragma(dbapi_connection, _connection_record) -> None:  # type: ignore[no-untyped-def]
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()


SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)


def _sqlite_add_column_if_missing(table: str, column: str, ddl_type: str) -> None:
    if not _url.startswith("sqlite"):
        return
    with engine.begin() as conn:
        rows = conn.execute(text(f"PRAGMA table_info({table})")).fetchall()
        names = {r[1] for r in rows}
        if column not in names:
            conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {column} {ddl_type}"))


def init_db() -> None:
    Base.metadata.create_all(bind=engine)
    # Lightweight migrations for already-created SQLite volumes
    _sqlite_add_column_if_missing("users", "email_verified", "BOOLEAN NOT NULL DEFAULT 0")
    _sqlite_add_column_if_missing("users", "email_verify_code", "VARCHAR(16)")
    _sqlite_add_column_if_missing("users", "email_verify_expires", "DATETIME")
    _sqlite_add_column_if_missing("users", "reset_code", "VARCHAR(16)")
    _sqlite_add_column_if_missing("users", "reset_expires", "DATETIME")
    _sqlite_add_column_if_missing("users", "terms_accepted_at", "DATETIME")
    _sqlite_add_column_if_missing("users", "skin_type", "VARCHAR(64) DEFAULT ''")
    _sqlite_add_column_if_missing("users", "concerns_csv", "VARCHAR(500) DEFAULT ''")
    _sqlite_add_column_if_missing("users", "owned_items_csv", "VARCHAR(500) DEFAULT ''")
    _sqlite_add_column_if_missing("users", "avoid_items_csv", "VARCHAR(500) DEFAULT ''")
    _sqlite_add_column_if_missing("skin_checks", "parent_check_id", "INTEGER")
    _sqlite_add_column_if_missing("skin_checks", "remind_at", "DATETIME")
    _sqlite_add_column_if_missing("skin_checks", "remind_sent_at", "DATETIME")
    _sqlite_add_column_if_missing("skin_checks", "trip_id", "INTEGER")
    _sqlite_add_column_if_missing("skin_checkins", "revised_check_id", "INTEGER")


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
