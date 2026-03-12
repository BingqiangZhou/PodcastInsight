"""Typed internal projections for podcast episode-oriented service outputs."""

from collections.abc import Mapping
from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class PodcastEpisodeProjection(BaseModel):
    """Internal DTO for episode list/feed/search results."""

    model_config = ConfigDict(extra="ignore")

    id: int
    subscription_id: int
    title: str
    description: str | None = None
    audio_url: str
    audio_duration: int | None = None
    audio_file_size: int | None = None
    published_at: datetime
    image_url: str | None = None
    item_link: str | None = None
    subscription_image_url: str | None = None
    transcript_url: str | None = None
    transcript_content: str | None = None
    ai_summary: str | None = None
    summary_version: str | None = None
    ai_confidence_score: float | None = None
    play_count: int = 0
    last_played_at: datetime | None = None
    season: int | None = None
    episode_number: int | None = None
    explicit: bool = False
    status: str
    metadata: dict[str, Any] | None = Field(default_factory=dict)
    subscription_title: str | None = None
    playback_position: int | None = None
    is_playing: bool = False
    playback_rate: float = 1.0
    is_played: bool | None = None
    created_at: datetime
    updated_at: datetime | None = None
    relevance_score: float | None = None

    def to_response_payload(self) -> dict[str, Any]:
        """Serialize the projection for API-layer response assembly."""
        return self.model_dump()

    @classmethod
    def from_payload(cls, payload: Mapping[str, Any]) -> "PodcastEpisodeProjection":
        """Rehydrate a projection from cached or route-level payloads."""
        return cls.model_validate(payload)


class PodcastEpisodeDetailProjection(PodcastEpisodeProjection):
    """Internal DTO for the detailed episode endpoint."""

    summary_status: str | None = None
    summary_error_message: str | None = None
    summary_model_used: str | None = None
    summary_processing_time: float | None = None
    subscription: dict[str, Any] | None = None
    related_episodes: list[dict[str, Any]] = Field(default_factory=list)


EpisodeProjectionLike = PodcastEpisodeProjection | PodcastEpisodeDetailProjection | Mapping[str, Any]


def episode_projection_to_payload(projection: EpisodeProjectionLike) -> dict[str, Any]:
    """Normalize projection-like inputs for response model construction."""
    if isinstance(projection, PodcastEpisodeProjection | PodcastEpisodeDetailProjection):
        return projection.to_response_payload()
    return dict(projection)
