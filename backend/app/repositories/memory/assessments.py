from typing import Dict, Optional

from app.repositories.base import AssessmentRepository


class InMemoryAssessmentRepository(AssessmentRepository):
    """Phase-1 style store: a dict per patient, lost on restart — the same
    tradeoff every other in-memory repository here accepts."""

    def __init__(self) -> None:
        self._intakes: Dict[str, dict] = {}
        self._baselines: Dict[str, dict] = {}

    async def save_intake_step(self, patient_id: str, step: str, payload: dict) -> None:
        record = self._intakes.setdefault(patient_id, {})
        record[step] = payload

    async def get_intake(self, patient_id: str) -> Optional[dict]:
        return self._intakes.get(patient_id)

    async def save_baseline(self, patient_id: str, baseline: dict) -> None:
        self._baselines[patient_id] = baseline

    async def get_baseline(self, patient_id: str) -> Optional[dict]:
        return self._baselines.get(patient_id)
