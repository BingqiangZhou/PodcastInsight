"""Typed internal projections for playback and queue service outputs."""

from collections.abc import Mapping
from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class PodcastPlaybackStateProjection(BaseModel):
    """Internal DTO for playback-state service results."""

    model_config = ConfigDict(extra="ignore")

    episode_id: int
    current_position: int
    is_playing: bool
    playback_rate: float
    play_count: int
    last_updated_at: datetime
    progress_percentage: float
    remaining_time: int

    def to_response_payload(self) -> dict[str, Any]:
        return self.model_dump()

    @classmethod
    def from_payload(
        cls, payload: Mapping[str, Any]
    ) -> "PodcastPlaybackStateProjection":
        return cls.model_validate(payload)


class PodcastQueueItemProjection(BaseModel):
    """Internal DTO for a queue item."""

    model_config = ConfigDict(extra="ignore")

    episode_id: int
    position: int
    playback_position: int | None = None
    title: str
    podcast_id: int
    audio_url: str
    duration: int | None = None
    published_at: datetime | None = None
    image_url: str | None = None
    subscription_title: str | None = None
    subscription_image_url: str | None = None


class PodcastQueueProjection(BaseModel):
    """Internal DTO for a playback queue snapshot."""

    model_config = ConfigDict(extra="ignore")

    current_episode_id: int | None = None
    revision: int
    updated_at: datetime | None = None
    items: list[PodcastQueueItemProjection] = Field(default_factory=list)

    def to_response_payload(self) -> dict[str, Any]:
        return self.model_dump()

    @classmethod
    def from_payload(cls, payload: Mapping[str, Any]) -> "PodcastQueueProjection":
        return cls.model_validate(payload)


PlaybackStateProjectionLike = PodcastPlaybackStateProjection | Mapping[str, Any]
QueueProjectionLike = PodcastQueueProjection | Mapping[str, Any]


def playback_state_projection_to_payload(
    projection: PlaybackStateProjectionLike,
) -> dict[str, Any]:
    if isinstance(projection, PodcastPlaybackStateProjection):
        return projection.to_response_payload()
    return dict(projection)


def queue_projection_to_payload(projection: QueueProjectionLike) -> dict[str, Any]:
    if isinstance(projection, PodcastQueueProjection):
        return projection.to_response_payload()
    return dict(projection)
