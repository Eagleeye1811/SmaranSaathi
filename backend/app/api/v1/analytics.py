from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_analytics_repository
from app.core.security import get_current_user
from app.repositories.base import AnalyticsRepository
from app.schemas.analytics import CognitiveProfileResponse, WeeklySeriesResponse
from app.services.analytics_service import AnalyticsService

router = APIRouter(prefix="/analytics", tags=["cognitive analytics"], dependencies=[Depends(get_current_user)])


def get_service(repository: AnalyticsRepository = Depends(get_analytics_repository)) -> AnalyticsService:
    return AnalyticsService(repository)


@router.get("/{patient_id}/cognitive-profile", response_model=CognitiveProfileResponse)
async def cognitive_profile(
    patient_id: str, service: AnalyticsService = Depends(get_service)
) -> CognitiveProfileResponse:
    profile = await service.get_profile(patient_id)
    return CognitiveProfileResponse(patient_id=patient_id, **profile.model_dump(by_alias=False))


@router.get("/{patient_id}/weekly", response_model=WeeklySeriesResponse)
async def weekly_series(
    patient_id: str,
    series: str = Query(..., description="engagement | games | adherence"),
    service: AnalyticsService = Depends(get_service),
) -> WeeklySeriesResponse:
    points = await service.weekly_series(patient_id, series)
    return WeeklySeriesResponse(series=series, points=points)
