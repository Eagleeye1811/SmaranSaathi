from typing import List, Optional

from starlette.concurrency import run_in_threadpool

from app.core.firebase import get_firestore_client
from app.models.clinical import ClinicPatient, CognitiveProfile, DoctorAlert, SeriesPoint
from app.repositories.base import AnalyticsRepository


class FirestoreAnalyticsRepository(AnalyticsRepository):
    def __init__(self) -> None:
        self._db = get_firestore_client()

    def _profile_doc(self, patient_id: str):
        return self._db.collection("patients").document(patient_id).collection("analytics").document("profile")

    async def get_profile(self, patient_id: str) -> Optional[CognitiveProfile]:
        def _get() -> Optional[CognitiveProfile]:
            doc = self._profile_doc(patient_id).get()
            return CognitiveProfile.model_validate(doc.to_dict()) if doc.exists else None

        return await run_in_threadpool(_get)

    async def save_profile(self, patient_id: str, profile: CognitiveProfile) -> CognitiveProfile:
        def _save() -> CognitiveProfile:
            self._profile_doc(patient_id).set(profile.model_dump(mode="json", by_alias=True))
            return profile

        return await run_in_threadpool(_save)

    async def weekly_series(self, patient_id: str, series: str) -> List[SeriesPoint]:
        def _list() -> List[SeriesPoint]:
            docs = (
                self._db.collection("patients")
                .document(patient_id)
                .collection("weekly_series")
                .document(series)
                .collection("points")
                .stream()
            )
            return [SeriesPoint.model_validate(d.to_dict()) for d in docs]

        return await run_in_threadpool(_list)

    async def caseload(self) -> List[ClinicPatient]:
        def _list() -> List[ClinicPatient]:
            return [ClinicPatient.model_validate(d.to_dict()) for d in self._db.collection("caseload").stream()]

        return await run_in_threadpool(_list)

    async def alerts(self) -> List[DoctorAlert]:
        def _list() -> List[DoctorAlert]:
            return [DoctorAlert.model_validate(d.to_dict()) for d in self._db.collection("alerts").stream()]

        return await run_in_threadpool(_list)
