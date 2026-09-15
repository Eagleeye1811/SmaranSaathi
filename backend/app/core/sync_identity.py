"""Who is calling `/api/v1/sync/*`, and which patient record they may touch.

Two kinds of caller reach these endpoints, and they are not equivalent:

  * **An account** — a caregiver or doctor holding a Firebase ID token. The
    app derives its patient id from the uid (`_patientIdFor` in
    `app_state.dart`: ``acct_<uid>``), so the record an account owns is
    fully determined by the token and needs no trust in the request body.
  * **A paired device** — a patient's phone, approved by a caregiver through
    `PairingService`. It has no account at all, only the device token from
    `POST /api/v1/auth/device`, and it legitimately carries the *caregiver's*
    patient id.

`get_current_device` alone could not tell these apart, so every caller was
treated as the weaker one: the server trusted `payload.patientId` outright,
and `GET /sync/restore?patientId=…` would hand any record to anyone holding
a freely-minted device token. Resolving the identity first means an account
is now held to its own record, which is what makes signing in on a second
device return that person's data and nobody else's.
"""
from dataclasses import dataclass
from typing import Optional

from fastapi import Header

from app.core.device_auth import verify_device_token
from app.core.errors import ApiError

ACCOUNT_PATIENT_PREFIX = "acct_"


def patient_id_for_account(uid: str) -> str:
    """Mirrors `_patientIdFor` in the Flutter client. Keep the two in step."""
    return f"{ACCOUNT_PATIENT_PREFIX}{uid}"


@dataclass(frozen=True)
class SyncIdentity:
    """`uid` is set for an account caller, `device_id` for a paired device."""

    uid: Optional[str] = None
    device_id: Optional[str] = None

    @property
    def is_account(self) -> bool:
        return self.uid is not None

    def may_access(self, patient_id: str) -> bool:
        # A device token proves only "a copy of SmaranSaathi is calling", so it
        # stays as permissive as it was; an account is pinned to its own record.
        if not self.is_account:
            return True
        return patient_id == patient_id_for_account(self.uid or "")

    def assert_may_access(self, patient_id: str) -> None:
        if not self.may_access(patient_id):
            raise ApiError(
                "forbidden",
                "This account may only read and write its own patient record.",
            )


async def get_sync_identity(authorization: Optional[str] = Header(default=None)) -> SyncIdentity:
    """Accepts either token, preferring the stronger one it can prove.

    The device token is tried first because it verifies locally in
    microseconds against our own HS256 secret, and a Firebase ID token can
    never satisfy it (different algorithm and issuer), so the order costs an
    account caller nothing but saves every patient device a network-backed
    key lookup.
    """
    if not authorization or not authorization.lower().startswith("bearer "):
        raise ApiError("unauthorized", "Missing or malformed Authorization header.")
    token = authorization.split(" ", 1)[1].strip()

    try:
        return SyncIdentity(device_id=verify_device_token(token))
    except ApiError:
        pass

    # Not a device token, so it has to be a Firebase ID token or nothing.
    try:
        from firebase_admin import auth as firebase_auth

        from app.core.firebase import init_firebase

        init_firebase()
        decoded = firebase_auth.verify_id_token(token)
    except Exception as exc:  # firebase_admin raises several distinct types
        raise ApiError("unauthorized", "Invalid or expired token.") from exc

    return SyncIdentity(uid=decoded["uid"])
