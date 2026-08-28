from typing import Dict, List, Optional

from app.models.patient import Patient
from app.repositories.base import PatientRepository


class InMemoryPatientRepository(PatientRepository):
    def __init__(self) -> None:
        self._store: Dict[str, Patient] = {}

    async def get(self, patient_id: str) -> Optional[Patient]:
        return self._store.get(patient_id)

    async def list(self) -> List[Patient]:
        return list(self._store.values())

    async def create(self, patient: Patient) -> Patient:
        self._store[patient.id] = patient
        return patient

    async def update(self, patient: Patient) -> Patient:
        self._store[patient.id] = patient
        return patient
