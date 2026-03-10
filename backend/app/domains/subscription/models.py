"""Subscription domain models."""

from datetime import UTC, datetime, timedelta
from enum import StrEnum

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
)
from sqlalchemy.orm import relationship

from app.core.database import Base


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

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    source_type = Column(String(50), nullable=False)
    source_url = Column(String(500), nullable=False)
    image_url = Column(String(500), nullable=True)
    config = Column(JSON, nullable=True, default={})
    status = Column(String(20), default=SubscriptionStatus.ACTIVE)
    last_fetched_at = Column(DateTime(timezone=True), nullable=True)
    latest_item_published_at = Column(
        DateTime(timezone=True),
        nullable=True,
        comment="Published timestamp of the latest item from this feed"
    )
    error_message = Column(Text, nullable=True)
    fetch_interval = Column(Integer, default=3600)

    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC), onupdate=lambda: datetime.now(UTC))

    user_subscriptions = relationship("UserSubscription", back_populates="subscription", cascade="all, delete-orphan")
    items = relationship("SubscriptionItem", back_populates="subscription", cascade="all, delete-orphan")
    categories = relationship(
        "SubscriptionCategory",
        secondary="subscription_category_mappings",
        back_populates="subscriptions"
    )

    __table_args__ = (
        Index('idx_source_type', 'source_type'),
        Index('idx_source_url', 'source_url'),
    )


class UserSubscription(Base):
    """Many-to-many mapping between users and subscriptions.

    Allows multiple users to subscribe to the same subscription source
    while maintaining user-specific settings like update frequency,
    archive status, and pinned status.
    """

    __tablename__ = "user_subscriptions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    subscription_id = Column(Integer, ForeignKey("subscriptions.id", ondelete="CASCADE"), nullable=False)

    # User-specific settings
    update_frequency = Column(
        String(10),
        nullable=True,
        default=UpdateFrequency.HOURLY.value,
        comment="Update frequency type: HOURLY, DAILY, WEEKLY"
    )
    update_time = Column(
        String(5),
        nullable=True,
        comment="Update time in HH:MM format (24-hour)"
    )
    update_day_of_week = Column(
        Integer,
        nullable=True,
        comment="Day of week for WEEKLY frequency (1=Monday, 7=Sunday)"
    )

    # User-specific state
    is_archived = Column(Boolean, default=False, comment="User has archived this subscription")
    is_pinned = Column(Boolean, default=False, comment="User has pinned this subscription")
    playback_rate_preference = Column(
        Float,
        nullable=True,
        comment="Subscription-level playback speed preference",
    )

    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC), onupdate=lambda: datetime.now(UTC))

    user = relationship("User", back_populates="user_subscriptions")
    subscription = relationship("Subscription", back_populates="user_subscriptions")

    __table_args__ = (
        CheckConstraint(
            "playback_rate_preference IS NULL OR "
            "(playback_rate_preference >= 0.5 AND playback_rate_preference <= 3.0)",
            name="ck_user_subscriptions_playback_rate_preference_range",
        ),
        Index('idx_user_subscription', 'user_id', 'subscription_id', unique=True),
        Index('idx_user_archived', 'user_id', 'is_archived'),
    )

    def _parse_local_time(self) -> tuple[int, int]:
        """Parse update_time string (HH:MM) to local hour/minute integers."""
        if not self.update_time:
            return 0, 0
        try:
            parts = self.update_time.split(':')
            if len(parts) == 2:
                return int(parts[0]), int(parts[1])
        except (ValueError, AttributeError):
            pass
        return 0, 0

    def _get_next_scheduled_time(self, base_time: datetime) -> datetime:
        """
        Calculate the next scheduled time after base_time.

        All date calculations are done in local timezone (Asia/Shanghai),
        then converted to UTC for storage/comparison.

        Args:
            base_time: UTC datetime to compare against

        Returns:
            UTC datetime of next scheduled time
        """
        from zoneinfo import ZoneInfo

        # Convert base_time to local timezone for comparison
        shanghai_tz = ZoneInfo('Asia/Shanghai')
        base_local = base_time.astimezone(shanghai_tz)

        frequency = self.update_frequency or UpdateFrequency.HOURLY.value

        if frequency == UpdateFrequency.HOURLY.value:
            # Next top of the hour in local time, then convert to UTC
            next_local = (base_local + timedelta(hours=1)).replace(minute=0, second=0, microsecond=0)
            return next_local.astimezone(UTC)

        elif frequency == UpdateFrequency.DAILY.value:
            # Get local hour/minute from stored time
            local_hour, local_minute = self._parse_local_time()

            # Today at scheduled time in local timezone
            scheduled_local = base_local.replace(hour=local_hour, minute=local_minute, second=0, microsecond=0)

            # If already passed today, next one is tomorrow
            if scheduled_local <= base_local:
                scheduled_local += timedelta(days=1)

            # Convert back to UTC
            return scheduled_local.astimezone(UTC)

        elif frequency == UpdateFrequency.WEEKLY.value:
            # Get local hour/minute from stored time
            local_hour, local_minute = self._parse_local_time()

            # DB stores 1-7 (Mon-Sun), Python weekday is 0-6 (Mon-Sun)
            target_weekday = (self.update_day_of_week - 1) if self.update_day_of_week else 0

            # Today at scheduled time in local timezone
            scheduled_local = base_local.replace(hour=local_hour, minute=local_minute, second=0, microsecond=0)

            # Find days until target weekday
            days_ahead = target_weekday - base_local.weekday()
            if days_ahead < 0 or (days_ahead == 0 and scheduled_local <= base_local):
                days_ahead += 7

            # Add the days and convert to UTC
            scheduled_local += timedelta(days=days_ahead)
            return scheduled_local.astimezone(UTC)

        return base_time + timedelta(hours=1) # Fallback

    @property
    def computed_next_update_at(self) -> datetime | None:
        """
        Calculate next update time based on frequency and user settings.
        Aligns to the next scheduled interval based on CURRENT time.
        """
        return self._get_next_scheduled_time(datetime.now(UTC))

    def should_update_now(self) -> bool:
        """
        Check if we should update now based on time passed since last fetch.
        Uses the subscription's last_fetched_at but user's update frequency.
        """
        if not self.subscription.last_fetched_at:
            return True

        # Convert naive datetime to aware datetime (assume UTC)
        from app.core.datetime_utils import ensure_timezone_aware_fetch_time
        last_fetched_aware = ensure_timezone_aware_fetch_time(self.subscription.last_fetched_at)

        # Calculate the Earliest next scheduled time AFTER the last fetch
        next_possible = self._get_next_scheduled_time(last_fetched_aware)

        # If the scheduled time has arrived or passed, we should update
        return datetime.now(UTC) >= next_possible


class SubscriptionItem(Base):
    """Individual items from subscriptions."""

    __tablename__ = "subscription_items"

    id = Column(Integer, primary_key=True, index=True)
    subscription_id = Column(Integer, ForeignKey("subscriptions.id"), nullable=False)
    external_id = Column(String(255), nullable=True)
    title = Column(String(500), nullable=False)
    content = Column(Text, nullable=True)
    summary = Column(Text, nullable=True)
    author = Column(String(255), nullable=True)
    source_url = Column(String(500), nullable=True)
    image_url = Column(String(500), nullable=True)
    tags = Column(JSON, nullable=True, default=[])
    metadata_json = Column("metadata", JSON, nullable=True, default={})
    published_at = Column(DateTime(timezone=True), nullable=True)
    read_at = Column(DateTime(timezone=True), nullable=True)
    bookmarked = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC), onupdate=lambda: datetime.now(UTC))

    subscription = relationship("Subscription", back_populates="items")

    __table_args__ = (
        Index('idx_subscription_external', 'subscription_id', 'external_id'),
        Index('idx_published_at', 'published_at'),
        Index('idx_read_at', 'read_at'),
        Index('idx_bookmarked', 'bookmarked'),
    )


class SubscriptionCategory(Base):
    """Categories for organizing subscriptions.

    user_id is nullable to allow shared/system categories.
    If user_id is NULL, the category can be used by any user.
    """

    __tablename__ = "subscription_categories"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    color = Column(String(7), nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC), onupdate=lambda: datetime.now(UTC))

    user = relationship("User", back_populates="subscription_categories")
    subscriptions = relationship(
        "Subscription",
        secondary="subscription_category_mappings",
        back_populates="categories"
    )

    __table_args__ = (
        Index('idx_user_category', 'user_id', 'name'),
    )


class SubscriptionCategoryMapping(Base):
    """Many-to-many mapping between subscriptions and categories."""

    __tablename__ = "subscription_category_mappings"

    subscription_id = Column(Integer, ForeignKey("subscriptions.id"), primary_key=True)
    category_id = Column(Integer, ForeignKey("subscription_categories.id"), primary_key=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
