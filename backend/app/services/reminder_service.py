import uuid
from typing import List

from app.core.errors import ApiError
from app.models.daily import Reminder
from app.repositories.base import ReminderRepository
from app.schemas.reminder import ReminderCreate


class ReminderService:
    def __init__(self, repository: ReminderRepository) -> None:
        self._repository = repository

    async def list_for_patient(self, patient_id: str) -> List[Reminder]:
        return await self._repository.list_for_patient(patient_id)

    async def create(self, data: ReminderCreate) -> Reminder:
        reminder = Reminder(
            id=str(uuid.uuid4()),
            time=data.time,
            minutes_from_midnight=data.minutes_from_midnight,
            title=data.title,
            kind=data.kind,
            detail=data.detail,
            sms_enabled=data.sms_enabled,
        )
        return await self._repository.create(data.patient_id, reminder)

    async def set_done(self, patient_id: str, reminder_id: str, done: bool) -> Reminder:
        updated = await self._repository.set_done(patient_id, reminder_id, done)
        if updated is None:
            raise ApiError("not_found", f"No reminder '{reminder_id}' for patient '{patient_id}'.")
        return updated
