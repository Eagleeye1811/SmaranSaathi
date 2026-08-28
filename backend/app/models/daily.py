"""Mirrors frontend/lib/core/models/daily.dart (mood + journal + reminders)."""
from enum import Enum
from typing import Optional

from .common import APIModel


class MoodLevel(str, Enum):
    good = "good"
    okay = "okay"
    low = "low"


class ReminderKind(str, Enum):
    medicine = "medicine"
    hydration = "hydration"
    cognitive = "cognitive"
    appointment = "appointment"
    routine = "routine"


class JournalEntry(APIModel):
    question_id: str
    label: str
    answer: str
    positive: bool
    time: str


class Reminder(APIModel):
    id: str
    time: str
    minutes_from_midnight: int
    title: str
    kind: ReminderKind
    detail: str = ""
    done: bool = False


class MoodCheckIn(APIModel):
    mood: MoodLevel
    at: Optional[str] = None
