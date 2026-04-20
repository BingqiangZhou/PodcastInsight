"""Podcast data models - core podcast domain.

Contains podcast-specific models: episodes, playback state, and queue.
Media and content models have been split into their own domains
but are re-exported here for backward compatibility.
"""

from datetime import UTC, datetime

from sqlalchemy import (
    JSON,
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


# ---------------------------------------------------------------------------
# Podcast-domain models (live here permanently)
# ---------------------------------------------------------------------------


class PodcastEpisode(Base):
    """Podcast episode data model.

    Design notes:
    - Uses foreign key to Subscription rather than inheritance
    - Reuses some SubscriptionItem fields but independently manages
      podcast-specific audio/summary fields
    - Maintains compatibility with existing schemas while avoiding
      complex SQLAlchemy inheritance configuration
    """

    __tablename__ = "podcast_episodes"

    id = Column(Integer, primary_key=True)
    subscription_id = Column(
        Integer, ForeignKey("subscriptions.id", ondelete="CASCADE"), nullable=False
    )

    # Podcast basic information
    title = Column(String(500), nullable=False)
    description = Column(Text, nullable=True)
    published_at = Column(DateTime(timezone=True), nullable=False)

    # Audio information
    audio_url = Column(String(500), nullable=False)
    audio_duration = Column(Integer)  # seconds
    audio_file_size = Column(Integer)  # bytes

    # Transcript
    transcript_url = Column(String(500))

    # AI summary
    ai_summary = Column(Text)
    summary_version = Column(String(50))  # Track summary version
    ai_confidence_score = Column(Float)  # AI summary quality score

    # Episode image
    image_url = Column(String(500))  # Episode cover image URL

    # Episode detail page link
    item_link = Column(
        String(500),
        unique=True,
        nullable=False,
    )  # <item><link> tag content, links to episode detail page

    # Playback statistics (global)
    play_count = Column(Integer, default=0)
    last_played_at = Column(DateTime(timezone=True))

    # Episode information
    season = Column(Integer)
    episode_number = Column(Integer)
    explicit = Column(Boolean, default=False)

    # Status and metadata
    status = Column(
        String(50),
        default="pending_summary",
    )  # pending, summarized, failed
    metadata_json = Column(
        "metadata",
        JSON,
        nullable=True,
        default=dict,
    )  # Renamed to avoid SQLAlchemy reserved attribute
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    # Relationships
    subscription = relationship("Subscription", back_populates="podcast_episodes")
    playback_states = relationship(
        "PodcastPlaybackState",
        back_populates="episode",
        cascade="all, delete",
    )
    queue_items = relationship(
        "PodcastQueueItem",
        back_populates="episode",
        cascade="all, delete",
    )
    daily_report_items = relationship(
        "PodcastDailyReportItem",
        back_populates="episode",
        cascade="all, delete",
    )
    transcript = relationship(
        "PodcastEpisodeTranscript",
        back_populates="episode",
        uselist=False,
        cascade="all, delete",
    )

    # Indexes
    __table_args__ = (
        Index("idx_podcast_subscription", "subscription_id"),
        Index("idx_podcast_status", "status"),
        Index("idx_podcast_published", "published_at"),
        Index(
            "idx_podcast_episodes_status_published_id", "status", "published_at", "id"
        ),
        Index("idx_podcast_episode_image", "image_url"),
        Index("idx_podcast_episodes_item_link", "item_link", unique=True),
    )

    def __repr__(self):
        return f"<PodcastEpisode(id={self.id}, title='{self.title[:30]}...', status='{self.status}')>"


class PodcastPlaybackState(Base):
    """User playback state - tracks each user's podcast playback progress."""

    __tablename__ = "podcast_playback_states"

    id = Column(Integer, primary_key=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    episode_id = Column(
        Integer,
        ForeignKey("podcast_episodes.id", ondelete="CASCADE"),
        nullable=False,
    )

    # Playback state
    current_position = Column(Integer, default=0)  # Current playback position (seconds)
    is_playing = Column(Boolean, default=False)
    playback_rate = Column(Float, default=1.0, nullable=False)  # Playback speed
    last_updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    # Statistics
    play_count = Column(Integer, default=0)

    # Relationships
    episode = relationship("PodcastEpisode", back_populates="playback_states")
    # Note: User model not imported; accessed via repositories only

    __table_args__ = (
        CheckConstraint(
            "playback_rate >= 0.5 AND playback_rate <= 3.0",
            name="ck_podcast_playback_states_playback_rate_range",
        ),
        # Ensure each user-episode combination is unique
        Index("idx_user_episode_unique", "user_id", "episode_id", unique=True),
    )

    def __repr__(self):
        return f"<PlaybackState(user={self.user_id}, ep={self.episode_id}, pos={self.current_position}s)>"


class PodcastQueue(Base):
    """Per-user persistent podcast playback queue."""

    __tablename__ = "podcast_queues"

    id = Column(Integer, primary_key=True)
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
    )
    current_episode_id = Column(
        Integer,
        ForeignKey("podcast_episodes.id", ondelete="SET NULL"),
        nullable=True,
    )
    revision = Column(Integer, default=0, nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    items = relationship(
        "PodcastQueueItem",
        back_populates="queue",
        cascade="all, delete-orphan",
        order_by="PodcastQueueItem.position",
    )
    current_episode = relationship(
        "PodcastEpisode",
        foreign_keys=[current_episode_id],
        lazy="joined",
    )

    __table_args__ = (Index("idx_podcast_queue_user", "user_id"),)

    def __repr__(self):
        return f"<PodcastQueue(user={self.user_id}, current={self.current_episode_id}, revision={self.revision})>"


class PodcastQueueItem(Base):
    """Item in a user's podcast queue."""

    __tablename__ = "podcast_queue_items"

    id = Column(Integer, primary_key=True)
    queue_id = Column(
        Integer,
        ForeignKey("podcast_queues.id", ondelete="CASCADE"),
        nullable=False,
    )
    episode_id = Column(
        Integer,
        ForeignKey("podcast_episodes.id", ondelete="CASCADE"),
        nullable=False,
    )
    position = Column(Integer, nullable=False)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    queue = relationship("PodcastQueue", back_populates="items")
    episode = relationship("PodcastEpisode", back_populates="queue_items")

    __table_args__ = (
        UniqueConstraint(
            "queue_id",
            "episode_id",
            name="uq_podcast_queue_item_episode",
        ),
        UniqueConstraint("queue_id", "position", name="uq_podcast_queue_item_position"),
        Index("idx_podcast_queue_items_queue_position", "queue_id", "position"),
    )

    def __repr__(self):
        return f"<PodcastQueueItem(queue={self.queue_id}, episode={self.episode_id}, position={self.position})>"



# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------


def is_podcast_subscription(subscription) -> bool:
    """Check whether a Subscription is a podcast type."""
    return subscription.source_type == "podcast-rss"


# ---------------------------------------------------------------------------
# Backward-compatible re-exports from media and content domains
# ---------------------------------------------------------------------------
# These allow existing code that imports from app.domains.podcast.models
# to continue working without changes.

from app.domains.content.models.conversation import (  # noqa: E402
    ConversationSession,
    PodcastConversation,
)
from app.domains.content.models.daily_report import (  # noqa: E402
    PodcastDailyReport,
    PodcastDailyReportItem,
)
from app.domains.content.models.highlight import (  # noqa: E402
    EpisodeHighlight,
    HighlightExtractionTask,
)
from app.domains.media.models.transcript import PodcastEpisodeTranscript  # noqa: E402
from app.domains.media.models.transcription_task import (  # noqa: E402
    TranscriptionStatus,
    TranscriptionStep,
    TranscriptionTask,
)


__all__ = [
    # Podcast domain
    "PodcastEpisode",
    "PodcastPlaybackState",
    "PodcastQueue",
    "PodcastQueueItem",
    "is_podcast_subscription",
    # Media domain (re-exported)
    "PodcastEpisodeTranscript",
    "TranscriptionStatus",
    "TranscriptionStep",
    "TranscriptionTask",
    # Content domain (re-exported)
    "ConversationSession",
    "PodcastConversation",
    "PodcastDailyReport",
    "PodcastDailyReportItem",
    "EpisodeHighlight",
    "HighlightExtractionTask",
]
