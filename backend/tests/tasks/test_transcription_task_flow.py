"""Transcription task flow tests."""

from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.domains.podcast.services.transcription_service import (
    TranscriptionWorkflowService,
)
from app.domains.podcast.tasks import tasks_transcription as transcription
from app.domains.podcast.tasks.task_orchestration import (
    PodcastTaskOrchestrationService,
)
from app.domains.podcast.tasks.tasks_transcription import (
    process_audio_transcription_handler,
)


class _ScalarResult:
    def __init__(self, value):
        self._value = value

    def scalar_one_or_none(self):
        return self._value


class _FakeSession:
    def __init__(self, values):
        self._values = iter(values)

    async def execute(self, _stmt):
        return _ScalarResult(next(self._values))

    async def refresh(self, _obj):
        return None


class _FakeStateManager:
    def __init__(self, lock_ok: bool = True):
        self.lock_ok = lock_ok
        self.progress_updates: list[tuple[int, str, int, str]] = []
        self.cleared: list[tuple[int, int]] = []
        self.released: list[tuple[int, int]] = []
        self.failed: list[tuple[int, int, str]] = []

    async def acquire_task_lock(self, _episode_id, _task_id, expire_seconds=3600):
        return self.lock_ok

    async def is_episode_locked(self, _episode_id):
        return 999

    async def set_task_progress(self, task_id, status, progress, message):
        self.progress_updates.append((task_id, status, progress, message))

    async def clear_task_state(self, task_id, episode_id):
        self.cleared.append((task_id, episode_id))

    async def fail_task_state(self, _task_id, _episode_id, _error):
        self.failed.append((_task_id, _episode_id, _error))

    async def release_task_lock(self, episode_id, task_id):
        self.released.append((episode_id, task_id))


@pytest.mark.asyncio
async def test_transcription_handler_lock_conflict(monkeypatch):
    monkeypatch.setattr(
        PodcastTaskOrchestrationService,
        "process_audio_transcription_task",
        AsyncMock(side_effect=RuntimeError("locked")),
    )

    with pytest.raises(RuntimeError, match="locked"):
        await process_audio_transcription_handler(session=object(), task_id=10)


@pytest.mark.asyncio
async def test_transcription_workflow_updates_status_and_releases_lock():
    fake_task = SimpleNamespace(id=1, episode_id=2)
    session = _FakeSession([fake_task])
    state = _FakeStateManager(lock_ok=True)

    class _FakeService:
        def __init__(self, _session):
            self._update_task_progress_with_session = self._default_update

        async def _default_update(self, *_args, **_kwargs):
            return None

        async def execute_transcription_task(self, task_id, db_session, _config_db_id):
            await self._update_task_progress_with_session(
                db_session,
                task_id,
                "in_progress",
                50,
                "halfway",
            )

    async def _claim(_session, _task_id: int) -> bool:
        return True

    async def _clear(_task_id: int) -> None:
        return None

    async def _get_state():
        return state

    workflow = TranscriptionWorkflowService(
        session,
        transcription_service_factory=_FakeService,
        state_manager_factory=_get_state,
        claim_dispatched=_claim,
        clear_dispatched=_clear,
    )

    result = await workflow.execute_transcription_task(task_id=1, config_db_id=None)
    assert result["status"] == "success"
    assert (
        1,
        "pending",
        0,
        "Worker starting transcription process...",
    ) in state.progress_updates
    assert (1, "in_progress", 50, "halfway") in state.progress_updates
    assert state.cleared == [(1, 2)]
    assert state.released == [(2, 1)]


def test_transcription_task_retries_on_failure(monkeypatch):
    class _RetryError(Exception):
        pass

    def _run_async_raise(coro):
        coro.close()
        raise RuntimeError("boom")

    task = transcription.process_audio_transcription
    monkeypatch.setattr(transcription, "run_async", _run_async_raise)

    def _retry(*, countdown):
        raise _RetryError(countdown)

    monkeypatch.setattr(task, "retry", _retry)

    with pytest.raises(_RetryError):
        task.run(task_id=123, config_db_id=None)


@pytest.mark.asyncio
async def test_transcription_workflow_raises_when_execution_fails():
    fake_task = SimpleNamespace(id=33, episode_id=44)
    session = _FakeSession([fake_task])
    state = _FakeStateManager(lock_ok=True)

    class _FailingService:
        def __init__(self, _session):
            self._update_task_progress_with_session = self._default_update

        async def _default_update(self, *_args, **_kwargs):
            return None

        async def execute_transcription_task(self, *_args, **_kwargs):
            raise RuntimeError("transcription boom")

    async def _claim(_session, _task_id: int) -> bool:
        return True

    async def _clear(_task_id: int) -> None:
        return None

    async def _get_state():
        return state

    workflow = TranscriptionWorkflowService(
        session,
        transcription_service_factory=_FailingService,
        state_manager_factory=_get_state,
        claim_dispatched=_claim,
        clear_dispatched=_clear,
    )

    with pytest.raises(RuntimeError, match="transcription boom"):
        await workflow.execute_transcription_task(task_id=33, config_db_id=None)

    assert state.failed
    assert state.failed[-1][0] == 33
    assert state.released == [(44, 33)]
