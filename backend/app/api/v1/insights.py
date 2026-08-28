"""AI insights — structure only, per the phase-1 brief: no Gemini, no model
calls. Every route here answers honestly with 501 rather than fabricating a
response, so a caller can tell "not built" apart from "no insights yet"."""
from fastapi import APIRouter

from app.core.errors import ApiError

router = APIRouter(prefix="/insights", tags=["ai insights"])


@router.get("/{patient_id}")
async def get_insights(patient_id: str) -> None:
    raise ApiError(
        "not_implemented",
        "AI insights are not implemented yet — this endpoint is reserved for a future phase.",
    )
