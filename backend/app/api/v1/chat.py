"""Persistent 1-on-1 Doctor-Patient Messaging Router & WebSocket."""

import json
import logging
import uuid
from datetime import datetime
from typing import Dict, List, Set
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.schemas.telehealth import ChatMessageSchema, SendMessageRequest

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/chat", tags=["chat"])

# In-memory message store: thread_key (e.g. "doc_001_pat_001") -> List[ChatMessageSchema]
chat_threads: Dict[str, List[ChatMessageSchema]] = {}


class ChatSocketManager:
    def __init__(self):
        # thread_key -> Set[WebSocket]
        self.active_connections: Dict[str, Set[WebSocket]] = {}

    async def connect(self, thread_key: str, websocket: WebSocket):
        await websocket.accept()
        if thread_key not in self.active_connections:
            self.active_connections[thread_key] = set()
        self.active_connections[thread_key].add(websocket)
        logger.info(f"[Chat] Connected to thread {thread_key}. Active connections: {len(self.active_connections[thread_key])}")

    def disconnect(self, thread_key: str, websocket: WebSocket):
        if thread_key in self.active_connections and websocket in self.active_connections[thread_key]:
            self.active_connections[thread_key].remove(websocket)
            if not self.active_connections[thread_key]:
                del self.active_connections[thread_key]
            logger.info(f"[Chat] Disconnected from thread {thread_key}")

    async def broadcast_message(self, thread_key: str, message: ChatMessageSchema):
        if thread_key in self.active_connections:
            payload = message.model_dump(mode="json")
            for connection in list(self.active_connections[thread_key]):
                try:
                    await connection.send_text(json.dumps(payload))
                except Exception as e:
                    logger.warning(f"[Chat] Error broadcasting message: {e}")


chat_socket_manager = ChatSocketManager()


def _get_thread_key(doctor_id: str, patient_id: str) -> str:
    return f"{doctor_id}_{patient_id}"


@router.get("/{doctor_id}/{patient_id}/messages", response_model=List[ChatMessageSchema])
async def get_messages(doctor_id: str, patient_id: str):
    """Retrieve all persistent chat messages between a doctor and patient."""
    key = _get_thread_key(doctor_id, patient_id)
    if key not in chat_threads:
        # Seed initial greeting if empty
        chat_threads[key] = [
            ChatMessageSchema(
                id=f"msg_{uuid.uuid4().hex[:6]}",
                doctor_id=doctor_id,
                patient_id=patient_id,
                sender_id=doctor_id,
                sender_role="doctor",
                sender_name="Dr. Sharma",
                content="Namaste Ramesh ji. I am reviewing your cognitive session scores. How are you feeling today?",
                timestamp=datetime.utcnow(),
                is_read=True,
            ),
            ChatMessageSchema(
                id=f"msg_{uuid.uuid4().hex[:6]}",
                doctor_id=doctor_id,
                patient_id=patient_id,
                sender_id=patient_id,
                sender_role="patient",
                sender_name="Ramesh Kumar (Caregiver)",
                content="Namaste Doctor Sahab. Father is doing well. We played the familiar faces game this morning.",
                timestamp=datetime.utcnow(),
                is_read=True,
            ),
        ]
    return chat_threads.get(key, [])


@router.post("/messages", response_model=ChatMessageSchema)
async def send_message(req: SendMessageRequest):
    """Send a persistent text message."""
    key = _get_thread_key(req.doctor_id, req.patient_id)
    if key not in chat_threads:
        chat_threads[key] = []

    new_msg = ChatMessageSchema(
        id=f"msg_{uuid.uuid4().hex[:8]}",
        doctor_id=req.doctor_id,
        patient_id=req.patient_id,
        sender_id=req.sender_id,
        sender_role=req.sender_role,
        sender_name=req.sender_name,
        content=req.content,
        timestamp=datetime.utcnow(),
        is_read=False,
    )
    chat_threads[key].append(new_msg)

    # Broadcast to any active WebSocket listeners
    await chat_socket_manager.broadcast_message(key, new_msg)
    return new_msg


@router.websocket("/ws/{doctor_id}/{patient_id}")
async def chat_websocket_endpoint(websocket: WebSocket, doctor_id: str, patient_id: str):
    """Live WebSocket channel for instant messaging."""
    thread_key = _get_thread_key(doctor_id, patient_id)
    await chat_socket_manager.connect(thread_key, websocket)
    try:
        while True:
            data = await websocket.receive_text()
            try:
                payload = json.loads(data)
                req = SendMessageRequest(
                    doctor_id=doctor_id,
                    patient_id=patient_id,
                    sender_id=payload.get("sender_id", doctor_id),
                    sender_role=payload.get("sender_role", "doctor"),
                    sender_name=payload.get("sender_name", "User"),
                    content=payload.get("content", ""),
                )
                await send_message(req)
            except Exception as e:
                logger.error(f"[Chat] Error processing websocket message: {e}")
    except WebSocketDisconnect:
        chat_socket_manager.disconnect(thread_key, websocket)
    except Exception as e:
        logger.error(f"[Chat] Error in websocket connection: {e}")
        chat_socket_manager.disconnect(thread_key, websocket)
