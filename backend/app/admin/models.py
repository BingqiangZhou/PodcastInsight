"""Admin domain models."""

from datetime import UTC, datetime

from sqlalchemy import JSON, Column, DateTime, Integer, String

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

