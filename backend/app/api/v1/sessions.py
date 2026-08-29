from typing import List

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_game_session_repository
from app.core.security import get_current_user
from app.repositories.base import GameSessionRepository
from app.schemas.session import GameSessionCreate, GameSessionResponse
from app.services.session_service import SessionService

router = APIRouter(prefix="/sessions", tags=["game sessions"], dependencies=[Depends(get_current_user)])


def get_service(repository: GameSessionRepository = Depends(get_game_session_repository)) -> SessionService:
    return SessionService(repository)


@router.post("", response_model=GameSessionResponse, status_code=201)
async def record_session(
    data: GameSessionCreate, service: SessionService = Depends(get_service)
) -> GameSessionResponse:
    session_id, session = await service.record(data)
    return GameSessionResponse(id=session_id, patient_id=data.patient_id, **session.model_dump(by_alias=False))


@router.get("", response_model=List[GameSessionResponse])
async def list_sessions(
    patient_id: str = Query(..., alias="patientId"), service: SessionService = Depends(get_service)
) -> List[GameSessionResponse]:
    sessions = await service.history(patient_id)
    return [
        GameSessionResponse(id="", patient_id=patient_id, **s.model_dump(by_alias=False)) for s in sessions
    ]
