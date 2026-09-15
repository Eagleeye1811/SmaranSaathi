from fastapi import APIRouter

from . import (
    alerts,
    analytics,
    auth,
    caregivers,
    chat,
    daily,
    doctor_connections,
    health,
    insights,
    pairing,
    patients,
    reminders,
    sessions,
    sync,
    telehealth,
    weekly_reports,
)

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(auth.router)
api_router.include_router(patients.router)
api_router.include_router(sessions.router)
api_router.include_router(analytics.router)
api_router.include_router(daily.router)
api_router.include_router(reminders.router)
api_router.include_router(caregivers.router)
api_router.include_router(doctor_connections.router)
api_router.include_router(alerts.router)
api_router.include_router(insights.router)
api_router.include_router(pairing.router)
api_router.include_router(sync.router)
api_router.include_router(telehealth.router)
api_router.include_router(chat.router)
api_router.include_router(weekly_reports.router)
