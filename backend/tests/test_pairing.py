"""The patient-device handshake.

What matters here is not the happy path but the boundary: only the caregiver
who claimed a username may approve a device asking to use it.
"""
import pytest


def _device_token(client) -> str:
    r = client.post("/api/v1/auth/device", json={"deviceId": "test-device"})
    assert r.status_code == 200
    return r.json()["token"]


@pytest.fixture()
def auth(client):
    return {"Authorization": f"Bearer {_device_token(client)}"}


def _claim(client, auth, username="aama", patient="p_1", uid="uid-priya"):
    return client.post(
        "/api/v1/pairing/claim",
        headers=auth,
        json={
            "username": username,
            "patientId": patient,
            "caregiverUid": uid,
            "patientName": "Aama Devi",
        },
    )


def test_a_username_is_claimed_once_and_is_case_insensitive(client, auth):
    first = _claim(client, auth, username="AamaDevi")
    assert first.status_code == 200
    assert first.json()["username"] == "aamadevi"

    # The same caregiver re-claiming is a retry, not a collision — a double
    # tap on a slow connection must not report the name as taken.
    again = _claim(client, auth, username="aamadevi")
    assert again.status_code == 200
    assert again.json()["alreadyClaimed"] is True

    # A different caregiver cannot take it.
    other = _claim(client, auth, username="aamadevi", patient="p_2", uid="uid-other")
    assert other.status_code == 409


def test_only_the_claiming_caregiver_can_approve(client, auth):
    _claim(client, auth, username="bhaskar", patient="p_9", uid="uid-real")

    made = client.post(
        "/api/v1/pairing/request",
        headers=auth,
        json={"username": "bhaskar", "deviceId": "dev-1", "deviceLabel": "His phone"},
    )
    assert made.status_code == 201
    request_id = made.json()["requestId"]

    # Someone else holding the request id gets nowhere.
    refused = client.post(
        "/api/v1/pairing/respond",
        headers=auth,
        json={"requestId": request_id, "caregiverUid": "uid-imposter", "approve": True},
    )
    assert refused.status_code == 403

    ok = client.post(
        "/api/v1/pairing/respond",
        headers=auth,
        json={"requestId": request_id, "caregiverUid": "uid-real", "approve": True},
    )
    assert ok.status_code == 200
    assert ok.json()["status"] == "approved"

    # And the patient's device sees it.
    seen = client.get(f"/api/v1/pairing/status?requestId={request_id}", headers=auth)
    assert seen.json()["status"] == "approved"


def test_an_unknown_username_cannot_be_requested(client, auth):
    r = client.post(
        "/api/v1/pairing/request",
        headers=auth,
        json={"username": "nobody-here", "deviceId": "dev-x"},
    )
    assert r.status_code == 404


def test_pairing_needs_a_device_token(client):
    assert client.get("/api/v1/pairing/requests?caregiverUid=uid-real").status_code == 401


def test_a_caregiver_can_recover_their_claim_after_forgetting_it(client, auth):
    # This is what a device signing back in relies on: its own local record
    # of "we already claimed a username" is not durable (see
    # `AppState.signOutAccount`), so it has to be able to ask the backend
    # instead of silently assuming nothing was ever set up.
    _claim(client, auth, username="chitra", patient="p_5", uid="uid-returning")

    mine = client.get("/api/v1/pairing/claims?caregiverUid=uid-returning", headers=auth)
    assert mine.status_code == 200
    usernames = [c["username"] for c in mine.json()]
    assert usernames == ["chitra"]

    nobody = client.get("/api/v1/pairing/claims?caregiverUid=uid-nobody", headers=auth)
    assert nobody.status_code == 200
    assert nobody.json() == []
