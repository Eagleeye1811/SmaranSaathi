"""Doctor-only weekly clinical report.

The caregiver's app computes the report client-side (from the same session
data already backing its own dashboard, plus the caregiver's notes and
concern check-ins) and posts it here the moment a 7-activity cycle actually
closes — there is no scheduler and no "send" button, the caregiver's device
just posts once the round is done. See `WeeklyReportBuilder` in
`frontend/lib/core/models/weekly_report.dart` for the aggregation itself.

Storage is an append-only history per patient, not a single overwritable
slot: an in-progress cycle is never posted here at all (the frontend only
calls this once `activities_completed` reaches the full 7 — see
`AppState._syncWeeklyReport`), and a completed report is never replaced by a
later one. The first version of this endpoint stored one report per patient
and blindly overwrote it on every sync, which meant a genuinely-completed
week's report could be silently erased the moment the next cycle's first
activity synced, before a doctor ever saw it. Same demo-grade, single-tenant
pattern as `patient_consultations` in `telehealth.py` — just append-only.
"""
from typing import Dict, List, Optional

from fastapi import APIRouter

from app.schemas.weekly_report import WeeklyClinicalReport

router = APIRouter(prefix="/weekly-reports", tags=["weekly-reports"])

# The frontend never posts a report with fewer than every one of the 7 scored
# activities — see `AppState._syncWeeklyReport`'s early return. Enforced again
# here so a malformed or future client can't overwrite/pollute the archive
# with a partial-cycle snapshot.
_REQUIRED_ACTIVITIES = 7

_reports: Dict[str, List[WeeklyClinicalReport]] = {}


@router.post("", response_model=Optional[WeeklyClinicalReport])
async def record_weekly_report(report: WeeklyClinicalReport):
    """Appends a just-completed cycle's report. Anything short of a full
    7-activity cycle is accepted but not stored — the doctor only ever sees
    a finished week, never an in-progress one."""
    if report.activities_completed < _REQUIRED_ACTIVITIES:
        return None
    _reports.setdefault(report.patient_id, []).append(report)
    return report


@router.get("/{patient_id}", response_model=Optional[WeeklyClinicalReport])
async def get_latest_weekly_report(patient_id: str):
    """The most recently completed weekly report for this patient, if any."""
    history = _reports.get(patient_id)
    return history[-1] if history else None


@router.get("/{patient_id}/history", response_model=List[WeeklyClinicalReport])
async def get_weekly_report_history(patient_id: str):
    """Every completed weekly report on record for this patient, oldest first."""
    return _reports.get(patient_id, [])
