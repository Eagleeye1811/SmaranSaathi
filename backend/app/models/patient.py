"""Mirrors frontend/lib/core/models/patient.dart field-for-field."""
from enum import Enum
from typing import List, Optional

from .common import APIModel


class MemoryAssetKind(str, Enum):
    person = "person"
    place = "place"
    object_ = "object"
    event = "event"
    hobby = "hobby"


class RoutineKind(str, Enum):
    meal = "meal"
    activity = "activity"
    rest = "rest"
    cognitive = "cognitive"
    medicine = "medicine"
    social = "social"


class FamilyMember(APIModel):
    id: str
    name: str
    relation: str
    scene_id: str
    note: str = ""
    lives_with_patient: bool = False


class MemoryAsset(APIModel):
    id: str
    title: str
    scene_id: str
    kind: MemoryAssetKind
    caption: str = ""
    year: Optional[str] = None


class LifeMemory(APIModel):
    id: str
    category: str
    prompt: str
    answer: str


class RoutineItem(APIModel):
    time: str
    title: str
    kind: RoutineKind
    detail: str = ""


class Patient(APIModel):
    id: str
    name: str
    short_name: str
    age: int
    location: str
    language: str
    occupation: str
    favourite_activity: str
    favourite_food: str
    tradition: str
    portrait_scene: str
    family: List[FamilyMember] = []
    memories: List[LifeMemory] = []
    assets: List[MemoryAsset] = []
    routine: List[RoutineItem] = []
    stage_note: str = "Early-stage memory changes"
    joined_on: str = "Profile created today"
