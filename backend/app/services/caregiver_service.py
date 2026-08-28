import uuid
from typing import List

from app.models.relationship import CaregiverPatientLink
from app.repositories.base import CaregiverLinkRepository
from app.schemas.caregiver import CaregiverLinkCreate


class CaregiverService:
    def __init__(self, repository: CaregiverLinkRepository) -> None:
        self._repository = repository

    async def create_link(self, data: CaregiverLinkCreate) -> CaregiverPatientLink:
        link = CaregiverPatientLink(
            id=str(uuid.uuid4()),
            caregiver_id=data.caregiver_id,
            patient_id=data.patient_id,
            relation=data.relation,
        )
        return await self._repository.create(link)

    async def list_patients(self, caregiver_id: str) -> List[CaregiverPatientLink]:
        return await self._repository.list_for_caregiver(caregiver_id)
