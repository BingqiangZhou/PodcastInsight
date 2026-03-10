"""Typed internal projections for subscription schedule service outputs."""

from collections.abc import Mapping
from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict


class ScheduleConfigProjection(BaseModel):
    """Internal DTO for one subscription schedule row."""

    model_config = ConfigDict(extra="ignore")

    id: int
    title: str
    update_frequency: str
    update_time: str | None = None
    update_day_of_week: int | None = None
    fetch_interval: int | None = None
    next_update_at: datetime | None = None
    last_updated_at: datetime | None = None

    def to_response_payload(self) -> dict[str, Any]:
        return self.model_dump()

    @classmethod
    def from_payload(cls, payload: Mapping[str, Any]) -> "ScheduleConfigProjection":
        return cls.model_validate(payload)


ScheduleProjectionLike = ScheduleConfigProjection | Mapping[str, Any]


def schedule_projection_to_payload(projection: ScheduleProjectionLike) -> dict[str, Any]:
    if isinstance(projection, ScheduleConfigProjection):
        return projection.to_response_payload()
    return dict(projection)
