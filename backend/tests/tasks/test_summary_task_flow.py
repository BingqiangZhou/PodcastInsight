"""Summary task flow tests."""

from contextlib import asynccontextmanager

import pytest

from app.domains.podcast.tasks import tasks_summary as summary_generation
from app.domains.podcast.tasks.tasks_summary import (
    generate_pending_summaries_handler,
)


@asynccontextmanager
async def _worker_session_factory(session_obj):
    yield session_obj


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

    result = await generate_pending_summaries_handler(object())
    assert result == {"status": "success", "processed": 1, "failed": 0}


def test_generate_pending_summaries_retries_on_failure(monkeypatch):
    class _RetryError(Exception):
        pass

    def _run_async_raise(coro):
        coro.close()
        raise RuntimeError("summary failed")

    task = summary_generation.generate_pending_summaries
    monkeypatch.setattr(summary_generation, "run_async", _run_async_raise)

    def _retry(*, countdown):
        raise _RetryError(countdown)

    monkeypatch.setattr(task, "retry", _retry)

    with pytest.raises(_RetryError):
        task.run()


def test_generate_episode_summary_task_delegates_to_workflow(monkeypatch):
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
