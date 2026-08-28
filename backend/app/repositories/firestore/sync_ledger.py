from typing import Optional

from starlette.concurrency import run_in_threadpool

from app.core.firebase import get_firestore_client
from app.repositories.base import SyncLedgerRepository

_COLLECTION = "sync_operations"


class FirestoreSyncLedgerRepository(SyncLedgerRepository):
    def __init__(self) -> None:
        self._db = get_firestore_client()

    async def get(self, operation_id: str) -> Optional[dict]:
        def _get() -> Optional[dict]:
            doc = self._db.collection(_COLLECTION).document(operation_id).get()
            return doc.to_dict() if doc.exists else None

        return await run_in_threadpool(_get)

    async def mark_applied(self, operation_id: str, kind: str, patient_id: str, applied_at_millis: int) -> None:
        def _set() -> None:
            self._db.collection(_COLLECTION).document(operation_id).set(
                {"kind": kind, "patientId": patient_id, "appliedAtMillis": applied_at_millis}
            )

        await run_in_threadpool(_set)
