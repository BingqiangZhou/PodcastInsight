"""Summary task flow tests."""

from contextlib import asynccontextmanager
from unittest.mock import AsyncMock

import pytest

from app.core.exceptions import ValidationError
from app.domains.podcast.services.summary_service import SummaryWorkflowService
from app.domains.podcast.tasks import tasks_summary as summary_generation
from app.domains.podcast.tasks.tasks_summary import (
    generate_pending_summaries_handler,
)


@asynccontextmanager
async def _worker_session_factory(session_obj):
    yield session_obj


@asynccontextmanager
async def _acquired_lock(*args, **kwargs):
    yield True


@asynccontextmanager
async def _skipped_lock(*args, **kwargs):
    yield False


@pytest.mark.asyncio
async def test_generate_pending_summaries_success(monkeypatch):
    generated = []

    class _FakeRepo:
        def __init__(self, _session):
            self.session = _session

        async def mark_summary_failed(self, episode_id, error):
            raise AssertionError(f"unexpected failure mark for {episode_id}: {error}")

    class _FakeSummaryService:
        def __init__(self, _session):
            self.session = _session

        async def generate_summary(self, episode_id):
            generated.append((self.session, episode_id))
            return {"summary_content": "ok"}

    workflow = SummaryWorkflowService(
        db=AsyncMock(),
        repo_factory=_FakeRepo,
        summary_service_factory=_FakeSummaryService,
    )
    monkeypatch.setattr(workflow, "_reset_stale_summary_claims", AsyncMock())
    monkeypatch.setattr(
        workflow,
        "_claim_pending_summary_episode_ids",
        AsyncMock(return_value=[11, 12]),
    )
    monkeypatch.setattr(
        "app.domains.podcast.services.summary_service.worker_db_session",
        lambda *_args, **_kwargs: _worker_session_factory(object()),
    )

    result = await workflow.generate_pending_summaries_run()

    assert result["status"] == "success"
    assert result["processed"] == 2
    assert result["failed"] == 0
    assert [episode_id for _, episode_id in generated] == [11, 12]


@pytest.mark.asyncio
async def test_generate_pending_summaries_marks_failed_episode(monkeypatch):
    failed_marks = []

    class _FakeRepo:
        def __init__(self, _session):
            self.session = _session

        async def mark_summary_failed(self, episode_id, error):
            failed_marks.append((episode_id, error))

    class _FailingSummaryService:
        def __init__(self, _session):
            self.session = _session

        async def generate_summary(self, _episode_id):
            raise RuntimeError("boom")

    workflow = SummaryWorkflowService(
        db=AsyncMock(),
        repo_factory=_FakeRepo,
        summary_service_factory=_FailingSummaryService,
    )
    monkeypatch.setattr(workflow, "_reset_stale_summary_claims", AsyncMock())
    monkeypatch.setattr(
        workflow,
        "_claim_pending_summary_episode_ids",
        AsyncMock(return_value=[11]),
    )
    monkeypatch.setattr(
        "app.domains.podcast.services.summary_service.worker_db_session",
        lambda *_args, **_kwargs: _worker_session_factory(object()),
    )

    result = await workflow.generate_pending_summaries_run()

    assert result["status"] == "success"
    assert result["processed"] == 0
    assert result["failed"] == 1
    assert failed_marks == [(11, "boom")]


@pytest.mark.asyncio
async def test_generate_pending_summaries_resets_claim_for_skippable_validation_error(
    monkeypatch,
):
    resets = []

    class _FakeRepo:
        def __init__(self, _session):
            self.session = _session

        async def mark_summary_failed(self, episode_id, error):
            raise AssertionError(f"unexpected failure mark for {episode_id}: {error}")

    class _ValidationSummaryService:
        def __init__(self, _session):
            self.session = _session

        async def generate_summary(self, _episode_id):
            raise ValidationError("Summary generation already in progress for episode 11")

    workflow = SummaryWorkflowService(
        db=AsyncMock(),
        repo_factory=_FakeRepo,
        summary_service_factory=_ValidationSummaryService,
    )
    monkeypatch.setattr(workflow, "_reset_stale_summary_claims", AsyncMock())
    monkeypatch.setattr(
        workflow,
        "_claim_pending_summary_episode_ids",
        AsyncMock(return_value=[11]),
    )
    monkeypatch.setattr(
        workflow,
        "_reset_claimed_summary_status",
        AsyncMock(side_effect=lambda episode_id: resets.append(episode_id)),
    )
    monkeypatch.setattr(
        "app.domains.podcast.services.summary_service.worker_db_session",
        lambda *_args, **_kwargs: _worker_session_factory(object()),
    )

    result = await workflow.generate_pending_summaries_run()

    assert result["status"] == "success"
    assert result["processed"] == 0
    assert result["failed"] == 0
    assert resets == [11]


@pytest.mark.asyncio
async def test_handler_delegates_to_summary_workflow(monkeypatch):
    class _FakeWorkflow:
        def __init__(self, session):
            self.session = session

        async def generate_pending_summaries_run(self):
            return {"status": "success", "processed": 1, "failed": 0}

    monkeypatch.setattr(
        "app.domains.podcast.tasks.tasks_summary.SummaryWorkflowService",
        _FakeWorkflow,
    )
    monkeypatch.setattr(
        "app.domains.podcast.tasks.tasks_summary.single_instance_task_lock",
        _acquired_lock,
    )

    result = await generate_pending_summaries_handler(object())
    assert result == {"status": "success", "processed": 1, "failed": 0}


@pytest.mark.asyncio
async def test_handler_skips_when_summary_lock_is_held(monkeypatch):
    monkeypatch.setattr(
        "app.domains.podcast.tasks.tasks_summary.single_instance_task_lock",
        _skipped_lock,
    )

    result = await generate_pending_summaries_handler(object())

    assert result == {"status": "skipped_locked", "reason": "summary_task_already_running"}


def test_generate_pending_summaries_retries_on_failure(monkeypatch):
    class _RetryError(Exception):
        pass

    def _run_async_raise(coro):
        coro.close()
        raise RuntimeError("summary failed")

    logs = []

    def _log_task_run(**kwargs):
        logs.append(kwargs)

    task = summary_generation.generate_pending_summaries
    monkeypatch.setattr(summary_generation, "run_async", _run_async_raise)
    monkeypatch.setattr(summary_generation, "log_task_run", _log_task_run)

    def _retry(*, countdown):
        raise _RetryError(countdown)

    monkeypatch.setattr(task, "retry", _retry)

    with pytest.raises(_RetryError):
        task.run()

    assert logs
    assert logs[-1]["status"] == "failed"


def test_generate_episode_summary_task_delegates_to_workflow(monkeypatch):
    logs = []

    def _log_task_run(**kwargs):
        logs.append(kwargs)

    monkeypatch.setattr(summary_generation, "log_task_run", _log_task_run)
    monkeypatch.setattr(
        summary_generation,
        "worker_session",
        lambda *_args, **_kwargs: _worker_session_factory(object()),
    )

    class _FakeWorkflow:
        def __init__(self, session):
            self.session = session

        async def execute_episode_summary_generation(
            self,
            episode_id,
            *,
            summary_model=None,
            custom_prompt=None,
        ):
            return {
                "episode_id": episode_id,
                "summary_model": summary_model,
                "custom_prompt": custom_prompt,
            }

    monkeypatch.setattr(summary_generation, "SummaryWorkflowService", _FakeWorkflow)

    result = summary_generation.generate_episode_summary.run(
        episode_id=15,
        summary_model="model-a",
        custom_prompt="prompt",
    )

    assert result["episode_id"] == 15
    assert logs
    assert logs[-1]["status"] == "success"
