"""AI insights — structure only. No model is called yet (Gemini is explicitly
out of scope for this phase); the endpoint returns 501 so callers can detect
"not built yet" instead of getting a fabricated response."""
from typing import List, Optional

from app.models.common import APIModel


class AIInsight(APIModel):
    id: str
    patient_id: str
    summary: str
    generated_at: str


class AIInsightsResponse(APIModel):
    patient_id: str
    insights: List[AIInsight] = []
    note: Optional[str] = "AI insights are not implemented yet."
