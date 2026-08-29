from typing import Dict, Optional

from app.repositories.base import SyncLedgerRepository


class InMemorySyncLedgerRepository(SyncLedgerRepository):
    def __init__(self) -> None:
        self._store: Dict[str, dict] = {}

    async def get(self, operation_id: str) -> Optional[dict]:
        return self._store.get(operation_id)

    async def mark_applied(self, operation_id: str, kind: str, patient_id: str, applied_at_millis: int) -> None:
        self._store[operation_id] = {
            "kind": kind,
            "patientId": patient_id,
            "appliedAtMillis": applied_at_millis,
        }
