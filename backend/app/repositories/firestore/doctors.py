from typing import List, Optional

from starlette.concurrency import run_in_threadpool

from app.core.firebase import get_firestore_client
from app.models.doctor import DoctorPatientLink, DoctorProfile
from app.repositories.base import (
    DoctorConnectionRequestRepository,
    DoctorPatientLinkRepository,
    DoctorProfileRepository,
)
from app.schemas.doctor import DoctorConnectionRequest

_PROFILES_COLLECTION = "doctor_profiles"
_LINKS_COLLECTION = "doctor_patient_links"
_REQUESTS_COLLECTION = "doctor_connection_requests"


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


class FirestoreDoctorConnectionRequestRepository(DoctorConnectionRequestRepository):
    """One document per invite, keyed by request id.

    This is what lets a caregiver invite a doctor in the morning and the
    doctor accept that evening: the queue no longer lives in the web
    process's memory, so neither a deploy nor Render's free-tier spin-down
    takes the request with it.
    """

    def __init__(self) -> None:
        self._db = get_firestore_client()

    async def get(self, request_id: str) -> Optional[DoctorConnectionRequest]:
        def _get() -> Optional[DoctorConnectionRequest]:
            doc = self._db.collection(_REQUESTS_COLLECTION).document(request_id).get()
            if not doc.exists:
                return None
            return DoctorConnectionRequest.model_validate(doc.to_dict())

        return await run_in_threadpool(_get)

    async def save(self, request: DoctorConnectionRequest) -> DoctorConnectionRequest:
        def _save() -> DoctorConnectionRequest:
            self._db.collection(_REQUESTS_COLLECTION).document(request.request_id).set(
                request.model_dump(mode="json", by_alias=True)
            )
            return request

        return await run_in_threadpool(_save)

    async def list_pending_for_doctor(self, doctor_uid: str) -> List[DoctorConnectionRequest]:
        def _list() -> List[DoctorConnectionRequest]:
            docs = (
                self._db.collection(_REQUESTS_COLLECTION)
                .where("doctorUid", "==", doctor_uid)
                .where("status", "==", "pending")
                .stream()
            )
            return [DoctorConnectionRequest.model_validate(d.to_dict()) for d in docs]

        return await run_in_threadpool(_list)

    async def list_for_patient(self, patient_id: str) -> List[DoctorConnectionRequest]:
        def _list() -> List[DoctorConnectionRequest]:
            docs = (
                self._db.collection(_REQUESTS_COLLECTION)
                .where("patientId", "==", patient_id)
                .stream()
            )
            return [DoctorConnectionRequest.model_validate(d.to_dict()) for d in docs]

        return await run_in_threadpool(_list)
