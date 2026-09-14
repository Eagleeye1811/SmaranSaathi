"""Pairing: a durable claimed-username store plus an ephemeral request queue.

The two halves have deliberately different lifetimes. A pending *request* is
a short-lived handshake — a restart losing it is the correct behaviour, the
patient simply asks again and the caregiver approves again — so it stays a
plain process-local dict here, same as before. A *claimed username*, though,
needs to outlive both the handshake and the process: a patient's device may
look it up long after the caregiver claimed it, possibly after the backend
has restarted (this app's free-tier hosting spins down on idle). That half is
now backed by `PairingClaimRepository` (Firestore in production, matching
every other durable resource in this backend; in-memory only for local dev)
instead of a bare dict — the previous version kept claims in-memory too,
which meant a caregiver's claim could vanish on the very next cold start,
indistinguishable from "it never saved."
"""
from __future__ import annotations

import time
import uuid
from functools import lru_cache
from typing import Dict, List, Optional

from app.core.dependencies import get_pairing_claim_repository
from app.repositories.base import PairingClaimRepository
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
    def __init__(self, claims: PairingClaimRepository) -> None:
        self._claims = claims
        # request id -> request
        self._requests: Dict[str, PairingRequestResponse] = {}

    # ── claiming ────────────────────────────────────────────────────────
    async def claim(self, data: ClaimUsernameRequest) -> ClaimUsernameResponse:
        name = _normalise(data.username)
        existing = await self._claims.get(name)
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
        return await self._claims.save(claim)

    async def lookup(self, username: str) -> Optional[ClaimUsernameResponse]:
        return await self._claims.get(_normalise(username))

    async def claims_for(self, caregiver_uid: str) -> List[ClaimUsernameResponse]:
        """What this caregiver has already claimed, if anything.

        Exists so a device that has forgotten its own `patientUsername` cache
        — the caregiver signed out and back in, or reinstalled — can ask the
        durable backend record instead of assuming nothing was ever claimed.
        Without this, a returning caregiver silently stops seeing incoming
        pairing requests: the claim is still there, but the app no longer
        knows to poll for requests against it.
        """
        return await self._claims.list_for_caregiver(caregiver_uid)

    # ── requesting ──────────────────────────────────────────────────────
    async def request_access(self, data: AccessRequest) -> PairingRequestResponse:
        claim = await self.lookup(data.username)
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

    async def pending_for(self, caregiver_uid: str) -> List[PairingRequestResponse]:
        self._expire_stale()
        claims = await self._claims.list_for_caregiver(caregiver_uid)
        usernames = {c.username for c in claims}
        return [
            r
            for r in self._requests.values()
            if r.status == "pending" and r.username in usernames
        ]

    def status(self, request_id: str) -> Optional[PairingRequestResponse]:
        self._expire_stale()
        return self._requests.get(request_id)

    # ── deciding ────────────────────────────────────────────────────────
    async def decide(self, request_id: str, caregiver_uid: str, approve: bool) -> PairingRequestResponse:
        request = self._requests.get(request_id)
        if request is None:
            raise LookupError("unknown_request")

        claim = await self.lookup(request.username)
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


@lru_cache
def get_pairing_service() -> PairingService:
    # A real singleton, not a per-request construction like `SyncService`:
    # `_requests` is deliberately in-memory state that has to survive between
    # one HTTP call creating a request and a later one approving it. Only the
    # durable half (claims) goes through a swappable repository.
    return PairingService(claims=get_pairing_claim_repository())
