from collections import defaultdict
from typing import Dict, List, Optional

from app.models.daily import Reminder
from app.repositories.base import ReminderRepository


class InMemoryReminderRepository(ReminderRepository):
    def __init__(self) -> None:
        self._store: Dict[str, List[Reminder]] = defaultdict(list)
        self._sent_ids: set[str] = set()

    async def list_for_patient(self, patient_id: str) -> List[Reminder]:
        return sorted(self._store.get(patient_id, []), key=lambda r: r.minutes_from_midnight)

    async def create(self, patient_id: str, reminder: Reminder) -> Reminder:
        # If reminder already exists in patient store (upsert), replace it
        existing = self._store[patient_id]
        for idx, r in enumerate(existing):
            if r.id == reminder.id:
                existing[idx] = reminder
                return reminder
        existing.append(reminder)
        return reminder

    async def set_done(self, patient_id: str, reminder_id: str, done: bool) -> Optional[Reminder]:
        reminders = self._store.get(patient_id, [])
        for index, reminder in enumerate(reminders):
            if reminder.id == reminder_id:
                updated = reminder.model_copy(update={"done": done})
                reminders[index] = updated
                return updated
        return None

    async def list_all_due_now(
        self, hour: int, minute: int
    ) -> List[tuple[str, Optional[str], Reminder]]:
        current_minutes = hour * 60 + minute
        results = []

        from app.core.dependencies import get_patient_repository
        patient_repo = get_patient_repository()

        for patient_id, reminders in self._store.items():
            patient = await patient_repo.get(patient_id)
            phone = patient.phone_number if patient else None

            for r in reminders:
                if not r.done and r.sms_enabled and r.id not in self._sent_ids:
                    # Check if due now or due within the last 5 minutes (in case sync arrived slightly after 00s)
                    if r.minutes_from_midnight <= current_minutes and (current_minutes - r.minutes_from_midnight) <= 5:
                        self._sent_ids.add(r.id)
                        results.append((patient_id, phone, r))
        return results

