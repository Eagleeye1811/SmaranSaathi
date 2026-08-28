from app.core.config import get_settings


def test_root_health(client) -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_versioned_health(client) -> None:
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["firebaseConfigured"] == get_settings().firebase_configured


def test_insights_not_implemented(client) -> None:
    response = client.get("/api/v1/insights/some-patient")
    assert response.status_code == 501
    assert response.json()["error"]["code"] == "not_implemented"
