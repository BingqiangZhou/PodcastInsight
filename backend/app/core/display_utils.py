"""Display formatting utilities for admin templates."""
from datetime import UTC, datetime


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
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if bytes_value < 1024.0:
            return f"{bytes_value:.1f} {unit}"
        bytes_value /= 1024.0
    return f"{bytes_value:.1f} PB"


def format_number(value: int | None) -> str:
    """Format number with thousand separators."""
    if value is None:
        return "-"
    return f"{value:,}"
