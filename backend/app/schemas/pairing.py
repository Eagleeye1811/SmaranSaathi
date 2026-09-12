"""Linking a patient's own device to the profile their caregiver created.

The patient never types an email or a password. Their caregiver claims a short
username for them, and a device that knows that username can *ask* to become
that patient — but only the caregiver's device can say yes. That keeps the
account reachable from any phone without asking a person with memory loss to
hold a credential they cannot be expected to remember.
"""
from typing import Literal, Optional

from app.models.common import APIModel

PairingStatus = Literal["pending", "approved", "declined", "expired"]


class ClaimUsernameRequest(APIModel):
    """The caregiver naming their patient's account. Idempotent per patient:
    claiming again with the same username is a no-op, which matters because a
    caregiver who taps twice on a slow connection should not be told the name
    they just chose is taken."""

    username: str
    patient_id: str
    caregiver_uid: str
    patient_name: str = ""


class ClaimUsernameResponse(APIModel):
    username: str
    patient_id: str
    caregiver_uid: str
    patient_name: str = ""
    already_claimed: bool = False


class AccessRequest(APIModel):
    """A device asking to sign in as the patient behind `username`."""

    username: str
    device_id: str
    device_label: str = ""


class PairingRequestResponse(APIModel):
    request_id: str
    username: str
    patient_id: str
    device_id: str
    device_label: str = ""
    status: PairingStatus
    requested_at_millis: int
    decided_at_millis: Optional[int] = None


class PairingDecision(APIModel):
    request_id: str
    caregiver_uid: str
    approve: bool
