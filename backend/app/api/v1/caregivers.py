from typing import List

from fastapi import APIRouter, Depends

from app.core.dependencies import get_caregiver_link_repository
from app.core.security import get_current_user
from app.models.relationship import CaregiverPatientLink
from app.repositories.base import CaregiverLinkRepository
from app.schemas.caregiver import CaregiverLinkCreate
from app.services.caregiver_service import CaregiverService

router = APIRouter(prefix="/caregivers", tags=["caregivers"], dependencies=[Depends(get_current_user)])


def get_service(repository: CaregiverLinkRepository = Depends(get_caregiver_link_repository)) -> CaregiverService:
    return CaregiverService(repository)


@router.post("/links", response_model=CaregiverPatientLink, status_code=201)
async def create_link(
    data: CaregiverLinkCreate, service: CaregiverService = Depends(get_service)
) -> CaregiverPatientLink:
    return await service.create_link(data)


@router.get("/{caregiver_id}/patients", response_model=List[CaregiverPatientLink])
async def list_patients(
    caregiver_id: str, service: CaregiverService = Depends(get_service)
) -> List[CaregiverPatientLink]:
    return await service.list_patients(caregiver_id)
