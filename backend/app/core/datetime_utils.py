"""Date and time utility functions.

This module provides utility functions for handling datetime operations,
including timezone management, formatting, and conversions.
日期时间工具函数
"""

from datetime import UTC, datetime


def remove_timezone(dt: datetime | None) -> datetime | None:
    """Remove timezone information from a datetime object.

    This is useful when working with databases that don't support
    timezone-aware datetime objects (e.g., SQLite or certain PostgreSQL configurations).

    Args:
        dt: Datetime object, may or may not have timezone info

    Returns:
        Datetime object without timezone info, or None if input is None

    Examples:
        >>> dt = datetime(2024, 1, 1, 12, 0, tzinfo=timezone.utc)
        >>> remove_timezone(dt)
        datetime.datetime(2024, 1, 1, 12, 0)

        >>> remove_timezone(None)
        None

    """
    if dt is None:
        return None

    if dt.tzinfo is not None:
        return dt.replace(tzinfo=None)

    return dt


def sanitize_published_date(published_at: datetime | None) -> datetime | None:
    """Sanitize podcast episode published date by removing timezone.

    This is a common operation for podcast feeds to ensure compatibility
    with databases that don't support timezone-aware datetimes.

    Args:
        published_at: Published date from podcast feed

    Returns:
        Datetime without timezone info, or None

    Examples:
        >>> dt = datetime(2024, 1, 1, 12, 0, tzinfo=timezone.utc)
        >>> sanitize_published_date(dt)
        datetime.datetime(2024, 1, 1, 12, 0)

    """
    return remove_timezone(published_at)


def ensure_timezone_aware_fetch_time(fetch_time: datetime | None) -> datetime | None:
    """Ensure fetch time is timezone-aware in UTC.

    Unlike sanitize_published_date() (which removes timezones for RSS feed compatibility),
    this function ENSURES timezones are present for internal timestamp tracking.

    This is critical for subscription.last_fetched_at comparisons with episode.published_at,
    as comparing naive and aware datetimes raises TypeError.

    Args:
        fetch_time: Datetime from fetch operation

    Returns:
        Timezone-aware datetime in UTC, or None

    Examples:
        >>> # Naive datetime - assumes UTC and adds timezone
        >>> naive_time = datetime(2024, 1, 1, 12, 0, 0)
        >>> ensure_timezone_aware_fetch_time(naive_time)
        datetime.datetime(2024, 1, 1, 12, 0, tzinfo=datetime.timezone.utc)

        >>> # Already timezone-aware - converts to UTC
        >>> from zoneinfo import ZoneInfo
        >>> aware_time = datetime(2024, 1, 1, 12, 0, tzinfo=ZoneInfo("America/New_York"))
        >>> result = ensure_timezone_aware_fetch_time(aware_time)
        >>> result.tzinfo
        datetime.timezone.utc

        >>> # None input
        >>> ensure_timezone_aware_fetch_time(None)
        None

    """
    if fetch_time is None:
        return None

    # If already timezone-aware, convert to UTC
    if fetch_time.tzinfo is not None:
        return fetch_time.astimezone(UTC)

    # If naive, assume it's UTC and add timezone
    return fetch_time.replace(tzinfo=UTC)

