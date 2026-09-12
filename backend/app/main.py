from contextlib import asynccontextmanager
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse

from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.errors import register_exception_handlers

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup actions
    from app.services.scheduler import start_scheduler
    start_scheduler()
    yield
    # Shutdown actions
    from app.services.scheduler import stop_scheduler
    stop_scheduler()


app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    description="MemoryMitra sync backend — SIH 2026 PS 26003.",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_origin_regex=settings.cors_dev_origin_regex if settings.app_env == "development" else None,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

register_exception_handlers(app)

app.include_router(api_router, prefix=settings.api_v1_prefix)


@app.get("/health", tags=["health"])
async def root_health() -> dict:
    """Unversioned liveness probe — for infra/uptime checks, not clients."""
    return {"status": "ok", "service": settings.app_name}


@app.get("/telehealth/test", response_class=HTMLResponse, tags=["telehealth"])
async def telehealth_browser_test_page():
    """WebRTC browser testing console to test calls against mobile app."""
    template_path = os.path.join(os.path.dirname(__file__), "templates", "telehealth_test.html")
    if os.path.exists(template_path):
        with open(template_path, "r", encoding="utf-8") as f:
            return HTMLResponse(content=f.read())
    return HTMLResponse(content="<h1>Telehealth test template not found</h1>", status_code=404)
