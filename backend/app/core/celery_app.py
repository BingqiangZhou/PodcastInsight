"""Central Celery application entrypoint."""

from __future__ import annotations

import asyncio
import logging
from typing import Any

from celery import Celery
from celery.schedules import crontab
from celery.signals import worker_process_shutdown

from app.core.config import get_settings


_logger = logging.getLogger(__name__)


_celery_app: Celery | None = None


def _build_beat_schedule() -> dict[str, Any]:
    return {
        "refresh-podcast-feeds": {
            "task": "app.domains.podcast.tasks.tasks_subscription.refresh_all_podcast_feeds",
            "schedule": crontab(minute=0),
            "options": {"queue": "default"},
        },
        "generate-pending-summaries": {
            "task": "app.domains.podcast.tasks.tasks_summary.generate_pending_summaries",
            "schedule": 1800.0,
            "options": {"queue": "default"},
        },
        "auto-cleanup-cache": {
            "task": "app.domains.podcast.tasks.tasks_maintenance.auto_cleanup_cache_files",
            "schedule": crontab(hour=4, minute=0),
            "options": {"queue": "default"},
        },
        "generate-daily-podcast-reports": {
            "task": "app.domains.podcast.tasks.tasks_daily_report.generate_daily_podcast_reports",
            "schedule": crontab(hour=19, minute=30),
            "options": {"queue": "default"},
        },
    }


def create_celery_app() -> Celery:
    """Create and configure the Celery application lazily."""
    global _celery_app
    if _celery_app is not None:
        return _celery_app

    settings = get_settings()
    celery = Celery(
        "personal_ai_tasks",
        broker=settings.CELERY_BROKER_URL,
        backend=settings.CELERY_RESULT_BACKEND,
    )
    celery.conf.update(
        task_serializer="json",
        accept_content=["json"],
        result_serializer="json",
        timezone="UTC",
        enable_utc=True,
        task_track_started=True,
        task_time_limit=30 * 60,
        task_soft_time_limit=25 * 60,
        worker_prefetch_multiplier=settings.CELERY_WORKER_PREFETCH_MULTIPLIER,
        worker_max_tasks_per_child=settings.CELERY_WORKER_MAX_TASKS_PER_CHILD,
        beat_schedule=_build_beat_schedule(),
    )

    _celery_app = celery

    # Ensure task modules are imported so Celery registers them.
    import app.domains.podcast.tasks  # noqa: F401

    return celery


# ---------------------------------------------------------------------------
# Worker lifecycle hooks
# ---------------------------------------------------------------------------

try:
    from celery.signals import worker_process_shutdown  # type: ignore[import-untyped]

    @worker_process_shutdown.connect
    def _on_worker_process_shutdown(**kwargs):  # type: ignore[misc]
        """Dispose DB engines and close the worker event loop on shutdown."""
        try:
            from app.domains.podcast.tasks.runtime import _worker_loop

            if _worker_loop is not None and not _worker_loop.is_closed():
                from app.core.database import close_db

                _worker_loop.run_until_complete(close_db())
                _worker_loop.close()
        except Exception:
            _logger.warning(
                "Failed to dispose worker DB engines during shutdown", exc_info=True
            )
except ImportError:
    pass


class _LazyCeleryApp:
    """Proxy that resolves the Celery application on first use."""

    def __getattr__(self, name: str) -> Any:
        return getattr(create_celery_app(), name)

    def __repr__(self) -> str:
        return repr(create_celery_app())


celery_app = _LazyCeleryApp()


__all__ = ["celery_app", "create_celery_app"]
