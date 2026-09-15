from typing import Dict, List, Optional

from app.models.doctor import DoctorPatientLink, DoctorProfile
from app.repositories.base import DoctorPatientLinkRepository, DoctorProfileRepository


class InMemoryDoctorProfileRepository(DoctorProfileRepository):
    def __init__(self) -> None:
        self._store: Dict[str, DoctorProfile] = {}

    async def get(self, uid: str) -> Optional[DoctorProfile]:
        return self._store.get(uid)

    async def upsert(self, profile: DoctorProfile) -> DoctorProfile:
        self._store[profile.id] = profile
        return profile

    async def list_all(self) -> List[DoctorProfile]:
        return list(self._store.values())


class InMemoryDoctorPatientLinkRepository(DoctorPatientLinkRepository):
    def __init__(self) -> None:
        self._links: Dict[str, DoctorPatientLink] = {}

    async def create(self, link: DoctorPatientLink) -> DoctorPatientLink:
        self._links[link.id] = link
        return link

    async def list_for_doctor(self, doctor_uid: str) -> List[DoctorPatientLink]:
        return [l for l in self._links.values() if l.doctor_uid == doctor_uid]

    async def get_for_patient(self, patient_id: str) -> Optional[DoctorPatientLink]:
        for link in self._links.values():
            if link.patient_id == patient_id:
                return link
        return None

    async def delete(self, patient_id: str, doctor_uid: str) -> None:
        for link_id, link in list(self._links.items()):
            if link.patient_id == patient_id and link.doctor_uid == doctor_uid:
                del self._links[link_id]
