from typing import List

from app.core.errors import ApiError
from app.models.clinical import ClinicPatient, CognitiveProfile, DoctorAlert, SeriesPoint
from app.repositories.base import AnalyticsRepository


class AnalyticsService:
    def __init__(self, repository: AnalyticsRepository) -> None:
        self._repository = repository

    async def get_profile(self, patient_id: str) -> CognitiveProfile:
        profile = await self._repository.get_profile(patient_id)
        if profile is None:
            raise ApiError("not_found", f"No cognitive profile yet for patient '{patient_id}'.")
        return profile

    async def save_profile(self, patient_id: str, profile: CognitiveProfile) -> CognitiveProfile:
        return await self._repository.save_profile(patient_id, profile)

    async def weekly_series(self, patient_id: str, series: str) -> List[SeriesPoint]:
        return await self._repository.weekly_series(patient_id, series)

    async def caseload(self) -> List[ClinicPatient]:
        return await self._repository.caseload()

    async def alerts(self) -> List[DoctorAlert]:
        return await self._repository.alerts()
