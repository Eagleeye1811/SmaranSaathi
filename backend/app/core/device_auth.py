"""Lightweight, backend-issued device tokens for sync requests.

Deliberately separate from `core/security.py`'s Firebase user auth: the
Flutter app has no login UI, so it cannot obtain a Firebase ID token, and
adding the `firebase_auth` client SDK (native config, app registration) is
out of scope for this backend-only phase. A device calls `POST
/api/v1/auth/device` once, gets a signed JWT back, and attaches it as a
Bearer token to every `/api/v1/sync/operations` call. This is app-level
device authentication, not per-user identity — it proves "a copy of
MemoryMitra issued this token", not "this is a specific logged-in person".
"""
import time
import uuid
from typing import Optional, Tuple

import jwt
from fastapi import Header

from app.core.config import get_settings
from app.core.errors import ApiError

_ALGORITHM = "HS256"


def mint_device_token(device_id: Optional[str] = None) -> Tuple[str, str, int]:
    """Returns (device_id, token, expires_at_millis)."""
    settings = get_settings()
    device_id = device_id or str(uuid.uuid4())
    now = int(time.time())
    exp = now + settings.device_jwt_ttl_seconds
    payload = {
        "sub": device_id,
        "iss": settings.device_jwt_issuer,
        "iat": now,
        "exp": exp,
        "scope": "sync",
    }
    token = jwt.encode(payload, settings.device_jwt_secret, algorithm=_ALGORITHM)
    return device_id, token, exp * 1000


def verify_device_token(token: str) -> str:
    """Returns the device id (JWT `sub`) or raises `ApiError('unauthorized', ...)`."""
    settings = get_settings()
    try:
        payload = jwt.decode(
            token,
            settings.device_jwt_secret,
            algorithms=[_ALGORITHM],
            issuer=settings.device_jwt_issuer,
            options={"require": ["exp", "iat", "sub"]},
        )
    except jwt.PyJWTError as exc:
        raise ApiError("unauthorized", "Invalid or expired device token.") from exc
    return payload["sub"]


async def get_current_device(authorization: Optional[str] = Header(default=None)) -> str:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise ApiError("unauthorized", "Missing or malformed Authorization header.")
    token = authorization.split(" ", 1)[1].strip()
    return verify_device_token(token)
