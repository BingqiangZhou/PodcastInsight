from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.domains.podcast.models import ProcessingStatus


class TranscriptCreate(BaseModel):
    episode_id: UUID
    content: str | None = None
    language: str | None = None
    duration: int | None = None
    word_count: int | None = None
    model_used: str | None = None


class TranscriptResponse(BaseModel):
    id: UUID
    episode_id: UUID
    status: ProcessingStatus
    language: str | None = None
    duration: int | None = None
    word_count: int | None = None
    model_used: str | None = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class TranscriptSegment(BaseModel):
    start: float
    end: float
    text: str


class TranscriptDetail(TranscriptResponse):
    content: str | None = None
    segments: list[TranscriptSegment] | None = None

    model_config = ConfigDict(from_attributes=True)
