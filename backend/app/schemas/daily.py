from typing import List, Optional

from app.models.common import APIModel
from app.models.daily import JournalEntry, MoodLevel


class MoodCheckInCreate(APIModel):
    patient_id: str
    mood: MoodLevel


class JournalEntryCreate(APIModel):
    patient_id: str
    question_id: str
    label: str
    answer: str
    positive: bool = True


class DailyResponse(APIModel):
    patient_id: str
    mood: Optional[MoodLevel] = None
    journal: List[JournalEntry] = []
