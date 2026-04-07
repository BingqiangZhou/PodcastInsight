"""Highlight extraction models for podcast episode insights."""

from datetime import UTC, datetime

from sqlalchemy import (
    JSON,
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


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
