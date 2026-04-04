"""Admin authentication helpers and dependencies."""

import logging
from datetime import UTC, datetime

from fastapi import Cookie, Depends, HTTPException, Request, status
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import get_db_session_dependency
from app.core.config import get_settings
from app.domains.user.models import User
from app.domains.user.repositories import UserRepository


logger = logging.getLogger(__name__)

SESSION_TIMEOUT = 30 * 60


def _get_serializer() -> URLSafeTimedSerializer:
    """Build the admin session serializer lazily."""
    return URLSafeTimedSerializer(get_settings().get_secret_key())


class AdminAuthRequired:
    """Dependency to require admin authentication."""

    def __init__(self, require_2fa: bool = True):
        self.require_2fa = require_2fa

    async def __call__(
        self,
        request: Request,
        admin_session: str | None = Cookie(None),
        db: AsyncSession = Depends(get_db_session_dependency),
    ) -> User:
        if not admin_session:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Not authenticated",
            )

        try:
            data = _get_serializer().loads(admin_session, max_age=SESSION_TIMEOUT)
            user_id = data.get("user_id")
            if not user_id:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid session",
                )

            # Validate client IP matches session IP
            session_ip = data.get("client_ip")
            current_ip = request.client.host if request.client else None
            if session_ip and current_ip and session_ip != current_ip:
                logger.warning(
                    "Admin session IP mismatch: session=%s current=%s user_id=%s",
                    session_ip,
                    current_ip,
                    user_id,
                )
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Session IP mismatch",
                )

            user_repo = UserRepository(db)
            user = await user_repo.get_by_id(user_id)
            if not user or not user.is_active:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="User not found or inactive",
                )

            from app.admin.security_settings import get_admin_2fa_enabled

            admin_2fa_enabled, _ = await get_admin_2fa_enabled(db)
            if self.require_2fa and admin_2fa_enabled and not user.is_2fa_enabled:
                raise HTTPException(
                    status_code=status.HTTP_307_TEMPORARY_REDIRECT,
                    detail="2FA setup required",
                    headers={"Location": "/api/v1/admin/2fa/setup"},
                )

            return user
        except SignatureExpired as err:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Session expired",
            ) from err
        except BadSignature as err:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid session",
            ) from err
        except HTTPException:
            raise
        except Exception as err:
            logger.error("Admin auth error: %s", err)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Authentication failed",
            ) from err


def create_admin_session(user_id: int, client_ip: str) -> str:
    """Create a secure session token for admin user bound to client IP."""
    data = {
        "user_id": user_id,
        "client_ip": client_ip,
        "created_at": datetime.now(UTC).isoformat(),
    }
    return _get_serializer().dumps(data)


admin_required = AdminAuthRequired(require_2fa=True)
admin_required_no_2fa = AdminAuthRequired(require_2fa=False)
