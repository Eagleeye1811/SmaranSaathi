import pytest
from fastapi.testclient import TestClient

from app.core.dependencies import (
    get_analytics_repository,
    get_caregiver_link_repository,
    get_daily_repository,
    get_game_session_repository,
    get_patient_repository,
    get_reminder_repository,
    get_sync_ledger_repository,
)
from app.core.device_auth import mint_device_token
from app.core.security import get_current_user
from app.main import app
from app.models.user import User, UserRole
from app.repositories.memory.analytics import InMemoryAnalyticsRepository
from app.repositories.memory.caregivers import InMemoryCaregiverLinkRepository
from app.repositories.memory.daily import InMemoryDailyRepository
from app.repositories.memory.patients import InMemoryPatientRepository
from app.repositories.memory.reminders import InMemoryReminderRepository
from app.repositories.memory.sessions import InMemoryGameSessionRepository
from app.repositories.memory.sync_ledger import InMemorySyncLedgerRepository


@pytest.fixture
def client() -> TestClient:
    """Unauthenticated client — for health/insights and 401 checks."""
    return TestClient(app)


@pytest.fixture
def authed_client():
    """A client for unit-testing protected routers' business logic, isolated
    from whatever backend/.env happens to configure:

    - `get_current_user` is overridden to a fake caregiver, so no real
      Firebase ID token is needed.
    - Every repository dependency is overridden to a fresh in-memory instance,
      so these tests never touch real Firestore (even when Firebase IS
      configured) — hermetic and fast. Real Firebase/Firestore behaviour is
      covered end-to-end in `test_firebase_integration.py` instead.

    Note this does *not* override `get_current_device` (Phase 3's separate
    device-token auth) — sync tests use the `device_headers` fixture, which
    mints a real device JWT, so that code path stays genuinely exercised.
    """

    def _fake_user() -> User:
        return User(id="test-caregiver", email="test@example.com", display_name="Test Caregiver", role=UserRole.caregiver)

    # One instance per repository, shared across every request the test
    # makes — a fresh instance *per request* (e.g. `dependency_overrides[...] =
    # InMemoryPatientRepository`) would silently lose state between a test's
    # POST and its follow-up GET.
    patients = InMemoryPatientRepository()
    sessions = InMemoryGameSessionRepository()
    analytics = InMemoryAnalyticsRepository()
    daily = InMemoryDailyRepository()
    reminders = InMemoryReminderRepository()
    caregiver_links = InMemoryCaregiverLinkRepository()
    sync_ledger = InMemorySyncLedgerRepository()

    app.dependency_overrides[get_current_user] = _fake_user
    app.dependency_overrides[get_patient_repository] = lambda: patients
    app.dependency_overrides[get_game_session_repository] = lambda: sessions
    app.dependency_overrides[get_analytics_repository] = lambda: analytics
    app.dependency_overrides[get_daily_repository] = lambda: daily
    app.dependency_overrides[get_reminder_repository] = lambda: reminders
    app.dependency_overrides[get_caregiver_link_repository] = lambda: caregiver_links
    app.dependency_overrides[get_sync_ledger_repository] = lambda: sync_ledger

    test_client = TestClient(app)
    yield test_client

    for dependency in (
        get_current_user,
        get_patient_repository,
        get_game_session_repository,
        get_analytics_repository,
        get_daily_repository,
        get_reminder_repository,
        get_caregiver_link_repository,
        get_sync_ledger_repository,
    ):
        app.dependency_overrides.pop(dependency, None)


@pytest.fixture
def device_headers() -> dict:
    """A real, freshly-minted device JWT (no HTTP round trip) — for sync
    tests that aren't specifically about the token-issuance endpoint itself."""
    _, token, _ = mint_device_token()
    return {"Authorization": f"Bearer {token}"}
