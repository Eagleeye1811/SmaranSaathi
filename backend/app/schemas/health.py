from app.models.common import APIModel


class HealthResponse(APIModel):
    status: str = "ok"
    service: str
    version: str
    environment: str
    firebase_configured: bool = False
