from fastapi import APIRouter, Depends
from firebase_admin import auth as firebase_auth

from app.core.device_auth import mint_device_token
from app.core.security import get_current_user
from app.models.user import User
from app.schemas.auth import DeviceTokenRequest, DeviceTokenResponse, MeResponse, SetRoleRequest

router = APIRouter(prefix="/auth", tags=["auth"])


@router.get("/me", response_model=MeResponse)
async def me(user: User = Depends(get_current_user)) -> MeResponse:
    return MeResponse(id=user.id, email=user.email, display_name=user.display_name, role=user.role)


@router.post("/role", response_model=MeResponse)
async def set_role(data: SetRoleRequest, user: User = Depends(get_current_user)) -> MeResponse:
    """Self-declared role, by design: there's no admin-approval flow in this
    prototype, so whichever role the caregiver/doctor picks on
    `RoleSelectionScreen` the first time is what gets set. A client can't set
    its own custom claims directly (only the Admin SDK can), which is why
    this is a real backend round trip rather than something the Flutter app
    could do on its own. The caller must refresh its cached ID token
    afterward (`idToken(forceRefresh: true)`) to see the new claim — Firebase
    caches tokens for up to an hour otherwise."""
    firebase_auth.set_custom_user_claims(user.id, {"role": data.role.value})
    return MeResponse(id=user.id, email=user.email, display_name=user.display_name, role=data.role)


@router.post("/device", response_model=DeviceTokenResponse)
async def issue_device_token(data: DeviceTokenRequest = DeviceTokenRequest()) -> DeviceTokenResponse:
    """Open enrollment, by design: the Flutter app has no login UI, so this
    proves "a copy of SmaranSaathi is calling", not "this is a specific
    person" — see core/device_auth.py's module docstring. `deviceId`, when
    supplied, re-mints a token for the same device rather than minting a new
    identity."""
    device_id, token, expires_at_millis = mint_device_token(data.device_id)
    return DeviceTokenResponse(device_id=device_id, token=token, expires_at_millis=expires_at_millis)
