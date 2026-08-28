"""Single place that decides which repository implementation is active.

Firestore implementations are used automatically once `.env` configures
Firebase (`FIREBASE_PROJECT_ID` + `GOOGLE_APPLICATION_CREDENTIALS`); otherwise
everything falls back to the in-memory set from Phase 1. No router or
service code needs to change either way.
"""
from functools import lru_cache

from app.core.config import get_settings
from app.repositories.base import (
    AnalyticsRepository,
    CaregiverLinkRepository,
    DailyRepository,
    GameSessionRepository,
    PatientRepository,
    ReminderRepository,
    SyncLedgerRepository,
)
from app.repositories.memory.analytics import InMemoryAnalyticsRepository
from app.repositories.memory.caregivers import InMemoryCaregiverLinkRepository
from app.repositories.memory.daily import InMemoryDailyRepository
from app.repositories.memory.patients import InMemoryPatientRepository
from app.repositories.memory.reminders import InMemoryReminderRepository
from app.repositories.memory.sessions import InMemoryGameSessionRepository
from app.repositories.memory.sync_ledger import InMemorySyncLedgerRepository


@lru_cache
def get_patient_repository() -> PatientRepository:
    if get_settings().firebase_configured:
        from app.repositories.firestore.patients import FirestorePatientRepository

        return FirestorePatientRepository()
    return InMemoryPatientRepository()


@lru_cache
def get_game_session_repository() -> GameSessionRepository:
    if get_settings().firebase_configured:
        from app.repositories.firestore.sessions import FirestoreGameSessionRepository

        return FirestoreGameSessionRepository()
    return InMemoryGameSessionRepository()


@lru_cache
def get_analytics_repository() -> AnalyticsRepository:
    if get_settings().firebase_configured:
        from app.repositories.firestore.analytics import FirestoreAnalyticsRepository

        return FirestoreAnalyticsRepository()
    return InMemoryAnalyticsRepository()


@lru_cache
def get_daily_repository() -> DailyRepository:
    if get_settings().firebase_configured:
        from app.repositories.firestore.daily import FirestoreDailyRepository

        return FirestoreDailyRepository()
    return InMemoryDailyRepository()


@lru_cache
def get_reminder_repository() -> ReminderRepository:
    if get_settings().firebase_configured:
        from app.repositories.firestore.reminders import FirestoreReminderRepository

        return FirestoreReminderRepository()
    return InMemoryReminderRepository()


@lru_cache
def get_caregiver_link_repository() -> CaregiverLinkRepository:
    if get_settings().firebase_configured:
        from app.repositories.firestore.caregivers import FirestoreCaregiverLinkRepository

        return FirestoreCaregiverLinkRepository()
    return InMemoryCaregiverLinkRepository()


@lru_cache
def get_sync_ledger_repository() -> SyncLedgerRepository:
    if get_settings().firebase_configured:
        from app.repositories.firestore.sync_ledger import FirestoreSyncLedgerRepository

        return FirestoreSyncLedgerRepository()
    return InMemorySyncLedgerRepository()
