from typing import List, Optional

from app.models.common import APIModel
from app.models.patient import FamilyMember, LifeMemory, MemoryAsset, RoutineItem


class PatientCreate(APIModel):
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


class PatientUpdate(APIModel):
    name: Optional[str] = None
    short_name: Optional[str] = None
    age: Optional[int] = None
    location: Optional[str] = None
    language: Optional[str] = None
    occupation: Optional[str] = None
    favourite_activity: Optional[str] = None
    favourite_food: Optional[str] = None
    tradition: Optional[str] = None
    portrait_scene: Optional[str] = None
    family: Optional[List[FamilyMember]] = None
    memories: Optional[List[LifeMemory]] = None
    assets: Optional[List[MemoryAsset]] = None
    routine: Optional[List[RoutineItem]] = None


class PatientResponse(APIModel):
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
    family: List[FamilyMember]
    memories: List[LifeMemory]
    assets: List[MemoryAsset]
    routine: List[RoutineItem]
    stage_note: str
    joined_on: str
