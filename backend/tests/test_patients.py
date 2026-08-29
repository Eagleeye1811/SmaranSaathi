"""Unit-level coverage of the patients router's business logic, using the
`authed_client` fixture (auth dependency overridden) so these stay fast and
hermetic — real Firebase-token auth is covered end-to-end in
`test_firebase_integration.py`."""

_NEW_PATIENT = {
    "name": "Test Aama",
    "shortName": "Aama",
    "age": 72,
    "location": "Jorhat, Assam",
    "language": "Assamese",
    "occupation": "Weaver",
    "favouriteActivity": "Weaving",
    "favouriteFood": "Pitha",
    "tradition": "Bihu",
    "portraitScene": "weaver",
}


def test_patients_require_auth(client) -> None:
    response = client.get("/api/v1/patients")
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "unauthorized"


def test_patient_lifecycle(authed_client) -> None:
    create = authed_client.post("/api/v1/patients", json=_NEW_PATIENT)
    assert create.status_code == 201
    patient_id = create.json()["id"]

    fetched = authed_client.get(f"/api/v1/patients/{patient_id}")
    assert fetched.status_code == 200
    assert fetched.json()["shortName"] == "Aama"

    updated = authed_client.put(f"/api/v1/patients/{patient_id}", json={"age": 73})
    assert updated.status_code == 200
    assert updated.json()["age"] == 73


def test_patient_not_found(authed_client) -> None:
    response = authed_client.get("/api/v1/patients/does-not-exist")
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"
