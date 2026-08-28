"""Applies a queued Flutter `PendingOperation` to the backend, exactly once.

Idempotency: `operation_id` (the Dart side's client-generated
`PendingOperation.id`) is checked against the `sync_operations` ledger first.
If it's already there, the operation is a retry — nothing is re-applied, the
previous result is returned as `status: "duplicate"`. Otherwise the operation
is dispatched by `kind` to the matching repository write, using
`operation_id` itself as the target document's id wherever the repository
supports that (game sessions, journal entries) — so even a concurrent/racing
retry of a *new* operation can't create a second document. Reminder toggles
and mood/profile updates are naturally idempotent (re-applying the same value
is a no-op), so no deterministic id is needed there.
"""
import time

from app.core.errors import ApiError
from app.models.daily import JournalEntry, MoodLevel
from app.models.game import GameId, GamePerformance, GameSession
from app.repositories.base import (
    AssessmentRepository,
    DailyRepository,
    GameSessionRepository,
    PatientRepository,
    ReminderRepository,
    SyncLedgerRepository,
)
from app.schemas.sync import (
    AssessmentUpdatePayload,
    BaselineCapturedPayload,
    GameSessionPayload,
    JournalEntryPayload,
    MoodCheckInPayload,
    ProfileUpdatePayload,
    ReflectionPayload,
    ReminderTogglePayload,
    SyncOperationRequest,
    SyncOperationResult,
)


class SyncService:
    def __init__(
        self,
        ledger: SyncLedgerRepository,
        patients: PatientRepository,
        sessions: GameSessionRepository,
        daily: DailyRepository,
        reminders: ReminderRepository,
        assessments: AssessmentRepository,
    ) -> None:
        self._ledger = ledger
        self._patients = patients
        self._sessions = sessions
        self._daily = daily
        self._reminders = reminders
        self._assessments = assessments

    async def apply(self, request: SyncOperationRequest) -> SyncOperationResult:
        existing = await self._ledger.get(request.operation_id)
        if existing is not None:
            return SyncOperationResult(
                operation_id=request.operation_id,
                status="duplicate",
                synced_at_millis=existing["appliedAtMillis"],
            )

        patient_id = request.payload.get("patientId")
        if not patient_id or not isinstance(patient_id, str):
            raise ApiError("validation_error", "payload.patientId is required for every sync operation.")

        await self._dispatch(request.kind, patient_id, request.payload, request.operation_id)

        applied_at_millis = int(time.time() * 1000)
        await self._ledger.mark_applied(request.operation_id, request.kind, patient_id, applied_at_millis)
        return SyncOperationResult(
            operation_id=request.operation_id, status="synced", synced_at_millis=applied_at_millis
        )

    async def _dispatch(self, kind: str, patient_id: str, raw_payload: dict, operation_id: str) -> None:
        if kind == "gameSession":
            payload = GameSessionPayload.model_validate(raw_payload)
            session = GameSession(
                game_id=GameId(payload.game_id),
                level=payload.level,
                performance=GamePerformance(
                    accuracy=payload.accuracy,
                    focus=payload.focus,
                    memory=payload.memory,
                    hints_used=payload.hints_used,
                    mistakes=payload.mistakes,
                    seconds=payload.seconds,
                    completed=payload.completed,
                ),
                time_label=payload.time_label,
            )
            await self._sessions.add(operation_id, patient_id, session)

        elif kind == "moodCheckIn":
            payload = MoodCheckInPayload.model_validate(raw_payload)
            await self._daily.set_mood(patient_id, MoodLevel(payload.mood))

        elif kind == "journalEntry":
            payload = JournalEntryPayload.model_validate(raw_payload)
            entry = JournalEntry(
                question_id=payload.question_id,
                label=payload.question_id,
                answer=payload.answer,
                positive=payload.positive,
                time=payload.at,
            )
            await self._daily.add_journal_entry(patient_id, entry, entry_id=operation_id)

        elif kind == "reminderToggle":
            payload = ReminderTogglePayload.model_validate(raw_payload)
            await self._reminders.set_done(patient_id, payload.reminder_id, payload.done)

        elif kind == "profileUpdate":
            payload = ProfileUpdatePayload.model_validate(raw_payload)
            existing_patient = await self._patients.get(patient_id)
            if existing_patient is not None:
                await self._patients.update(existing_patient.model_copy(update={"name": payload.name}))
            # No profile exists yet on the backend for this patient (it was
            # created locally and hasn't been synced as a full profile) —
            # nothing to update. The full-profile sync path isn't wired yet;
            # the Flutter side currently only ever enqueues {patientId, name}.

        elif kind == "assessmentUpdate":
            payload = AssessmentUpdatePayload.model_validate(raw_payload)
            answers = payload.model_dump(by_alias=True, exclude={"patient_id", "step"})
            await self._assessments.save_intake_step(
                patient_id, payload.step or "unspecified", answers
            )

        elif kind == "baselineCaptured":
            payload = BaselineCapturedPayload.model_validate(raw_payload)
            await self._assessments.save_baseline(
                patient_id,
                {
                    "scores": payload.scores,
                    "capturedAt": payload.captured_at,
                    "sessionCount": payload.session_count,
                },
            )

        elif kind in ("reflection", "unknown"):
            ReflectionPayload.model_validate(raw_payload) if kind == "reflection" else None
            # Nothing structured to write — recording it in the ledger (done
            # by the caller after this returns) is the entire effect.

        else:
            raise ApiError("validation_error", f"Unknown sync operation kind '{kind}'.")
