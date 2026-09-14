"""Doctor connections: a durable profile directory and durable
doctor↔patient links, plus an ephemeral pending-request queue in between.

Structured exactly like `pairing_service.py`, for the same reason: a pending
*request* is a short-lived handshake (a restart losing it is fine — the
caregiver just invites again), so it stays a plain process-local dict, while
profiles and accepted links are durable (`DoctorProfileRepository` /
`DoctorPatientLinkRepository`, Firestore in production).

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
from typing import Dict, List, Optional

from app.models.doctor import DoctorPatientLink, DoctorProfile
from app.repositories.base import DoctorPatientLinkRepository, DoctorProfileRepository
from app.schemas.doctor import DoctorConnectionInvite, DoctorConnectionRequest, DoctorProfileUpsert

# Same reasoning as pairing's request TTL: an invite nobody has acted on in
# 15 minutes is stale, not worth resurrecting with a late accept.
_REQUEST_TTL_MILLIS = 15 * 60 * 1000


def _now() -> int:
    return int(time.time() * 1000)


# Module-level, not per-instance: `DoctorConnectionService` is constructed
# fresh per request (see `api/v1/doctor_connections.py`'s `get_service`, the
# same per-request-factory pattern `caregivers.py` uses, so its two
# repository dependencies stay overridable in tests) — but the pending
# invite queue still has to be one shared, process-wide queue, or an invite
# made on one request would be invisible to the accept made on the next.
# Same lifetime reasoning as pairing's `_requests`: fine to lose on a
# restart, not fine to lose between two requests seconds apart.
_requests: Dict[str, DoctorConnectionRequest] = {}


class DoctorConnectionService:
    def __init__(self, profiles: DoctorProfileRepository, links: DoctorPatientLinkRepository) -> None:
        self._profiles = profiles
        self._links = links
        self._requests = _requests

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

        self._expire_stale()

        # One live invite per doctor+patient pair — asking twice must not
        # fill the doctor's inbox with duplicates of the same request.
        for req in self._requests.values():
            if (
                req.status == "pending"
                and req.doctor_uid == data.doctor_uid
                and req.patient_id == data.patient_id
            ):
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
        self._requests[request.request_id] = request
        return request

    async def pending_for(self, doctor_uid: str) -> List[DoctorConnectionRequest]:
        self._expire_stale()
        return [r for r in self._requests.values() if r.status == "pending" and r.doctor_uid == doctor_uid]

    # ── deciding ────────────────────────────────────────────────────────
    async def decide(self, request_id: str, doctor_uid: str, approve: bool) -> DoctorConnectionRequest:
        request = self._requests.get(request_id)
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
        self._requests[request_id] = decided

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
    def _expire_stale(self) -> None:
        cutoff = _now() - _REQUEST_TTL_MILLIS
        for rid, req in list(self._requests.items()):
            if req.status == "pending" and req.requested_at_millis < cutoff:
                self._requests[rid] = req.model_copy(update={"status": "expired"})
