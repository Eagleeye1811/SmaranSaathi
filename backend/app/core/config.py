"""Environment-driven configuration.

Every value here has a safe local-dev default so the app boots with zero
setup. `firebase_project_id` and `google_application_credentials` resolve to
`None` until a real `.env` supplies them (see `.env.example`) — Firebase-backed
routes then fail loudly (`core/firebase.py`) rather than silently misbehaving.

`device_jwt_secret` is the one exception: it needs *some* default so device
sync auth works out of the box in local dev, so it falls back to a
well-known, publicly-visible placeholder value. `Settings` refuses to
construct with that placeholder still in effect when `app_env=production` —
see `model_post_init` below — so a deployment can't silently ship with every
device token forgeable.
"""
from functools import lru_cache
from typing import List, Optional

from pydantic_settings import BaseSettings, SettingsConfigDict

_INSECURE_DEVICE_JWT_SECRET = "dev-insecure-secret-change-me"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # ── General ────────────────────────────────────────────────────────────
    app_name: str = "MemoryMitra Backend"
    app_env: str = "development"
    api_v1_prefix: str = "/api/v1"

    # ── CORS ───────────────────────────────────────────────────────────────
    # Exact origins always allowed (e.g. a deployed web build's real domain).
    allowed_origins: List[str] = []
    # In development, additionally allow any localhost/127.0.0.1 port so
    # `flutter run -d chrome` works without touching config every time the
    # dev server picks a new port. Set to None to disable.
    cors_dev_origin_regex: Optional[str] = r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"

    # ── Firebase (Phase 2) — unset until a real project exists ───────────────
    firebase_project_id: Optional[str] = None
    google_application_credentials: Optional[str] = None
    # Not a runtime secret (Firebase Web API keys are safe to expose — Firebase
    # docs are explicit about this; access is governed by Firestore/Auth rules,
    # not this key's secrecy). Used only by tests, to mint a real ID token via
    # the Identity Toolkit REST API without any client SDK.
    firebase_web_api_key: Optional[str] = None

    # ── Device sync auth (Phase 3) ────────────────────────────────────────
    device_jwt_secret: str = _INSECURE_DEVICE_JWT_SECRET
    device_jwt_issuer: str = "memorymitra-backend"
    device_jwt_ttl_seconds: int = 60 * 60 * 24 * 30  # 30 days

    # ── SMS notifications via Twilio (Phase 4) ────────────────────────────
    # All three must be set for SMS to be enabled. Leave blank in dev to skip
    # sending silently — the scheduler still runs but no SMS is dispatched.
    twilio_account_sid: Optional[str] = None
    twilio_auth_token: Optional[str] = None
    twilio_from_number: Optional[str] = None
    # Set to False in .env to disable all outgoing SMS without removing creds.
    sms_enabled: bool = True

    def model_post_init(self, __context: object) -> None:
        if self.app_env == "production" and self.device_jwt_secret == _INSECURE_DEVICE_JWT_SECRET:
            raise RuntimeError(
                "DEVICE_JWT_SECRET is unset (still the local-dev placeholder) while "
                "APP_ENV=production. Every device sync token would be forgeable. Set a "
                "real DEVICE_JWT_SECRET in the environment before starting in production "
                "(see .env.example for how to generate one)."
            )

    @property
    def cors_origins(self) -> List[str]:
        return self.allowed_origins

    @property
    def firebase_configured(self) -> bool:
        return bool(self.firebase_project_id and self.google_application_credentials)

    @property
    def twilio_configured(self) -> bool:
        """True only when all three Twilio credentials are present and SMS is enabled."""
        return bool(
            self.sms_enabled
            and self.twilio_account_sid
            and self.twilio_auth_token
            and self.twilio_from_number
        )


def get_settings() -> Settings:
    return Settings()
