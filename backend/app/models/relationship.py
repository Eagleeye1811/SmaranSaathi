from .common import APIModel


class CaregiverPatientLink(APIModel):
    id: str
    caregiver_id: str
    patient_id: str
    relation: str = "caregiver"
