"""Daily report models for podcast episode summaries."""

from datetime import UTC, datetime

from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


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
