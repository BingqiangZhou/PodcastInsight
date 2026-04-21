"""Date and time utility functions.

This module provides utility functions for handling datetime operations,
including timezone management, formatting, and conversions.
日期时间工具函数
"""

from datetime import UTC, datetime, timezone


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


# Display utilities — will be moved to core/display_utils.py in Phase 3
def to_local_timezone(
    dt: datetime | None,
    format_str: str = "%Y-%m-%d %H:%M:%S",
    timezone: str = "Asia/Shanghai",
) -> str:
    """Convert UTC datetime to local timezone and format it."""
    if dt is None:
        return "-"
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=UTC)
    from zoneinfo import ZoneInfo

    local_tz = ZoneInfo(timezone)
    local_dt = dt.astimezone(local_tz)
    return local_dt.strftime(format_str)


def format_uptime(seconds: float | None) -> str:
    """Format uptime seconds to human readable string."""
    if seconds is None:
        return "-"
    days = int(seconds // 86400)
    hours = int((seconds % 86400) // 3600)
    minutes = int((seconds % 3600) // 60)
    if days > 0:
        return f"{days}天 {hours}小时"
    if hours > 0:
        return f"{hours}小时 {minutes}分钟"
    return f"{minutes}分钟"


def format_bytes(bytes_value: int | None) -> str:
    """Format bytes to human readable string."""
    if bytes_value is None:
        return "-"
    if bytes_value >= 1073741824:
        return f"{bytes_value / 1073741824:.1f} GB"
    if bytes_value >= 1048576:
        return f"{bytes_value / 1048576:.1f} MB"
    if bytes_value >= 1024:
        return f"{bytes_value / 1024:.1f} KB"
    return f"{bytes_value} B"


def format_number(value: int | None) -> str:
    """Format number with thousand separators."""
    if value is None:
        return "-"
    return f"{value:,}"
