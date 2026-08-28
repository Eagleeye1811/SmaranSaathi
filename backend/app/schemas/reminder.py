from app.models.common import APIModel
from app.models.daily import ReminderKind


class ReminderCreate(APIModel):
    patient_id: str
    time: str
    minutes_from_midnight: int
    title: str
    kind: ReminderKind
    detail: str = ""


class ReminderSetDone(APIModel):
    done: bool
