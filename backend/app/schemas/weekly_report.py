"""The doctor-only weekly clinical report.

Mirrors `frontend/lib/core/models/weekly_report.dart`. There is deliberately
no patient/caregiver-facing endpoint anywhere for this resource — that is
the entire mechanism keeping it doctor-only, the same way a permission flag
would, but with nothing to forget to check.
"""
from typing import List, Optional

from pydantic import BaseModel


class GameDomainSummary(BaseModel):
    game_id: str
    game_name: str
    sessions_played: int
    avg_accuracy: float
    avg_focus: float
    avg_memory: float
    avg_hints_used: float
    avg_mistakes: float


class ConcernUpdateEntry(BaseModel):
    difficulty: str
    difficulty_label: str
    trend: str  # better | same | worse
    comment: str = ""
    at: str


class CaregiverNoteRecord(BaseModel):
    text: str
    at: str


class WeeklyClinicalReport(BaseModel):
    patient_id: str
    doctor_id: Optional[str] = None
    patient_name: str
    cycle_start: str
    generated_at: str
    days_active: int = 0
    activities_completed: int = 0
    game_summaries: List[GameDomainSummary] = []
    caregiver_concern_updates: List[ConcernUpdateEntry] = []
    caregiver_notes: List[CaregiverNoteRecord] = []
    onboarding_baseline_note: Optional[str] = None
