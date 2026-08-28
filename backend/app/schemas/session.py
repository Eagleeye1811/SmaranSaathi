from app.models.common import APIModel
from app.models.game import GameId, GamePerformance


class GameSessionCreate(APIModel):
    patient_id: str
    game_id: GameId
    level: int
    performance: GamePerformance
    time_label: str


class GameSessionResponse(APIModel):
    id: str
    patient_id: str
    game_id: GameId
    level: int
    performance: GamePerformance
    time_label: str
