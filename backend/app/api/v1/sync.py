from fastapi import APIRouter, Depends

from app.core.dependencies import (
    get_daily_repository,
    get_game_session_repository,
    get_patient_repository,
    get_reminder_repository,
    get_sync_ledger_repository,
)
from app.core.device_auth import get_current_device
from app.repositories.base import (
    DailyRepository,
    GameSessionRepository,
    PatientRepository,
    ReminderRepository,
    SyncLedgerRepository,
)
from app.schemas.sync import SyncOperationRequest, SyncOperationResult
from app.services.sync_service import SyncService

router = APIRouter(prefix="/sync", tags=["sync"], dependencies=[Depends(get_current_device)])


def get_service(
    ledger: SyncLedgerRepository = Depends(get_sync_ledger_repository),
    patients: PatientRepository = Depends(get_patient_repository),
    sessions: GameSessionRepository = Depends(get_game_session_repository),
    daily: DailyRepository = Depends(get_daily_repository),
    reminders: ReminderRepository = Depends(get_reminder_repository),
) -> SyncService:
    return SyncService(ledger=ledger, patients=patients, sessions=sessions, daily=daily, reminders=reminders)


@router.post("/operations", response_model=SyncOperationResult)
async def sync_operation(
    data: SyncOperationRequest, service: SyncService = Depends(get_service)
) -> SyncOperationResult:
    return await service.apply(data)
