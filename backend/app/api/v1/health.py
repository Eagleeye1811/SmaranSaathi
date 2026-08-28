from typing import Any, Dict

from fastapi import APIRouter, Depends

from app.core.config import Settings, get_settings
from app.schemas.health import HealthResponse
from app.services.sms_service import sms_service

router = APIRouter(tags=["health"])

_VERSION = "0.1.0"


@router.get("/health", response_model=HealthResponse)
async def health(settings: Settings = Depends(get_settings)) -> HealthResponse:
    return HealthResponse(
        service=settings.app_name,
        version=_VERSION,
        environment=settings.app_env,
        firebase_configured=settings.firebase_configured,
    )


@router.post("/health/test-sms", response_model=Dict[str, Any])
async def test_sms(
    to: str,
    settings: Settings = Depends(get_settings),
) -> Dict[str, Any]:
    """Send a test SMS to verify Twilio credentials and delivery."""
    sent, reason = await sms_service.send_with_details(
        to=to,
        body="sms_appointment_reminders",
    )
    return {"sent": sent, "reason": reason, "to": to}

