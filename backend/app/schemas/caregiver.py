from app.models.common import APIModel


class CaregiverLinkCreate(APIModel):
    caregiver_id: str
    patient_id: str
    relation: str = "caregiver"
