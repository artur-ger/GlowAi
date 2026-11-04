from fastapi import APIRouter
from sqlalchemy import text

from app.core.config import settings
from app.db.session import SessionLocal

router = APIRouter(tags=["system"])


@router.get("/healthz")
async def healthz() -> dict[str, str]:
    return {"status": "ok", "app": settings.app_name}


@router.get("/readyz")
async def readyz() -> dict[str, object]:
    db_ok = False
    try:
        db = SessionLocal()
        try:
            db.execute(text("SELECT 1"))
            db_ok = True
        finally:
            db.close()
    except Exception:
        db_ok = False
    return {
        "status": "ready" if db_ok else "degraded",
        "db_ok": db_ok,
        "llm_provider": settings.llm_provider,
        "llm_configured": bool(settings.llm_api_key) and settings.llm_provider != "rule_based",
        "remind_worker": settings.remind_worker_enabled,
    }
