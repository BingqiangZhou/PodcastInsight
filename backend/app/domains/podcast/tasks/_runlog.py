"""Task run logging utilities."""

import logging
from datetime import datetime

from app.admin.models import BackgroundTaskRun
from app.core.database import create_isolated_session_factory


_logger = logging.getLogger(__name__)

# Cached session factory + engine for runlog writes (reused across task runs)
_runlog_session_factory = None
_runlog_engine = None


async def _insert_run_async(
    task_name: str,
    queue_name: str,
    status: str,
    started_at: datetime,
    finished_at: datetime | None = None,
    error_message: str | None = None,
    metadata: dict | None = None,
) -> None:
    """Insert a BackgroundTaskRun row, reusing a cached engine across calls."""
    global _runlog_session_factory, _runlog_engine

    try:
        if _runlog_session_factory is None:
            _runlog_session_factory, _runlog_engine = create_isolated_session_factory(
                "celery-runlog",
            )

        async with _runlog_session_factory() as session:
            duration_ms = None
            if finished_at is not None:
                duration_ms = int((finished_at - started_at).total_seconds() * 1000)
            session.add(
                BackgroundTaskRun(
                    task_name=task_name,
                    queue_name=queue_name,
                    status=status,
                    started_at=started_at,
                    finished_at=finished_at,
                    duration_ms=duration_ms,
                    error_message=error_message,
                    metadata_json=metadata or {},
                ),
            )
            await session.commit()
    except Exception:
        _logger.exception("Failed to insert runlog for %s", task_name)
        # Reset cached factory on error so next call creates a fresh one
        if _runlog_engine is not None:
            try:
                await _runlog_engine.dispose()
            except Exception:
                _logger.warning("Failed to dispose runlog engine", exc_info=True)
        _runlog_session_factory = None
        _runlog_engine = None


async def dispose_runlog_engine() -> None:
    """Dispose the cached runlog engine (called during worker shutdown)."""
    global _runlog_session_factory, _runlog_engine
    if _runlog_engine is not None:
        try:
            await _runlog_engine.dispose()
        except Exception:
            _logger.warning("Failed to dispose runlog engine on shutdown", exc_info=True)
    _runlog_session_factory = None
    _runlog_engine = None
