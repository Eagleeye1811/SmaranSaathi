from typing import List, Optional

from starlette.concurrency import run_in_threadpool

from app.core.firebase import get_firestore_client
from app.models.patient import Patient
from app.repositories.base import PatientRepository

_COLLECTION = "patients"


class FirestorePatientRepository(PatientRepository):
    def __init__(self) -> None:
        self._db = get_firestore_client()

    async def get(self, patient_id: str) -> Optional[Patient]:
        def _get() -> Optional[Patient]:
            doc = self._db.collection(_COLLECTION).document(patient_id).get()
            return Patient.model_validate(doc.to_dict()) if doc.exists else None

        return await run_in_threadpool(_get)

    async def list(self) -> List[Patient]:
        def _list() -> List[Patient]:
            return [Patient.model_validate(d.to_dict()) for d in self._db.collection(_COLLECTION).stream()]

        return await run_in_threadpool(_list)

    async def create(self, patient: Patient) -> Patient:
        def _create() -> Patient:
            self._db.collection(_COLLECTION).document(patient.id).set(
                patient.model_dump(mode="json", by_alias=True)
            )
            return patient

        return await run_in_threadpool(_create)

    async def update(self, patient: Patient) -> Patient:
        def _update() -> Patient:
            self._db.collection(_COLLECTION).document(patient.id).set(
                patient.model_dump(mode="json", by_alias=True)
            )
            return patient

        return await run_in_threadpool(_update)
