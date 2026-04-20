from unittest.mock import AsyncMock

import pytest

from app.domains.podcast.transcription import PodcastTranscriptionService
from app.domains.podcast.models import TranscriptionStatus


class _NoopThrottle:
    def __init__(self) -> None:
        self.calls: list[tuple[int, str, float]] = []

    def should_log(self, task_id: int, status: str, progress: float) -> bool:
        self.calls.append((task_id, status, progress))
        return False


@pytest.mark.asyncio
async def test_update_task_progress_in_progress_path_no_name_error(monkeypatch):
    db = AsyncMock()
    service = PodcastTranscriptionService(db)
    service._get_task_field = AsyncMock(return_value=None)

    throttle = _NoopThrottle()
    monkeypatch.setattr(
        "app.domains.media.transcription.service._progress_throttle",
        throttle,
    )

    await service.update_task_progress(
        task_id=123,
        status=TranscriptionStatus.IN_PROGRESS,
        progress=35.0,
        message="step running",
    )

    service._get_task_field.assert_awaited_once_with(123, "started_at")
    db.execute.assert_awaited_once()
    db.commit.assert_awaited_once()
    assert "started_at" in str(db.execute.await_args.args[0])
    assert throttle.calls == [
        (123, str(TranscriptionStatus.IN_PROGRESS), 35.0),
    ]
