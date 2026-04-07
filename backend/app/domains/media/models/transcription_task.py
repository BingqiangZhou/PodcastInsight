"""Transcription task models for podcast audio transcription.

Tracks the full lifecycle of audio transcription including download,
conversion, splitting, transcription, and merging stages.
"""

from datetime import UTC, datetime
from enum import StrEnum

from sqlalchemy import (
    JSON,
    Column,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


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
