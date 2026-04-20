"""Admin setup and authentication routes module.

This module contains all routes related to:
- First-run admin setup
- Login/logout
"""

import logging

from fastapi import APIRouter, Depends, Form, Request, status
from fastapi.responses import HTMLResponse, RedirectResponse

from app.admin.dependencies import get_admin_setup_auth_service
from app.admin.routes._shared import get_templates
from app.admin.services import AdminSetupAuthService


logger = logging.getLogger(__name__)

router = APIRouter()
templates = get_templates()


# ==================== First-Run Setup ====================


@router.get("/setup", response_class=HTMLResponse)
async def setup_page(
    request: Request,
    service: AdminSetupAuthService = Depends(get_admin_setup_auth_service),
):
    """Display first-run setup page."""
    # Check if admin already exists
    admin_exists = await service.admin_exists()
    if admin_exists:
        # Admin already exists, redirect to login
        return RedirectResponse(url="/api/v1/admin/login", status_code=303)

    return service.build_csrf_template_response(
        templates=templates,
        template_name="setup.html",
        request=request,
    )


@router.post("/setup")
async def setup_admin(
    request: Request,
    username: str = Form(...),
    email: str = Form(...),
    password: str = Form(...),
    password_confirm: str = Form(...),
    account_name: str | None = Form(None),
    service: AdminSetupAuthService = Depends(get_admin_setup_auth_service),
):
    """Create initial admin user."""
    try:
        # Check if admin already exists
        admin_exists = await service.admin_exists()
        if admin_exists:
            return RedirectResponse(url="/api/v1/admin/login", status_code=303)

        # Validate passwords match
        if password != password_confirm:
            return service.build_csrf_template_response(
                templates=templates,
                template_name="setup.html",
                request=request,
                messages=[{"type": "error", "text": "两次输入的密码不一致"}],
            )

        # Validate password length
        if len(password) < 8:
            return service.build_csrf_template_response(
                templates=templates,
                template_name="setup.html",
                request=request,
                messages=[{"type": "error", "text": "密码长度至少为8个字符"}],
            )

        # Check if username or email already exists
        existing_user = await service.get_existing_admin_user(username, email)

        if existing_user:
            return service.build_csrf_template_response(
                templates=templates,
                template_name="setup.html",
                request=request,
                messages=[{"type": "error", "text": "用户名或邮箱已存在"}],
            )

        # Create admin user
        admin_user = await service.create_initial_admin(
            username=username,
            email=email,
            password=password,
            account_name=account_name,
        )
        return service.build_setup_redirect(
            admin_user.id, client_ip=request.client.host
        )

    except Exception as e:
        logger.error(f"Setup error: {e}")
        return service.build_csrf_template_response(
            templates=templates,
            template_name="setup.html",
            request=request,
            messages=[{"type": "error", "text": "创建管理员失败，请稍后重试"}],
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )


# ==================== Login & Logout ====================


@router.get("/login", response_class=HTMLResponse)
async def login_page(request: Request, error: str = None):
    """Display login page."""
    # Convert error string to messages list format
    messages = [{"type": "error", "text": error}] if error else []
    return AdminSetupAuthService.build_csrf_template_response(
        templates=templates,
        template_name="login.html",
        request=request,
        messages=messages,
    )


@router.post("/login")
async def login(
    request: Request,
    username: str = Form(...),
    password: str = Form(...),
    service: AdminSetupAuthService = Depends(get_admin_setup_auth_service),
):
    """Handle login."""
    try:
        # Get user
        user = await service.get_user_by_username(username)

        if not user:
            return service.build_csrf_template_response(
                templates=templates,
                template_name="login.html",
                request=request,
                messages=[{"type": "error", "text": "用户名或密码错误"}],
                status_code=status.HTTP_401_UNAUTHORIZED,
            )

        # Verify password
        from app.core.security import verify_password

        if not verify_password(password, user.hashed_password):
            return service.build_csrf_template_response(
                templates=templates,
                template_name="login.html",
                request=request,
                messages=[{"type": "error", "text": "用户名或密码错误"}],
                status_code=status.HTTP_401_UNAUTHORIZED,
            )

        # Create session directly
        response = service.build_session_redirect(
            user.id, url="/api/v1/admin", client_ip=request.client.host
        )

        logger.info(f"User {username} logged in")
        return response

    except Exception as e:
        logger.error(f"Login error: {e}")
        return service.build_csrf_template_response(
            templates=templates,
            template_name="login.html",
            request=request,
            messages=[{"type": "error", "text": "登录失败，请稍后重试"}],
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )


@router.post("/logout")
async def logout():
    """Handle logout."""
    response = RedirectResponse(
        url="/api/v1/admin/login", status_code=status.HTTP_303_SEE_OTHER
    )
    response.delete_cookie(key="admin_session")
    return response
