"""Admin authentication — API key based."""

import logging

from fastapi import Cookie, HTTPException, Request, status

from app.core.auth import _extract_api_key
from app.core.config import get_settings


logger = logging.getLogger(__name__)


class AdminAuthRequired:
    async def __call__(
        self,
        request: Request,
        admin_session: str | None = Cookie(None),
    ) -> int:
        settings = get_settings()
        api_key = _extract_api_key(request) or admin_session

        if not settings.API_KEY:
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
