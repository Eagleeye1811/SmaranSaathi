import uuid
from typing import List

from app.core.errors import ApiError
from app.models.patient import Patient
from app.repositories.base import PatientRepository
from app.schemas.patient import PatientCreate, PatientUpdate


class PatientService:
    def __init__(self, repository: PatientRepository) -> None:
        self._repository = repository

    async def get(self, patient_id: str) -> Patient:
        patient = await self._repository.get(patient_id)
        if patient is None:
            raise ApiError("not_found", f"No patient with id '{patient_id}'.")
        return patient

    async def list(self) -> List[Patient]:
        return await self._repository.list()

    async def create(self, data: PatientCreate) -> Patient:
        patient = Patient(id=str(uuid.uuid4()), **data.model_dump(by_alias=False))
        return await self._repository.create(patient)

    async def update(self, patient_id: str, data: PatientUpdate) -> Patient:
        existing = await self.get(patient_id)
        changes = data.model_dump(by_alias=False, exclude_unset=True, exclude_none=True)
        updated = existing.model_copy(update=changes)
        return await self._repository.update(updated)
