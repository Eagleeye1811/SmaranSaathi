"""Firebase ID-token verification for the general (dashboard-style) API
surface — caregivers and doctors. This is deliberately separate from Phase
3's device-token scheme (`core/device_auth.py`): the Flutter app has no login
UI yet, so it cannot obtain a Firebase ID token, and pulling in the
`firebase_auth` client SDK is out of scope for this backend-only task (see
the plan's decision #2). This dependency exists for when a real login screen
lands, and is exercised today only by direct API callers with a token minted
through the Identity Toolkit REST API (see `tests/test_firebase_integration.py`).
"""
from typing import Optional

from fastapi import Header
from firebase_admin import auth as firebase_auth

from app.core.errors import ApiError
from app.core.firebase import init_firebase
from app.models.user import User, UserRole


async def get_current_user(authorization: Optional[str] = Header(default=None)) -> User:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise ApiError("unauthorized", "Missing or malformed Authorization header.")

    token = authorization.split(" ", 1)[1].strip()
    init_firebase()

    try:
        decoded = firebase_auth.verify_id_token(token)
    except Exception as exc:  # firebase_admin raises several distinct error types
        raise ApiError("unauthorized", "Invalid or expired token.") from exc

    role_claim = decoded.get("role")
    try:
        role = UserRole(role_claim) if role_claim else UserRole.caregiver
    except ValueError:
        role = UserRole.caregiver

    return User(
        id=decoded["uid"],
        email=decoded.get("email"),
        display_name=decoded.get("name"),
        role=role,
    )
