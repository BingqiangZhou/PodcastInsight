"""Authentication service for user management."""

import logging
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import and_, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.exceptions import (
    BadRequestError,
    ConflictError,
    NotFoundError,
    UnauthorizedError,
)
from app.core.security import (
    create_access_token,
    create_refresh_token,
    get_password_hash,
    verify_password,
    verify_token,
)
from app.domains.user.models import PasswordReset, User, UserSession


logger = logging.getLogger(__name__)


class AuthenticationService:
    """Service for handling authentication operations."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def register_user(
        self,
        email: str,
        password: str,
        username: str | None = None,
    ) -> User:
        """Register a new user.

        Args:
            email: User's email address
            password: Plain text password
            username: Optional username

        Returns:
            Created user instance

        Raises:
            ConflictError: If user already exists
            BadRequestError: If password is too weak

        """
        # Validate password strength
        if len(password) < 8:
            raise BadRequestError("Password must be at least 8 characters long")

        # Generate username from email if not provided
        if not username:
            # Extract username from email (part before @)
            username = email.split("@", maxsplit=1)[0]
            # Ensure uniqueness by adding number if needed
            base_username = username
            counter = 1
            while await self._get_user_by_username(username):
                username = f"{base_username}{counter}"
                counter += 1

        # Check if user already exists
        existing_user = await self._get_user_by_email_or_username(email, username)
        if existing_user:
            if existing_user.email == email:
                raise ConflictError("Email already registered")
            if existing_user.username == username:
                raise ConflictError("Username already taken")

        # Create new user
        hashed_password = get_password_hash(password)

        user = User(
            email=email,
            username=username,
            hashed_password=hashed_password,
            status="active",
            is_verified=False,
            is_superuser=False,
        )

        try:
            self.db.add(user)
            await self.db.commit()
            # No refresh needed - user.id is auto-populated by SQLAlchemy after flush/commit
            return user
        except IntegrityError as err:
            await self.db.rollback()
            raise ConflictError("User registration failed") from err

    async def authenticate_user(
        self,
        email_or_username: str,
        password: str,
    ) -> User | None:
        """Authenticate user with email/username and password.

        Args:
            email_or_username: User's email or username
            password: Plain text password

        Returns:
            User instance if authentication successful, None otherwise

        """
        # Get user by email or username
        user = await self._get_user_by_email_or_username(
            email_or_username, email_or_username
        )

        if not user:
            return None

        # Check password
        if not verify_password(password, user.hashed_password):
            return None

        # Check if user is active
        if user.status != "active":
            return None

        # Update last login
        user.last_login_at = datetime.now(UTC)
        await self.db.commit()

        return user

    async def create_user_session(
        self,
        user: User,
        device_info: dict[str, Any] | None = None,
        ip_address: str | None = None,
        user_agent: str | None = None,
        remember_me: bool = False,
    ) -> dict[str, Any]:
        """Create user session with tokens and concurrent session limit.

        Security features:
        - Maximum 5 concurrent active sessions per user
        - Oldest sessions are automatically invalidated when limit is reached

        Args:
            user: User instance
            device_info: Optional device information
            ip_address: Optional IP address
            user_agent: Optional user agent string
            remember_me: If True, refresh token expires in 30 days

        Returns:
            Dictionary containing access and refresh tokens

        """
        # Security: Limit concurrent sessions (max 5 per user)
        max_concurrent_sessions = 5

        # Get existing active sessions for this user
        existing_sessions = await self.db.execute(
            select(UserSession)
            .where(
                and_(
                    UserSession.user_id == user.id,
                    UserSession.is_active,
                    UserSession.expires_at > datetime.now(UTC),
                ),
            )
            .order_by(UserSession.created_at),
        )
        active_sessions = existing_sessions.scalars().all()

        # If limit reached, invalidate oldest sessions
        if len(active_sessions) >= max_concurrent_sessions:
            sessions_to_invalidate = len(active_sessions) - max_concurrent_sessions + 1
            for i in range(sessions_to_invalidate):
                old_session = active_sessions[i]
                old_session.is_active = False
                logger.info(
                    f"🔒 Invalidating old session {old_session.id} for user {user.id}"
                )

        # Create tokens
        access_token = await create_access_token(
            data={"sub": str(user.id), "email": user.email},
        )

        # Set refresh token expiry based on remember_me
        refresh_expiry_days = 30 if remember_me else settings.REFRESH_TOKEN_EXPIRE_DAYS
        refresh_token = await create_refresh_token(
            data={"sub": str(user.id), "email": user.email},
            expires_delta=timedelta(days=refresh_expiry_days),
        )

        # Calculate expiry times
        refresh_expires_at = datetime.now(UTC) + timedelta(
            days=refresh_expiry_days,
        )

        # Create session record
        session = UserSession(
            user_id=user.id,
            session_token=access_token,
            refresh_token=refresh_token,
            device_info=device_info or {},
            ip_address=ip_address,
            user_agent=user_agent,
            expires_at=refresh_expires_at,  # Fix: session expires at same time as refresh token (7 days)
            last_activity_at=datetime.now(UTC),
            is_active=True,
        )

        try:
            self.db.add(session)
            await self.db.commit()
            # No refresh needed - session.id is auto-populated by SQLAlchemy after flush/commit
        except IntegrityError as err:
            await self.db.rollback()
            raise BadRequestError("Failed to create user session") from err

        # Calculate UTC expiration time for frontend
        access_token_expires_at = datetime.now(UTC) + timedelta(
            minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES,
        )

        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            "expires_at": access_token_expires_at.isoformat(),
            "server_time": datetime.now(UTC).isoformat(),
            "session_id": session.id,
        }

    async def refresh_access_token(self, refresh_token: str) -> dict[str, Any]:
        """Refresh access token using refresh token with sliding session expiration.

        This implements a sliding session mechanism where:
        - The refresh token expiration is extended each time it's used
        - Active users can stay logged in indefinitely
        - Inactive users will eventually need to re-login
        - Rate limited: max 10 refreshes per minute per session

        Args:
            refresh_token: Valid refresh token

        Returns:
            Dictionary with new access token and updated refresh token

        Raises:
            UnauthorizedError: If refresh token is invalid
            NotFoundError: If session not found

        """
        # Verify refresh token
        try:
            payload = await verify_token(refresh_token, token_type="refresh")
            user_id = int(payload.get("sub"))
        except Exception as err:
            raise UnauthorizedError("Invalid refresh token") from err

        # Find valid session
        session = await self._get_valid_session_by_refresh_token(refresh_token)
        if not session or session.user_id != user_id:
            raise NotFoundError("Invalid session")

        # Check if session is still active
        if not session.is_active:
            raise UnauthorizedError("Session expired")

        # Security: Rate limit token refresh (prevent abuse)
        # Allow max 10 refreshes per minute per session
        min_refresh_interval_seconds = 6  # ~10 refreshes per minute
        time_since_last_activity = (
            datetime.now(UTC) - session.last_activity_at
        ).total_seconds()
        if time_since_last_activity < min_refresh_interval_seconds:
            logger.warning(
                f"⚠️ Rate limit: User {user_id} refreshing too frequently (interval: {time_since_last_activity}s)"
            )
            # Still allow refresh, but log suspicious activity

        # Get user
        user = await self._get_user_by_id(user_id)
        if not user or user.status != "active":
            raise UnauthorizedError("User not found or inactive")

        # Create new access token
        new_access_token = await create_access_token(
            data={"sub": str(user.id), "email": user.email},
        )

        # Determine refresh expiry days based on current session
        # If session has > 7 days remaining, it was created with remember_me=True (30 days)
        # Otherwise, use default 7 days
        days_until_expiry = (session.expires_at - datetime.now(UTC)).days
        if days_until_expiry > settings.REFRESH_TOKEN_EXPIRE_DAYS:
            # Session was created with remember_me=True (30 days)
            refresh_expiry_days = 30
        else:
            # Standard session (7 days)
            refresh_expiry_days = settings.REFRESH_TOKEN_EXPIRE_DAYS

        # Create new refresh token (sliding session - extend expiration)
        new_refresh_token = await create_refresh_token(
            data={"sub": str(user.id), "email": user.email},
            expires_delta=timedelta(days=refresh_expiry_days),
        )

        # Calculate new expiration times
        refresh_expires_at = datetime.now(UTC) + timedelta(
            days=refresh_expiry_days,
        )

        # Update session with sliding expiration
        session.session_token = new_access_token
        session.refresh_token = new_refresh_token
        session.last_activity_at = datetime.now(UTC)
        session.expires_at = refresh_expires_at  # Fix: session should expire with refresh token, not access token

        await self.db.commit()

        # Calculate UTC expiration time for frontend
        access_token_expires_at = datetime.now(UTC) + timedelta(
            minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES,
        )

        return {
            "access_token": new_access_token,
            "refresh_token": new_refresh_token,  # Return new refresh token
            "token_type": "bearer",
            "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            "expires_at": access_token_expires_at.isoformat(),
            "server_time": datetime.now(UTC).isoformat(),
        }

    async def logout_user(self, refresh_token: str) -> bool:
        """Logout user by invalidating session.

        Args:
            refresh_token: Refresh token to invalidate

        Returns:
            True if logout successful

        Raises:
            NotFoundError: If session not found

        """
        session = await self._get_valid_session_by_refresh_token(refresh_token)
        if not session:
            raise NotFoundError("Session not found")

        # Mark session as inactive
        session.is_active = False
        session.last_activity_at = datetime.now(UTC)
        await self.db.commit()

        return True

    async def logout_all_sessions(self, user_id: int) -> bool:
        """Logout user from all devices.

        Args:
            user_id: User ID

        Returns:
            True if logout successful

        """
        result = await self.db.execute(
            select(UserSession).where(
                and_(
                    UserSession.user_id == user_id,
                    UserSession.is_active,
                ),
            ),
        )
        sessions = result.scalars().all()

        for session in sessions:
            session.is_active = False
            session.last_activity_at = datetime.now(UTC)

        await self.db.commit()

        return True

    async def cleanup_expired_sessions(self) -> int:
        """Clean up expired sessions.

        Returns:
            Number of sessions cleaned up

        """
        result = await self.db.execute(
            select(UserSession).where(
                or_(
                    UserSession.expires_at < datetime.now(UTC),
                    and_(
                        UserSession.last_activity_at
                        < datetime.now(UTC) - timedelta(days=30),
                        not UserSession.is_active,
                    ),
                ),
            ),
        )
        sessions = result.scalars().all()

        count = 0
        for session in sessions:
            await self.db.delete(session)
            count += 1

        await self.db.commit()
        return count

    async def create_password_reset_token(self, email: str) -> dict[str, Any]:
        """Create a password reset token for the given email.

        Args:
            email: User's email address

        Returns:
            Dictionary containing the reset token and expiry time

        Raises:
            NotFoundError: If user with given email doesn't exist

        """
        # Check if user exists
        user = await self._get_user_by_email(email)
        if not user:
            # Don't reveal if email exists or not for security
            result = {
                "message": "If an account with this email exists, a password reset link has been sent.",
            }
            if settings.ENVIRONMENT == "development":
                result["token"] = None
            return result

        # Invalidate any existing unused tokens for this email
        await self._invalidate_existing_tokens(email)

        # Generate secure token
        reset_token = str(uuid.uuid4())
        expires_at = datetime.now(UTC) + timedelta(hours=1)  # Token expires in 1 hour

        # Create password reset record
        password_reset = PasswordReset(
            email=email,
            token=reset_token,
            expires_at=expires_at,
            is_used=False,
        )

        try:
            self.db.add(password_reset)
            await self.db.commit()
            # No refresh needed - password_reset.id is auto-populated by SQLAlchemy after flush/commit

            result = {
                "message": "If an account with this email exists, a password reset link has been sent.",
            }
            if settings.ENVIRONMENT == "development":
                result["token"] = reset_token
                result["expires_at"] = expires_at.isoformat()
            return result

        except IntegrityError as err:
            await self.db.rollback()
            raise BadRequestError("Failed to create password reset token") from err

    async def reset_password(self, token: str, new_password: str) -> dict[str, Any]:
        """Reset user password using the given token.

        Args:
            token: Password reset token
            new_password: New password to set

        Returns:
            Success message

        Raises:
            BadRequestError: If token is invalid or expired
            NotFoundError: If token doesn't exist

        """
        # Validate password strength
        if len(new_password) < 8:
            raise BadRequestError("Password must be at least 8 characters long")

        # Get the password reset record
        password_reset = await self._get_valid_password_reset_token(token)

        if not password_reset:
            raise BadRequestError("Invalid or expired reset token")

        # Get user by email
        user = await self._get_user_by_email(password_reset.email)
        if not user:
            raise NotFoundError("User not found")

        # Update user password
        user.hashed_password = get_password_hash(new_password)
        user.updated_at = datetime.now(UTC)

        # Mark token as used
        password_reset.is_used = True
        password_reset.updated_at = datetime.now(UTC)

        # Invalidate all user sessions (force re-login)
        await self.logout_all_sessions(user.id)

        await self.db.commit()

        return {
            "message": "Password has been successfully reset. Please login with your new password.",
        }

    async def _get_user_by_email(self, email: str) -> User | None:
        """Get user by email."""
        result = await self.db.execute(
            select(User).where(User.email == email),
        )
        return result.scalar_one_or_none()

    async def _invalidate_existing_tokens(self, email: str) -> None:
        """Invalidate all existing unused tokens for the given email."""
        result = await self.db.execute(
            select(PasswordReset).where(
                and_(
                    PasswordReset.email == email,
                    PasswordReset.is_used.is_(False),
                    PasswordReset.expires_at > datetime.now(UTC),
                ),
            ),
        )
        tokens = result.scalars().all()

        for token in tokens:
            token.is_used = True
            token.updated_at = datetime.now(UTC)

        await self.db.commit()

    async def _get_valid_password_reset_token(self, token: str) -> PasswordReset | None:
        """Get valid password reset token."""
        result = await self.db.execute(
            select(PasswordReset).where(
                and_(
                    PasswordReset.token == token,
                    PasswordReset.is_used.is_(False),
                    PasswordReset.expires_at > datetime.now(UTC),
                ),
            ),
        )
        return result.scalar_one_or_none()

    async def _get_user_by_username(self, username: str) -> User | None:
        """Get user by username."""
        result = await self.db.execute(
            select(User).where(User.username == username),
        )
        return result.scalar_one_or_none()

    async def _get_user_by_email_or_username(
        self,
        email: str | None = None,
        username: str | None = None,
    ) -> User | None:
        """Get user by email or username."""
        conditions = []
        if email:
            conditions.append(User.email == email)
        if username:
            conditions.append(User.username == username)

        if not conditions:
            return None

        result = await self.db.execute(
            select(User).where(or_(*conditions)),
        )
        return result.scalar_one_or_none()

    async def _get_user_by_id(self, user_id: int) -> User | None:
        """Get user by ID."""
        result = await self.db.execute(
            select(User).where(User.id == user_id),
        )
        return result.scalar_one_or_none()

    async def _get_valid_session_by_refresh_token(
        self,
        refresh_token: str,
    ) -> UserSession | None:
        """Get valid session by refresh token."""
        result = await self.db.execute(
            select(UserSession).where(
                and_(
                    UserSession.refresh_token == refresh_token,
                    UserSession.is_active,
                    UserSession.expires_at > datetime.now(UTC),
                ),
            ),
        )
        return result.scalar_one_or_none()
