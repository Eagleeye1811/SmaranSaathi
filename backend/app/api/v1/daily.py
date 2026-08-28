from typing import List

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_daily_repository
from app.core.security import get_current_user
from app.models.daily import JournalEntry
from app.repositories.base import DailyRepository
from app.schemas.daily import DailyResponse, JournalEntryCreate, MoodCheckInCreate
from app.services.daily_service import DailyService

router = APIRouter(prefix="/daily", tags=["mood & journal"], dependencies=[Depends(get_current_user)])


def get_service(repository: DailyRepository = Depends(get_daily_repository)) -> DailyService:
    return DailyService(repository)


@router.post("/mood", status_code=204)
async def check_in_mood(data: MoodCheckInCreate, service: DailyService = Depends(get_service)) -> None:
    await service.check_in_mood(data)


@router.post("/journal", response_model=JournalEntry, status_code=201)
async def add_journal_entry(
    data: JournalEntryCreate, service: DailyService = Depends(get_service)
) -> JournalEntry:
    return await service.add_journal_entry(data)


@router.get("", response_model=DailyResponse)
async def daily_snapshot(
    patient_id: str = Query(..., alias="patientId"), service: DailyService = Depends(get_service)
) -> DailyResponse:
    mood = await service.get_mood(patient_id)
    journal = await service.list_journal(patient_id)
    return DailyResponse(patient_id=patient_id, mood=mood, journal=journal)
