"""Linking a patient's device to the profile their caregiver built.

Auth here is the *device* token, not a user token: the whole point is that the
patient's phone has no account yet. What protects the account is that only the
caregiver who claimed the username can approve a request, which is checked in
`PairingService.decide`.
"""
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.device_auth import get_current_device
from app.schemas.pairing import (
    AccessRequest,
    ClaimUsernameRequest,
    ClaimUsernameResponse,
    PairingDecision,
    PairingRequestResponse,
)
from app.services.pairing_service import PairingService, get_pairing_service

router = APIRouter(
    prefix="/pairing",
    tags=["pairing"],
    dependencies=[Depends(get_current_device)],
)


@router.post("/claim", response_model=ClaimUsernameResponse)
async def claim_username(
    data: ClaimUsernameRequest,
    service: PairingService = Depends(get_pairing_service),
) -> ClaimUsernameResponse:
    try:
        return await service.claim(data)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="That username is already in use.",
        )


@router.get("/lookup", response_model=ClaimUsernameResponse)
async def lookup_username(
    username: str = Query(...),
    service: PairingService = Depends(get_pairing_service),
) -> ClaimUsernameResponse:
    claim = await service.lookup(username)
    if claim is None:
        raise HTTPException(status_code=404, detail="No account with that username.")
    return claim


@router.get("/claims", response_model=List[ClaimUsernameResponse])
async def claims_for_caregiver(
    caregiverUid: str = Query(...),
    service: PairingService = Depends(get_pairing_service),
) -> List[ClaimUsernameResponse]:
    return await service.claims_for(caregiverUid)


@router.post("/request", response_model=PairingRequestResponse, status_code=201)
async def request_access(
    data: AccessRequest,
    service: PairingService = Depends(get_pairing_service),
) -> PairingRequestResponse:
    try:
        return await service.request_access(data)
    except LookupError:
        raise HTTPException(status_code=404, detail="No account with that username.")


@router.get("/requests", response_model=List[PairingRequestResponse])
async def pending_requests(
    caregiverUid: str = Query(...),
    service: PairingService = Depends(get_pairing_service),
) -> List[PairingRequestResponse]:
    return await service.pending_for(caregiverUid)


@router.get("/status", response_model=PairingRequestResponse)
async def request_status(
    requestId: str = Query(...),
    service: PairingService = Depends(get_pairing_service),
) -> PairingRequestResponse:
    found = service.status(requestId)
    if found is None:
        raise HTTPException(status_code=404, detail="Unknown request.")
    return found


@router.post("/respond", response_model=PairingRequestResponse)
async def respond(
    data: PairingDecision,
    service: PairingService = Depends(get_pairing_service),
) -> PairingRequestResponse:
    try:
        return await service.decide(data.request_id, data.caregiver_uid, data.approve)
    except LookupError:
        raise HTTPException(status_code=404, detail="Unknown request.")
    except PermissionError:
        raise HTTPException(status_code=403, detail="Not your patient.")
