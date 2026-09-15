from typing import List, Optional

from starlette.concurrency import run_in_threadpool

from app.core.firebase import get_firestore_client
from app.models.doctor import DoctorPatientLink, DoctorProfile
from app.repositories.base import DoctorPatientLinkRepository, DoctorProfileRepository

_PROFILES_COLLECTION = "doctor_profiles"
_LINKS_COLLECTION = "doctor_patient_links"


class FirestoreDoctorProfileRepository(DoctorProfileRepository):
    def __init__(self) -> None:
        self._db = get_firestore_client()

    async def get(self, uid: str) -> Optional[DoctorProfile]:
        def _get() -> Optional[DoctorProfile]:
            doc = self._db.collection(_PROFILES_COLLECTION).document(uid).get()
            if not doc.exists:
                return None
            return DoctorProfile.model_validate(doc.to_dict())

        return await run_in_threadpool(_get)

    async def upsert(self, profile: DoctorProfile) -> DoctorProfile:
        def _upsert() -> DoctorProfile:
            self._db.collection(_PROFILES_COLLECTION).document(profile.id).set(
                profile.model_dump(mode="json", by_alias=True)
            )
            return profile

        return await run_in_threadpool(_upsert)

    async def list_all(self) -> List[DoctorProfile]:
        def _list() -> List[DoctorProfile]:
            docs = self._db.collection(_PROFILES_COLLECTION).stream()
            return [DoctorProfile.model_validate(d.to_dict()) for d in docs]

        return await run_in_threadpool(_list)


class FirestoreDoctorPatientLinkRepository(DoctorPatientLinkRepository):
    def __init__(self) -> None:
        self._db = get_firestore_client()

    async def create(self, link: DoctorPatientLink) -> DoctorPatientLink:
        def _create() -> DoctorPatientLink:
            self._db.collection(_LINKS_COLLECTION).document(link.id).set(
                link.model_dump(mode="json", by_alias=True)
            )
            return link

        return await run_in_threadpool(_create)

    async def list_for_doctor(self, doctor_uid: str) -> List[DoctorPatientLink]:
        def _list() -> List[DoctorPatientLink]:
            docs = self._db.collection(_LINKS_COLLECTION).where("doctorUid", "==", doctor_uid).stream()
            return [DoctorPatientLink.model_validate(d.to_dict()) for d in docs]

        return await run_in_threadpool(_list)

    async def get_for_patient(self, patient_id: str) -> Optional[DoctorPatientLink]:
        def _get() -> Optional[DoctorPatientLink]:
            docs = (
                self._db.collection(_LINKS_COLLECTION)
                .where("patientId", "==", patient_id)
                .limit(1)
                .stream()
            )
            for d in docs:
                return DoctorPatientLink.model_validate(d.to_dict())
            return None

        return await run_in_threadpool(_get)

    async def delete(self, patient_id: str, doctor_uid: str) -> None:
        def _delete() -> None:
            docs = (
                self._db.collection(_LINKS_COLLECTION)
                .where("patientId", "==", patient_id)
                .where("doctorUid", "==", doctor_uid)
                .stream()
            )
            for d in docs:
                d.reference.delete()

        await run_in_threadpool(_delete)
