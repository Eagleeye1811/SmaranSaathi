"""Tests for Telehealth and AI Clinical Scribe endpoints."""


def test_initiate_call(client):
    res = client.post(
        "/api/v1/telehealth/call/initiate",
        json={
            "doctor_id": "doc_001",
            "patient_id": "pat_001",
            "patient_name": "Ramesh Kumar",
            "caller_role": "doctor",
        },
    )
    assert res.status_code == 200
    data = res.json()
    assert "session_id" in data
    assert "room_name" in data
    assert data["room_name"] == "room_doc_001_pat_001"


def test_summarize_call(client):
    transcript = (
        "Doctor: Namaste Ramesh ji. How has your sleep been this week? "
        "Patient: Doctor sahab, I wake up around 3 AM and feel a bit restless. "
        "Doctor: I see. Let's adjust your evening routine. Take a warm cup of milk and continue your memory games."
    )
    res = client.post(
        "/api/v1/telehealth/call/summarize",
        json={
            "doctor_id": "doc_001",
            "patient_id": "pat_001",
            "patient_name": "Ramesh Kumar",
            "transcript": transcript,
        },
    )
    assert res.status_code == 200
    data = res.json()
    assert "soap_note" in data
    assert "patient_summary" in data
    assert "subjective" in data["soap_note"]
    assert "plan" in data["soap_note"]
    assert len(data["patient_summary"]["key_takeaways"]) > 0


def test_persistent_chat(client):
    # Send message
    res = client.post(
        "/api/v1/chat/messages",
        json={
            "doctor_id": "doc_001",
            "patient_id": "pat_001",
            "sender_id": "doc_001",
            "sender_role": "doctor",
            "sender_name": "Dr. Sharma",
            "content": "Please remind Ramesh ji about the morning walking routine.",
        },
    )
    assert res.status_code == 200
    data = res.json()
    assert data["content"] == "Please remind Ramesh ji about the morning walking routine."

    # Fetch messages
    res2 = client.get("/api/v1/chat/doc_001/pat_001/messages")
    assert res2.status_code == 200
    messages = res2.json()
    assert len(messages) >= 1
