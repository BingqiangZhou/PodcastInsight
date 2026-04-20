"""Admin setup/authentication service helpers."""

import logging

from fastapi import Request, status
from fastapi.responses import RedirectResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.admin.auth import create_admin_session
from app.admin.first_run import check_admin_exists
from app.core.security import get_password_hash, verify_password
from app.domains.user.models import User, UserStatus


logger = logging.getLogger(__name__)


class AdminSetupAuthService:
    """Encapsulate admin setup/login state changes."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def admin_exists(self) -> bool:
        return await check_admin_exists()

    async def get_user_by_username(self, username: str) -> User | None:
        result = await self.db.execute(select(User).where(User.username == username))
        return result.scalar_one_or_none()

    async def get_user_by_id(self, user_id: int) -> User | None:
        result = await self.db.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()

    async def get_existing_admin_user(self, username: str, email: str) -> User | None:
        result = await self.db.execute(
            select(User).where((User.username == username) | (User.email == email)),
        )
        return result.scalar_one_or_none()

    async def create_initial_admin(
        self,
        *,
        username: str,
        email: str,
        password: str,
        account_name: str | None,
    ) -> User:
        hashed_password = get_password_hash(password)
        admin_user = User(
            username=username,
            email=email,
            hashed_password=hashed_password,
            account_name=account_name or f"Admin {username}",
            status=UserStatus.ACTIVE,
            is_superuser=True,
            is_verified=True,
        )
        self.db.add(admin_user)
        await self.db.commit()
        # No refresh needed - admin_user.id is auto-populated by SQLAlchemy after flush/commit

        logger.info("Initial admin user created: %s", username)
        return admin_user

    async def verify_login_credentials(
        self,
        *,
        username: str,
        password: str,
    ) -> User | None:
        user = await self.get_user_by_username(username)
        if not user:
            return None
        if not verify_password(password, user.hashed_password):
            return None
        return user

    def build_session_redirect(
        self, user_id: int, *, url: str, client_ip: str
    ) -> RedirectResponse:
        response = RedirectResponse(url=url, status_code=status.HTTP_303_SEE_OTHER)
        response.set_cookie(
            key="admin_session",
            value=create_admin_session(user_id, client_ip),
            httponly=True,
            secure=True,
            samesite="lax",
            max_age=30 * 60,
        )
        return response

    def build_setup_redirect(self, user_id: int, *, client_ip: str) -> RedirectResponse:
        response = RedirectResponse(
            url="/api/v1/admin",
            status_code=status.HTTP_303_SEE_OTHER,
        )
        response.set_cookie(
            key="admin_session",
            value=create_admin_session(user_id, client_ip),
            httponly=True,
            secure=True,
            samesite="lax",
            max_age=30 * 60,
        )
        return response

    @staticmethod
    def build_template_response(
        *,
        templates,
        template_name: str,
        request: Request,
        messages: list[dict] | None = None,
        status_code: int = status.HTTP_200_OK,
        **context,
    ):
        """Render a template response."""
        return templates.TemplateResponse(
            request,
            template_name,
            {
                "request": request,
                "csrf_token": "",  # Empty CSRF token for template compatibility
                "messages": messages or [],
                **context,
            },
            status_code=status_code,
        )

    @staticmethod
    def build_csrf_template_response(
        *,
        templates,
        template_name: str,
        request: Request,
        messages: list[dict] | None = None,
        status_code: int = status.HTTP_200_OK,
        **context,
    ):
        """Render a template (same as build_template_response without CSRF)."""
        return AdminSetupAuthService.build_template_response(
            templates=templates,
            template_name=template_name,
            request=request,
            messages=messages,
            status_code=status_code,
            **context,
        )

    @staticmethod
    def validate_csrf(request: Request, csrf_token: str) -> None:
        """CSRF validation is disabled."""
        pass
