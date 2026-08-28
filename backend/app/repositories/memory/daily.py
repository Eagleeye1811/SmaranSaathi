from collections import defaultdict
from typing import Dict, List, Optional

from app.models.daily import JournalEntry, MoodLevel
from app.repositories.base import DailyRepository


class InMemoryDailyRepository(DailyRepository):
    def __init__(self) -> None:
        self._mood: Dict[str, MoodLevel] = {}
        self._journal: Dict[str, List[JournalEntry]] = defaultdict(list)

    async def get_mood(self, patient_id: str) -> Optional[MoodLevel]:
        return self._mood.get(patient_id)

    async def set_mood(self, patient_id: str, mood: MoodLevel) -> None:
        self._mood[patient_id] = mood

    async def add_journal_entry(
        self, patient_id: str, entry: JournalEntry, entry_id: Optional[str] = None
    ) -> JournalEntry:
        self._journal[patient_id].append(entry)
        return entry

    async def list_journal(self, patient_id: str) -> List[JournalEntry]:
        return list(self._journal.get(patient_id, []))
