"""Admin authentication — API key based.

Checks X-API-Key header or admin_session cookie against settings.API_KEY.
"""

import logging

from fastapi import Cookie, Depends, HTTPException, Request, status

from app.core.auth import get_db_session_dependency, require_api_key
from app.core.config import get_settings


logger = logging.getLogger(__name__)


class AdminAuthRequired:
    """Dependency to require admin authentication via API key."""

    async def __call__(
        self,
        request: Request,
        admin_session: str | None = Cookie(None),
    ) -> int:
        settings = get_settings()

        # Check X-API-Key header or Authorization header first
        auth_header = request.headers.get("Authorization")
        x_api_key = request.headers.get("X-API-Key")

        api_key = None
        if auth_header:
            if auth_header.startswith("Bearer "):
                api_key = auth_header[7:]
            else:
                api_key = auth_header
        elif x_api_key:
            api_key = x_api_key
        elif admin_session:
            # Cookie-based: admin_session cookie contains the API key directly
            api_key = admin_session

        if not settings.API_KEY:
            # No API key configured — allow all (development mode)
            return 1

        if api_key is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Not authenticated",
            )

        if api_key != settings.API_KEY:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid API key",
            )

        return 1


admin_required = AdminAuthRequired()
