"""Shared utilities for admin routes."""

from datetime import UTC, datetime

from fastapi import HTTPException
from fastapi.responses import JSONResponse, Response
from fastapi.templating import Jinja2Templates


# ==================== Template Setup ====================

# Setup Jinja2 templates with custom functions
_templates = None


def get_templates() -> Jinja2Templates:
    """Get configured Jinja2Templates instance (singleton)."""
    global _templates
    if _templates is None:
        _templates = Jinja2Templates(directory="app/admin/templates")
        # Add min function to template globals
        _templates.env.globals["min"] = min

        # Register custom filters
        _templates.env.filters['to_local'] = to_local_timezone
        _templates.env.filters['format_uptime'] = format_uptime
        _templates.env.filters['format_bytes'] = format_bytes
        _templates.env.filters['format_number'] = format_number
    return _templates


def render_admin_template(
    *,
    templates: Jinja2Templates,
    template_name: str,
    request,
    status_code: int = 200,
    **context,
):
    """Render an admin template with the request injected."""
    return templates.TemplateResponse(
        template_name,
        {
            "request": request,
            **context,
        },
        status_code=status_code,
    )


def json_payload(payload: dict | list, status_code: int = 200) -> JSONResponse:
    """Return a JSON response for admin action payloads."""
    return JSONResponse(content=payload, status_code=status_code)


def empty_response(status_code: int = 200) -> Response:
    """Return an empty HTTP response for admin actions."""
    return Response(status_code=status_code)


def xml_download_response(*, content: str, filename: str) -> Response:
    """Return an OPML/XML download response."""
    return Response(
        content=content,
        media_type="application/xml; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


def require_payload(payload, *, detail: str):
    """Raise a 404 when a service intentionally returns no payload."""
    if payload is None:
        raise HTTPException(status_code=404, detail=detail)
    return payload


# Custom filter to convert UTC datetime to local timezone (Asia/Shanghai, UTC+8)
def to_local_timezone(dt: datetime, format_str: str = '%Y-%m-%d %H:%M:%S') -> str:
    """Convert UTC datetime to Asia/Shanghai timezone and format it."""
    if dt is None:
        return '-'
    # Ensure dt is timezone-aware (assume UTC if naive)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=UTC)
    # Convert to Asia/Shanghai timezone (UTC+8)
    from zoneinfo import ZoneInfo
    shanghai_tz = ZoneInfo('Asia/Shanghai')
    local_dt = dt.astimezone(shanghai_tz)
    return local_dt.strftime(format_str)


# Custom filter for uptime formatting
def format_uptime(seconds: float) -> str:
    """Format uptime seconds to human readable string."""
    if seconds is None:
        return '-'
    days = int(seconds // 86400)
    hours = int((seconds % 86400) // 3600)
    minutes = int((seconds % 3600) // 60)
    if days > 0:
        return f"{days}天 {hours}小时"
    elif hours > 0:
        return f"{hours}小时 {minutes}分钟"
    else:
        return f"{minutes}分钟"


# Custom filter for bytes formatting
def format_bytes(bytes_value: int) -> str:
    """Format bytes to human readable string."""
    if bytes_value is None:
        return '-'
    if bytes_value >= 1073741824:
        return f"{bytes_value / 1073741824:.1f} GB"
    elif bytes_value >= 1048576:
        return f"{bytes_value / 1048576:.1f} MB"
    elif bytes_value >= 1024:
        return f"{bytes_value / 1024:.1f} KB"
    else:
        return f"{bytes_value} B"


# Custom filter for number formatting
def format_number(value: int) -> str:
    """Format number with thousand separators."""
    if value is None:
        return '-'
    return f"{value:,}"

