"""Mirrors frontend/lib/core/models/game.dart.

`GameDefinition` (name/tagline/colours/scene) is static UI catalogue content
that lives in the Flutter app's `MockData`, not user-generated data, so it is
deliberately not modelled here — the backend only needs to know about the
sessions a patient actually plays.
"""
from enum import Enum

from .common import APIModel


class GameId(str, Enum):
    procedure = "procedure"
    story = "story"
    familiar_place = "familiarPlace"
    melody = "melody"
    weaves = "weaves"
    memory_cards = "memoryCards"


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


class GameSession(APIModel):
    game_id: GameId
    day_offset: int = 0
    level: int
    performance: GamePerformance
    time_label: str


class AdaptiveDecision(APIModel):
    direction: DifficultyDirection
    next_level: int
    reason: str
    signals: list[str] = []
