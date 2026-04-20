"""Admin domain models."""

from datetime import UTC, datetime

from sqlalchemy import JSON, Column, DateTime, Index, Integer, String, Text

from app.core.database import Base


class SystemSettings(Base):
    """System settings model for storing configuration values."""

    __tablename__ = "system_settings"

    id = Column(Integer, primary_key=True)
    key = Column(
        String(100), unique=True, nullable=False, index=True, comment="Setting key"
    )
    value = Column(JSON, nullable=True, comment="Setting value (JSON)")
    description = Column(String(500), nullable=True, comment="Setting description")
    category = Column(
        String(50),
        nullable=False,
        default="general",
        comment="Setting category: general, audio, ai, etc.",
    )

    created_at = Column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC), comment="Created at"
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
        comment="Updated at",
    )

    def __repr__(self):
        return f"<SystemSettings(id={self.id}, key={self.key})>"


class BackgroundTaskRun(Base):
    """Background task execution log for monitoring."""

    __tablename__ = "background_task_runs"

    id = Column(Integer, primary_key=True)
    task_name = Column(String(255), nullable=False, index=True)
    queue_name = Column(String(64), nullable=False, index=True)
    status = Column(String(20), nullable=False, index=True)  # started, success, failed
    started_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
        index=True,
    )
    finished_at = Column(DateTime(timezone=True), nullable=True)
    duration_ms = Column(Integer, nullable=True)
    error_message = Column(Text, nullable=True)
    metadata_json = Column("metadata", JSON, nullable=True, default=dict)

    __table_args__ = (
        Index("idx_task_queue_started", "queue_name", "started_at"),
        Index("idx_task_status_started", "status", "started_at"),
    )
