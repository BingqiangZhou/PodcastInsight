"""Exception handlers for Admin Panel."""

import logging
from typing import Any

from fastapi import Request, Response
from fastapi.templating import Jinja2Templates

from app.admin.csrf import CSRFException, generate_csrf_token


logger = logging.getLogger(__name__)

# Setup Jinja2 templates
templates = Jinja2Templates(directory="app/admin/templates")


async def csrf_exception_handler(request: Request, exc: CSRFException) -> Response:
    """Handle CSRF exceptions by rendering user-friendly error pages.

    This handler intercepts CSRFException and returns HTML pages
    with friendly error messages instead of JSON responses.

    Args:
        request: The incoming request
        exc: The CSRF exception that was raised

    Returns:
        Response: HTML page with error message and new CSRF token

    """
    # Log the technical error
    logger.warning(
        f"CSRF validation failed: {exc.detail} | "
        f"Type: {exc.error_type} | "
        f"Path: {request.url.path}",
    )

    # Generate new CSRF token for retry
    new_csrf_token = generate_csrf_token()

    # Determine which template to use based on referer
    referer = request.headers.get("referer", "")

    # Map paths to their templates
    template_mapping = {
        "/api/v1/admin/setup": "setup.html",
        "/api/v1/admin/login": "login.html",
        "/api/v1/admin/2fa_setup": "2fa_setup.html",
        "/api/v1/admin/2fa_verify": "2fa_verify.html",
    }

    # Try to determine the current page from referer or path
    current_template = "login.html"  # Default fallback

    # Check if we're on a setup/login page
    for path, template in template_mapping.items():
        if path in referer or request.url.path.startswith(path):
            current_template = template
            break

    # Prepare context for template
    context: dict[str, Any] = {
        "request": request,
        "csrf_token": new_csrf_token,
        "messages": [
            {
                "type": "error",
                "text": exc.user_message,
            },
        ],
    }

    # Add page-specific context
    if current_template == "setup.html":
        context.update(
            {
                "username": "",
                "email": "",
                "account_name": "",
            }
        )

    # Render the template with error message
    response = templates.TemplateResponse(current_template, context)

    # Set new CSRF token in cookie
    response.set_cookie(
        key="csrf_token",
        value=new_csrf_token,
        httponly=True,
        secure=True,
        samesite="lax",
        max_age=3600,
    )

    return response
