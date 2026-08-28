"""Request/response shape for POST /api/v1/sync/operations, plus one payload
schema per `SyncOperationKind` — field names taken verbatim from the Dart
side's `sync.enqueue(...)` payload maps in `app_state.dart` (see
`data/local/sync_operation.dart` for the enum). `SyncOperationRequest.payload`
stays a loose `Dict[str, Any]` at the top level (it's whatever the queued
`PendingOperation` carried); `sync_service.py` re-validates it against the
matching payload schema below once `kind` is known.
"""
from typing import Any, Dict, Literal

from app.models.common import APIModel

SyncOperationKind = Literal[
    "gameSession",
    "moodCheckIn",
    "journalEntry",
    "reminderToggle",
    "profileUpdate",
    "reflection",
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
    name: str


class ReflectionPayload(APIModel):
    patient_id: str
    at: str
