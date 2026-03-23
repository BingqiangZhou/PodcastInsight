"""Admin setup and authentication routes module.

This module contains all routes related to:
- First-run admin setup
- Login/logout
- Two-factor authentication (2FA)
"""

import logging

from fastapi import APIRouter, Depends, Form, HTTPException, Request, status
from fastapi.responses import HTMLResponse, RedirectResponse

from app.admin.auth import admin_required, admin_required_no_2fa
from app.admin.routes._shared import get_templates
from app.admin.services import AdminSetupAuthService
from app.admin.twofa import verify_totp_token
from app.core.providers import get_admin_setup_auth_service
from app.domains.user.models import User


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
    csrf_token: str = Form(...),
    service: AdminSetupAuthService = Depends(get_admin_setup_auth_service),
):
    """Create initial admin user."""
    try:
        # Check if admin already exists
        admin_exists = await service.admin_exists()
        if admin_exists:
            return RedirectResponse(url="/api/v1/admin/login", status_code=303)

        # Validate CSRF token
        service.validate_csrf(request, csrf_token)

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
        return service.build_setup_redirect(admin_user.id)

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
    csrf_token: str = Form(...),
    service: AdminSetupAuthService = Depends(get_admin_setup_auth_service),
):
    """Handle login."""
    try:
        # Validate CSRF token
        service.validate_csrf(request, csrf_token)

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

        # Check if user has 2FA enabled AND global 2FA is enabled
        # 检查用户是否启用2FA 且 全局2FA已启用
        admin_2fa_enabled, _ = await service.get_admin_2fa_state()

        if user.is_2fa_enabled and admin_2fa_enabled:
            # User has 2FA enabled, require verification
            # 用户已启用2FA，要求验证
            response = service.build_2fa_challenge_response(
                templates=templates,
                request=request,
                user_id=user.id,
                username=username,
                csrf_token=csrf_token,
            )
            return response
        # Check if global 2FA is enabled but user hasn't set up 2FA
        # 检查全局2FA是否开启但用户未设置2FA
        if admin_2fa_enabled and not user.is_2fa_enabled:
            # Create session first (user is authenticated)
            response = service.build_setup_redirect(user.id)
            logger.info(f"User {username} logged in but required to set up 2FA")
            return response

        # No 2FA required, create session directly
        response = service.build_session_redirect(user.id, url="/api/v1/admin")

        # Log login with 2FA status
        if user.is_2fa_enabled and not admin_2fa_enabled:
            logger.info(
                f"User {username} logged in with 2FA enabled but global 2FA is disabled"
            )
        elif not admin_2fa_enabled:
            logger.info(f"User {username} logged in without 2FA (global disabled)")
        else:
            logger.info(f"User {username} logged in without 2FA configured")
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


# ==================== 2FA Routes ====================


@router.post("/login/2fa")
async def verify_2fa_login(
    request: Request,
    username: str = Form(...),
    token: str = Form(...),
    csrf_token: str = Form(...),
    service: AdminSetupAuthService = Depends(get_admin_setup_auth_service),
):
    """Verify 2FA token during login."""
    try:
        # Validate CSRF token
        service.validate_csrf(request, csrf_token)

        # Get user_id from cookie
        user_id_str = request.cookies.get("2fa_user_id")
        if not user_id_str:
            return service.build_template_response(
                templates=templates,
                template_name="2fa_verify.html",
                request=request,
                user=None,
                username=username,
                csrf_token=csrf_token,
                messages=[{"type": "error", "text": "会话已过期，请重新登录"}],
                status_code=status.HTTP_401_UNAUTHORIZED,
            )

        user_id = int(user_id_str)

        # Get user
        user = await service.get_user_by_id(user_id)

        if not user or not user.totp_secret:
            return service.build_template_response(
                templates=templates,
                template_name="2fa_verify.html",
                request=request,
                user=None,
                username=username,
                csrf_token=csrf_token,
                messages=[{"type": "error", "text": "用户未找到或未启用2FA"}],
                status_code=status.HTTP_401_UNAUTHORIZED,
            )

        # Verify TOTP token
        if not verify_totp_token(user.totp_secret, token):
            return service.build_template_response(
                templates=templates,
                template_name="2fa_verify.html",
                request=request,
                user=None,
                username=username,
                csrf_token=csrf_token,
                messages=[{"type": "error", "text": "验证码错误，请重试"}],
                status_code=status.HTTP_401_UNAUTHORIZED,
            )

        response = service.build_session_redirect(user.id, url="/api/v1/admin")
        # Clear 2FA cookie
        response.delete_cookie(key="2fa_user_id")

        logger.info(f"User {username} completed 2FA login")
        return response

    except Exception as e:
        logger.error(f"2FA verification error: {e}")
        return service.build_template_response(
            templates=templates,
            template_name="2fa_verify.html",
            request=request,
            user=None,
            username=username,
            csrf_token=csrf_token,
            messages=[{"type": "error", "text": "验证失败，请稍后重试"}],
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )


@router.get("/2fa/setup", response_class=HTMLResponse)
async def setup_2fa_page(
    request: Request,
    user: User = Depends(admin_required_no_2fa),
    service: AdminSetupAuthService = Depends(get_admin_setup_auth_service),
):
    """Display 2FA setup page."""
    try:
        # Generate new TOTP secret if not exists
        secret = await service.ensure_totp_secret(user)
        qr_payload = service.build_2fa_qr_payload(user, secret)
        return service.build_csrf_template_response(
            templates=templates,
            template_name="2fa_setup.html",
            request=request,
            user=user,
            qr_code=qr_payload["qr_code"],
            secret=qr_payload["secret"],
        )

    except Exception as e:
        logger.error(f"2FA setup page error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to load 2FA setup page",
        ) from e


@router.post("/2fa/verify")
async def verify_2fa_setup(
    request: Request,
    token: str = Form(...),
    csrf_token: str = Form(...),
    user: User = Depends(admin_required_no_2fa),
    service: AdminSetupAuthService = Depends(get_admin_setup_auth_service),
):
    """Verify and enable 2FA."""
    try:
        # Validate CSRF token
        service.validate_csrf(request, csrf_token)

        if not user.totp_secret:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="TOTP secret not found",
            )

        # Verify token
        if not verify_totp_token(user.totp_secret, token):
            qr_payload = service.build_2fa_qr_payload(user, user.totp_secret)
            return service.build_csrf_template_response(
                templates=templates,
                template_name="2fa_setup.html",
                request=request,
                user=user,
                qr_code=qr_payload["qr_code"],
                secret=user.totp_secret,
                messages=[{"type": "error", "text": "验证码错误，请重试"}],
            )

        # Enable 2FA
        await service.enable_2fa(user=user)

        logger.info(f"User {user.username} enabled 2FA")

        # Redirect to dashboard
        return RedirectResponse(url="/api/v1/admin", status_code=status.HTTP_303_SEE_OTHER)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"2FA verification error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to verify 2FA",
        ) from e


@router.post("/2fa/disable")
async def disable_2fa(
    request: Request,
    password: str = Form(...),
    csrf_token: str = Form(...),
    user: User = Depends(admin_required),
    service: AdminSetupAuthService = Depends(get_admin_setup_auth_service),
):
    """Disable 2FA for the current user."""
    try:
        # Validate CSRF token
        service.validate_csrf(request, csrf_token)

        # Verify password
        from app.core.security import verify_password

        if not verify_password(password, user.hashed_password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="密码错误",
            )

        # Disable 2FA
        await service.disable_2fa(user=user)

        logger.info(f"User {user.username} disabled 2FA")

        # Redirect to dashboard with success message
        return RedirectResponse(url="/api/v1/admin", status_code=status.HTTP_303_SEE_OTHER)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to disable 2FA: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to disable 2FA",
        ) from e
