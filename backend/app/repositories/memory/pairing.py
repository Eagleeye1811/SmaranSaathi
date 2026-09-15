from typing import Dict, List, Optional

from app.repositories.base import PairingClaimRepository
from app.schemas.pairing import ClaimUsernameResponse


class InMemoryPairingClaimRepository(PairingClaimRepository):
    def __init__(self) -> None:
        self._claims: Dict[str, ClaimUsernameResponse] = {}

    async def get(self, username: str) -> Optional[ClaimUsernameResponse]:
        return self._claims.get(username)

    async def save(self, claim: ClaimUsernameResponse) -> ClaimUsernameResponse:
        self._claims[claim.username] = claim
        return claim

    async def list_for_caregiver(self, caregiver_uid: str) -> List[ClaimUsernameResponse]:
        return [c for c in self._claims.values() if c.caregiver_uid == caregiver_uid]
