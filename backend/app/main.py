from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

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
    description="SmaranSaathi sync backend — SIH 2026 PS 26003.",
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
