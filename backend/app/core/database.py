"""Database configuration and session management.

The runtime is intentionally lazy so importing the app for tests, snapshots, or
scripts does not require a production database URL or eagerly construct an
engine with dialect-specific settings.
"""

import asyncio
import logging
import threading
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
_engine_lock = threading.Lock()  # Protect global engine state for concurrent access
_worker_runtime_lock = asyncio.Lock()
_worker_runtimes: dict[
    str,
    tuple[int | None, async_sessionmaker[AsyncSession], AsyncEngine],
] = {}

# Read replica engine and session factory (optional)
_read_engine: AsyncEngine | None = None
_read_session_factory: async_sessionmaker[AsyncSession] | None = None
_read_engine_url: str | None = None
_read_engine_lock = threading.Lock()


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


def _build_engine_kwargs(database_url: str, is_read_replica: bool = False) -> dict[str, Any]:
    settings = get_settings()
    common: dict[str, Any] = {
        "echo": False,
        "future": True,
        "pool_pre_ping": True,
    }

    if database_url.startswith("postgresql+asyncpg://"):
        # Use read replica pool settings if available, otherwise use primary settings
        pool_size = (
            settings.DATABASE_READ_POOL_SIZE if is_read_replica and settings.DATABASE_READ_POOL_SIZE else settings.DATABASE_POOL_SIZE
        )
        max_overflow = (
            settings.DATABASE_READ_MAX_OVERFLOW if is_read_replica and settings.DATABASE_READ_MAX_OVERFLOW else settings.DATABASE_MAX_OVERFLOW
        )

        common.update(
            {
                "pool_size": pool_size,
                "max_overflow": max_overflow,
                "pool_recycle": settings.DATABASE_RECYCLE,
                "pool_timeout": settings.DATABASE_POOL_TIMEOUT,
                "isolation_level": "READ COMMITTED" if not is_read_replica else "READ ONLY",
                "connect_args": {
                    "server_settings": {
                        "application_name": f"personal-ai-assistant{'-read' if is_read_replica else ''}",
                        "client_encoding": "utf8",
                    },
                    "timeout": settings.DATABASE_CONNECT_TIMEOUT,
                },
            },
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
    """Get or create the async SQLAlchemy engine lazily with thread-safe protection."""
    global _engine, _engine_url

    database_url = get_settings().require_database_url()

    # Fast path: check without lock
    if _engine is not None and _engine_url == database_url:
        return _engine

    # Slow path: acquire lock and create engine
    with _engine_lock:
        # Double-check after acquiring lock
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


def get_read_engine() -> AsyncEngine:
    """Get or create the read replica async SQLAlchemy engine.

    If READ_DATABASE_URL is not configured, returns the primary engine.
    This allows the application to function without a read replica.
    """
    global _read_engine, _read_engine_url

    settings = get_settings()
    read_url = settings.READ_DATABASE_URL or settings.require_database_url()

    # If read URL equals primary URL, use primary engine
    if read_url == settings.require_database_url():
        return get_engine()

    # Fast path: check without lock
    if _read_engine is not None and _read_engine_url == read_url:
        return _read_engine

    # Slow path: acquire lock and create engine
    with _read_engine_lock:
        # Double-check after acquiring lock
        if _read_engine is not None and _read_engine_url == read_url:
            return _read_engine

        _read_engine = create_async_engine(read_url, **_build_engine_kwargs(read_url, is_read_replica=True))
        _read_engine_url = read_url
        return _read_engine


def get_read_session_factory() -> async_sessionmaker[AsyncSession]:
    """Get or create the read replica async session factory lazily.

    If READ_DATABASE_URL is not configured, returns the primary session factory.
    """
    global _read_session_factory

    engine = get_read_engine()
    if _read_session_factory is None or _read_session_factory.kw["bind"] != engine:
        _read_session_factory = async_sessionmaker(
            engine,
            class_=AsyncSession,
            expire_on_commit=False,
        )
    return _read_session_factory


def is_read_replica_configured() -> bool:
    """Check if a separate read replica database is configured."""
    settings = get_settings()
    return bool(settings.READ_DATABASE_URL and settings.READ_DATABASE_URL != settings.DATABASE_URL)


def create_isolated_session_factory(
    application_name: str,
) -> tuple[async_sessionmaker[AsyncSession], AsyncEngine]:
    """Create a worker-oriented session factory with its own engine."""
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


async def _get_worker_runtime(
    application_name: str,
) -> tuple[async_sessionmaker[AsyncSession], AsyncEngine]:
    """Reuse one worker runtime per application name within the current event loop."""
    try:
        current_loop_token: int | None = id(asyncio.get_running_loop())
    except RuntimeError:
        current_loop_token = None

    async with _worker_runtime_lock:
        runtime = _worker_runtimes.get(application_name)
        if runtime is not None:
            loop_token, session_factory, engine = runtime
            if loop_token == current_loop_token:
                return session_factory, engine
            await engine.dispose()

        session_factory, engine = create_isolated_session_factory(application_name)
        _worker_runtimes[application_name] = (
            current_loop_token,
            session_factory,
            engine,
        )
        return session_factory, engine


@asynccontextmanager
async def worker_db_session(application_name: str):
    """Yield a worker DB session while reusing the runtime engine in the same loop."""
    session_factory, _engine = await _get_worker_runtime(application_name)
    async with session_factory() as session:
        try:
            yield session
        finally:
            await session.close()


async def close_worker_db_runtimes() -> None:
    """Dispose cached worker runtimes."""
    async with _worker_runtime_lock:
        runtimes = list(_worker_runtimes.values())
        _worker_runtimes.clear()

    for _, _, engine in runtimes:
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
    """Yield a request-scoped database session from the primary database."""
    session_factory = get_async_session_factory()
    async with session_factory() as session:
        try:
            yield session
        finally:
            await session.close()


async def get_read_db_session() -> AsyncGenerator[AsyncSession, None]:
    """Yield a request-scoped database session from the read replica.

    This function provides a read-only database session that routes queries
    to a read replica when READ_DATABASE_URL is configured. If no read replica
    is configured, it falls back to the primary database.

    Use this for read-heavy operations that don't require write access or
    transactional consistency with writes.

    Example:
        ```python
        @router.get("/episodes")
        async def list_episodes(read_db: AsyncSession = Depends(get_read_db_session)):
            # This query runs on the read replica if configured
            result = await read_db.execute(select(PodcastEpisode))
            return result.scalars().all()
        ```
    """
    session_factory = get_read_session_factory()
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
                "Database connectivity verified; schema is managed by Alembic migrations.",
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
                            "SELECT 1 FROM information_schema.tables WHERE table_name = 'users'",
                        ),
                    )
                    if result.first():
                        logger.info(
                            "Database tables verified to exist (ignoring ENUM duplicate error)",
                        )
                    else:
                        raise ValueError(
                            "Tables do not exist after ENUM error"
                        ) from exc
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
    """Dispose the lazily-created engines if they exist."""
    global _engine, _session_factory, _engine_url, _read_engine, _read_session_factory, _read_engine_url

    await close_worker_db_runtimes()

    # Close read replica engine first
    if _read_engine is not None:
        await _read_engine.dispose()
        _read_engine = None
        _read_session_factory = None
        _read_engine_url = None

    if _engine is None:
        return

    await _engine.dispose()
    _engine = None
    _session_factory = None
    _engine_url = None

    await asyncio.sleep(0.1)


async def check_db_health() -> dict[str, Any]:
    """Return runtime DB health metrics including read replica if configured."""
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

    # Check read replica health if configured
    if is_read_replica_configured():
        read_engine = get_read_engine()
        read_url = str(read_engine.url)
        if read_engine.url.password:
            read_url = read_url.replace(read_engine.url.password, "***")
        read_pool = read_engine.pool

        read_health_info = {
            "connection_url": read_url,
            "pool_size": _pool_metric(read_pool, "size"),
            "checked_out": _pool_metric(read_pool, "checkedout"),
            "overflow": _pool_metric(read_pool, "overflow"),
        }

        start_time = time.time()
        try:
            async with read_engine.connect() as conn:
                result = await conn.execute(text("SELECT 1 as ping"))
                read_health_info["connect_time_ms"] = round((time.time() - start_time) * 1000, 2)
                read_health_info["status"] = "healthy"
                read_health_info["query_result"] = result.scalar()
        except Exception as exc:
            logger.error("Read replica health check failed: %s", exc)
            read_health_info["status"] = "unhealthy"
            read_health_info["error"] = str(exc)

        health_info["read_replica"] = read_health_info

    return health_info


async def check_db_readiness(timeout_seconds: float = 1.5) -> dict[str, Any]:
    """Return a compact DB readiness payload suitable for readiness probes."""
    if not is_database_configured():
        return {"status": "not_configured"}

    engine = get_engine()
    try:
        async with asyncio.timeout(timeout_seconds):
            async with engine.connect() as conn:
                await conn.execute(text("SELECT 1"))
    except TimeoutError:
        return {"status": "unhealthy", "error": "timeout"}
    except Exception as exc:
        logger.error("Database readiness check failed: %s", exc)
        return {"status": "unhealthy", "error": str(exc)}

    # Check read replica if configured (non-blocking)
    if is_read_replica_configured():
        read_engine = get_read_engine()
        try:
            async with asyncio.timeout(timeout_seconds):
                async with read_engine.connect() as conn:
                    await conn.execute(text("SELECT 1"))
            return {"status": "healthy", "read_replica": "connected"}
        except TimeoutError:
            return {"status": "healthy", "read_replica": "timeout"}
        except Exception as exc:
            logger.warning("Read replica readiness check failed (continuing with primary): %s", exc)
            return {"status": "healthy", "read_replica": "unavailable"}

    return {"status": "healthy"}


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

    settings = get_settings()
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

    occupancy_ratio = checked_out / capacity if capacity > 0 else 0.0

    # Log warning if pool occupancy is high
    if occupancy_ratio > settings.OBS_ALERT_DB_POOL_OCCUPANCY_RATIO:
        logger.warning(
            "DB pool occupancy high: %.2f%% (%d/%d connections)",
            occupancy_ratio * 100,
            checked_out,
            capacity,
        )

    return {
        "pool_size": pool_size,
        "checked_out": checked_out,
        "overflow": overflow,
        "max_overflow_limit": max_overflow_limit,
        "capacity": capacity,
        "occupancy_ratio": occupancy_ratio,
        "status": "configured",
    }
