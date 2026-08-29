from typing import Optional

from starlette.concurrency import run_in_threadpool

from app.core.firebase import get_firestore_client
from app.repositories.base import AssessmentRepository

_COLLECTION = "assessments"


class FirestoreAssessmentRepository(AssessmentRepository):
    """One document per patient: `intake` holds the questionnaire steps keyed
    by step name, `baseline` holds the frozen domain scores. Steps are merged
    rather than overwritten, so a resumed intake never loses earlier answers."""

    def __init__(self) -> None:
        self._db = get_firestore_client()

    def _doc(self, patient_id: str):
        return self._db.collection(_COLLECTION).document(patient_id)

    async def save_intake_step(self, patient_id: str, step: str, payload: dict) -> None:
        def _save() -> None:
            self._doc(patient_id).set({"intake": {step: payload}}, merge=True)

        await run_in_threadpool(_save)

    async def get_intake(self, patient_id: str) -> Optional[dict]:
        def _get() -> Optional[dict]:
            doc = self._doc(patient_id).get()
            return (doc.to_dict() or {}).get("intake") if doc.exists else None

        return await run_in_threadpool(_get)

    async def save_baseline(self, patient_id: str, baseline: dict) -> None:
        def _save() -> None:
            self._doc(patient_id).set({"baseline": baseline}, merge=True)

        await run_in_threadpool(_save)

    async def get_baseline(self, patient_id: str) -> Optional[dict]:
        def _get() -> Optional[dict]:
            doc = self._doc(patient_id).get()
            return (doc.to_dict() or {}).get("baseline") if doc.exists else None

        return await run_in_threadpool(_get)
