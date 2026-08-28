from typing import Dict, List, Optional

from app.models.clinical import ClinicPatient, CognitiveProfile, DoctorAlert, SeriesPoint
from app.repositories.base import AnalyticsRepository


class InMemoryAnalyticsRepository(AnalyticsRepository):
    def __init__(self) -> None:
        self._profiles: Dict[str, CognitiveProfile] = {}
        self._series: Dict[str, Dict[str, List[SeriesPoint]]] = {}
        self._caseload: List[ClinicPatient] = []
        self._alerts: List[DoctorAlert] = []

    async def get_profile(self, patient_id: str) -> Optional[CognitiveProfile]:
        return self._profiles.get(patient_id)

    async def save_profile(self, patient_id: str, profile: CognitiveProfile) -> CognitiveProfile:
        self._profiles[patient_id] = profile
        return profile

    async def weekly_series(self, patient_id: str, series: str) -> List[SeriesPoint]:
        return self._series.get(patient_id, {}).get(series, [])

    async def caseload(self) -> List[ClinicPatient]:
        return list(self._caseload)

    async def alerts(self) -> List[DoctorAlert]:
        return list(self._alerts)
