"""Podcast data models - unified domain models.

Contains all models: podcast episodes, playback, queue,
subscription, transcription, conversation, reports, and highlights.
"""

from datetime import UTC, datetime, timedelta
from enum import StrEnum

from sqlalchemy import (
    JSON,
    Boolean,
    CheckConstraint,
    Column,
    Date,
    DateTime,
    Enum,
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
    - Independently manages podcast-specific audio/summary fields
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
# Subscription domain models (merged from domains/subscription)
# ---------------------------------------------------------------------------


class SubscriptionType(StrEnum):
    """Subscription source types."""

    RSS = "rss"
    API = "api"
    SOCIAL = "social"
    EMAIL = "email"
    WEBSITE = "website"


class SubscriptionStatus(StrEnum):
    """Subscription status."""

    ACTIVE = "active"
    INACTIVE = "inactive"
    ERROR = "error"
    PENDING = "pending"


class UpdateFrequency(StrEnum):
    """Update frequency for scheduled RSS feed refresh."""

    HOURLY = "HOURLY"
    DAILY = "DAILY"
    WEEKLY = "WEEKLY"


class Subscription(Base):
    """Subscription model for managing information sources.

    Represents a subscription source (e.g., RSS feed) that can be
    subscribed to by multiple users via the UserSubscription mapping table.
    """

    __tablename__ = "subscriptions"

    id = Column(Integer, primary_key=True)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    source_type = Column(String(50), nullable=False)
    source_url = Column(String(500), nullable=False)
    image_url = Column(String(500), nullable=True)
    config = Column(JSON, nullable=True, default=dict)
    status = Column(String(20), default=SubscriptionStatus.ACTIVE)
    last_fetched_at = Column(DateTime(timezone=True), nullable=True)
    latest_item_published_at = Column(
        DateTime(timezone=True),
        nullable=True,
        comment="Published timestamp of the latest item from this feed",
    )
    error_message = Column(Text, nullable=True)
    fetch_interval = Column(Integer, default=3600)

    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    user_subscriptions = relationship(
        "UserSubscription", back_populates="subscription", cascade="all, delete-orphan"
    )
    podcast_episodes = relationship(
        "PodcastEpisode",
        back_populates="subscription",
        cascade="all, delete-orphan",
    )

    __table_args__ = (
        UniqueConstraint("source_url", "source_type", name="uq_subscriptions_source"),
        Index("idx_source_type", "source_type"),
        Index("idx_source_url", "source_url"),
    )


class UserSubscription(Base):
    """Many-to-many mapping between users and subscriptions.

    Allows multiple users to subscribe to the same subscription source
    while maintaining user-specific settings like update frequency
    and archive status.
    """

    __tablename__ = "user_subscriptions"

    id = Column(Integer, primary_key=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    subscription_id = Column(
        Integer, ForeignKey("subscriptions.id", ondelete="CASCADE"), nullable=False
    )

    # User-specific settings
    update_frequency = Column(
        String(10),
        nullable=True,
        default=UpdateFrequency.HOURLY.value,
        comment="Update frequency type: HOURLY, DAILY, WEEKLY",
    )
    update_time = Column(
        String(5),
        nullable=True,
        comment="Update time in HH:MM format (24-hour)",
    )
    update_day_of_week = Column(
        Integer,
        nullable=True,
        comment="Day of week for WEEKLY frequency (1=Monday, 7=Sunday)",
    )

    # User-specific state
    is_archived = Column(
        Boolean, default=False, comment="User has archived this subscription"
    )
    playback_rate_preference = Column(
        Float,
        nullable=True,
        comment="Subscription-level playback speed preference",
    )

    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    subscription = relationship("Subscription", back_populates="user_subscriptions")

    __table_args__ = (
        CheckConstraint(
            "playback_rate_preference IS NULL OR "
            "(playback_rate_preference >= 0.5 AND playback_rate_preference <= 3.0)",
            name="ck_user_subscriptions_playback_rate_preference_range",
        ),
        Index("idx_user_subscription", "user_id", "subscription_id", unique=True),
        Index("idx_user_archived", "user_id", "is_archived"),
    )

    def _parse_local_time(self) -> tuple[int, int]:
        """Parse update_time string (HH:MM) to local hour/minute integers."""
        if not self.update_time:
            return 0, 0
        try:
            parts = self.update_time.split(":")
            if len(parts) == 2:
                return int(parts[0]), int(parts[1])
        except (ValueError, AttributeError):
            pass
        return 0, 0

    def _get_next_scheduled_time(self, base_time: datetime) -> datetime:
        """Calculate the next scheduled time after base_time.

        All date calculations are done in local timezone (Asia/Shanghai),
        then converted to UTC for storage/comparison.

        Args:
            base_time: UTC datetime to compare against

        Returns:
            UTC datetime of next scheduled time

        """
        from zoneinfo import ZoneInfo

        # Convert base_time to local timezone for comparison
        shanghai_tz = ZoneInfo("Asia/Shanghai")
        base_local = base_time.astimezone(shanghai_tz)

        frequency = self.update_frequency or UpdateFrequency.HOURLY.value

        if frequency == UpdateFrequency.HOURLY.value:
            # Next top of the hour in local time, then convert to UTC
            next_local = (base_local + timedelta(hours=1)).replace(
                minute=0, second=0, microsecond=0
            )
            return next_local.astimezone(UTC)

        if frequency == UpdateFrequency.DAILY.value:
            # Get local hour/minute from stored time
            local_hour, local_minute = self._parse_local_time()

            # Today at scheduled time in local timezone
            scheduled_local = base_local.replace(
                hour=local_hour, minute=local_minute, second=0, microsecond=0
            )

            # If already passed today, next one is tomorrow
            if scheduled_local <= base_local:
                scheduled_local += timedelta(days=1)

            # Convert back to UTC
            return scheduled_local.astimezone(UTC)

        if frequency == UpdateFrequency.WEEKLY.value:
            # Get local hour/minute from stored time
            local_hour, local_minute = self._parse_local_time()

            # DB stores 1-7 (Mon-Sun), Python weekday is 0-6 (Mon-Sun)
            target_weekday = (
                (self.update_day_of_week - 1) if self.update_day_of_week else 0
            )

            # Today at scheduled time in local timezone
            scheduled_local = base_local.replace(
                hour=local_hour, minute=local_minute, second=0, microsecond=0
            )

            # Find days until target weekday
            days_ahead = target_weekday - base_local.weekday()
            if days_ahead < 0 or (days_ahead == 0 and scheduled_local <= base_local):
                days_ahead += 7

            # Add the days and convert to UTC
            scheduled_local += timedelta(days=days_ahead)
            return scheduled_local.astimezone(UTC)

        return base_time + timedelta(hours=1)  # Fallback

    @property
    def computed_next_update_at(self) -> datetime | None:
        """Calculate next update time based on frequency and user settings.
        Aligns to the next scheduled interval based on CURRENT time.
        """
        return self._get_next_scheduled_time(datetime.now(UTC))

    def should_update_now(self) -> bool:
        """Check if we should update now based on time passed since last fetch.
        Uses the subscription's last_fetched_at but user's update frequency.
        """
        if not self.subscription.last_fetched_at:
            return True

        # Convert naive datetime to aware datetime (assume UTC)
        from app.core.datetime_utils import ensure_timezone_aware_fetch_time

        last_fetched_aware = ensure_timezone_aware_fetch_time(
            self.subscription.last_fetched_at
        )

        # Calculate the Earliest next scheduled time AFTER the last fetch
        next_possible = self._get_next_scheduled_time(last_fetched_aware)

        # If the scheduled time has arrived or passed, we should update
        return datetime.now(UTC) >= next_possible


# ---------------------------------------------------------------------------
# Media domain models (merged from domains/media)
# ---------------------------------------------------------------------------


class TranscriptionStatus(StrEnum):
    """Transcription task status enum."""

    PENDING = "pending"  # Waiting to start
    IN_PROGRESS = "in_progress"  # Processing
    COMPLETED = "completed"  # Done
    FAILED = "failed"  # Failed
    CANCELLED = "cancelled"  # Cancelled


class TranscriptionStep(StrEnum):
    """Transcription task execution step enum."""

    NOT_STARTED = "not_started"  # Not started
    DOWNLOADING = "downloading"  # Downloading audio file
    CONVERTING = "converting"  # Format conversion to MP3
    SPLITTING = "splitting"  # Splitting audio file
    TRANSCRIBING = "transcribing"  # Speech recognition transcription
    MERGING = "merging"  # Merging transcription results


class PodcastEpisodeTranscript(Base):
    """Dedicated storage for episode transcript content.

    Separated from podcast_episodes to improve query performance
    on the main table by avoiding large TEXT column scans.
    """

    __tablename__ = "podcast_episode_transcripts"

    episode_id = Column(
        Integer, ForeignKey("podcast_episodes.id", ondelete="CASCADE"), primary_key=True
    )
    transcript_content = Column(Text, nullable=True)
    transcript_word_count = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    # Relationship
    episode = relationship("PodcastEpisode", back_populates="transcript")

    def __repr__(self):
        return f"<PodcastEpisodeTranscript(episode_id={self.episode_id}, word_count={self.transcript_word_count})>"


class TranscriptionTask(Base):
    """Podcast audio transcription task model.

    Tracks the full lifecycle of audio transcription, including
    download, conversion, splitting, transcription, and merging stages.

    State management:
    - status: Overall task status (PENDING, IN_PROGRESS, COMPLETED, FAILED, CANCELLED)
    - current_step: Current execution step (NOT_STARTED, DOWNLOADING, CONVERTING, SPLITTING, TRANSCRIBING, MERGING)
    """

    __tablename__ = "transcription_tasks"

    id = Column(Integer, primary_key=True)
    episode_id = Column(
        Integer,
        ForeignKey("podcast_episodes.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
    )

    # Task status (simplified) - Use explicit values to match database enum
    status = Column(
        Enum(
            "pending",
            "in_progress",
            "completed",
            "failed",
            "cancelled",
            name="transcriptionstatus",
        ),
        default="pending",
        nullable=False,
    )

    # Current execution step - Use explicit values to match database enum
    current_step = Column(
        Enum(
            "not_started",
            "downloading",
            "converting",
            "splitting",
            "transcribing",
            "merging",
            name="transcriptionstep",
        ),
        default="not_started",
        nullable=False,
    )

    # Progress percentage 0-100
    progress_percentage = Column(Float, default=0.0)

    # File information
    original_audio_url = Column(String(500), nullable=False)
    original_file_path = Column(String(1000))  # Original download file path
    original_file_size = Column(Integer)  # Original file size (bytes)

    # Processing results
    transcript_content = Column(Text)  # Final transcript text
    transcript_word_count = Column(Integer)  # Transcript word count
    transcript_duration = Column(Integer)  # Actual transcription duration (seconds)

    # AI summary results
    summary_content = Column(Text)  # AI summary content
    summary_model_used = Column(String(100))  # AI summary model used
    summary_word_count = Column(Integer)  # Summary word count
    summary_processing_time = Column(Float)  # Summary processing time (seconds)
    summary_error_message = Column(Text)  # Summary error message

    # Chunk information (stored in JSON format)
    chunk_info = Column(
        JSON,
        default=dict,
    )  # Stores chunk info, e.g.: {"chunks": [{"index": 1, "file": "path", "size": 1024, "transcript": "..."}]}

    # Error information
    error_message = Column(Text)  # Error details
    error_code = Column(String(50))  # Error code

    # Performance statistics
    download_time = Column(Float)  # Download time (seconds)
    conversion_time = Column(Float)  # Conversion time (seconds)
    transcription_time = Column(Float)  # Total transcription time (seconds)

    # Configuration (records task configuration)
    chunk_size_mb = Column(Integer, default=10)  # Chunk size (MB)
    model_used = Column(String(100))  # Transcription model used

    # Timestamps (using timezone-aware datetime)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
    )
    started_at = Column(DateTime(timezone=True))  # Task start time
    completed_at = Column(DateTime(timezone=True))  # Task completion time
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    # Relationships
    episode = relationship("PodcastEpisode", backref="transcription_task")

    # Indexes
    __table_args__ = (
        Index("idx_transcription_episode", "episode_id", unique=True),
        Index("idx_transcription_status", "status"),
        Index("idx_transcription_created", "created_at"),
        Index("idx_transcription_status_updated", "status", "updated_at"),
        Index("idx_transcription_status_created", "status", "created_at"),
    )

    @property
    def duration_seconds(self) -> int | None:
        """Get task execution duration (seconds)."""
        if self.started_at and self.completed_at:
            return int((self.completed_at - self.started_at).total_seconds())
        return None

    @property
    def total_processing_time(self) -> float | None:
        """Get total processing time (seconds)."""
        total = 0
        if self.download_time:
            total += self.download_time
        if self.conversion_time:
            total += self.conversion_time
        if self.transcription_time:
            total += self.transcription_time
        return total if total > 0 else None

    def __repr__(self):
        return f"<TranscriptionTask(id={self.id}, episode_id={self.episode_id}, status='{self.status}')>"



# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Content domain models (merged from domains/content)
# ---------------------------------------------------------------------------


class ConversationSession(Base):
    """Conversation session model.

    Each episode+user can have multiple sessions, each with independent
    conversation history.
    """

    __tablename__ = "conversation_sessions"

    id = Column(Integer, primary_key=True)
    episode_id = Column(
        Integer,
        ForeignKey("podcast_episodes.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    title = Column(String(255), default="Default Conversation")

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
    episode = relationship("PodcastEpisode", backref="conversation_sessions")
    messages = relationship(
        "PodcastConversation",
        back_populates="session",
        cascade="all, delete-orphan",
        order_by="PodcastConversation.created_at",
    )

    __table_args__ = (
        Index("idx_session_episode_user", "episode_id", "user_id"),
        Index("idx_session_created", "created_at"),
    )

    def __repr__(self):
        return f"<ConversationSession(id={self.id}, episode_id={self.episode_id}, title='{self.title}')>"


class PodcastConversation(Base):
    """Podcast episode conversation interaction model.

    Stores user-AI conversation history based on podcast summaries,
    supporting context-preserving interactions.
    """

    __tablename__ = "podcast_conversations"

    id = Column(Integer, primary_key=True)
    episode_id = Column(
        Integer,
        ForeignKey("podcast_episodes.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    session_id = Column(
        Integer,
        ForeignKey("conversation_sessions.id", ondelete="CASCADE"),
        nullable=True,
    )

    # Conversation content
    role = Column(String(20), nullable=False)  # 'user' or 'assistant'
    content = Column(Text, nullable=False)

    # Context management
    parent_message_id = Column(
        Integer,
        ForeignKey("podcast_conversations.id", ondelete="SET NULL"),
        nullable=True,
    )  # Parent message ID for building conversation tree
    conversation_turn = Column(Integer, default=0)  # Conversation turn number

    # Metadata
    tokens_used = Column(Integer)  # Tokens used for this message
    model_used = Column(String(100))  # AI model used
    processing_time = Column(Float)  # Processing time (seconds)

    # Timestamps
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        index=True,
    )

    # Relationships
    episode = relationship("PodcastEpisode", backref="conversations")
    session = relationship("ConversationSession", back_populates="messages")
    parent_message = relationship(
        "PodcastConversation",
        remote_side=[id],
        backref="replies",
    )

    # Indexes
    __table_args__ = (
        Index("idx_conversation_episode", "episode_id"),
        Index("idx_conversation_user", "user_id"),
        Index("idx_conversation_session", "session_id"),
        Index("idx_conversation_created", "created_at"),
        Index("idx_conversation_turn", "episode_id", "conversation_turn"),
        Index("idx_conversation_parent", "parent_message_id"),
    )

    def __repr__(self):
        return f"<PodcastConversation(id={self.id}, episode_id={self.episode_id}, role='{self.role}')>"


class PodcastDailyReport(Base):
    """Per-user daily report snapshot."""

    __tablename__ = "podcast_daily_reports"

    id = Column(Integer, primary_key=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    report_date = Column(Date, nullable=False)
    timezone = Column(String(64), nullable=False, default="Asia/Shanghai")
    schedule_time_local = Column(String(5), nullable=False, default="03:30")
    generated_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
    )
    total_items = Column(Integer, nullable=False, default=0)
    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
    )
    updated_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    items = relationship(
        "PodcastDailyReportItem",
        back_populates="report",
        cascade="all, delete-orphan",
        order_by="PodcastDailyReportItem.id",
    )

    __table_args__ = (
        UniqueConstraint(
            "user_id", "report_date", name="uq_podcast_daily_reports_user_date"
        ),
        Index("idx_podcast_daily_reports_user_date", "user_id", "report_date"),
        Index("idx_podcast_daily_reports_generated_at", "generated_at"),
    )


class PodcastDailyReportItem(Base):
    """Snapshot item for one episode inside a daily report."""

    __tablename__ = "podcast_daily_report_items"

    id = Column(Integer, primary_key=True)
    report_id = Column(
        Integer,
        ForeignKey("podcast_daily_reports.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    episode_id = Column(
        Integer,
        ForeignKey("podcast_episodes.id", ondelete="CASCADE"),
        nullable=False,
    )
    subscription_id = Column(Integer, nullable=False)
    episode_title_snapshot = Column(String(500), nullable=False)
    subscription_title_snapshot = Column(String(255), nullable=True)
    one_line_summary = Column(Text, nullable=False)
    is_carryover = Column(Boolean, nullable=False, default=False)
    episode_created_at = Column(DateTime(timezone=True), nullable=False)
    episode_published_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
    )

    report = relationship("PodcastDailyReport", back_populates="items")
    episode = relationship("PodcastEpisode", back_populates="daily_report_items")

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "episode_id",
            name="uq_podcast_daily_report_items_user_episode",
        ),
        Index("idx_podcast_daily_report_items_report_id", "report_id"),
        Index("idx_podcast_daily_report_items_user_id", "user_id"),
        Index("idx_podcast_daily_report_items_episode_id", "episode_id"),
    )


class HighlightExtractionTask(Base):
    """Highlight extraction task.

    Tracks the full lifecycle of highlight/insight extraction
    from podcast episodes.
    """

    __tablename__ = "highlight_extraction_tasks"

    id = Column(Integer, primary_key=True)
    episode_id = Column(
        Integer,
        ForeignKey("podcast_episodes.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )

    # Task status
    status = Column(
        String(20),
        default="pending",
        nullable=False,
    )
    progress = Column(Float, default=0.0)

    # Result statistics
    highlights_count = Column(Integer, default=0)
    processing_time = Column(Float)

    # Error information
    error_message = Column(Text)

    # Model information
    model_used = Column(String(100))

    # Timestamps
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
    )
    started_at = Column(DateTime(timezone=True))
    completed_at = Column(DateTime(timezone=True))

    # Relationships
    episode = relationship("PodcastEpisode", backref="highlight_extraction_task")

    # Indexes
    __table_args__ = (
        Index("idx_highlight_extraction_episode", "episode_id", unique=True),
        Index("idx_highlight_extraction_status", "status"),
        Index("idx_highlight_extraction_created", "created_at"),
    )

    def __repr__(self):
        return f"<HighlightExtractionTask(id={self.id}, episode_id={self.episode_id}, status='{self.status}')>"


class EpisodeHighlight(Base):
    """Podcast highlight/insight.

    Stores core viewpoints and insights extracted from podcast episodes.
    """

    __tablename__ = "episode_highlights"

    id = Column(Integer, primary_key=True)
    episode_id = Column(
        Integer,
        ForeignKey("podcast_episodes.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Highlight content
    original_text = Column(Text, nullable=False)  # Original text citation (core field)
    context_before = Column(Text)  # Preceding context (optional)
    context_after = Column(Text)  # Following context (optional)

    # Scoring dimensions (0-10)
    insight_score = Column(Float, nullable=False)  # Insight score
    novelty_score = Column(Float, nullable=False)  # Novelty score
    actionability_score = Column(Float, nullable=False)  # Actionability score
    overall_score = Column(Float, nullable=False)  # Overall score

    # Metadata
    speaker_hint = Column(String(200))  # Speaker hint
    timestamp_hint = Column(String(50))  # Timestamp hint
    topic_tags = Column(JSON, default=list)  # Topic tag list

    # Generation information
    model_used = Column(String(100))  # LLM model used
    extraction_task_id = Column(
        Integer,
        ForeignKey("highlight_extraction_tasks.id", ondelete="SET NULL"),
        nullable=True,
    )

    # User interaction
    is_user_favorited = Column(Boolean, default=False)  # User favorited

    # Status
    status = Column(
        String(20),
        default="active",
    )  # active/archived/deleted

    # Timestamps
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
    episode = relationship("PodcastEpisode", backref="highlights")
    extraction_task = relationship("HighlightExtractionTask", backref="highlights")

    # Indexes
    __table_args__ = (
        Index("idx_episode_highlight_episode", "episode_id"),
        Index("idx_episode_highlight_status", "status"),
        Index("idx_episode_highlight_overall_score", "overall_score"),
        Index("idx_episode_highlight_favorited", "is_user_favorited"),
        Index("idx_episode_highlight_created", "created_at"),
        # Composite index for date range queries and date-ordered results
        # Note: Migration uses DESC for created_at to optimize get_highlight_dates
        Index("idx_episode_highlight_status_created", "status", "created_at"),
    )

    def __repr__(self):
        return f"<EpisodeHighlight(id={self.id}, episode_id={self.episode_id}, overall_score={self.overall_score})>"


__all__ = [
    # Podcast domain
    "PodcastEpisode",
    "PodcastPlaybackState",
    "PodcastQueue",
    "PodcastQueueItem",
    "is_podcast_subscription",
    # Subscription domain (merged)
    "SubscriptionType",
    "SubscriptionStatus",
    "UpdateFrequency",
    "Subscription",
    "UserSubscription",
    # Media domain (merged)
    "PodcastEpisodeTranscript",
    "TranscriptionStatus",
    "TranscriptionStep",
    "TranscriptionTask",
    # Content domain (merged)
    "ConversationSession",
    "PodcastConversation",
    "PodcastDailyReport",
    "PodcastDailyReportItem",
    "EpisodeHighlight",
    "HighlightExtractionTask",
]
