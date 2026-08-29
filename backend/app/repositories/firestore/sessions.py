from typing import List

from firebase_admin import firestore
from starlette.concurrency import run_in_threadpool

from app.core.firebase import get_firestore_client
from app.models.game import GameSession
from app.repositories.base import GameSessionRepository


class FirestoreGameSessionRepository(GameSessionRepository):
    def __init__(self) -> None:
        self._db = get_firestore_client()

    def _collection(self, patient_id: str):
        return self._db.collection("patients").document(patient_id).collection("sessions")

    async def add(self, session_id: str, patient_id: str, session: GameSession) -> GameSession:
        def _add() -> GameSession:
            payload = session.model_dump(mode="json", by_alias=True)
            payload["recordedAt"] = firestore.SERVER_TIMESTAMP
            self._collection(patient_id).document(session_id).set(payload)
            return session

        return await run_in_threadpool(_add)

    async def list_for_patient(self, patient_id: str) -> List[GameSession]:
        def _list() -> List[GameSession]:
            docs = self._collection(patient_id).order_by(
                "recordedAt", direction=firestore.Query.DESCENDING
            ).stream()
            return [GameSession.model_validate(d.to_dict()) for d in docs]

        return await run_in_threadpool(_list)
