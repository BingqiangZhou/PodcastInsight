"""Shared utilities for admin routes."""

from fastapi import HTTPException
from fastapi.responses import JSONResponse, Response
from fastapi.templating import Jinja2Templates

from app.core.datetime_utils import (
    format_bytes,
    format_number,
    format_uptime,
    to_local_timezone,
)


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
        _templates.env.filters["to_local"] = to_local_timezone
        _templates.env.filters["format_uptime"] = format_uptime
        _templates.env.filters["format_bytes"] = format_bytes
        _templates.env.filters["format_number"] = format_number
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
        request,
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
