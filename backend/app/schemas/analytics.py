from typing import Dict, List

from app.models.clinical import CognitiveProfile, SeriesPoint
from app.models.common import APIModel
from app.models.game import CognitiveDomain


class CognitiveProfileUpdate(APIModel):
    scores: Dict[CognitiveDomain, int]


class WeeklySeriesResponse(APIModel):
    series: str
    points: List[SeriesPoint]


class CognitiveProfileResponse(CognitiveProfile):
    patient_id: str
