"""Mirrors frontend/lib/core/models/clinical.dart."""
from enum import Enum
from typing import Dict, List, Optional

from .common import APIModel
from .game import CognitiveDomain


class TrendDirection(str, Enum):
    up = "up"
    flat = "flat"
    down = "down"


class ClinicalStatus(str, Enum):
    stable = "stable"
    needs_attention = "needsAttention"
    follow_up = "followUp"


class AlertSeverity(str, Enum):
    info = "info"
    watch = "watch"
    urgent = "urgent"


class CognitiveProfile(APIModel):
    scores: Dict[CognitiveDomain, int]
    overall: int
    updated: str


class ClinicPatient(APIModel):
    id: str
    name: str
    age: int
    district: str
    score: int
    trend: TrendDirection
    status: ClinicalStatus
    scene_id: str
    language: str
    last_session: str
    profile: CognitiveProfile
    thirty_day: List[float] = []
    adherence: int
    engagement: int


class DoctorAlert(APIModel):
    id: str
    patient_name: str
    title: str
    detail: str
    severity: AlertSeverity
    age: str
    domain: Optional[CognitiveDomain] = None


class SeriesPoint(APIModel):
    label: str
    value: float
