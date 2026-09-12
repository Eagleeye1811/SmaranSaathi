from fastapi import APIRouter, Depends, Query

from app.core.dependencies import (
    get_assessment_repository,
    get_daily_repository,
    get_game_session_repository,
    get_patient_repository,
    get_reminder_repository,
    get_sync_ledger_repository,
)
from app.core.device_auth import get_current_device
from app.repositories.base import (
    AssessmentRepository,
    DailyRepository,
    GameSessionRepository,
    PatientRepository,
    ReminderRepository,
    SyncLedgerRepository,
)
from app.schemas.sync import RestoreBundle, SyncOperationRequest, SyncOperationResult
from app.services.sync_service import SyncService

router = APIRouter(prefix="/sync", tags=["sync"], dependencies=[Depends(get_current_device)])


def get_service(
    ledger: SyncLedgerRepository = Depends(get_sync_ledger_repository),
    patients: PatientRepository = Depends(get_patient_repository),
    sessions: GameSessionRepository = Depends(get_game_session_repository),
    daily: DailyRepository = Depends(get_daily_repository),
    reminders: ReminderRepository = Depends(get_reminder_repository),
    assessments: AssessmentRepository = Depends(get_assessment_repository),
) -> SyncService:
    return SyncService(
        ledger=ledger,
        patients=patients,
        sessions=sessions,
        daily=daily,
        reminders=reminders,
        assessments=assessments,
    )


@router.post("/operations", response_model=SyncOperationResult)
async def sync_operation(
    data: SyncOperationRequest, service: SyncService = Depends(get_service)
) -> SyncOperationResult:
    return await service.apply(data)


@router.get("/restore", response_model=RestoreBundle)
async def restore(
    patientId: str = Query(...),
    patients: PatientRepository = Depends(get_patient_repository),
    sessions: GameSessionRepository = Depends(get_game_session_repository),
    daily: DailyRepository = Depends(get_daily_repository),
    reminders: ReminderRepository = Depends(get_reminder_repository),
    assessments: AssessmentRepository = Depends(get_assessment_repository),
) -> RestoreBundle:
    """Everything a second device needs to become this patient.

    The mirror image of `POST /operations`: that drains a device's outbox up
    here, this fills a fresh device's local store back down. A record the
    server has never seen returns an empty bundle rather than a 404 — a new
    profile that has not synced yet is an ordinary state, not an error.
    """
    patient = await patients.get(patientId)
    mood = await daily.get_mood(patientId)
    return RestoreBundle(
        patient_id=patientId,
        patient=patient.model_dump(by_alias=True) if patient is not None else None,
        intake=await assessments.get_intake(patientId),
        baseline=await assessments.get_baseline(patientId),
        sessions=[s.model_dump(by_alias=True) for s in await sessions.list_for_patient(patientId)],
        reminders=[r.model_dump(by_alias=True) for r in await reminders.list_for_patient(patientId)],
        journal=[j.model_dump(by_alias=True) for j in await daily.list_journal(patientId)],
        mood=mood.value if mood is not None else None,
    )
