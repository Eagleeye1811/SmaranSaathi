import uuid
from typing import List

from app.models.game import GameSession
from app.repositories.base import GameSessionRepository
from app.schemas.session import GameSessionCreate


class SessionService:
    def __init__(self, repository: GameSessionRepository) -> None:
        self._repository = repository

    async def record(self, data: GameSessionCreate) -> tuple[str, GameSession]:
        session_id = str(uuid.uuid4())
        session = GameSession(
            game_id=data.game_id,
            level=data.level,
            performance=data.performance,
            time_label=data.time_label,
        )
        await self._repository.add(session_id, data.patient_id, session)
        return session_id, session

    async def history(self, patient_id: str) -> List[GameSession]:
        return await self._repository.list_for_patient(patient_id)
