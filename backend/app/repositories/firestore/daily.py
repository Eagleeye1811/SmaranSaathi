from typing import List, Optional

from starlette.concurrency import run_in_threadpool

from app.core.firebase import get_firestore_client
from app.models.daily import JournalEntry, MoodLevel
from app.repositories.base import DailyRepository


class FirestoreDailyRepository(DailyRepository):
    def __init__(self) -> None:
        self._db = get_firestore_client()

    def _state_doc(self, patient_id: str):
        return self._db.collection("patients").document(patient_id).collection("daily").document("state")

    def _journal_collection(self, patient_id: str):
        return self._db.collection("patients").document(patient_id).collection("journal")

    async def get_mood(self, patient_id: str) -> Optional[MoodLevel]:
        def _get() -> Optional[MoodLevel]:
            doc = self._state_doc(patient_id).get()
            if not doc.exists:
                return None
            mood = doc.to_dict().get("mood")
            return MoodLevel(mood) if mood else None

        return await run_in_threadpool(_get)

    async def set_mood(self, patient_id: str, mood: MoodLevel) -> None:
        def _set() -> None:
            self._state_doc(patient_id).set({"mood": mood.value}, merge=True)

        await run_in_threadpool(_set)

    async def add_journal_entry(
        self, patient_id: str, entry: JournalEntry, entry_id: Optional[str] = None
    ) -> JournalEntry:
        def _add() -> JournalEntry:
            payload = entry.model_dump(mode="json", by_alias=True)
            if entry_id:
                self._journal_collection(patient_id).document(entry_id).set(payload)
            else:
                self._journal_collection(patient_id).add(payload)
            return entry

        return await run_in_threadpool(_add)

    async def list_journal(self, patient_id: str) -> List[JournalEntry]:
        def _list() -> List[JournalEntry]:
            return [JournalEntry.model_validate(d.to_dict()) for d in self._journal_collection(patient_id).stream()]

        return await run_in_threadpool(_list)
