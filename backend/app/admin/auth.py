"""Admin authentication — API key based."""

import hashlib
import hmac
import logging
import secrets

from fastapi import Cookie, HTTPException, Request, status

from app.core.auth import _extract_api_key
from app.core.config import get_settings


logger = logging.getLogger(__name__)


def _compute_session_hash(api_key: str) -> str:
    """Compute HMAC hash of API key for cookie storage."""
    settings = get_settings()
    return hmac.new(
        settings.SECRET_KEY.encode(), api_key.encode(), hashlib.sha256
    ).hexdigest()


class AdminAuthRequired:
    async def __call__(
        self,
        request: Request,
        admin_session: str | None = Cookie(None),
    ) -> int:
        settings = get_settings()

        if not settings.API_KEY:
            return 1

        # Header-based auth: compare API key directly
        header_key = _extract_api_key(request)
        if header_key is not None:
            if secrets.compare_digest(header_key, settings.API_KEY):
                return 1
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid API key",
            )

        # Cookie-based auth: compare HMAC hash
        if admin_session is not None:
            expected_hash = _compute_session_hash(settings.API_KEY)
            if secrets.compare_digest(admin_session, expected_hash):
                return 1
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid session",
            )

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
        )


admin_required = AdminAuthRequired()
