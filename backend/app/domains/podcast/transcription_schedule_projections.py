"""Typed internal projections for transcription scheduling route outputs."""

from collections.abc import Mapping
from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class EpisodeTranscriptionScheduleProjection(BaseModel):
    """Internal DTO for scheduling a single episode transcription."""

    model_config = ConfigDict(extra="ignore")

    status: str
    message: str
    task_id: int | None = None
    transcript_content: str | None = None
    reason: str | None = None
    action: str | None = None
    progress: float | None = None
    current_status: str | None = None
    episode_id: int | None = None
    scheduled_at: datetime | None = None

    def to_response_payload(self) -> dict[str, Any]:
        return self.model_dump()

    @classmethod
    def from_payload(
        cls, payload: Mapping[str, Any]
    ) -> "EpisodeTranscriptionScheduleProjection":
        return cls.model_validate(payload)


class EpisodeTranscriptProjection(BaseModel):
    """Internal DTO for an existing episode transcript payload."""

    model_config = ConfigDict(extra="ignore")

    episode_id: int
    episode_title: str
    transcript_length: int
    transcript: str
    status: str

    def to_response_payload(self) -> dict[str, Any]:
        return self.model_dump()

    @classmethod
    def from_payload(cls, payload: Mapping[str, Any]) -> "EpisodeTranscriptProjection":
        return cls.model_validate(payload)


class BatchTranscriptionDetailProjection(BaseModel):
    """Internal DTO for one batch transcription result row."""

    model_config = ConfigDict(extra="ignore")

    episode_id: int
    episode_title: str | None = None
    status: str
    message: str | None = None
    task_id: int | None = None
    transcript_content: str | None = None
    reason: str | None = None
    action: str | None = None
    progress: float | None = None
    current_status: str | None = None
    error: str | None = None
    scheduled_at: datetime | None = None


class BatchTranscriptionProjection(BaseModel):
    """Internal DTO for one subscription batch transcription response."""

    model_config = ConfigDict(extra="ignore")

    subscription_id: int
    total: int
    scheduled: int
    skipped: int
    errors: int
    details: list[BatchTranscriptionDetailProjection] = Field(default_factory=list)

    def to_response_payload(self) -> dict[str, Any]:
        return self.model_dump()

    @classmethod
    def from_payload(cls, payload: Mapping[str, Any]) -> "BatchTranscriptionProjection":
        return cls.model_validate(payload)


class TranscriptionScheduleStatusProjection(BaseModel):
    """Internal DTO for one episode transcription scheduling status."""

    model_config = ConfigDict(extra="ignore")

    episode_id: int
    episode_title: str
    status: str
    has_transcript: bool
    transcript_preview: str | None = None
    task_id: int | None = None
    progress: float | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None
    completed_at: datetime | None = None
    transcript_word_count: int | None = None
    has_summary: bool | None = None
    summary_word_count: int | None = None
    error_message: str | None = None

    def to_response_payload(self) -> dict[str, Any]:
        return self.model_dump()

    @classmethod
    def from_payload(
        cls, payload: Mapping[str, Any]
    ) -> "TranscriptionScheduleStatusProjection":
        return cls.model_validate(payload)


class TranscriptionCancelProjection(BaseModel):
    """Internal DTO for cancellation results."""

    model_config = ConfigDict(extra="ignore")

    success: bool
    message: str

    def to_response_payload(self) -> dict[str, Any]:
        return self.model_dump()

    @classmethod
    def from_payload(cls, payload: Mapping[str, Any]) -> "TranscriptionCancelProjection":
        return cls.model_validate(payload)


class CheckNewEpisodesDetailProjection(BaseModel):
    """Internal DTO for one recently-published episode scheduling result."""

    model_config = ConfigDict(extra="ignore")

    episode_id: int
    status: str
    task_id: int | None = None
    error: str | None = None


class CheckNewEpisodesProjection(BaseModel):
    """Internal DTO for recently-published episode scheduling summary."""

    model_config = ConfigDict(extra="ignore")

    status: str
    message: str
    processed: int
    skipped: int | None = None
    scheduled: int | None = None
    errors: int | None = None
    details: list[CheckNewEpisodesDetailProjection] = Field(default_factory=list)

    def to_response_payload(self) -> dict[str, Any]:
        return self.model_dump()

    @classmethod
    def from_payload(cls, payload: Mapping[str, Any]) -> "CheckNewEpisodesProjection":
        return cls.model_validate(payload)


class PendingTranscriptionTaskProjection(BaseModel):
    """Internal DTO for one pending transcription task."""

    model_config = ConfigDict(extra="ignore")

    task_id: int
    episode_id: int
    status: str
    progress: float
    created_at: datetime
    updated_at: datetime | None = None


class PendingTranscriptionsProjection(BaseModel):
    """Internal DTO for pending transcription task listings."""

    model_config = ConfigDict(extra="ignore")

    total: int
    tasks: list[PendingTranscriptionTaskProjection] = Field(default_factory=list)

    def to_response_payload(self) -> dict[str, Any]:
        return self.model_dump()

    @classmethod
    def from_payload(cls, payload: Mapping[str, Any]) -> "PendingTranscriptionsProjection":
        return cls.model_validate(payload)


EpisodeTranscriptionScheduleProjectionLike = (
    EpisodeTranscriptionScheduleProjection | Mapping[str, Any]
)
EpisodeTranscriptProjectionLike = EpisodeTranscriptProjection | Mapping[str, Any]
BatchTranscriptionProjectionLike = BatchTranscriptionProjection | Mapping[str, Any]
TranscriptionScheduleStatusProjectionLike = (
    TranscriptionScheduleStatusProjection | Mapping[str, Any]
)
TranscriptionCancelProjectionLike = TranscriptionCancelProjection | Mapping[str, Any]
CheckNewEpisodesProjectionLike = CheckNewEpisodesProjection | Mapping[str, Any]
PendingTranscriptionsProjectionLike = PendingTranscriptionsProjection | Mapping[str, Any]


def episode_transcription_schedule_projection_to_payload(
    projection: EpisodeTranscriptionScheduleProjectionLike,
) -> dict[str, Any]:
    if isinstance(projection, EpisodeTranscriptionScheduleProjection):
        return projection.to_response_payload()
    return dict(projection)


def episode_transcript_projection_to_payload(
    projection: EpisodeTranscriptProjectionLike,
) -> dict[str, Any]:
    if isinstance(projection, EpisodeTranscriptProjection):
        return projection.to_response_payload()
    return dict(projection)


def batch_transcription_projection_to_payload(
    projection: BatchTranscriptionProjectionLike,
) -> dict[str, Any]:
    if isinstance(projection, BatchTranscriptionProjection):
        return projection.to_response_payload()
    return dict(projection)


def transcription_schedule_status_projection_to_payload(
    projection: TranscriptionScheduleStatusProjectionLike,
) -> dict[str, Any]:
    if isinstance(projection, TranscriptionScheduleStatusProjection):
        return projection.to_response_payload()
    return dict(projection)


def transcription_cancel_projection_to_payload(
    projection: TranscriptionCancelProjectionLike,
) -> dict[str, Any]:
    if isinstance(projection, TranscriptionCancelProjection):
        return projection.to_response_payload()
    return dict(projection)


def check_new_episodes_projection_to_payload(
    projection: CheckNewEpisodesProjectionLike,
) -> dict[str, Any]:
    if isinstance(projection, CheckNewEpisodesProjection):
        return projection.to_response_payload()
    return dict(projection)


def pending_transcriptions_projection_to_payload(
    projection: PendingTranscriptionsProjectionLike,
) -> dict[str, Any]:
    if isinstance(projection, PendingTranscriptionsProjection):
        return projection.to_response_payload()
    return dict(projection)
