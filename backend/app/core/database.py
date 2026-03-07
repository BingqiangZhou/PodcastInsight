"""
Database configuration and session management.

The runtime is intentionally lazy so importing the app for tests, snapshots, or
scripts does not require a production database URL or eagerly construct an
engine with dialect-specific settings.
"""

import asyncio
import logging
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from importlib import import_module
from typing import Any

from sqlalchemy import text
from sqlalchemy.exc import IntegrityError, ProgrammingError
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import declarative_base
from sqlalchemy.pool import NullPool

from app.core.config import get_settings


logger = logging.getLogger(__name__)
Base = declarative_base()

_orm_models_registered = False
_engine: AsyncEngine | None = None
_session_factory: async_sessionmaker[AsyncSession] | None = None
_engine_url: str | None = None


def _pool_metric(pool: Any, attr: str, default: int = 0) -> int:
    """Safely read optional pool metrics across different SQLAlchemy pool types."""
    metric = getattr(pool, attr, None)
    if callable(metric):
        try:
            value = metric()
            return int(value) if value is not None else default
        except Exception:
            return default
    if metric is None:
        return default
    try:
        return int(metric)
    except Exception:
        return default


def _build_engine_kwargs(database_url: str) -> dict[str, Any]:
    settings = get_settings()
    common: dict[str, Any] = {
        "echo": False,
        "future": True,
        "pool_pre_ping": True,
    }

    if database_url.startswith("postgresql+asyncpg://"):
        common.update(
            {
                "pool_size": settings.DATABASE_POOL_SIZE,
                "max_overflow": settings.DATABASE_MAX_OVERFLOW,
                "pool_recycle": settings.DATABASE_RECYCLE,
                "pool_timeout": settings.DATABASE_POOL_TIMEOUT,
                "isolation_level": "READ COMMITTED",
                "connect_args": {
                    "server_settings": {
                        "application_name": "personal-ai-assistant",
                        "client_encoding": "utf8",
                    },
                    "timeout": settings.DATABASE_CONNECT_TIMEOUT,
                },
            }
        )
        return common

    if database_url.startswith("sqlite+aiosqlite://"):
        common["connect_args"] = {"timeout": settings.DATABASE_CONNECT_TIMEOUT}
        return common

    common["pool_recycle"] = settings.DATABASE_RECYCLE
    return common


def is_database_configured() -> bool:
    """Return whether DATABASE_URL is available for runtime use."""
    return bool(get_settings().DATABASE_URL)


def get_engine() -> AsyncEngine:
    """Get or create the async SQLAlchemy engine lazily."""
    global _engine, _engine_url

    database_url = get_settings().require_database_url()
    if _engine is not None and _engine_url == database_url:
        return _engine

    _engine = create_async_engine(database_url, **_build_engine_kwargs(database_url))
    _engine_url = database_url
    return _engine


def get_async_session_factory() -> async_sessionmaker[AsyncSession]:
    """Get or create the async session factory lazily."""
    global _session_factory

    engine = get_engine()
    if _session_factory is None:
        _session_factory = async_sessionmaker(
            engine,
            class_=AsyncSession,
            expire_on_commit=False,
        )
    return _session_factory


def create_isolated_session_factory(
    application_name: str,
) -> tuple[async_sessionmaker[AsyncSession], AsyncEngine]:
    """Create a short-lived session factory for worker contexts."""
    settings = get_settings()
    database_url = settings.require_database_url()
    engine_kwargs = _build_engine_kwargs(database_url)
    engine_kwargs["poolclass"] = NullPool
    engine_kwargs["pool_pre_ping"] = False
    # NullPool does not accept pool sizing arguments
    for key in ("pool_size", "max_overflow", "pool_timeout", "pool_recycle"):
        engine_kwargs.pop(key, None)

    connect_args = dict(engine_kwargs.get("connect_args") or {})
    if database_url.startswith("postgresql+asyncpg://"):
        connect_args["server_settings"] = {
            "application_name": application_name,
            "client_encoding": "utf8",
        }
        connect_args["timeout"] = settings.DATABASE_CONNECT_TIMEOUT
    elif database_url.startswith("sqlite+aiosqlite://"):
        connect_args["timeout"] = settings.DATABASE_CONNECT_TIMEOUT
    if connect_args:
        engine_kwargs["connect_args"] = connect_args

    engine = create_async_engine(database_url, **engine_kwargs)
    session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    return session_factory, engine


@asynccontextmanager
async def worker_db_session(application_name: str):
    """Yield an isolated worker session and dispose its engine afterwards."""
    session_factory, engine = create_isolated_session_factory(application_name)
    try:
        async with session_factory() as session:
            yield session
    finally:
        await engine.dispose()


def register_orm_models() -> None:
    """Import all ORM model modules exactly once to populate Base metadata."""
    global _orm_models_registered
    if _orm_models_registered:
        return

    for module in (
        "app.admin.models",
        "app.domains.ai.models",
        "app.domains.podcast.models",
        "app.domains.subscription.models",
        "app.domains.user.models",
    ):
        import_module(module)

    _orm_models_registered = True


async def get_db_session() -> AsyncGenerator[AsyncSession, None]:
    """Yield a request-scoped database session."""
    session_factory = get_async_session_factory()
    async with session_factory() as session:
        try:
            yield session
        finally:
            await session.close()


async def init_db(run_metadata_sync: bool = False) -> None:
    """Initialize database connectivity and optionally sync metadata."""
    register_orm_models()
    engine = get_engine()

    async with engine.begin() as conn:
        if not run_metadata_sync:
            logger.info(
                "Database connectivity verified; schema is managed by Alembic migrations."
            )
            return

        try:
            await conn.run_sync(Base.metadata.create_all, checkfirst=True)
            logger.info("Database tables initialized successfully via metadata sync")
        except (IntegrityError, ProgrammingError) as exc:
            error_msg = str(exc).lower()
            if "duplicate key" in error_msg and (
                "enum" in error_msg or "pg_type" in error_msg or "typname" in error_msg
            ):
                logger.warning("ENUM type conflict detected (non-critical): %s", exc)
                try:
                    result = await conn.execute(
                        text(
                            "SELECT 1 FROM information_schema.tables WHERE table_name = 'users'"
                        )
                    )
                    if result.first():
                        logger.info(
                            "Database tables verified to exist (ignoring ENUM duplicate error)"
                        )
                    else:
                        raise ValueError("Tables do not exist after ENUM error") from exc
                except Exception as verify_error:
                    logger.error(
                        "Could not verify tables after ENUM error: %s",
                        verify_error,
                    )
                    raise exc from verify_error
            else:
                logger.error("Failed to initialize database: %s", exc)
                raise


async def close_db() -> None:
    """Dispose the lazily-created engine if it exists."""
    global _engine, _session_factory, _engine_url

    if _engine is None:
        return

    await _engine.dispose()
    _engine = None
    _session_factory = None
    _engine_url = None

    await asyncio.sleep(0.1)


async def check_db_health() -> dict[str, Any]:
    """Return runtime DB health metrics."""
    if not is_database_configured():
        return {
            "status": "not_configured",
            "connection_url": None,
            "pool_size": 0,
            "checked_out": 0,
            "overflow": 0,
        }

    import time

    engine = get_engine()
    password = engine.url.password
    connection_url = str(engine.url)
    if password:
        connection_url = connection_url.replace(password, "***")
    pool = engine.pool

    health_info = {
        "pool_size": _pool_metric(pool, "size"),
        "checked_out": _pool_metric(pool, "checkedout"),
        "overflow": _pool_metric(pool, "overflow"),
        "connection_url": connection_url,
    }

    start_time = time.time()
    try:
        async with engine.connect() as conn:
            result = await conn.execute(text("SELECT 1 as ping"))
            health_info["connect_time_ms"] = round((time.time() - start_time) * 1000, 2)
            health_info["status"] = "healthy"
            health_info["query_result"] = result.scalar()
    except Exception as exc:
        logger.error("Database health check failed: %s", exc)
        health_info["status"] = "unhealthy"
        health_info["error"] = str(exc)

    return health_info


def get_db_pool_snapshot() -> dict[str, Any]:
    """Return lightweight DB pool metrics without forcing startup failure."""
    if not is_database_configured():
        return {
            "pool_size": 0,
            "checked_out": 0,
            "overflow": 0,
            "capacity": 0,
            "occupancy_ratio": 0.0,
            "status": "not_configured",
        }

    engine = get_engine()
    pool = engine.pool
    pool_size = _pool_metric(pool, "size")
    checked_out = _pool_metric(pool, "checkedout")
    overflow = _pool_metric(pool, "overflow")
    max_overflow_limit = _pool_metric(pool, "_max_overflow")

    # SQLAlchemy can report negative overflow before the pool reaches steady size.
    # Use configured overflow limit (if available) to avoid inflating occupancy.
    if max_overflow_limit > 0:
        capacity = max(pool_size + max_overflow_limit, 1)
    else:
        capacity = max(pool_size + max(overflow, 0), pool_size, 1)

    return {
        "pool_size": pool_size,
        "checked_out": checked_out,
        "overflow": overflow,
        "max_overflow_limit": max_overflow_limit,
        "capacity": capacity,
        "occupancy_ratio": checked_out / capacity,
        "status": "configured",
    }
