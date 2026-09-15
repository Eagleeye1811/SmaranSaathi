"""Doctor connections: a durable profile directory, durable doctor↔patient
links, and a durable pending-request queue in between.

The queue used to be a process-local dict, structured after
`pairing_service.py` on the reasoning that a pending *request* is a
short-lived handshake a restart may safely lose. That holds for pairing,
where caregiver and patient are in the same room seconds apart. It does not
hold here: the caregiver sends the invite and the doctor sees it whenever
their next clinic session happens to be. In production the queue lived in a
Render free-tier web process that spins down after ~15 minutes idle, and a
15-minute TTL expired anything that survived that — so an invite was
essentially never there when the doctor finally looked. All three stores are
now repositories (Firestore in production).

One real difference from pairing: both sides here are actual Firebase
accounts. Pairing has to trust a `caregiver_uid` field in the request body
because a patient device has no account to authenticate with — that field
is deliberately absent here. `decide()`'s `doctor_uid` must always come from
the caller's own verified identity (see `api/v1/doctor_connections.py`),
never from anything the client supplies.
"""
from __future__ import annotations

import time
import uuid
from typing import List, Optional

from app.models.doctor import DoctorPatientLink, DoctorProfile
from app.repositories.base import (
    DoctorConnectionRequestRepository,
    DoctorPatientLinkRepository,
    DoctorProfileRepository,
)
from app.schemas.doctor import DoctorConnectionInvite, DoctorConnectionRequest, DoctorProfileUpsert

# An invite is answered on the doctor's schedule, not the caregiver's, so this
# is measured in days rather than pairing's minutes. It exists only so a
# forgotten invite eventually stops cluttering an inbox.
_REQUEST_TTL_MILLIS = 14 * 24 * 60 * 60 * 1000


def _now() -> int:
    return int(time.time() * 1000)


class DoctorConnectionService:
    def __init__(
        self,
        profiles: DoctorProfileRepository,
        links: DoctorPatientLinkRepository,
        requests: DoctorConnectionRequestRepository,
    ) -> None:
        self._profiles = profiles
        self._links = links
        self._requests = requests

    # ── profile / directory ────────────────────────────────────────────
    async def upsert_profile(
        self, uid: str, email: Optional[str], data: DoctorProfileUpsert
    ) -> DoctorProfile:
        profile = DoctorProfile(
            id=uid,
            name=data.name,
            specialization=data.specialization,
            hospital=data.hospital,
            email=email or "",
            phone=data.phone,
            registration_number=data.registration_number,
            avatar_initials=data.avatar_initials or (data.name[:1].upper() if data.name else ""),
        )
        return await self._profiles.upsert(profile)

    async def directory(self) -> List[DoctorProfile]:
        return await self._profiles.list_all()

    # ── inviting ────────────────────────────────────────────────────────
    async def invite(self, caregiver_uid: str, data: DoctorConnectionInvite) -> DoctorConnectionRequest:
        existing_link = await self._links.get_for_patient(data.patient_id)
        if existing_link is not None and existing_link.doctor_uid == data.doctor_uid:
            raise ValueError("already_connected")

        # One live invite per doctor+patient pair — asking twice must not
        # fill the doctor's inbox with duplicates of the same request.
        for req in await self._requests.list_for_patient(data.patient_id):
            if self._is_live(req) and req.doctor_uid == data.doctor_uid:
                return req

        request = DoctorConnectionRequest(
            request_id=uuid.uuid4().hex,
            doctor_uid=data.doctor_uid,
            caregiver_uid=caregiver_uid,
            patient_id=data.patient_id,
            patient_name=data.patient_name,
            patient_age=data.patient_age,
            district=data.district,
            status="pending",
            requested_at_millis=_now(),
        )
        return await self._requests.save(request)

    async def pending_for(self, doctor_uid: str) -> List[DoctorConnectionRequest]:
        """Newest first, so the doctor's inbox reads the way an inbox should."""
        live = [r for r in await self._requests.list_pending_for_doctor(doctor_uid) if self._is_live(r)]
        live.sort(key=lambda r: r.requested_at_millis, reverse=True)
        return live

    # ── deciding ────────────────────────────────────────────────────────
    async def decide(self, request_id: str, doctor_uid: str, approve: bool) -> DoctorConnectionRequest:
        request = await self._requests.get(request_id)
        if request is None:
            raise LookupError("unknown_request")

        # Only the invited doctor's own authenticated identity may decide —
        # `doctor_uid` here always comes from the verified token, never a
        # client-supplied field, so this check cannot be spoofed the way a
        # trusted body field could be.
        if request.doctor_uid != doctor_uid:
            raise PermissionError("not_your_invite")
        if request.status != "pending":
            return request

        decided = request.model_copy(
            update={"status": "approved" if approve else "declined", "decided_at_millis": _now()}
        )
        await self._requests.save(decided)

        if approve:
            await self._links.create(
                DoctorPatientLink(
                    id=uuid.uuid4().hex,
                    doctor_uid=doctor_uid,
                    patient_id=request.patient_id,
                    caregiver_uid=request.caregiver_uid,
                    connected_at_millis=_now(),
                )
            )
        return decided

    # ── the durable link ────────────────────────────────────────────────
    async def for_patient(self, patient_id: str) -> Optional[DoctorPatientLink]:
        return await self._links.get_for_patient(patient_id)

    async def caseload_links(self, doctor_uid: str) -> List[DoctorPatientLink]:
        return await self._links.list_for_doctor(doctor_uid)

    async def disconnect(self, patient_id: str, doctor_uid: str) -> None:
        await self._links.delete(patient_id, doctor_uid)

    # ── housekeeping ────────────────────────────────────────────────────
    @staticmethod
    def _is_live(request: DoctorConnectionRequest) -> bool:
        """Pending and not yet past its TTL.

        Read at the point of use rather than swept on a timer: with the queue
        in Firestore there is no long-lived process to run a sweep, and a
        stale row is harmless as long as nothing treats it as live.
        """
        if request.status != "pending":
            return False
        return request.requested_at_millis >= _now() - _REQUEST_TTL_MILLIS
