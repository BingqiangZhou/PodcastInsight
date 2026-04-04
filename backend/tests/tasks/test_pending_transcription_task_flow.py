"""Pending-transcription backlog task flow tests."""

from contextlib import asynccontextmanager
from unittest.mock import AsyncMock

import pytest

from app.core.config import settings
from app.domains.podcast.services.task_orchestration_service import (
    PodcastTaskOrchestrationService,
)
from app.domains.podcast.tasks import tasks_transcription as pending_transcription
from app.domains.podcast.tasks.tasks_transcription import (
    process_pending_transcriptions_handler,
)


@asynccontextmanager
async def _acquired_lock(*args, **kwargs):
    yield True


@asynccontextmanager
async def _skipped_lock(*args, **kwargs):
    yield False


@pytest.mark.asyncio
async def test_backlog_handler_dispatches_candidates(monkeypatch):
    expected = {
        "status": "success",
        "total_candidates": 37,
        "checked": 3,
        "dispatched": 3,
        "skipped": 0,
        "failed": 0,
        "skipped_reasons": {},
    }
    monkeypatch.setattr(
        PodcastTaskOrchestrationService,
        "process_pending_transcriptions",
        AsyncMock(return_value=expected),
    )
    monkeypatch.setattr(
        "app.domains.podcast.tasks.tasks_transcription.single_instance_task_lock",
        _acquired_lock,
    )

    result = await process_pending_transcriptions_handler(session=object())
    assert result["status"] == "success"
    assert result["total_candidates"] == 37
    assert result["checked"] == 3
    assert result["dispatched"] == 3
    assert result["skipped"] == 0
    assert result["failed"] == 0


@pytest.mark.asyncio
async def test_backlog_handler_skips_reused_actions(monkeypatch):
    monkeypatch.setattr(
        PodcastTaskOrchestrationService,
        "process_pending_transcriptions",
        AsyncMock(
            return_value={
                "status": "success",
                "total_candidates": 2,
                "checked": 2,
                "dispatched": 0,
                "skipped": 2,
                "failed": 0,
                "skipped_reasons": {
                    "reused_pending": 1,
                    "reused_in_progress": 1,
                },
            }
        ),
    )
    monkeypatch.setattr(
        "app.domains.podcast.tasks.tasks_transcription.single_instance_task_lock",
        _acquired_lock,
    )

    result = await process_pending_transcriptions_handler(session=object())
    assert result["status"] == "success"
    assert result["dispatched"] == 0
    assert result["skipped"] == 2
    assert result["failed"] == 0
    assert result["skipped_reasons"] == {
        "reused_pending": 1,
        "reused_in_progress": 1,
    }


@pytest.mark.asyncio
async def test_backlog_handler_counts_failures(monkeypatch):
    monkeypatch.setattr(
        PodcastTaskOrchestrationService,
        "process_pending_transcriptions",
        AsyncMock(
            return_value={
                "status": "success",
                "total_candidates": 2,
                "checked": 2,
                "dispatched": 1,
                "skipped": 0,
                "failed": 1,
                "skipped_reasons": {},
            }
        ),
    )
    monkeypatch.setattr(
        "app.domains.podcast.tasks.tasks_transcription.single_instance_task_lock",
        _acquired_lock,
    )

    result = await process_pending_transcriptions_handler(session=object())
    assert result["status"] == "success"
    assert result["dispatched"] == 1
    assert result["failed"] == 1


@pytest.mark.asyncio
async def test_backlog_handler_respects_feature_toggle(monkeypatch):
    monkeypatch.setattr(
        "app.domains.podcast.tasks.tasks_transcription.single_instance_task_lock",
        _acquired_lock,
    )
    monkeypatch.setattr(settings, "TRANSCRIPTION_BACKLOG_ENABLED", False)
    result = await process_pending_transcriptions_handler(session=object())
    assert result["status"] == "skipped"
    assert result["reason"] == "backlog_transcription_disabled"


@pytest.mark.asyncio
async def test_backlog_handler_skips_when_task_lock_is_held(monkeypatch):
    monkeypatch.setattr(
        "app.domains.podcast.tasks.tasks_transcription.single_instance_task_lock",
        _skipped_lock,
    )

    result = await process_pending_transcriptions_handler(session=object())

    assert result == {
        "status": "skipped_locked",
        "reason": "pending_transcription_task_already_running",
    }


def test_process_pending_transcriptions_retries_on_failure(monkeypatch):
    class _RetryError(Exception):
        pass

    def _run_async_raise(coro):
        coro.close()
        raise RuntimeError("boom")

    logs = []

    def _log_task_run(**kwargs):
        logs.append(kwargs)

    task = pending_transcription.process_pending_transcriptions
    monkeypatch.setattr(pending_transcription, "run_async", _run_async_raise)
    monkeypatch.setattr(pending_transcription, "log_task_run", _log_task_run)

    def _retry(*, countdown):
        raise _RetryError(countdown)

    monkeypatch.setattr(task, "retry", _retry)

    with pytest.raises(_RetryError):
        task.run()

    assert logs
    assert logs[-1]["status"] == "failed"
