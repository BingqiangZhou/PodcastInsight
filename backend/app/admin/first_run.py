"""First-run setup middleware for admin panel."""

import logging

from fastapi import Request
from fastapi.responses import RedirectResponse
from sqlalchemy import select

from app.core.database import get_async_session_factory
from app.domains.user.models import User


logger = logging.getLogger(__name__)


async def check_admin_exists() -> bool:
    """Check if any superuser exists in the database.

    Returns:
        True if at least one superuser exists, False otherwise

    """
    try:
        session_factory = get_async_session_factory()
        async with session_factory() as db:
            result = await db.execute(
                select(User).where(User.is_superuser).limit(1),
            )
            admin_user = result.scalar_one_or_none()
            return admin_user is not None
    except Exception as e:
        logger.error(f"Error checking admin existence: {e}")
        # If there's an error, assume admin exists to avoid blocking access
        return True


async def first_run_middleware(request: Request, call_next):
    """Middleware to redirect to setup page if no admin user exists.

    This middleware checks if any superuser exists in the database.
    If not, it redirects all /api/v1/admin/* requests (except /api/v1/admin/setup)
    to the setup page.
    """
    # Only apply to /api/v1/admin routes
    if not request.url.path.startswith("/api/v1/admin"):
        return await call_next(request)

    # Allow access to setup page itself
    if request.url.path.startswith("/api/v1/admin/setup"):
        return await call_next(request)

    # Allow access to static files
    if request.url.path.startswith("/api/v1/admin/static"):
        return await call_next(request)

    # Check if admin exists
    admin_exists = await check_admin_exists()

    if not admin_exists:
        # Redirect to setup page
        logger.info(f"No admin user found, redirecting {request.url.path} to setup")
        return RedirectResponse(url="/api/v1/admin/setup", status_code=303)

    # Admin exists, continue normally
    return await call_next(request)
