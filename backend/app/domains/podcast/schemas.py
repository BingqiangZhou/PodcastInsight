from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.domains.podcast.models import ProcessingStatus


# ---- Pagination ----
class PaginatedResponse(BaseModel):
    items: list
    total: int
    page: int
    page_size: int
    total_pages: int

    model_config = ConfigDict(from_attributes=True)


# ---- Podcast Schemas ----
class PodcastBase(BaseModel):
    name: str
    rank: int = 0
    logo_url: str | None = None
    category: str | None = None
    author: str | None = None
    rss_feed_url: str | None = None
    track_count: int | None = None
    avg_duration: int | None = None
    avg_play_count: int | None = None


class PodcastResponse(PodcastBase):
    id: UUID
    xyzrank_id: str
    is_tracked: bool
    last_synced_at: datetime | None = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class PodcastListResponse(PaginatedResponse):
    items: list[PodcastResponse]


class PodcastDetail(PodcastResponse):
    episode_count: int = 0


class PodcastTrackResponse(BaseModel):
    id: UUID
    is_tracked: bool

    model_config = ConfigDict(from_attributes=True)


class RankingHistoryResponse(BaseModel):
    id: UUID
    podcast_id: UUID
    rank: int
    avg_play_count: int | None = None
    recorded_at: datetime

    model_config = ConfigDict(from_attributes=True)


# ---- Episode Schemas ----
class EpisodeBase(BaseModel):
    title: str
    description: str | None = None
    audio_url: str | None = None
    duration: int | None = None
    published_at: datetime | None = None


class EpisodeResponse(EpisodeBase):
    id: UUID
    podcast_id: UUID
    transcript_status: ProcessingStatus | None = None
    summary_status: ProcessingStatus | None = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class EpisodeListResponse(PaginatedResponse):
    items: list[EpisodeResponse]


class EpisodeDetail(EpisodeResponse):
    podcast_name: str | None = None
    podcast_logo_url: str | None = None


# ---- Sync Schemas ----
class SyncResponse(BaseModel):
    message: str
    task_id: str | None = None
