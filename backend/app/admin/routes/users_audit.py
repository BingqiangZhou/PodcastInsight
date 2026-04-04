"""Admin users and audit routes module.

This module contains all routes related to:
- User management (list, toggle status, reset password)
- Audit log viewing (with filtering and pagination)
"""

import logging

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse

from app.admin.auth import admin_required
from app.admin.dependencies import get_admin_users_audit_service
from app.admin.routes._shared import get_templates, json_payload, render_admin_template
from app.admin.services.users_audit_service import AdminUsersAuditService
from app.domains.user.models import User


logger = logging.getLogger(__name__)

router = APIRouter()
templates = get_templates()


# ==================== Audit Log Management ====================


@router.get("/audit-logs", response_class=HTMLResponse)
async def audit_logs_page(
    request: Request,
    user: User = Depends(admin_required),
    service: AdminUsersAuditService = Depends(get_admin_users_audit_service),
    page: int = 1,
    per_page: int = 10,
    action: str | None = None,
    resource_type: str | None = None,
):
    """Display audit logs page with filtering and pagination."""
    try:
        context = await service.get_audit_logs_context(
            page=page,
            per_page=per_page,
            action=action,
            resource_type=resource_type,
        )

        return render_admin_template(
            templates=templates,
            template_name="audit_logs.html",
            request=request,
            user=user,
            messages=[],
            **context,
        )
    except Exception as exc:
        logger.error("Audit logs page error: %s", exc)
        raise HTTPException(
            status_code=500,
            detail="Failed to load audit logs",
        ) from exc


# ==================== User Management ====================


@router.get("/users", response_class=HTMLResponse)
async def users_page(
    request: Request,
    user: User = Depends(admin_required),
    service: AdminUsersAuditService = Depends(get_admin_users_audit_service),
    page: int = 1,
    per_page: int = 10,
):
    """Display users management page with pagination."""
    try:
        context = await service.get_users_context(page=page, per_page=per_page)

        return render_admin_template(
            templates=templates,
            template_name="users.html",
            request=request,
            user=user,
            messages=[],
            **context,
        )
    except Exception as exc:
        logger.error("Users page error: %s", exc)
        raise HTTPException(
            status_code=500,
            detail="Failed to load users",
        ) from exc


@router.put("/users/{user_id}/toggle")
async def toggle_user(
    user_id: int,
    request: Request,
    user: User = Depends(admin_required),
    service: AdminUsersAuditService = Depends(get_admin_users_audit_service),
):
    """Toggle user active status."""
    try:
        return json_payload(
            await service.toggle_user(
                request=request,
                user=user,
                target_user_id=user_id,
            ),
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Toggle user error: %s", exc)
        raise HTTPException(
            status_code=500,
            detail="Failed to toggle user",
        ) from exc


@router.put("/users/{user_id}/reset-password")
async def reset_user_password(
    user_id: int,
    request: Request,
    user: User = Depends(admin_required),
    service: AdminUsersAuditService = Depends(get_admin_users_audit_service),
):
    """Reset user password to a random value."""
    try:
        return json_payload(
            await service.reset_user_password_action(
                request=request,
                user=user,
                target_user_id=user_id,
            ),
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Reset password error: %s", exc)
        raise HTTPException(
            status_code=500,
            detail="Failed to reset password",
        ) from exc
