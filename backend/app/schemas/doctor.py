"""A caregiver connecting their patient to a real doctor account.

Shaped like `schemas/pairing.py`'s claim/request/decide handshake, with one
deliberate difference: both sides here are real Firebase accounts (a doctor
signs up the same way a caregiver does), so the identity that matters for
authorisation is taken from the verified token in the router, never from a
client-supplied field in the body — see `DoctorConnectionService.decide`.
"""
from typing import Literal, Optional

from app.models.common import APIModel

DoctorConnectionStatus = Literal["pending", "approved", "declined", "expired"]


class DoctorProfileUpsert(APIModel):
    """What a doctor account can set about itself. `id`/`email` are taken
    from the authenticated token, not from this body."""

    name: str
    specialization: str = ""
    hospital: str = ""
    phone: str = ""
    registration_number: str = ""
    avatar_initials: str = ""


class DoctorConnectionInvite(APIModel):
    """A caregiver asking a doctor to take on their patient."""

    doctor_uid: str
    patient_id: str
    patient_name: str = ""
    patient_age: int = 0
    district: str = ""


class DoctorConnectionRequest(APIModel):
    request_id: str
    doctor_uid: str
    caregiver_uid: str
    patient_id: str
    patient_name: str = ""
    patient_age: int = 0
    district: str = ""
    status: DoctorConnectionStatus
    requested_at_millis: int
    decided_at_millis: Optional[int] = None


class DoctorConnectionDecision(APIModel):
    """`doctor_uid` is accepted for schema symmetry with the pairing
    endpoints but is ignored by the router in favour of the authenticated
    caller's own uid — see the module docstring."""

    request_id: str
    approve: bool


class DoctorDisconnectRequest(APIModel):
    patient_id: str
