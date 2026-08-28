from typing import List

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_reminder_repository
from app.core.security import get_current_user
from app.models.daily import Reminder
from app.repositories.base import ReminderRepository
from app.schemas.reminder import ReminderCreate, ReminderSetDone
from app.services.reminder_service import ReminderService

router = APIRouter(prefix="/reminders", tags=["reminders"], dependencies=[Depends(get_current_user)])


def get_service(repository: ReminderRepository = Depends(get_reminder_repository)) -> ReminderService:
    return ReminderService(repository)


@router.get("", response_model=List[Reminder])
async def list_reminders(
    patient_id: str = Query(..., alias="patientId"), service: ReminderService = Depends(get_service)
) -> List[Reminder]:
    return await service.list_for_patient(patient_id)


@router.post("", response_model=Reminder, status_code=201)
async def create_reminder(data: ReminderCreate, service: ReminderService = Depends(get_service)) -> Reminder:
    return await service.create(data)


@router.patch("/{reminder_id}", response_model=Reminder)
async def set_reminder_done(
    reminder_id: str,
    data: ReminderSetDone,
    patient_id: str = Query(..., alias="patientId"),
    service: ReminderService = Depends(get_service),
) -> Reminder:
    return await service.set_done(patient_id, reminder_id, data.done)
