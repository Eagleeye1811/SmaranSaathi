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

from app.models.clinical import CognitiveProfile, DoctorAlert, SeriesPoint
from app.models.daily import JournalEntry, MoodLevel, Reminder
from app.models.game import GameSession
from app.models.patient import Patient
from app.models.relationship import CaregiverPatientLink
from app.schemas.doctor import DoctorConnectionRequest
from app.models.doctor import DoctorPatientLink, DoctorProfile
from app.schemas.pairing import ClaimUsernameResponse


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

    @abstractmethod
    async def list_all_due_now(
        self, hour: int, minute: int
    ) -> List[tuple[str, Optional[str], Reminder]]:
        """Return (patient_id, patient_phone_number, reminder) tuples for every
        undone, sms_enabled reminder scheduled at the given hour:minute across
        ALL patients. Used exclusively by the SMS scheduler."""
        ...


class CaregiverLinkRepository(ABC):
    @abstractmethod
    async def create(self, link: CaregiverPatientLink) -> CaregiverPatientLink: ...

    @abstractmethod
    async def list_for_caregiver(self, caregiver_id: str) -> List[CaregiverPatientLink]: ...


class PairingClaimRepository(ABC):
    """The username a caregiver claims for their patient — unlike a pending
    pairing *request* (a short-lived handshake, fine to lose on a restart),
    a claim needs to outlive the process: it is the durable mapping a
    patient's device looks up by name, potentially long after the caregiver
    claimed it. Keyed by the normalised (lowercased, trimmed) username."""

    @abstractmethod
    async def get(self, username: str) -> Optional[ClaimUsernameResponse]: ...

    @abstractmethod
    async def save(self, claim: ClaimUsernameResponse) -> ClaimUsernameResponse: ...

    @abstractmethod
    async def list_for_caregiver(self, caregiver_uid: str) -> List[ClaimUsernameResponse]: ...


class DoctorConnectionRequestRepository(ABC):
    """A caregiver's pending invite to a doctor, durable and keyed by its own
    request id.

    This used to be a process-local dict, on the same reasoning as pairing:
    a handshake is short-lived, so losing it on a restart is fine. Pairing can
    afford that because both devices are in the same room, seconds apart. A
    doctor invite is not that shape — the caregiver sends it and the doctor
    looks whenever their next clinic session happens to be — so the queue has
    to outlive both the process and the afternoon.
    """

    @abstractmethod
    async def get(self, request_id: str) -> Optional[DoctorConnectionRequest]: ...

    @abstractmethod
    async def save(self, request: DoctorConnectionRequest) -> DoctorConnectionRequest: ...

    @abstractmethod
    async def list_pending_for_doctor(self, doctor_uid: str) -> List[DoctorConnectionRequest]: ...

    @abstractmethod
    async def list_for_patient(self, patient_id: str) -> List[DoctorConnectionRequest]: ...


class DoctorProfileRepository(ABC):
    """A doctor's own listing, durable and keyed by their Firebase uid — the
    directory every caregiver browses. Unlike `PairingClaimRepository`, no
    normalisation is needed: the key is an account id, not a name someone
    typed in."""

    @abstractmethod
    async def get(self, uid: str) -> Optional[DoctorProfile]: ...

    @abstractmethod
    async def upsert(self, profile: DoctorProfile) -> DoctorProfile: ...

    @abstractmethod
    async def list_all(self) -> List[DoctorProfile]: ...


class DoctorPatientLinkRepository(ABC):
    """The durable half of a doctor↔patient connection — written once a
    pending `DoctorConnectionRequest` (ephemeral, held in-process by
    `DoctorConnectionService`, same reasoning as pairing's request queue) is
    accepted. Two query directions, both needed: a doctor's caseload reads
    `list_for_doctor`; a caregiver's "who is our doctor" reads
    `get_for_patient`."""

    @abstractmethod
    async def create(self, link: DoctorPatientLink) -> DoctorPatientLink: ...

    @abstractmethod
    async def list_for_doctor(self, doctor_uid: str) -> List[DoctorPatientLink]: ...

    @abstractmethod
    async def get_for_patient(self, patient_id: str) -> Optional[DoctorPatientLink]: ...

    @abstractmethod
    async def delete(self, patient_id: str, doctor_uid: str) -> None: ...


class AssessmentRepository(ABC):
    """The structured intake and the cognitive baseline, as the Flutter app
    recorded them. Stored as documents rather than typed rows for the same
    reason the app does: the questionnaire is still moving."""

    @abstractmethod
    async def save_intake_step(self, patient_id: str, step: str, payload: dict) -> None: ...

    @abstractmethod
    async def get_intake(self, patient_id: str) -> Optional[dict]: ...

    @abstractmethod
    async def save_baseline(self, patient_id: str, baseline: dict) -> None: ...

    @abstractmethod
    async def get_baseline(self, patient_id: str) -> Optional[dict]: ...


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
