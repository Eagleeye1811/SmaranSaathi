"""Repository interfaces.

Every service talks to these, never to a concrete store — the same rule the
Flutter side follows for its own `PatientRepository`/`GameRepository`/etc.
interfaces. Phase 1 ships `repositories/memory/*` (dict-backed, mirrors
`Mock*Repository`); Phase 2 adds `repositories/firestore/*` (mirrors
`Hive*Repository`) behind these same interfaces — swapped in one place
(`core/dependencies.py`), no router changes.
"""
from abc import ABC, abstractmethod
from typing import List, Optional

from app.models.clinical import ClinicPatient, CognitiveProfile, DoctorAlert, SeriesPoint
from app.models.daily import JournalEntry, MoodLevel, Reminder
from app.models.game import GameSession
from app.models.patient import Patient
from app.models.relationship import CaregiverPatientLink


class PatientRepository(ABC):
    @abstractmethod
    async def get(self, patient_id: str) -> Optional[Patient]: ...

    @abstractmethod
    async def list(self) -> List[Patient]: ...

    @abstractmethod
    async def create(self, patient: Patient) -> Patient: ...

    @abstractmethod
    async def update(self, patient: Patient) -> Patient: ...


class GameSessionRepository(ABC):
    @abstractmethod
    async def add(self, session_id: str, patient_id: str, session: GameSession) -> GameSession: ...

    @abstractmethod
    async def list_for_patient(self, patient_id: str) -> List[GameSession]: ...


class AnalyticsRepository(ABC):
    @abstractmethod
    async def get_profile(self, patient_id: str) -> Optional[CognitiveProfile]: ...

    @abstractmethod
    async def save_profile(self, patient_id: str, profile: CognitiveProfile) -> CognitiveProfile: ...

    @abstractmethod
    async def weekly_series(self, patient_id: str, series: str) -> List[SeriesPoint]: ...

    @abstractmethod
    async def caseload(self) -> List[ClinicPatient]: ...

    @abstractmethod
    async def alerts(self) -> List[DoctorAlert]: ...


class DailyRepository(ABC):
    @abstractmethod
    async def get_mood(self, patient_id: str) -> Optional[MoodLevel]: ...

    @abstractmethod
    async def set_mood(self, patient_id: str, mood: MoodLevel) -> None: ...

    @abstractmethod
    async def add_journal_entry(
        self, patient_id: str, entry: JournalEntry, entry_id: Optional[str] = None
    ) -> JournalEntry:
        """`entry_id`, when given, makes the write idempotent (same id twice =
        one entry, not two) — used by the sync endpoint so a retried
        operation can't duplicate a journal entry. Direct API callers can
        omit it and get an auto-generated id."""
        ...

    @abstractmethod
    async def list_journal(self, patient_id: str) -> List[JournalEntry]: ...


class ReminderRepository(ABC):
    @abstractmethod
    async def list_for_patient(self, patient_id: str) -> List[Reminder]: ...

    @abstractmethod
    async def create(self, patient_id: str, reminder: Reminder) -> Reminder: ...

    @abstractmethod
    async def set_done(self, patient_id: str, reminder_id: str, done: bool) -> Optional[Reminder]: ...


class CaregiverLinkRepository(ABC):
    @abstractmethod
    async def create(self, link: CaregiverPatientLink) -> CaregiverPatientLink: ...

    @abstractmethod
    async def list_for_caregiver(self, caregiver_id: str) -> List[CaregiverPatientLink]: ...


class SyncLedgerRepository(ABC):
    """The idempotency record behind `/api/v1/sync/operations` — one entry
    per `PendingOperation.id` the Flutter app has ever successfully synced.
    Retrying the same operation looks it up here first and, if found, skips
    re-applying the write entirely."""

    @abstractmethod
    async def get(self, operation_id: str) -> Optional[dict]: ...

    @abstractmethod
    async def mark_applied(
        self, operation_id: str, kind: str, patient_id: str, applied_at_millis: int
    ) -> None: ...
