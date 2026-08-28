"""Shared base for every domain model.

`APIModel` serialises to camelCase (matching the Dart side's field names,
e.g. `hintsUsed`, `patientId`) while still accepting snake_case on the way
in, so either convention works from a client.
"""
from pydantic import BaseModel, ConfigDict
from pydantic.alias_generators import to_camel


class APIModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        from_attributes=True,
    )
