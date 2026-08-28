"""Real device-token issuance (Phase 3) + a Firebase-user lookup (Phase 2).
See `core/device_auth.py` and `core/security.py` respectively — the two are
deliberately separate auth schemes, not one."""
from typing import Optional

from app.models.common import APIModel
from app.models.user import UserRole


class MeResponse(APIModel):
    id: str
    email: Optional[str] = None
    display_name: Optional[str] = None
    role: UserRole


class DeviceTokenRequest(APIModel):
    device_id: Optional[str] = None


class DeviceTokenResponse(APIModel):
    device_id: str
    token: str
    expires_at_millis: int


class SetRoleRequest(APIModel):
    role: UserRole
