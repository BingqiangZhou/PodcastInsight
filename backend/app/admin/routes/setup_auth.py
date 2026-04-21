"""Admin login/logout routes (API key mode)."""

import logging

from fastapi import APIRouter, Form, Request, status
from fastapi.responses import HTMLResponse, RedirectResponse

from app.admin.routes._shared import get_templates
from app.core.config import get_settings


logger = logging.getLogger(__name__)

router = APIRouter()
templates = get_templates()


@router.get("/login", response_class=HTMLResponse)
async def login_page(request: Request, error: str = None):
    """Display login page."""
    messages = [{"type": "error", "text": error}] if error else []
    from app.admin.services.setup_auth_service import AdminSetupAuthService

    return AdminSetupAuthService.build_template_response(
        templates=templates,
        template_name="login.html",
        request=request,
        messages=messages,
    )


@router.post("/login")
async def login(
    request: Request,
    api_key: str = Form(...),
):
    """Handle login with API key."""
    settings = get_settings()

    if not settings.API_KEY:
        # No API key configured — redirect directly to admin
        response = RedirectResponse(
            url="/api/v1/admin", status_code=status.HTTP_303_SEE_OTHER
        )
        return response

    if api_key != settings.API_KEY:
        from app.admin.services.setup_auth_service import AdminSetupAuthService

        return AdminSetupAuthService.build_template_response(
            templates=templates,
            template_name="login.html",
            request=request,
            messages=[{"type": "error", "text": "API key is incorrect"}],
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    response = RedirectResponse(
        url="/api/v1/admin", status_code=status.HTTP_303_SEE_OTHER
    )
    response.set_cookie(
        key="admin_session",
        value=api_key,
        httponly=True,
        secure=True,
        samesite="lax",
        max_age=30 * 60,
    )
    logger.info("Admin logged in via API key")
    return response


@router.post("/logout")
async def logout():
    """Handle logout."""
    response = RedirectResponse(
        url="/api/v1/admin/login", status_code=status.HTTP_303_SEE_OTHER
    )
    response.delete_cookie(key="admin_session")
    return response
