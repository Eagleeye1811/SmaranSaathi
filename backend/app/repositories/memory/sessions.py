from collections import defaultdict
from typing import Dict, List

from app.models.game import GameSession
from app.repositories.base import GameSessionRepository


class InMemoryGameSessionRepository(GameSessionRepository):
    def __init__(self) -> None:
        self._store: Dict[str, List[GameSession]] = defaultdict(list)

    async def add(self, session_id: str, patient_id: str, session: GameSession) -> GameSession:
        self._store[patient_id].insert(0, session)
        return session

    async def list_for_patient(self, patient_id: str) -> List[GameSession]:
        return list(self._store.get(patient_id, []))
