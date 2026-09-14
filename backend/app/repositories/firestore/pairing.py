from typing import List, Optional

from starlette.concurrency import run_in_threadpool

from app.core.firebase import get_firestore_client
from app.repositories.base import PairingClaimRepository
from app.schemas.pairing import ClaimUsernameResponse

_COLLECTION = "pairing_claims"


class FirestorePairingClaimRepository(PairingClaimRepository):
    def __init__(self) -> None:
        self._db = get_firestore_client()

    async def get(self, username: str) -> Optional[ClaimUsernameResponse]:
        def _get() -> Optional[ClaimUsernameResponse]:
            doc = self._db.collection(_COLLECTION).document(username).get()
            if not doc.exists:
                return None
            return ClaimUsernameResponse.model_validate(doc.to_dict())

        return await run_in_threadpool(_get)

    async def save(self, claim: ClaimUsernameResponse) -> ClaimUsernameResponse:
        def _save() -> ClaimUsernameResponse:
            self._db.collection(_COLLECTION).document(claim.username).set(
                claim.model_dump(mode="json", by_alias=True)
            )
            return claim

        return await run_in_threadpool(_save)

    async def list_for_caregiver(self, caregiver_uid: str) -> List[ClaimUsernameResponse]:
        def _list() -> List[ClaimUsernameResponse]:
            docs = self._db.collection(_COLLECTION).where("caregiverUid", "==", caregiver_uid).stream()
            return [ClaimUsernameResponse.model_validate(d.to_dict()) for d in docs]

        return await run_in_threadpool(_list)
