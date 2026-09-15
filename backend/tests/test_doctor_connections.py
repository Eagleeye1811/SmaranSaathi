"""Doctor connections: a real, backend-persisted caregiver↔doctor handshake.

What matters here is not the happy path but the boundary: only the invited
doctor's own authenticated identity may accept their invite — never a
client-supplied id, unlike pairing (which has no better option, since a
patient device has no account). And the caseload numbers must come from
real, seeded game sessions, not be fabricated.
"""
import asyncio
from datetime import datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from app.core.dependencies import (
    get_doctor_connection_request_repository,
    get_doctor_patient_link_repository,
    get_doctor_profile_repository,
    get_game_session_repository,
    get_patient_repository,
)
from app.core.security import get_current_user
from app.main import app
from app.models.game import GameId, GamePerformance, GameSession
from app.models.patient import Patient
from app.models.user import User, UserRole
from app.repositories.memory.doctors import (
    InMemoryDoctorPatientLinkRepository,
    InMemoryDoctorConnectionRequestRepository,
    InMemoryDoctorProfileRepository,
)
from app.repositories.memory.patients import InMemoryPatientRepository
from app.repositories.memory.sessions import InMemoryGameSessionRepository


@pytest.fixture()
def repos():
    """Fresh in-memory repositories per test — hermetic, never touches real
    Firestore even when backend/.env configures it."""
    store = {
        "profiles": InMemoryDoctorProfileRepository(),
        "links": InMemoryDoctorPatientLinkRepository(),
        "requests": InMemoryDoctorConnectionRequestRepository(),
        "patients": InMemoryPatientRepository(),
        "sessions": InMemoryGameSessionRepository(),
    }
    app.dependency_overrides[get_doctor_profile_repository] = lambda: store["profiles"]
    app.dependency_overrides[get_doctor_patient_link_repository] = lambda: store["links"]
    app.dependency_overrides[get_doctor_connection_request_repository] = lambda: store["requests"]
    app.dependency_overrides[get_patient_repository] = lambda: store["patients"]
    app.dependency_overrides[get_game_session_repository] = lambda: store["sessions"]

    yield store

    for dep in (
        get_doctor_profile_repository,
        get_doctor_patient_link_repository,
        get_doctor_connection_request_repository,
        get_patient_repository,
        get_game_session_repository,
        get_current_user,
    ):
        app.dependency_overrides.pop(dep, None)


@pytest.fixture()
def client(repos) -> TestClient:
    return TestClient(app)


def _as(uid: str, role: UserRole = UserRole.caregiver) -> None:
    """Switches the authenticated identity for subsequent requests on this
    client — a fresh Firebase account per call, exactly as real caregiver
    and doctor accounts are."""
    app.dependency_overrides[get_current_user] = lambda: User(id=uid, email=None, display_name=None, role=role)


def test_a_doctor_becomes_findable_after_signing_in_once(client):
    _as("doc-priya", UserRole.doctor)
    upserted = client.post(
        "/api/v1/doctors/profile",
        json={"name": "Dr. Priya Rao", "specialization": "Neurologist", "hospital": "Guwahati Memory Clinic"},
    )
    assert upserted.status_code == 200
    assert upserted.json()["id"] == "doc-priya"

    _as("some-caregiver")
    listing = client.get("/api/v1/doctors/directory")
    assert listing.status_code == 200
    names = [d["name"] for d in listing.json()]
    assert "Dr. Priya Rao" in names


def test_invite_accept_creates_a_real_connection(client):
    _as("doc-hazarika", UserRole.doctor)
    client.post("/api/v1/doctors/profile", json={"name": "Dr. Hazarika"})

    _as("cg-1")
    invited = client.post(
        "/api/v1/doctors/connections/invite",
        json={"doctorUid": "doc-hazarika", "patientId": "p_1", "patientName": "Ramesh", "patientAge": 70},
    )
    assert invited.status_code == 201
    request_id = invited.json()["requestId"]
    assert invited.json()["status"] == "pending"

    # The doctor sees it waiting.
    _as("doc-hazarika", UserRole.doctor)
    pending = client.get("/api/v1/doctors/connections/requests")
    assert pending.status_code == 200
    assert [r["requestId"] for r in pending.json()] == [request_id]

    accepted = client.post(
        "/api/v1/doctors/connections/respond", json={"requestId": request_id, "approve": True}
    )
    assert accepted.status_code == 200
    assert accepted.json()["status"] == "approved"

    # Now durable: the caregiver's device can find the connected doctor.
    for_patient = client.get("/api/v1/doctors/connections/for-patient?patientId=p_1")
    assert for_patient.status_code == 200
    assert for_patient.json()["doctorUid"] == "doc-hazarika"

    # And the request queue is empty for the doctor again.
    still_pending = client.get("/api/v1/doctors/connections/requests")
    assert still_pending.json() == []


def test_decline_creates_no_connection(client):
    _as("doc-das", UserRole.doctor)
    client.post("/api/v1/doctors/profile", json={"name": "Dr. Das"})

    _as("cg-2")
    invited = client.post(
        "/api/v1/doctors/connections/invite", json={"doctorUid": "doc-das", "patientId": "p_2"}
    )
    request_id = invited.json()["requestId"]

    _as("doc-das", UserRole.doctor)
    declined = client.post(
        "/api/v1/doctors/connections/respond", json={"requestId": request_id, "approve": False}
    )
    assert declined.status_code == 200
    assert declined.json()["status"] == "declined"

    for_patient = client.get("/api/v1/doctors/connections/for-patient?patientId=p_2")
    assert for_patient.json() is None


def test_only_the_invited_doctor_can_accept(client):
    _as("doc-real", UserRole.doctor)
    client.post("/api/v1/doctors/profile", json={"name": "Dr. Real"})

    _as("cg-3")
    invited = client.post(
        "/api/v1/doctors/connections/invite", json={"doctorUid": "doc-real", "patientId": "p_3"}
    )
    request_id = invited.json()["requestId"]

    # A different doctor holding the request id gets nowhere — this is the
    # whole point: unlike pairing, we can actually verify identity here.
    _as("doc-imposter", UserRole.doctor)
    refused = client.post(
        "/api/v1/doctors/connections/respond", json={"requestId": request_id, "approve": True}
    )
    assert refused.status_code == 403

    _as("doc-real", UserRole.doctor)
    ok = client.post(
        "/api/v1/doctors/connections/respond", json={"requestId": request_id, "approve": True}
    )
    assert ok.status_code == 200
    assert ok.json()["status"] == "approved"


def test_doctor_connections_need_a_real_token(client):
    assert client.get("/api/v1/doctors/directory").status_code == 401


def test_caseload_scores_are_computed_from_real_sessions_not_fabricated(client, repos):
    async def _seed():
        await repos["patients"].create(
            Patient(
                id="p_4",
                name="Kamala Devi",
                short_name="Kamala",
                age=68,
                location="Jorhat",
                language="Assamese",
                occupation="Weaver",
                favourite_activity="Weaving",
                favourite_food="Khar",
                tradition="Assamese",
                portrait_scene="portrait_kamala",
            )
        )
        now = datetime.utcnow()
        for i in range(3):
            await repos["sessions"].add(
                f"op-{i}",
                "p_4",
                GameSession(
                    game_id=GameId.memory_cards,
                    level=2,
                    performance=GamePerformance(
                        accuracy=80, focus=70, memory=90, hints_used=0, mistakes=1, seconds=60, completed=True
                    ),
                    time_label="10:00 AM",
                    played_at=now - timedelta(days=i),
                ),
            )

    asyncio.run(_seed())

    _as("doc-kamala", UserRole.doctor)
    client.post("/api/v1/doctors/profile", json={"name": "Dr. For Kamala"})

    _as("cg-4")
    invited = client.post(
        "/api/v1/doctors/connections/invite", json={"doctorUid": "doc-kamala", "patientId": "p_4"}
    )
    request_id = invited.json()["requestId"]

    _as("doc-kamala", UserRole.doctor)
    client.post("/api/v1/doctors/connections/respond", json={"requestId": request_id, "approve": True})

    caseload = client.get("/api/v1/doctors/connections/caseload")
    assert caseload.status_code == 200
    rows = caseload.json()
    assert len(rows) == 1
    row = rows[0]
    assert row["id"] == "p_4"
    assert row["name"] == "Kamala Devi"
    # accuracy*0.5 + focus*0.25 + memory*0.25 = 80*.5+70*.25+90*.25 = 40+17.5+22.5 = 80
    assert row["score"] == 80
    assert row["profile"]["scores"]["memory"] == 80
    assert row["adherence"] > 0
    assert row["engagement"] > 0

    # A patient with no sessions at all must never be silently scored.
    _as("doc-empty", UserRole.doctor)
    client.post("/api/v1/doctors/profile", json={"name": "Dr. Empty"})
    _as("cg-5")
    await_invite = client.post(
        "/api/v1/doctors/connections/invite", json={"doctorUid": "doc-empty", "patientId": "p_5"}
    )
    _as("doc-empty", UserRole.doctor)
    client.post(
        "/api/v1/doctors/connections/respond",
        json={"requestId": await_invite.json()["requestId"], "approve": True},
    )

    async def _seed_empty_patient():
        await repos["patients"].create(
            Patient(
                id="p_5",
                name="Unscored Patient",
                short_name="Unscored",
                age=60,
                location="Jorhat",
                language="Assamese",
                occupation="",
                favourite_activity="",
                favourite_food="",
                tradition="",
                portrait_scene="portrait_default",
            )
        )

    asyncio.run(_seed_empty_patient())

    caseload2 = client.get("/api/v1/doctors/connections/caseload")
    empty_row = next(r for r in caseload2.json() if r["id"] == "p_5")
    assert empty_row["score"] == 0
    assert empty_row["profile"]["scores"] == {}


# ── The invite has to outlive the web process and the afternoon ────────────
#
# Both of these used to fail. The pending queue was a module-level dict with a
# 15-minute TTL, so on Render's free tier (which spins the web process down
# after ~15 minutes idle) a caregiver's invite was essentially never still
# there when the doctor next opened their app.


def test_an_invite_is_held_in_the_durable_store_not_in_process_memory(client, repos):
    """What actually makes an invite survive a restart: it is written to the
    injected repository (Firestore in production) rather than to a
    module-level dict. Asserting on the store is the honest check — a second
    TestClient would not restart the process, so it could not tell the two
    apart."""
    _as("doc-borah", UserRole.doctor)
    client.post("/api/v1/doctors/profile", json={"name": "Dr. Borah"})

    _as("cg-restart")
    invited = client.post(
        "/api/v1/doctors/connections/invite",
        json={"doctorUid": "doc-borah", "patientId": "acct_cg-restart", "patientName": "Abhinav"},
    )
    assert invited.status_code == 201
    request_id = invited.json()["requestId"]

    # The request is in the store the app was handed, which is the thing that
    # outlives the process — not in any module the process happens to hold.
    import asyncio

    stored = asyncio.run(repos["requests"].get(request_id))
    assert stored is not None
    assert stored.doctor_uid == "doc-borah"
    assert stored.status == "pending"

    fresh = TestClient(app)
    _as("doc-borah", UserRole.doctor)
    inbox = fresh.get("/api/v1/doctors/connections/requests")
    assert inbox.status_code == 200
    assert [r["requestId"] for r in inbox.json()] == [request_id]

    decided = fresh.post(
        "/api/v1/doctors/connections/respond",
        json={"requestId": request_id, "approve": True},
    )
    assert decided.status_code == 200
    assert decided.json()["status"] == "approved"


def test_an_invite_is_still_pending_the_next_morning(client, repos):
    """A doctor reads their inbox on their own schedule, not within fifteen
    minutes of the caregiver sending it."""
    import asyncio
    import time

    from app.schemas.doctor import DoctorConnectionRequest

    eight_hours_ago = int(time.time() * 1000) - 8 * 60 * 60 * 1000
    asyncio.run(
        repos["requests"].save(
            DoctorConnectionRequest(
                request_id="req-overnight",
                doctor_uid="doc-overnight",
                caregiver_uid="cg-overnight",
                patient_id="acct_cg-overnight",
                patient_name="Abhinav",
                status="pending",
                requested_at_millis=eight_hours_ago,
            )
        )
    )

    _as("doc-overnight", UserRole.doctor)
    inbox = client.get("/api/v1/doctors/connections/requests")
    assert inbox.status_code == 200
    assert [r["requestId"] for r in inbox.json()] == ["req-overnight"]
