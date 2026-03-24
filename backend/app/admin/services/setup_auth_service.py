"""Admin setup/authentication service helpers."""

import logging

from fastapi import Request, status
from fastapi.responses import RedirectResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.admin.auth import create_admin_session
from app.admin.csrf import generate_csrf_token, validate_csrf_token
from app.admin.first_run import check_admin_exists
from app.admin.security_settings import get_admin_2fa_enabled
from app.admin.twofa import generate_qr_code, generate_totp_secret
from app.core.security import get_password_hash, verify_password
from app.domains.user.models import User, UserStatus


logger = logging.getLogger(__name__)


class AdminSetupAuthService:
    """Encapsulate admin setup/login/2FA state changes."""

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

        admin_user.totp_secret = generate_totp_secret()
        await self.db.commit()
        # No refresh needed - admin_user is already in session with updated values
        logger.info("Initial admin user created: %s", username)
        return admin_user

    async def ensure_totp_secret(self, user: User) -> str:
        if not user.totp_secret:
            user.totp_secret = generate_totp_secret()
            await self.db.commit()
            # No refresh needed - user is already in session with updated values
        return user.totp_secret

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

    async def get_admin_2fa_state(self) -> tuple[bool, str]:
        return await get_admin_2fa_enabled(self.db)

    async def disable_2fa(self, *, user: User) -> None:
        user.is_2fa_enabled = False
        user.totp_secret = None
        await self.db.commit()

    async def enable_2fa(self, *, user: User) -> None:
        user.is_2fa_enabled = True
        await self.db.commit()

    def build_setup_redirect(self, user_id: int) -> RedirectResponse:
        response = RedirectResponse(
            url="/api/v1/admin/2fa/setup",
            status_code=status.HTTP_303_SEE_OTHER,
        )
        response.set_cookie(
            key="admin_session",
            value=create_admin_session(user_id),
            httponly=True,
            secure=True,
            samesite="lax",
            max_age=30 * 60,
        )
        return response

    def build_session_redirect(self, user_id: int, *, url: str) -> RedirectResponse:
        response = RedirectResponse(url=url, status_code=status.HTTP_303_SEE_OTHER)
        response.set_cookie(
            key="admin_session",
            value=create_admin_session(user_id),
            httponly=True,
            secure=True,
            samesite="lax",
            max_age=30 * 60,
        )
        return response

    def build_2fa_challenge_response(
        self,
        *,
        templates,
        request: Request,
        user_id: int,
        username: str,
        csrf_token: str,
    ):
        """Render the 2FA challenge page and persist the pending user id."""
        response = self.build_template_response(
            templates=templates,
            template_name="2fa_verify.html",
            request=request,
            user=None,
            username=username,
            csrf_token=csrf_token,
        )
        response.set_cookie(
            key="2fa_user_id",
            value=str(user_id),
            httponly=True,
            secure=True,
            samesite="lax",
            max_age=5 * 60,
        )
        return response

    @staticmethod
    def build_csrf_cookie_response(response):
        response.set_cookie(
            key="csrf_token",
            value=generate_csrf_token(),
            httponly=True,
            secure=True,
            samesite="lax",
            max_age=3600,
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
        """Render a template response without mutating CSRF cookies."""
        return templates.TemplateResponse(
            template_name,
            {
                "request": request,
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
        """Render a template with a fresh CSRF token and matching cookie."""
        csrf_token = generate_csrf_token()
        response = templates.TemplateResponse(
            template_name,
            {
                "request": request,
                "csrf_token": csrf_token,
                "messages": messages or [],
                **context,
            },
            status_code=status_code,
        )
        response.set_cookie(
            key="csrf_token",
            value=csrf_token,
            httponly=True,
            secure=True,
            samesite="lax",
            max_age=3600,
        )
        return response

    @staticmethod
    def validate_csrf(request: Request, csrf_token: str) -> None:
        validate_csrf_token(request, csrf_token)

    @staticmethod
    def build_2fa_qr_payload(user: User, secret: str) -> dict[str, str]:
        return {
            "secret": secret,
            "qr_code": generate_qr_code(user.username or user.email, secret),
        }
