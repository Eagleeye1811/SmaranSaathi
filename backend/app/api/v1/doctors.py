from typing import List

from fastapi import APIRouter, Depends

from app.core.dependencies import get_analytics_repository
from app.core.security import get_current_user
from app.models.clinical import ClinicPatient
from app.repositories.base import AnalyticsRepository
from app.services.analytics_service import AnalyticsService

router = APIRouter(prefix="/doctors", tags=["doctors"], dependencies=[Depends(get_current_user)])


def get_service(repository: AnalyticsRepository = Depends(get_analytics_repository)) -> AnalyticsService:
    return AnalyticsService(repository)


@router.get("/caseload", response_model=List[ClinicPatient])
async def caseload(service: AnalyticsService = Depends(get_service)) -> List[ClinicPatient]:
    return await service.caseload()
