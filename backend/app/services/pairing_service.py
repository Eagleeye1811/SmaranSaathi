"""In-memory pairing store.

Deliberately process-local, like the other memory repositories: a pairing is a
short-lived handshake, not a record. A restart losing a pending request is the
correct behaviour — the patient simply asks again and the caregiver approves
again — whereas a *claimed username* does need to outlive the handshake, which
is why it is written through to the patient repository as well.
"""
from __future__ import annotations

import time
import uuid
from typing import Dict, List, Optional

from app.schemas.pairing import (
    AccessRequest,
    ClaimUsernameRequest,
    ClaimUsernameResponse,
    PairingRequestResponse,
)

# A pending request older than this is no use to anyone: the caregiver has put
# the phone down, and an approval arriving an hour later is a security problem
# rather than a feature.
_REQUEST_TTL_MILLIS = 15 * 60 * 1000


def _now() -> int:
    return int(time.time() * 1000)


def _normalise(username: str) -> str:
    return username.strip().lower()


class PairingService:
    def __init__(self) -> None:
        # username -> claim
        self._claims: Dict[str, ClaimUsernameResponse] = {}
        # request id -> request
        self._requests: Dict[str, PairingRequestResponse] = {}

    # ── claiming ────────────────────────────────────────────────────────
    def claim(self, data: ClaimUsernameRequest) -> ClaimUsernameResponse:
        name = _normalise(data.username)
        existing = self._claims.get(name)
        if existing is not None:
            # Same caregiver re-claiming the same name for the same patient is
            # a retry, not a collision.
            if existing.patient_id == data.patient_id and existing.caregiver_uid == data.caregiver_uid:
                return existing.model_copy(update={"already_claimed": True})
            raise ValueError("username_taken")

        claim = ClaimUsernameResponse(
            username=name,
            patient_id=data.patient_id,
            caregiver_uid=data.caregiver_uid,
            patient_name=data.patient_name,
            already_claimed=False,
        )
        self._claims[name] = claim
        return claim

    def lookup(self, username: str) -> Optional[ClaimUsernameResponse]:
        return self._claims.get(_normalise(username))

    # ── requesting ──────────────────────────────────────────────────────
    def request_access(self, data: AccessRequest) -> PairingRequestResponse:
        claim = self.lookup(data.username)
        if claim is None:
            raise LookupError("unknown_username")

        self._expire_stale()

        # One live request per device per username. Asking twice from the same
        # phone should not fill the caregiver's screen with duplicates.
        for req in self._requests.values():
            if (
                req.status == "pending"
                and req.device_id == data.device_id
                and req.username == claim.username
            ):
                return req

        request = PairingRequestResponse(
            request_id=uuid.uuid4().hex,
            username=claim.username,
            patient_id=claim.patient_id,
            device_id=data.device_id,
            device_label=data.device_label,
            status="pending",
            requested_at_millis=_now(),
        )
        self._requests[request.request_id] = request
        return request

    def pending_for(self, caregiver_uid: str) -> List[PairingRequestResponse]:
        self._expire_stale()
        usernames = {
            c.username for c in self._claims.values() if c.caregiver_uid == caregiver_uid
        }
        return [
            r
            for r in self._requests.values()
            if r.status == "pending" and r.username in usernames
        ]

    def status(self, request_id: str) -> Optional[PairingRequestResponse]:
        self._expire_stale()
        return self._requests.get(request_id)

    # ── deciding ────────────────────────────────────────────────────────
    def decide(self, request_id: str, caregiver_uid: str, approve: bool) -> PairingRequestResponse:
        request = self._requests.get(request_id)
        if request is None:
            raise LookupError("unknown_request")

        claim = self._claims.get(request.username)
        # Only the caregiver who claimed the username may decide. Without this
        # anyone holding a request id could approve their own access.
        if claim is None or claim.caregiver_uid != caregiver_uid:
            raise PermissionError("not_your_patient")
        if request.status != "pending":
            return request

        decided = request.model_copy(
            update={
                "status": "approved" if approve else "declined",
                "decided_at_millis": _now(),
            }
        )
        self._requests[request_id] = decided
        return decided

    # ── housekeeping ────────────────────────────────────────────────────
    def _expire_stale(self) -> None:
        cutoff = _now() - _REQUEST_TTL_MILLIS
        for rid, req in list(self._requests.items()):
            if req.status == "pending" and req.requested_at_millis < cutoff:
                self._requests[rid] = req.model_copy(update={"status": "expired"})


_service = PairingService()


def get_pairing_service() -> PairingService:
    return _service
