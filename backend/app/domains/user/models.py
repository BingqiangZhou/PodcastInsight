"""User domain models."""

from datetime import UTC, datetime
from enum import StrEnum

from sqlalchemy import (
    JSON,
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    Float,
    Index,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


class UserStatus(StrEnum):
    """User status."""

    ACTIVE = "active"
    INACTIVE = "inactive"
    SUSPENDED = "suspended"


class User(Base):
    """User model."""

    __tablename__ = "users"

    id = Column(Integer, primary_key=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    username = Column(String(100), unique=True, index=True, nullable=True)
    account_name = Column(String(255), nullable=True)  # Renamed from full_name
    hashed_password = Column(String(255), nullable=False)
    avatar_url = Column(String(500), nullable=True)
    status = Column(String(20), default=UserStatus.ACTIVE)
    is_superuser = Column(Boolean, default=False)
    is_verified = Column(Boolean, default=False)
    last_login_at = Column(DateTime(timezone=True), nullable=True)
    settings = Column(JSON, nullable=True, default=dict)
    preferences = Column(JSON, nullable=True, default=dict)
    default_playback_rate = Column(Float, nullable=False, default=1.0)
    api_key = Column(String(255), unique=True, nullable=True)

    # 2FA fields
    totp_secret = Column(String(32), nullable=True)  # Base32 encoded secret for TOTP
    is_2fa_enabled = Column(Boolean, default=False)

    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    # Relationships
    user_subscriptions = relationship(
        "UserSubscription", back_populates="user", cascade="all, delete-orphan"
    )
    subscriptions = relationship(
        "Subscription", secondary="user_subscriptions", viewonly=True
    )
    subscription_categories = relationship(
        "SubscriptionCategory", back_populates="user", cascade="all, delete-orphan"
    )

    # Indexes
    __table_args__ = (
        CheckConstraint(
            "default_playback_rate >= 0.5 AND default_playback_rate <= 3.0",
            name="ck_users_default_playback_rate_range",
        ),
        Index("idx_email_status", "email", "status"),
        Index("idx_username_status", "username", "status"),
    )

    @property
    def is_active(self) -> bool:
        """Check if user is active based on status."""
        return self.status == UserStatus.ACTIVE


class UserSession(Base):
    """User session model for tracking active sessions."""

    __tablename__ = "user_sessions"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, nullable=False)
    session_token = Column(String(255), unique=True, index=True, nullable=False)
    refresh_token = Column(String(255), unique=True, index=True, nullable=True)
    device_info = Column(JSON, nullable=True)
    ip_address = Column(String(45), nullable=True)  # IPv6 compatible
    user_agent = Column(Text, nullable=True)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    last_activity_at = Column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC))

    # Indexes
    __table_args__ = (
        Index("idx_user_active", "user_id", "is_active"),
        Index("idx_user_sessions_token_expires", "session_token", "expires_at"),
    )


class PasswordReset(Base):
    """Password reset model for managing password reset tokens."""

    __tablename__ = "password_resets"

    id = Column(Integer, primary_key=True)
    email = Column(String(255), nullable=False, index=True)
    token = Column(String(255), unique=True, index=True, nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    is_used = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    # Indexes
    __table_args__ = (
        Index("idx_email_token", "email", "token"),
        Index("idx_password_reset_token_expires", "token", "expires_at"),
        Index("idx_email_unused", "email", "is_used"),
    )
