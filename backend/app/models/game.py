"""Mirrors frontend/lib/core/models/game.dart.

`GameDefinition` (name/tagline/colours/scene) is static UI catalogue content
that lives in the Flutter app's `MockData`, not user-generated data, so it is
deliberately not modelled here — the backend only needs to know about the
sessions a patient actually plays.
"""
from datetime import datetime
from enum import Enum

from pydantic import Field

from .common import APIModel


class GameId(str, Enum):
    procedure = "procedure"
    story = "story"
    familiar_place = "familiarPlace"
    melody = "melody"
    weaves = "weaves"
    memory_cards = "memoryCards"
    village_market = "villageMarket"
    mood_canvas = "moodCanvas"


class CognitiveDomain(str, Enum):
    memory = "memory"
    attention = "attention"
    reasoning = "reasoning"
    spatial = "spatial"
    auditory = "auditory"
    procedural = "procedural"


class DifficultyDirection(str, Enum):
    increase = "increase"
    maintain = "maintain"
    decrease = "decrease"


class GamePerformance(APIModel):
    accuracy: float
    focus: float
    memory: float
    hints_used: int
    mistakes: int
    seconds: int
    completed: bool
    attempts: int = 0
    correct: int = 0
    response_millis: int = 0


class GameSession(APIModel):
    game_id: GameId
    day_offset: int = 0
    level: int
    performance: GamePerformance
    time_label: str
    played_at: datetime = Field(default_factory=datetime.utcnow)


class AdaptiveDecision(APIModel):
    direction: DifficultyDirection
    next_level: int
    reason: str
    signals: list[str] = []
