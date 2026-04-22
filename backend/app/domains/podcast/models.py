import enum
import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class ProcessingStatus(str, enum.Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


class Podcast(Base):
    __tablename__ = "podcasts"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    xyzrank_id: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(500), nullable=False)
    rank: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    logo_url: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    category: Mapped[str | None] = mapped_column(String(255), nullable=True)
    author: Mapped[str | None] = mapped_column(String(500), nullable=True)
    rss_feed_url: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    track_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    avg_duration: Mapped[int | None] = mapped_column(Integer, nullable=True)
    avg_play_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    last_synced_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    is_tracked: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )

    ranking_history: Mapped[list["PodcastRankingHistory"]] = relationship(
        back_populates="podcast", cascade="all, delete-orphan"
    )
    episodes: Mapped[list["Episode"]] = relationship(
        back_populates="podcast", cascade="all, delete-orphan"
    )


class PodcastRankingHistory(Base):
    __tablename__ = "podcast_ranking_history"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    podcast_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("podcasts.id", ondelete="CASCADE"), nullable=False
    )
    rank: Mapped[int] = mapped_column(Integer, nullable=False)
    avg_play_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    recorded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    podcast: Mapped["Podcast"] = relationship(back_populates="ranking_history")


class Episode(Base):
    __tablename__ = "episodes"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    podcast_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("podcasts.id", ondelete="CASCADE"), nullable=False
    )
    title: Mapped[str] = mapped_column(String(1000), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    audio_url: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    duration: Mapped[int | None] = mapped_column(Integer, nullable=True)
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    transcript_status: Mapped[ProcessingStatus | None] = mapped_column(
        Enum(ProcessingStatus), nullable=True, default=None
    )
    summary_status: Mapped[ProcessingStatus | None] = mapped_column(
        Enum(ProcessingStatus), nullable=True, default=None
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )

    podcast: Mapped["Podcast"] = relationship(back_populates="episodes")
    transcript: Mapped["Transcript | None"] = relationship(
        "Transcript", back_populates="episode", uselist=False, cascade="all, delete-orphan"
    )
    summary: Mapped["Summary | None"] = relationship(
        "Summary", back_populates="episode", uselist=False, cascade="all, delete-orphan"
    )
