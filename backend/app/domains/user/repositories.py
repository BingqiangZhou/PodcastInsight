"""User repository implementation."""

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domains.user.models import User, UserSession, UserStatus
from app.shared.schemas import UserCreate, UserUpdate


class UserRepository:
    """Repository for User model."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def create(self, user_data: UserCreate) -> User:
        """Create a new user."""
        from app.core.security import get_password_hash

        hashed_password = get_password_hash(user_data.password)
        # Map is_active to status
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

    async def get_by_id(self, user_id: int) -> User | None:
        """Get user by ID."""
        result = await self.db.execute(
            select(User).filter(User.id == user_id),
        )
        return result.scalar_one_or_none()

    async def get_by_email(self, email: str) -> User | None:
        """Get user by email."""
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

    async def update(self, user_id: int, user_data: UserUpdate) -> User | None:
        """Update user."""
        user = await self.get_by_id(user_id)
        if not user:
            return None

        update_data = user_data.dict(exclude_unset=True)
        for field, value in update_data.items():
            setattr(user, field, value)

        await self.db.commit()
        # No refresh needed - user is already in session with updated values
        return user

    async def delete(self, user_id: int) -> bool:
        """Delete user."""
        user = await self.get_by_id(user_id)
        if not user:
            return False

        await self.db.delete(user)
        await self.db.commit()
        return True

    async def list(
        self,
        skip: int = 0,
        limit: int = 100,
        active_only: bool = True,
    ) -> list[User]:
        """List users."""
        query = select(User)

        if active_only:
            query = query.filter(User.status == UserStatus.ACTIVE)

        query = query.offset(skip).limit(limit).order_by(User.created_at.desc())

        result = await self.db.execute(query)
        return result.scalars().all()


class UserSessionRepository:
    """Repository for UserSession model."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def create(self, user_id: int, session_token: str, **kwargs) -> UserSession:
        """Create a new user session."""
        db_session = UserSession(
            user_id=user_id,
            session_token=session_token,
            **kwargs,
        )

        self.db.add(db_session)
        await self.db.commit()
        # No refresh needed - db_session.id is auto-populated by SQLAlchemy after flush/commit
        return db_session

    async def get_by_token(self, session_token: str) -> UserSession | None:
        """Get session by token."""
        result = await self.db.execute(
            select(UserSession).filter(
                and_(
                    UserSession.session_token == session_token,
                    UserSession.is_active,
                ),
            ),
        )
        return result.scalar_one_or_none()

    async def deactivate(self, session_token: str) -> bool:
        """Deactivate a session."""
        session = await self.get_by_token(session_token)
        if not session:
            return False

        session.is_active = False
        await self.db.commit()
        return True

    async def deactivate_all_for_user(self, user_id: int) -> int:
        """Deactivate all sessions for a user."""
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
