"""A caregiver's patient connecting to a real doctor account.

Every endpoint sits behind `Depends(get_current_user)` — unlike pairing,
both sides here are real Firebase accounts, so identity for anything
security-sensitive (who is deciding, whose profile is being written) is
always taken from the verified token, never from the request body.
"""
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from app.core.dependencies import (
    get_doctor_connection_request_repository,
    get_doctor_patient_link_repository,
    get_doctor_profile_repository,
    get_game_session_repository,
    get_patient_repository,
)
from app.core.security import get_current_user
from app.models.clinical import ClinicPatient
from app.models.doctor import DoctorPatientLink, DoctorProfile
from app.models.user import User
from app.repositories.base import (
    DoctorConnectionRequestRepository,
    DoctorPatientLinkRepository,
    DoctorProfileRepository,
    GameSessionRepository,
    PatientRepository,
)
from app.schemas.doctor import (
    DoctorConnectionDecision,
    DoctorConnectionInvite,
    DoctorConnectionRequest,
    DoctorDisconnectRequest,
    DoctorProfileUpsert,
)
from app.services.clinical_aggregation_service import build_clinic_patient
from app.services.doctor_connection_service import DoctorConnectionService

router = APIRouter(prefix="/doctors", tags=["doctors"], dependencies=[Depends(get_current_user)])


def get_service(
    profiles: DoctorProfileRepository = Depends(get_doctor_profile_repository),
    links: DoctorPatientLinkRepository = Depends(get_doctor_patient_link_repository),
    requests: DoctorConnectionRequestRepository = Depends(get_doctor_connection_request_repository),
) -> DoctorConnectionService:
    # Constructed fresh per request from these three (test-overridable, same
    # as `caregivers.py`'s `get_service`) repository dependencies — the
    # pending-invite queue included, now that it is durable rather than a
    # module-level dict in `doctor_connection_service.py`.
    return DoctorConnectionService(profiles, links, requests)


@router.post("/profile", response_model=DoctorProfile)
async def upsert_profile(
    data: DoctorProfileUpsert,
    user: User = Depends(get_current_user),
    service: DoctorConnectionService = Depends(get_service),
) -> DoctorProfile:
    return await service.upsert_profile(user.id, user.email, data)


@router.get("/directory", response_model=List[DoctorProfile])
async def directory(service: DoctorConnectionService = Depends(get_service)) -> List[DoctorProfile]:
    return await service.directory()


@router.post("/connections/invite", response_model=DoctorConnectionRequest, status_code=201)
async def invite(
    data: DoctorConnectionInvite,
    user: User = Depends(get_current_user),
    service: DoctorConnectionService = Depends(get_service),
) -> DoctorConnectionRequest:
    try:
        return await service.invite(user.id, data)
    except ValueError:
        raise HTTPException(status_code=409, detail="Already connected to this doctor.")


@router.get("/connections/requests", response_model=List[DoctorConnectionRequest])
async def pending_requests(
    user: User = Depends(get_current_user),
    service: DoctorConnectionService = Depends(get_service),
) -> List[DoctorConnectionRequest]:
    return await service.pending_for(user.id)


@router.post("/connections/respond", response_model=DoctorConnectionRequest)
async def respond(
    data: DoctorConnectionDecision,
    user: User = Depends(get_current_user),
    service: DoctorConnectionService = Depends(get_service),
) -> DoctorConnectionRequest:
    try:
        return await service.decide(data.request_id, user.id, data.approve)
    except LookupError:
        raise HTTPException(status_code=404, detail="Unknown request.")
    except PermissionError:
        raise HTTPException(status_code=403, detail="Not your invite.")


@router.get("/connections/for-patient", response_model=Optional[DoctorPatientLink])
async def for_patient(
    patientId: str = Query(...),
    service: DoctorConnectionService = Depends(get_service),
) -> Optional[DoctorPatientLink]:
    return await service.for_patient(patientId)


@router.get("/connections/caseload", response_model=List[ClinicPatient])
async def caseload(
    user: User = Depends(get_current_user),
    service: DoctorConnectionService = Depends(get_service),
    patients: PatientRepository = Depends(get_patient_repository),
    sessions: GameSessionRepository = Depends(get_game_session_repository),
) -> List[ClinicPatient]:
    links = await service.caseload_links(user.id)
    rows: List[ClinicPatient] = []
    for link in links:
        patient = await patients.get(link.patient_id)
        if patient is None:
            continue
        patient_sessions = await sessions.list_for_patient(link.patient_id)
        rows.append(await build_clinic_patient(patient, patient_sessions))
    return rows


@router.post("/connections/disconnect", status_code=204)
async def disconnect(
    data: DoctorDisconnectRequest,
    user: User = Depends(get_current_user),
    service: DoctorConnectionService = Depends(get_service),
) -> None:
    await service.disconnect(data.patient_id, user.id)
