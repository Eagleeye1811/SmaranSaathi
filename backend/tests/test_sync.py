"""Unit-level coverage of /api/v1/sync/operations using the in-memory
repositories (via `authed_client`'s overrides) — proves the dispatch and
idempotency logic itself, independent of whichever backing store is
configured. The real end-to-end path (Firestore-backed, real device token)
is covered in `test_firebase_integration.py`."""
import time

_PATIENT_ID = "patient-1"


def _game_session_body(operation_id: str) -> dict:
    return {
        "operationId": operation_id,
        "kind": "gameSession",
        "createdAtMillis": int(time.time() * 1000),
        "payload": {
            "patientId": _PATIENT_ID,
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


def test_sync_requires_device_token(client) -> None:
    response = client.post("/api/v1/sync/operations", json=_game_session_body("op-no-auth"))
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "unauthorized"


def test_sync_game_session_is_idempotent(authed_client, device_headers) -> None:
    body = _game_session_body("op-game-session-1")

    first = authed_client.post("/api/v1/sync/operations", json=body, headers=device_headers)
    assert first.status_code == 200
    assert first.json()["status"] == "synced"

    second = authed_client.post("/api/v1/sync/operations", json=body, headers=device_headers)
    assert second.status_code == 200
    assert second.json()["status"] == "duplicate"
    # Same synced_at as the first application — nothing was re-applied.
    assert second.json()["syncedAtMillis"] == first.json()["syncedAtMillis"]

    sessions = authed_client.get(
        "/api/v1/sessions", params={"patientId": _PATIENT_ID}, headers=device_headers
    )
    assert sessions.status_code == 200
    assert len(sessions.json()) == 1


def test_sync_mood_check_in(authed_client, device_headers) -> None:
    body = {
        "operationId": "op-mood-1",
        "kind": "moodCheckIn",
        "createdAtMillis": int(time.time() * 1000),
        "payload": {"patientId": _PATIENT_ID, "mood": "good", "at": "9:00 AM"},
    }
    response = authed_client.post("/api/v1/sync/operations", json=body, headers=device_headers)
    assert response.status_code == 200
    assert response.json()["status"] == "synced"


def test_sync_unknown_kind_still_requires_patient_id(authed_client, device_headers) -> None:
    body = {
        "operationId": "op-bad-1",
        "kind": "reflection",
        "createdAtMillis": int(time.time() * 1000),
        "payload": {"at": "9:00 AM"},  # missing patientId
    }
    response = authed_client.post("/api/v1/sync/operations", json=body, headers=device_headers)
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_device_token_issuance(authed_client) -> None:
    """Uses `authed_client` purely for its in-memory repository overrides
    (so this never touches real Firestore) — the device token itself is
    real: minted and verified through the actual JWT path, not mocked."""
    response = authed_client.post("/api/v1/auth/device", json={})
    assert response.status_code == 200
    body = response.json()
    assert body["token"]
    assert body["deviceId"]
    assert body["expiresAtMillis"] > int(time.time() * 1000)

    # The freshly-minted token actually authorizes a sync request.
    authed = authed_client.post(
        "/api/v1/sync/operations",
        headers={"Authorization": f"Bearer {body['token']}"},
        json=_game_session_body("op-device-token-1"),
    )
    assert authed.status_code == 200
    assert authed.json()["status"] == "synced"


def test_device_token_rejects_tampered_token(authed_client) -> None:
    response = authed_client.post(
        "/api/v1/sync/operations",
        headers={"Authorization": "Bearer this.is.not-a-real-jwt"},
        json=_game_session_body("op-tampered-1"),
    )
    assert response.status_code == 401


def test_sync_assessment_step_is_stored(authed_client, device_headers) -> None:
    """The structured intake reaches the backend as one operation per step, so
    a questionnaire abandoned half way still syncs what was answered."""
    body = {
        "operationId": "op-assessment-1",
        "kind": "assessmentUpdate",
        "createdAtMillis": int(time.time() * 1000),
        "payload": {
            "patientId": _PATIENT_ID,
            "step": "function",
            "levels": {"fn_money": "needsHelp", "fn_meds": "independent"},
        },
    }

    first = authed_client.post("/api/v1/sync/operations", json=body, headers=device_headers)
    assert first.status_code == 200
    assert first.json()["status"] == "synced"

    # Replaying it is a duplicate, exactly like every other operation kind.
    second = authed_client.post("/api/v1/sync/operations", json=body, headers=device_headers)
    assert second.json()["status"] == "duplicate"


def test_sync_baseline_capture(authed_client, device_headers) -> None:
    body = {
        "operationId": "op-baseline-1",
        "kind": "baselineCaptured",
        "createdAtMillis": int(time.time() * 1000),
        "payload": {
            "patientId": _PATIENT_ID,
            "scores": {"memory": 82.5, "attention": 88.0},
            "capturedAt": "2026-06-01T10:00:00.000",
            "sessionCount": 12,
        },
    }

    response = authed_client.post("/api/v1/sync/operations", json=body, headers=device_headers)
    assert response.status_code == 200
    assert response.json()["status"] == "synced"


def test_sync_rejects_an_unrecognised_kind(authed_client, device_headers) -> None:
    """A kind the backend does not know is a client/server version mismatch,
    and must fail loudly rather than being silently swallowed."""
    body = {
        "operationId": "op-bogus-1",
        "kind": "somethingElse",
        "createdAtMillis": int(time.time() * 1000),
        "payload": {"patientId": _PATIENT_ID},
    }

    response = authed_client.post("/api/v1/sync/operations", json=body, headers=device_headers)
    assert response.status_code == 422
