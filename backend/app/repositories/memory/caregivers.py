from collections import defaultdict
from typing import Dict, List

from app.models.relationship import CaregiverPatientLink
from app.repositories.base import CaregiverLinkRepository


class InMemoryCaregiverLinkRepository(CaregiverLinkRepository):
    def __init__(self) -> None:
        self._store: Dict[str, List[CaregiverPatientLink]] = defaultdict(list)

    async def create(self, link: CaregiverPatientLink) -> CaregiverPatientLink:
        self._store[link.caregiver_id].append(link)
        return link

    async def list_for_caregiver(self, caregiver_id: str) -> List[CaregiverPatientLink]:
        return list(self._store.get(caregiver_id, []))
