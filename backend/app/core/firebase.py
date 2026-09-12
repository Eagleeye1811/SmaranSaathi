"""Firebase Admin SDK lifecycle — one place that initializes it, from
environment-supplied credentials only. Never hardcode a project ID or key
here; if `.env` doesn't configure Firebase, Firebase-backed routes fail
loudly (via `ApiError`) rather than the app crashing at import time, so
Phase 1's in-memory routes keep working with no Firebase project at all.
"""
import logging
from typing import Optional

import firebase_admin
from firebase_admin import credentials, firestore

from app.core.config import get_settings
from app.core.errors import ApiError

logger = logging.getLogger("SmaranSaathi")

_app: Optional[firebase_admin.App] = None
_db = None


def init_firebase() -> firebase_admin.App:
    """Initializes the Admin SDK exactly once per process. Raises a clean
    `ApiError` (503) if Firebase isn't configured, instead of a raw SDK
    traceback reaching the client."""
    global _app
    if _app is not None:
        return _app

    settings = get_settings()
    if not settings.firebase_configured:
        raise ApiError(
            "service_unavailable",
            "Firebase is not configured on this backend (FIREBASE_PROJECT_ID / "
            "GOOGLE_APPLICATION_CREDENTIALS are unset).",
            status_code=503,
        )

    try:
        _app = firebase_admin.get_app()
    except ValueError:
        cred = credentials.Certificate(settings.google_application_credentials)
        _app = firebase_admin.initialize_app(cred, {"projectId": settings.firebase_project_id})
        logger.info("Firebase Admin SDK initialized for project '%s'.", settings.firebase_project_id)
    return _app


def get_firestore_client():
    global _db
    if _db is None:
        init_firebase()
        _db = firestore.client()
    return _db
