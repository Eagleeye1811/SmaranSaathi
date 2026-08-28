from typing import List, Optional

from app.models.daily import JournalEntry, MoodLevel
from app.repositories.base import DailyRepository
from app.schemas.daily import JournalEntryCreate, MoodCheckInCreate


class DailyService:
    def __init__(self, repository: DailyRepository) -> None:
        self._repository = repository

    async def check_in_mood(self, data: MoodCheckInCreate) -> None:
        await self._repository.set_mood(data.patient_id, data.mood)

    async def get_mood(self, patient_id: str) -> Optional[MoodLevel]:
        return await self._repository.get_mood(patient_id)

    async def add_journal_entry(self, data: JournalEntryCreate) -> JournalEntry:
        entry = JournalEntry(
            question_id=data.question_id,
            label=data.label,
            answer=data.answer,
            positive=data.positive,
            time="",
        )
        return await self._repository.add_journal_entry(data.patient_id, entry)

    async def list_journal(self, patient_id: str) -> List[JournalEntry]:
        return await self._repository.list_journal(patient_id)
