"""Structure-only for now — real Firebase-backed auth lands in Phase 2.

A `User` is the backend's notion of "who is calling": a Firebase-authenticated
caregiver or doctor account, or a patient device identified by a lightweight
device token (see `core/device_auth.py`, Phase 3). Nothing constructs this
from a real Firebase token yet.
"""
from enum import Enum
from typing import Optional

from .common import APIModel


class UserRole(str, Enum):
    patient = "patient"
    caregiver = "caregiver"
    doctor = "doctor"


class User(APIModel):
    id: str
    email: Optional[str] = None
    display_name: Optional[str] = None
    role: UserRole
