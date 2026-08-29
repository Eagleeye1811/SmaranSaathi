from typing import List

from starlette.concurrency import run_in_threadpool

from app.core.firebase import get_firestore_client
from app.models.relationship import CaregiverPatientLink
from app.repositories.base import CaregiverLinkRepository

_COLLECTION = "caregiver_patient_links"


class FirestoreCaregiverLinkRepository(CaregiverLinkRepository):
    def __init__(self) -> None:
        self._db = get_firestore_client()

    async def create(self, link: CaregiverPatientLink) -> CaregiverPatientLink:
        def _create() -> CaregiverPatientLink:
            self._db.collection(_COLLECTION).document(link.id).set(link.model_dump(mode="json", by_alias=True))
            return link

        return await run_in_threadpool(_create)

    async def list_for_caregiver(self, caregiver_id: str) -> List[CaregiverPatientLink]:
        def _list() -> List[CaregiverPatientLink]:
            docs = self._db.collection(_COLLECTION).where("caregiverId", "==", caregiver_id).stream()
            return [CaregiverPatientLink.model_validate(d.to_dict()) for d in docs]

        return await run_in_threadpool(_list)
