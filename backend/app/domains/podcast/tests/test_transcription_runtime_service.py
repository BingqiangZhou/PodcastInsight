import asyncio
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import pytest

from app.domains.podcast.services import transcription_runtime_service as service_module
from app.domains.podcast.services.transcription_service import (
    PodcastTranscriptionRuntimeService,
)


class _ScalarOneOrNoneResult:
    def __init__(self, value):
        self._value = value

    def scalar_one_or_none(self):
        return self._value


class _FakeTaskOrchestrationService:
    def __init__(self, db):
        self.db = db
        self.audio_transcription_calls = []

    def enqueue_audio_transcription(self, *, task_id: int, config_db_id: int | None):
        self.audio_transcription_calls.append(
            {"task_id": task_id, "config_db_id": config_db_id},
        )


class _FakeStateManager:
    def __init__(self):
        self.episode_tasks = []

    async def set_episode_task(self, episode_id: int, task_id: int):
        self.episode_tasks.append((episode_id, task_id))

    async def is_episode_locked(self, episode_id: int):
        return None


@pytest.mark.asyncio
async def test_start_transcription_dispatches_via_task_orchestration_service():
    db = AsyncMock()
    fake_task_service = _FakeTaskOrchestrationService(db)
    service = PodcastTranscriptionRuntimeService(
        db=db,
        task_orchestration_service_factory=lambda session: fake_task_service,
    )
    created_task = SimpleNamespace(id=55)
    service._load_existing_task = AsyncMock(return_value=None)
    service._create_or_get_task_record = AsyncMock(
        return_value=(created_task, 11, True)
    )

    with patch(
        "app.domains.podcast.services.transcription_service.get_transcription_state_manager",
        new=AsyncMock(return_value=AsyncMock()),
    ):
        result = await service.start_transcription(episode_id=77)

    assert result == {"task": created_task, "action": "created"}
    assert fake_task_service.audio_transcription_calls == [
        {"task_id": 55, "config_db_id": 11},
    ]


@pytest.mark.asyncio
async def test_start_transcription_concurrent_calls_reuse_pending_task():
    db = AsyncMock()
    fake_task_service = _FakeTaskOrchestrationService(db)
    service = PodcastTranscriptionRuntimeService(
        db=db,
        task_orchestration_service_factory=lambda session: fake_task_service,
    )
    state_manager = _FakeStateManager()
    task = SimpleNamespace(id=91, status="pending", progress_percentage=0)
    create_call_count = 0

    service._load_existing_task = AsyncMock(return_value=None)

    async def _fake_create_or_get_task_record(episode_id: int, model_name: str | None):
        nonlocal create_call_count
        await asyncio.sleep(0)
        create_call_count += 1
        if create_call_count == 1:
            return task, 17, True
        return task, None, False

    service._create_or_get_task_record = _fake_create_or_get_task_record

    with patch.object(
        service_module,
        "get_transcription_state_manager",
        new=AsyncMock(return_value=state_manager),
    ):
        results = await asyncio.gather(
            service.start_transcription(episode_id=12),
            service.start_transcription(episode_id=12),
        )

    assert sorted(result["action"] for result in results) == [
        "created",
        "reused_pending",
    ]
    assert fake_task_service.audio_transcription_calls == [
        {"task_id": 91, "config_db_id": 17},
    ]
    assert state_manager.episode_tasks == [(12, 91)]
