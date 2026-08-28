from fastapi import APIRouter, Depends

from app.core.device_auth import mint_device_token
from app.core.security import get_current_user
from app.models.user import User
from app.schemas.auth import DeviceTokenRequest, DeviceTokenResponse, MeResponse

router = APIRouter(prefix="/auth", tags=["auth"])


@router.get("/me", response_model=MeResponse)
async def me(user: User = Depends(get_current_user)) -> MeResponse:
    return MeResponse(id=user.id, email=user.email, display_name=user.display_name, role=user.role)


@router.post("/device", response_model=DeviceTokenResponse)
async def issue_device_token(data: DeviceTokenRequest = DeviceTokenRequest()) -> DeviceTokenResponse:
    """Open enrollment, by design: the Flutter app has no login UI, so this
    proves "a copy of MemoryMitra is calling", not "this is a specific
    person" — see core/device_auth.py's module docstring. `deviceId`, when
    supplied, re-mints a token for the same device rather than minting a new
    identity."""
    device_id, token, expires_at_millis = mint_device_token(data.device_id)
    return DeviceTokenResponse(device_id=device_id, token=token, expires_at_millis=expires_at_millis)
