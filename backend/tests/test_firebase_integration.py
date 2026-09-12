"""Real integration tests against the actual Firebase project configured in
backend/.env — this is what the Phase 2 brief asked to verify: Firebase
initialization, an authenticated request, a Firestore read/write round-trip,
and unauthorized-request rejection.

Skipped automatically (module-level) if Firebase isn't configured at all, so
`pytest` still passes cleanly with zero setup — same guarantee Phase 1 had.
The one test that needs a real ID token additionally requires
FIREBASE_WEB_API_KEY (Project settings → General → Web API Key — not a
runtime secret, only used here to mint a token via the Identity Toolkit REST
API, no Firebase/Flutter client SDK involved) and skips on its own if that
isn't set yet, without blocking the other three.
"""
import uuid

import httpx
import pytest
from fastapi.testclient import TestClient

from app.core.config import get_settings
from app.core.firebase import get_firestore_client, init_firebase
from app.main import app

settings = get_settings()

pytestmark = pytest.mark.skipif(
    not settings.firebase_configured,
    reason="Firebase not configured — set FIREBASE_PROJECT_ID and GOOGLE_APPLICATION_CREDENTIALS in backend/.env",
)


def test_firebase_initializes() -> None:
    app_instance = init_firebase()
    assert app_instance is not None
    assert app_instance.project_id == settings.firebase_project_id


def test_firestore_read_write_roundtrip() -> None:
    db = get_firestore_client()
    doc_ref = db.collection("_pytest_smoke").document(f"pytest-{uuid.uuid4()}")
    doc_ref.set({"hello": "SmaranSaathi", "n": 1})
    try:
        snapshot = doc_ref.get()
        assert snapshot.exists
        assert snapshot.to_dict()["hello"] == "SmaranSaathi"
    finally:
        doc_ref.delete()


def test_unauthorized_request_rejected() -> None:
    client = TestClient(app)

    no_header = client.get("/api/v1/patients")
    assert no_header.status_code == 401
    assert no_header.json()["error"]["code"] == "unauthorized"

    garbage_token = client.get("/api/v1/patients", headers={"Authorization": "Bearer not-a-real-token"})
    assert garbage_token.status_code == 401
    assert garbage_token.json()["error"]["code"] == "unauthorized"


@pytest.mark.skipif(
    not settings.firebase_web_api_key,
    reason="FIREBASE_WEB_API_KEY not set — needed to mint a real ID token for this test",
)
def test_authenticated_request_creates_and_reads_through_firestore() -> None:
    from firebase_admin import auth as firebase_auth

    init_firebase()
    email = f"pytest-{uuid.uuid4().hex[:12]}@example.com"
    password = "Pytest!" + uuid.uuid4().hex[:16]
    user = firebase_auth.create_user(email=email, password=password)
    db = get_firestore_client()
    patient_id = None

    try:
        token_response = httpx.post(
            "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword",
            params={"key": settings.firebase_web_api_key},
            json={"email": email, "password": password, "returnSecureToken": True},
            timeout=15,
        )
        token_response.raise_for_status()
        id_token = token_response.json()["idToken"]
        headers = {"Authorization": f"Bearer {id_token}"}

        client = TestClient(app)

        # Authenticated request succeeds.
        listing = client.get("/api/v1/patients", headers=headers)
        assert listing.status_code == 200

        # ...and actually writes to real Firestore through the FastAPI route,
        # not just via a direct SDK call.
        create = client.post(
            "/api/v1/patients",
            headers=headers,
            json={
                "name": "Integration Test Aama",
                "shortName": "Aama",
                "age": 72,
                "location": "Jorhat, Assam",
                "language": "Assamese",
                "occupation": "Weaver",
                "favouriteActivity": "Weaving",
                "favouriteFood": "Pitha",
                "tradition": "Bihu",
                "portraitScene": "weaver",
            },
        )
        assert create.status_code == 201
        patient_id = create.json()["id"]

        doc = db.collection("patients").document(patient_id).get()
        assert doc.exists
        assert doc.to_dict()["shortName"] == "Aama"
    finally:
        if patient_id:
            db.collection("patients").document(patient_id).delete()
        firebase_auth.delete_user(user.uid)


@pytest.mark.skipif(
    not settings.firebase_web_api_key,
    reason="FIREBASE_WEB_API_KEY not set — needed to mint real ID tokens for this test",
)
def test_declared_role_round_trips_through_a_real_token_refresh() -> None:
    """The exact chain `POST /api/v1/auth/role` exists for: a user signs in
    with no role claim yet, declares a role, and — only after re-authenticating
    (the same "forceRefresh" a real client does) — `/auth/me` reflects it.
    Proves the self-declared-role endpoint actually sets a real Firebase
    custom claim, not just a database row somewhere."""
    from firebase_admin import auth as firebase_auth

    init_firebase()
    email = f"pytest-{uuid.uuid4().hex[:12]}@example.com"
    password = "Pytest!" + uuid.uuid4().hex[:16]
    user = firebase_auth.create_user(email=email, password=password)
    client = TestClient(app)

    def _sign_in() -> str:
        response = httpx.post(
            "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword",
            params={"key": settings.firebase_web_api_key},
            json={"email": email, "password": password, "returnSecureToken": True},
            timeout=15,
        )
        response.raise_for_status()
        return response.json()["idToken"]

    try:
        first_token = _sign_in()
        before = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {first_token}"})
        assert before.status_code == 200
        assert before.json()["role"] == "caregiver"  # default when no claim is set yet

        set_role = client.post(
            "/api/v1/auth/role",
            headers={"Authorization": f"Bearer {first_token}"},
            json={"role": "doctor"},
        )
        assert set_role.status_code == 200
        assert set_role.json()["role"] == "doctor"

        # A stale (already-issued) token still carries the old claims — this
        # is expected Firebase behaviour, not a bug, which is exactly why
        # FirebaseAuthService.declareRole() force-refreshes afterward.
        fresh_token = _sign_in()
        after = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {fresh_token}"})
        assert after.status_code == 200
        assert after.json()["role"] == "doctor"
    finally:
        firebase_auth.delete_user(user.uid)


def test_sync_operation_reaches_firestore_and_is_idempotent() -> None:
    """The Phase 3 checklist, steps 5-8, for real: FastAPI receives a synced
    operation, Firestore stores it under the operation's own id, the
    sync_operations ledger records it as applied, and resending the exact
    same operation does not create a second document."""
    from app.core.device_auth import mint_device_token

    init_firebase()
    db = get_firestore_client()
    client = TestClient(app)

    patient_id = f"pytest-patient-{uuid.uuid4().hex[:10]}"
    operation_id = f"pytest-op-{uuid.uuid4().hex[:10]}"
    _, token, _ = mint_device_token()
    headers = {"Authorization": f"Bearer {token}"}
    body = {
        "operationId": operation_id,
        "kind": "gameSession",
        "createdAtMillis": 1234567890000,
        "payload": {
            "patientId": patient_id,
            "gameId": "procedure",
            "level": 2,
            "nextLevel": 3,
            "accuracy": 92.0,
            "focus": 88.0,
            "memory": 90.0,
            "hintsUsed": 0,
            "mistakes": 1,
            "seconds": 38,
            "completed": True,
            "overall": 90,
            "timeLabel": "3:14 PM",
        },
    }

    try:
        first = client.post("/api/v1/sync/operations", json=body, headers=headers)
        assert first.status_code == 200
        assert first.json()["status"] == "synced"

        session_doc = (
            db.collection("patients").document(patient_id).collection("sessions").document(operation_id).get()
        )
        assert session_doc.exists
        assert session_doc.to_dict()["level"] == 2

        ledger_doc = db.collection("sync_operations").document(operation_id).get()
        assert ledger_doc.exists
        assert ledger_doc.to_dict()["patientId"] == patient_id

        # Resend the identical operation — must not duplicate.
        second = client.post("/api/v1/sync/operations", json=body, headers=headers)
        assert second.status_code == 200
        assert second.json()["status"] == "duplicate"

        remaining_sessions = list(
            db.collection("patients").document(patient_id).collection("sessions").stream()
        )
        assert len(remaining_sessions) == 1
    finally:
        db.collection("patients").document(patient_id).collection("sessions").document(operation_id).delete()
        db.collection("sync_operations").document(operation_id).delete()
