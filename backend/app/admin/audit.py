"""Admin audit log utilities."""

import logging
from typing import Any

from fastapi import Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.admin.models import AdminAuditLog


logger = logging.getLogger(__name__)


async def log_admin_action(
    db: AsyncSession,
    user_id: int,
    username: str,
    action: str,
    resource_type: str,
    resource_id: int | None = None,
    resource_name: str | None = None,
    details: dict[str, Any] | None = None,
    request: Request | None = None,
    status: str = "success",
    error_message: str | None = None,
) -> AdminAuditLog:
    """Log an admin action to the audit log.

    Args:
        db: Database session
        user_id: ID of the user performing the action
        username: Username of the user
        action: Action performed (create, update, delete, toggle, etc.)
        resource_type: Type of resource (apikey, subscription, user, etc.)
        resource_id: ID of the resource (optional)
        resource_name: Name of the resource (optional)
        details: Additional details about the operation (optional)
        request: FastAPI request object for IP and user agent (optional)
        status: Status of the operation (success, failed)
        error_message: Error message if operation failed (optional)

    Returns:
        Created audit log entry

    """
    try:
        # Extract IP and user agent from request if provided
        ip_address = None
        user_agent = None
        if request:
            ip_address = request.client.host if request.client else None
            user_agent = request.headers.get("user-agent")

        # Create audit log entry
        audit_log = AdminAuditLog(
            user_id=user_id,
            username=username,
            action=action,
            resource_type=resource_type,
            resource_id=resource_id,
            resource_name=resource_name,
            details=details,
            ip_address=ip_address,
            user_agent=user_agent,
            status=status,
            error_message=error_message,
        )

        db.add(audit_log)
        await db.commit()
        # No refresh needed - audit_log.id is auto-populated by SQLAlchemy after flush/commit

        logger.info(
            f"Audit log created: user={username}, action={action}, "
            f"resource={resource_type}:{resource_id}, status={status}",
        )

        return audit_log

    except Exception as e:
        logger.error(f"Failed to create audit log: {e}")
        # Don't fail the main operation if audit logging fails
        await db.rollback()
        raise
