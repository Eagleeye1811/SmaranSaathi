"""A doctor's own listing, and the durable link once a caregiver's patient is
actually connected to one. Mirrors `models/relationship.py`'s
`CaregiverPatientLink` shape, but doctor-specific: a doctor is a real Firebase
account (unlike a patient device), so this can be keyed by uid directly.
"""
from .common import APIModel


class DoctorProfile(APIModel):
    id: str  # the doctor's Firebase uid
    name: str
    specialization: str = ""
    hospital: str = ""
    email: str = ""
    phone: str = ""
    registration_number: str = ""
    avatar_initials: str = ""


class DoctorPatientLink(APIModel):
    id: str
    doctor_uid: str
    patient_id: str
    caregiver_uid: str
    connected_at_millis: int
