"""Request/response shape for POST /api/v1/sync/operations, plus one payload
schema per `SyncOperationKind` — field names taken verbatim from the Dart
side's `sync.enqueue(...)` payload maps in `app_state.dart` (see
`data/local/sync_operation.dart` for the enum). `SyncOperationRequest.payload`
stays a loose `Dict[str, Any]` at the top level (it's whatever the queued
`PendingOperation` carried); `sync_service.py` re-validates it against the
matching payload schema below once `kind` is known.
"""
from typing import Any, Dict, Literal, Optional

from app.models.common import APIModel

SyncOperationKind = Literal[
    "gameSession",
    "moodCheckIn",
    "journalEntry",
    "reminderToggle",
    "profileUpdate",
    "reflection",
    "assessmentUpdate",
    "baselineCaptured",
    "reminderCreate",
    "unknown",
]


class SyncOperationRequest(APIModel):
    operation_id: str
    kind: SyncOperationKind
    payload: Dict[str, Any]
    created_at_millis: int


class SyncOperationResult(APIModel):
    operation_id: str
    status: Literal["synced", "duplicate"]
    synced_at_millis: int


class GameSessionPayload(APIModel):
    patient_id: str
    game_id: str
    level: int
    next_level: int
    accuracy: float
    focus: float
    memory: float
    hints_used: int
    mistakes: int
    seconds: int
    completed: bool
    overall: int
    time_label: str


class MoodCheckInPayload(APIModel):
    patient_id: str
    mood: str
    at: str


class JournalEntryPayload(APIModel):
    patient_id: str
    question_id: str
    answer: str
    positive: bool
    at: str


class ReminderTogglePayload(APIModel):
    patient_id: str
    reminder_id: str
    done: bool
    at: str


class ProfileUpdatePayload(APIModel):
    patient_id: str
    name: Optional[str] = None
    phone_number: Optional[str] = None



class ReflectionPayload(APIModel):
    patient_id: str
    at: str


class AssessmentUpdatePayload(APIModel):
    """One completed step of the structured intake.

    The step name is validated; the answers themselves are passed through as
    written. The questionnaire is expected to keep changing shape as items are
    added and reworded, and a strict schema here would mean a backend release
    for every wording change — while the value of this record is the raw
    answers, which the app already keyed by permanent item ids.
    """

    patient_id: str
    step: Optional[str] = None

    model_config = {"extra": "allow"}


class BaselineCapturedPayload(APIModel):
    """The person's baseline domain scores, frozen at the end of their first
    complete assessment."""

    patient_id: str
    scores: Dict[str, float]
    captured_at: str
    session_count: int


class SyncReminderPayload(APIModel):
    id: str
    time: str
    minutes_from_midnight: int
    title: str
    kind: str
    detail: str = ""
    sms_enabled: bool = True


class ReminderCreatePayload(APIModel):
    patient_id: str
    reminder: SyncReminderPayload

