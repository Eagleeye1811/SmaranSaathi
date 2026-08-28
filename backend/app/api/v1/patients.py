from typing import List

from fastapi import APIRouter, Depends

from app.core.dependencies import get_patient_repository
from app.core.security import get_current_user
from app.repositories.base import PatientRepository
from app.schemas.patient import PatientCreate, PatientResponse, PatientUpdate
from app.services.patient_service import PatientService

router = APIRouter(prefix="/patients", tags=["patients"], dependencies=[Depends(get_current_user)])


def get_service(repository: PatientRepository = Depends(get_patient_repository)) -> PatientService:
    return PatientService(repository)


@router.get("", response_model=List[PatientResponse])
async def list_patients(service: PatientService = Depends(get_service)) -> List[PatientResponse]:
    patients = await service.list()
    return [PatientResponse.model_validate(p) for p in patients]


@router.get("/{patient_id}", response_model=PatientResponse)
async def get_patient(patient_id: str, service: PatientService = Depends(get_service)) -> PatientResponse:
    patient = await service.get(patient_id)
    return PatientResponse.model_validate(patient)


@router.post("", response_model=PatientResponse, status_code=201)
async def create_patient(data: PatientCreate, service: PatientService = Depends(get_service)) -> PatientResponse:
    patient = await service.create(data)
    return PatientResponse.model_validate(patient)


@router.put("/{patient_id}", response_model=PatientResponse)
async def update_patient(
    patient_id: str, data: PatientUpdate, service: PatientService = Depends(get_service)
) -> PatientResponse:
    patient = await service.update(patient_id, data)
    return PatientResponse.model_validate(patient)
