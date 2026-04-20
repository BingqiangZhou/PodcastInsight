"""User repository for CRUD operations on User model."""

from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domains.user.models import PasswordReset, User, UserSession, UserStatus
from app.shared.repository_helpers import resolve_window_total
from app.shared.schemas import UserCreate, UserUpdate


class UserRepository:
    """User data access layer.

    Provides standard CRUD operations plus domain-specific queries
    for the User model, following the repository pattern established
    by SubscriptionRepository and podcast repositories.
    """

    def __init__(self, db: AsyncSession):
        self.db = db

    # -- Lookup helpers -------------------------------------------------------

    async def get_by_id(self, user_id: int) -> User | None:
        """Get user by primary key."""
        result = await self.db.execute(
            select(User).filter(User.id == user_id),
        )
        return result.scalar_one_or_none()

    async def get_by_email(self, email: str) -> User | None:
        """Get user by email address."""
        result = await self.db.execute(
            select(User).filter(User.email == email),
        )
        return result.scalar_one_or_none()

    async def get_by_username(self, username: str) -> User | None:
        """Get user by username."""
        result = await self.db.execute(
            select(User).filter(User.username == username),
        )
        return result.scalar_one_or_none()

    async def get_by_api_key(self, api_key: str) -> User | None:
        """Get user by API key."""
        result = await self.db.execute(
            select(User).filter(User.api_key == api_key),
        )
        return result.scalar_one_or_none()

    async def get_by_email_or_username(
        self,
        email: str | None = None,
        username: str | None = None,
    ) -> User | None:
        """Get user by email or username (either match)."""
        conditions: list = []
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

    # -- Query methods --------------------------------------------------------

    async def list_users(
        self,
        page: int = 1,
        size: int = 20,
        status: str | None = None,
        search: str | None = None,
    ) -> tuple[list[User], int]:
        """List users with pagination, optional status filter and search.

        Args:
            page: 1-indexed page number.
            size: Page size (1-100).
            status: Optional status filter (active, inactive, suspended).
            search: Optional case-insensitive search on email/username.

        Returns:
            Tuple of (users, total_count).
        """
        skip = (page - 1) * size
        base_query = select(User)

        if status:
            base_query = base_query.where(User.status == status)

        if search:
            search_term = f"%{search}%"
            base_query = base_query.where(
                or_(
                    User.email.ilike(search_term),
                    User.username.ilike(search_term),
                    User.account_name.ilike(search_term),
                ),
            )

        query = (
            base_query.add_columns(func.count(User.id).over())
            .offset(skip)
            .limit(size)
            .order_by(User.created_at.desc())
        )

        result = await self.db.execute(query)
        rows = result.all()
        total = await resolve_window_total(
            self.db,
            rows,
            total_index=1,
            fallback_count_query=select(func.count()).select_from(
                base_query.subquery(),
            ),
        )
        users = [row[0] for row in rows]
        return users, total

    async def count_active_users(self) -> int:
        """Count users with active status."""
        result = await self.db.scalar(
            select(func.count())
            .select_from(User)
            .where(
                User.status == UserStatus.ACTIVE,
            ),
        )
        return result or 0

    # -- Mutation methods -----------------------------------------------------

    async def create(self, user_data: UserCreate) -> User:
        """Create a new user.

        Args:
            user_data: Pydantic schema with user creation fields.

        Returns:
            The created User instance.
        """
        from app.core.security import get_password_hash

        hashed_password = get_password_hash(user_data.password)
        user_status = UserStatus.ACTIVE if user_data.is_active else UserStatus.INACTIVE
        db_user = User(
            email=user_data.email,
            username=user_data.username,
            account_name=user_data.account_name,
            hashed_password=hashed_password,
            status=user_status,
            is_superuser=user_data.is_superuser,
        )

        self.db.add(db_user)
        await self.db.commit()
        # No refresh needed - db_user.id is auto-populated by SQLAlchemy after flush/commit
        return db_user

    async def create_user(
        self,
        *,
        email: str,
        username: str | None = None,
        hashed_password: str | None = None,
        status: str = UserStatus.ACTIVE,
        is_superuser: bool = False,
        account_name: str | None = None,
    ) -> User:
        """Create a new user from explicit fields.

        This is the low-level alternative to ``create`` that accepts
        individual keyword arguments instead of a Pydantic schema,
        useful when the caller already has a hashed password.

        Args:
            email: User email address.
            username: Optional username.
            hashed_password: Pre-hashed password.
            status: Initial user status.
            is_superuser: Whether user has admin privileges.
            account_name: Display name.

        Returns:
            The created User instance.
        """
        user = User(
            email=email,
            username=username,
            hashed_password=hashed_password or "",
            status=status,
            is_superuser=is_superuser,
            account_name=account_name,
        )
        self.db.add(user)
        await self.db.commit()
        return user

    async def update(self, user_id: int, user_data: UserUpdate) -> User | None:
        """Update user fields from a UserUpdate schema.

        Only fields explicitly set (exclude_unset) will be applied.

        Args:
            user_id: Primary key of the user to update.
            user_data: Pydantic schema with updatable fields.

        Returns:
            Updated User instance, or None if user not found.
        """
        user = await self.get_by_id(user_id)
        if not user:
            return None

        update_data = user_data.dict(exclude_unset=True)
        for field, value in update_data.items():
            setattr(user, field, value)

        await self.db.commit()
        # No refresh needed - user is already in session with updated values
        return user

    async def update_password(self, user_id: int, hashed_password: str) -> User | None:
        """Update user password (expects pre-hashed value).

        Args:
            user_id: Primary key of the user.
            hashed_password: The new bcrypt-hashed password.

        Returns:
            Updated User, or None if user not found.
        """
        user = await self.get_by_id(user_id)
        if not user:
            return None

        user.hashed_password = hashed_password
        user.updated_at = datetime.now(UTC)
        await self.db.commit()
        return user

    async def update_last_login(self, user_id: int) -> User | None:
        """Record the current time as last_login_at.

        Args:
            user_id: Primary key of the user.

        Returns:
            Updated User, or None if user not found.
        """
        user = await self.get_by_id(user_id)
        if not user:
            return None

        user.last_login_at = datetime.now(UTC)
        await self.db.commit()
        return user

    async def update_status(self, user_id: int, status: UserStatus) -> User | None:
        """Change user status (active / inactive / suspended).

        Args:
            user_id: Primary key of the user.
            status: New UserStatus value.

        Returns:
            Updated User, or None if user not found.
        """
        user = await self.get_by_id(user_id)
        if not user:
            return None

        user.status = status
        await self.db.commit()
        return user

    async def update_settings(
        self,
        user_id: int,
        settings: dict,
    ) -> User | None:
        """Replace user settings JSON blob.

        Args:
            user_id: Primary key of the user.
            settings: New settings dictionary.

        Returns:
            Updated User, or None if user not found.
        """
        user = await self.get_by_id(user_id)
        if not user:
            return None

        user.settings = settings
        await self.db.commit()
        return user

    async def update_preferences(
        self,
        user_id: int,
        preferences: dict,
    ) -> User | None:
        """Replace user preferences JSON blob.

        Args:
            user_id: Primary key of the user.
            preferences: New preferences dictionary.

        Returns:
            Updated User, or None if user not found.
        """
        user = await self.get_by_id(user_id)
        if not user:
            return None

        user.preferences = preferences
        await self.db.commit()
        return user

    async def delete(self, user_id: int) -> bool:
        """Hard-delete a user by primary key.

        Args:
            user_id: Primary key of the user.

        Returns:
            True if the user was deleted, False if not found.
        """
        user = await self.get_by_id(user_id)
        if not user:
            return False

        await self.db.delete(user)
        await self.db.commit()
        return True

    async def verify_email(self, user_id: int) -> User | None:
        """Mark user email as verified.

        Args:
            user_id: Primary key of the user.

        Returns:
            Updated User, or None if user not found.
        """
        user = await self.get_by_id(user_id)
        if not user:
            return None

        user.is_verified = True
        await self.db.commit()
        return user

    # -- Password reset helpers -----------------------------------------------

    async def create_password_reset(
        self,
        email: str,
        token: str,
        expires_at: datetime,
    ) -> PasswordReset:
        """Create a password reset record.

        Args:
            email: User email address.
            token: Secure reset token.
            expires_at: Expiration timestamp.

        Returns:
            Created PasswordReset instance.
        """
        password_reset = PasswordReset(
            email=email,
            token=token,
            expires_at=expires_at,
            is_used=False,
        )
        self.db.add(password_reset)
        await self.db.commit()
        return password_reset

    async def get_valid_password_reset(self, token: str) -> PasswordReset | None:
        """Get an unused, non-expired password reset record.

        Args:
            token: Password reset token.

        Returns:
            PasswordReset instance or None.
        """
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

    async def invalidate_password_resets(self, email: str) -> int:
        """Mark all unused, non-expired resets for an email as used.

        Args:
            email: Email address to invalidate tokens for.

        Returns:
            Number of tokens invalidated.
        """
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
        for reset_token in tokens:
            reset_token.is_used = True
            reset_token.updated_at = datetime.now(UTC)

        await self.db.commit()
        return len(tokens)

    async def mark_password_reset_used(self, reset_id: int) -> bool:
        """Mark a single password reset record as used.

        Args:
            reset_id: Primary key of the PasswordReset record.

        Returns:
            True if marked, False if not found.
        """
        result = await self.db.execute(
            select(PasswordReset).where(PasswordReset.id == reset_id),
        )
        reset = result.scalar_one_or_none()
        if not reset:
            return False

        reset.is_used = True
        reset.updated_at = datetime.now(UTC)
        await self.db.commit()
        return True

    # -- Session helpers ------------------------------------------------------

    async def create_session(
        self,
        user_id: int,
        session_token: str,
        refresh_token: str | None = None,
        device_info: dict | None = None,
        ip_address: str | None = None,
        user_agent: str | None = None,
        expires_at: datetime | None = None,
    ) -> UserSession:
        """Create a new user session record.

        Args:
            user_id: Owner of the session.
            session_token: Access token / session identifier.
            refresh_token: Optional refresh token.
            device_info: Optional device metadata dict.
            ip_address: Optional client IP.
            user_agent: Optional client user-agent string.
            expires_at: Session expiration timestamp.

        Returns:
            Created UserSession instance.
        """
        session = UserSession(
            user_id=user_id,
            session_token=session_token,
            refresh_token=refresh_token,
            device_info=device_info,
            ip_address=ip_address,
            user_agent=user_agent,
            expires_at=expires_at or datetime.now(UTC),
        )
        self.db.add(session)
        await self.db.commit()
        return session

    async def get_active_session_by_token(
        self, session_token: str
    ) -> UserSession | None:
        """Get an active session by its session token.

        Args:
            session_token: The session/access token.

        Returns:
            Active UserSession or None.
        """
        result = await self.db.execute(
            select(UserSession).filter(
                and_(
                    UserSession.session_token == session_token,
                    UserSession.is_active,
                ),
            ),
        )
        return result.scalar_one_or_none()

    async def get_active_session_by_refresh_token(
        self,
        refresh_token: str,
    ) -> UserSession | None:
        """Get an active, non-expired session by refresh token.

        Args:
            refresh_token: The refresh token.

        Returns:
            Active UserSession or None.
        """
        result = await self.db.execute(
            select(UserSession).filter(
                and_(
                    UserSession.refresh_token == refresh_token,
                    UserSession.is_active,
                    UserSession.expires_at > datetime.now(UTC),
                ),
            ),
        )
        return result.scalar_one_or_none()

    async def get_active_sessions_for_user(self, user_id: int) -> list[UserSession]:
        """Get all active sessions for a user, ordered by creation.

        Args:
            user_id: Owner of the sessions.

        Returns:
            List of active UserSession records.
        """
        result = await self.db.execute(
            select(UserSession)
            .where(
                and_(
                    UserSession.user_id == user_id,
                    UserSession.is_active,
                    UserSession.expires_at > datetime.now(UTC),
                ),
            )
            .order_by(UserSession.created_at),
        )
        return list(result.scalars().all())

    async def deactivate_session(self, session_token: str) -> bool:
        """Deactivate a session by its token.

        Args:
            session_token: The session/access token.

        Returns:
            True if deactivated, False if not found.
        """
        session = await self.get_active_session_by_token(session_token)
        if not session:
            return False

        session.is_active = False
        await self.db.commit()
        return True

    async def deactivate_all_sessions(self, user_id: int) -> int:
        """Deactivate all active sessions for a user.

        Args:
            user_id: Owner of the sessions.

        Returns:
            Number of sessions deactivated.
        """
        result = await self.db.execute(
            select(UserSession).filter(
                and_(
                    UserSession.user_id == user_id,
                    UserSession.is_active,
                ),
            ),
        )
        sessions = result.scalars().all()

        for session in sessions:
            session.is_active = False

        await self.db.commit()
        return len(sessions)

    async def cleanup_expired_sessions(self) -> int:
        """Remove expired and long-inactive sessions.

        Returns:
            Number of sessions removed.
        """
        from datetime import timedelta

        from sqlalchemy import delete as sa_delete

        result = await self.db.execute(
            sa_delete(UserSession).where(
                or_(
                    UserSession.expires_at < datetime.now(UTC),
                    and_(
                        UserSession.last_activity_at
                        < datetime.now(UTC) - timedelta(days=30),
                        UserSession.is_active.is_(False),
                    ),
                ),
            )
        )
        count = result.rowcount or 0
        await self.db.commit()
        return count
