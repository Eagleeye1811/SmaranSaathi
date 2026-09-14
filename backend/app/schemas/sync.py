"""Request/response shape for POST /api/v1/sync/operations, plus one payload
schema per `SyncOperationKind` — field names taken verbatim from the Dart
side's `sync.enqueue(...)` payload maps in `app_state.dart` (see
`data/local/sync_operation.dart` for the enum). `SyncOperationRequest.payload`
stays a loose `Dict[str, Any]` at the top level (it's whatever the queued
`PendingOperation` carried); `sync_service.py` re-validates it against the
matching payload schema below once `kind` is known.
"""
from typing import Any, Dict, List, Literal, Optional

from app.models.common import APIModel
from app.models.patient import FamilyMember, LifeMemory, MemoryAsset, RoutineItem

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
    attempts: int = 0
    correct: int = 0
    response_millis: int = 0
    played_at: Optional[str] = None


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
    """The person's profile as the app holds it.

    Every field past `patient_id` is optional so that a small edit — a phone
    number, a name — stays a small payload. A full push sends everything, and
    `sync_service` applies only what was actually sent: that is what makes the
    profile reconstructable on a second device without a partial write from
    one screen wiping the answers given on another.
    """

    patient_id: str
    name: Optional[str] = None
    short_name: Optional[str] = None
    age: Optional[int] = None
    location: Optional[str] = None
    language: Optional[str] = None
    occupation: Optional[str] = None
    favourite_activity: Optional[str] = None
    favourite_food: Optional[str] = None
    favourite_music: Optional[str] = None
    tradition: Optional[str] = None
    portrait_scene: Optional[str] = None
    stage_note: Optional[str] = None
    joined_on: Optional[str] = None
    phone_number: Optional[str] = None
    family: Optional[List[FamilyMember]] = None
    memories: Optional[List[LifeMemory]] = None
    assets: Optional[List[MemoryAsset]] = None
    routine: Optional[List[RoutineItem]] = None



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



class RestoreBundle(APIModel):
    """Everything a second device needs to become this patient.

    One response rather than five calls: a device coming online for the first
    time should either have the whole record or none of it, and five separate
    requests can half-succeed on a rural connection and leave a profile that
    looks complete but is missing its history.
    """

    patient_id: str
    patient: Optional[Dict[str, Any]] = None
    intake: Optional[Dict[str, Any]] = None
    baseline: Optional[Dict[str, Any]] = None
    sessions: List[Dict[str, Any]] = []
    reminders: List[Dict[str, Any]] = []
    journal: List[Dict[str, Any]] = []
    mood: Optional[str] = None
