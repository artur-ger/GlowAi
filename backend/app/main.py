import asyncio
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse, PlainTextResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles

from app.api.routes import analyze, auth, chat, checks, climate, geo, health, profile, trips
from app.core.config import settings
from app.core.startup import validate_runtime_settings
from app.db.session import init_db
from app.services.reminders import reminder_loop


@asynccontextmanager
async def lifespan(_app: FastAPI):
    validate_runtime_settings()
    init_db()
    stop = asyncio.Event()
    worker: asyncio.Task[None] | None = None
    if settings.remind_worker_enabled:
        worker = asyncio.create_task(reminder_loop(stop), name="glowai-reminders")
    try:
        yield
    finally:
        stop.set()
        if worker is not None:
            await worker


app = FastAPI(title=settings.app_name, version="0.3.0", lifespan=lifespan)

origins = [o.strip() for o in settings.cors_origins.split(",") if o.strip()]
wildcard = origins == ["*"] or not origins
if settings.is_prod and wildcard:
    # Belt: startup gate should already exit; keep middleware strict.
    origins = []
    wildcard = False
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if wildcard else origins,
    allow_credentials=not wildcard,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(analyze.router)
app.include_router(climate.router)
app.include_router(geo.router)
app.include_router(auth.router)
app.include_router(checks.router)
app.include_router(chat.router)
app.include_router(profile.router)
app.include_router(trips.router)

_WEB_DIR = Path(__file__).resolve().parent.parent / "web"
_WEB_INDEX = _WEB_DIR / "index.html"
_LEGAL_DIR = Path(__file__).resolve().parent.parent / "legal"


@app.get("/legal/privacy", response_model=None)
async def legal_privacy():
    path = _LEGAL_DIR / "privacy.md"
    if not path.exists():
        return PlainTextResponse("privacy not packaged", status_code=404)
    return FileResponse(path, media_type="text/markdown; charset=utf-8")


@app.get("/legal/terms", response_model=None)
async def legal_terms():
    path = _LEGAL_DIR / "terms.md"
    if not path.exists():
        return PlainTextResponse("terms not packaged", status_code=404)
    return FileResponse(path, media_type="text/markdown; charset=utf-8")


@app.get("/api")
async def api_root() -> dict[str, object]:
    return {
        "app": settings.app_name,
        "version": "0.3.0",
        "docs": "/docs",
        "healthz": "/healthz",
        "analyze": "POST /api/v1/analyze",
        "auth": "POST /api/v1/auth/register | login ; GET /me",
        "checks": "GET|POST /api/v1/checks",
        "chat": "GET|POST /api/v1/checks/{id}/messages",
        "trips": "GET|POST /api/v1/trips · GET /active · daily-tip",
        "profile": "GET|PATCH /api/v1/profile/me",
        "geo": "GET /api/v1/geo/places | /api/v1/geo/popular",
        "web": "/app/" if _WEB_INDEX.exists() else None,
        "web_ready": _WEB_INDEX.exists(),
        "llm_provider": settings.llm_provider,
        "llm_configured": bool(settings.llm_api_key)
        and settings.llm_provider != "rule_based",
        "remind_worker": settings.remind_worker_enabled,
        "app_env": settings.app_env,
    }


@app.get("/", response_model=None)
async def root() -> RedirectResponse | JSONResponse:
    if _WEB_INDEX.exists():
        return RedirectResponse(url="/app/")
    return JSONResponse(
        {
            "app": settings.app_name,
            "docs": "/docs",
            "hint": "UI ещё не собран. Запустите: .\\scripts\\start-mvp.ps1",
            "analyze": "POST /api/v1/analyze",
        }
    )


if _WEB_INDEX.exists():
    app.mount("/app", StaticFiles(directory=_WEB_DIR, html=True), name="web")
