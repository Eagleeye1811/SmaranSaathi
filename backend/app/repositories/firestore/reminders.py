from typing import List, Optional

from starlette.concurrency import run_in_threadpool

from app.core.firebase import get_firestore_client
from app.models.daily import Reminder
from app.repositories.base import ReminderRepository


class FirestoreReminderRepository(ReminderRepository):
    def __init__(self) -> None:
        self._db = get_firestore_client()

    def _collection(self, patient_id: str):
        return self._db.collection("patients").document(patient_id).collection("reminders")

    async def list_for_patient(self, patient_id: str) -> List[Reminder]:
        def _list() -> List[Reminder]:
            reminders = [Reminder.model_validate(d.to_dict()) for d in self._collection(patient_id).stream()]
            return sorted(reminders, key=lambda r: r.minutes_from_midnight)

        return await run_in_threadpool(_list)

    async def create(self, patient_id: str, reminder: Reminder) -> Reminder:
        def _create() -> Reminder:
            self._collection(patient_id).document(reminder.id).set(
                reminder.model_dump(mode="json", by_alias=True)
            )
            return reminder

        return await run_in_threadpool(_create)

    async def set_done(self, patient_id: str, reminder_id: str, done: bool) -> Optional[Reminder]:
        def _set() -> Optional[Reminder]:
            doc_ref = self._collection(patient_id).document(reminder_id)
            doc = doc_ref.get()
            if not doc.exists:
                return None
            doc_ref.update({"done": done})
            data = doc.to_dict()
            data["done"] = done
            return Reminder.model_validate(data)

        return await run_in_threadpool(_set)
