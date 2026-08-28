from collections import defaultdict
from typing import Dict, List, Optional

from app.models.daily import Reminder
from app.repositories.base import ReminderRepository


class InMemoryReminderRepository(ReminderRepository):
    def __init__(self) -> None:
        self._store: Dict[str, List[Reminder]] = defaultdict(list)

    async def list_for_patient(self, patient_id: str) -> List[Reminder]:
        return sorted(self._store.get(patient_id, []), key=lambda r: r.minutes_from_midnight)

    async def create(self, patient_id: str, reminder: Reminder) -> Reminder:
        self._store[patient_id].append(reminder)
        return reminder

    async def set_done(self, patient_id: str, reminder_id: str, done: bool) -> Optional[Reminder]:
        reminders = self._store.get(patient_id, [])
        for index, reminder in enumerate(reminders):
            if reminder.id == reminder_id:
                updated = reminder.model_copy(update={"done": done})
                reminders[index] = updated
                return updated
        return None
