from unittest.mock import AsyncMock

import pytest

from app.domains.podcast.services.orchestration import feed_sync as feed_sync_module
from app.domains.podcast.services.orchestration import (
    transcription as transcription_module,
)
from app.domains.podcast.services.orchestration.feed_sync import FeedSyncOrchestrator
from app.domains.podcast.services.task_orchestration_service import (
    PodcastTaskOrchestrationService,
)


class _ScalarResult:
    def __init__(self, values):
        self._values = values

    def scalars(self):
        return self

    def all(self):
        return self._values


class _RowsResult:
    def __init__(self, values):
        self._values = values

    def all(self):
        return self._values


@pytest.mark.asyncio
async def test_refresh_all_podcast_feeds_skips_when_no_subscription_is_due(
    monkeypatch,
):
    session = AsyncMock()

    parser_created = False

    def _fail_parser(*args, **kwargs):
        nonlocal parser_created
        parser_created = True
        raise AssertionError("parser should not be instantiated when nothing is due")

    monkeypatch.setattr(feed_sync_module, "SecureRSSParser", _fail_parser)
    monkeypatch.setattr(
        FeedSyncOrchestrator,
        "_load_due_refresh_candidates",
        AsyncMock(side_effect=[([], 100), ([], None)]),
    )

    service = PodcastTaskOrchestrationService(session)
    result = await service.refresh_all_podcast_feeds()

    assert result["status"] == "success"
    assert result["refreshed_subscriptions"] == 0
    assert result["new_episodes"] == 0
    assert parser_created is False


@pytest.mark.asyncio
async def test_process_pending_transcriptions_skips_without_count_query(monkeypatch):
    class _FakeSession:
        async def execute(self, stmt):
            sql = str(stmt).lower()
            assert "count(" not in sql
            return _RowsResult([])

    service = PodcastTaskOrchestrationService(_FakeSession())
    result = await service.process_pending_transcriptions()

    assert result["status"] == "success"
    assert result["total_candidates"] == 0
    assert result["checked"] == 0


@pytest.mark.asyncio
async def test_process_pending_transcriptions_dispatches_claimed_batch(monkeypatch):
    class _FakeSession:
        async def execute(self, stmt):
            sql = str(stmt).lower()
            assert "count(" not in sql
            return _RowsResult([(11, None), (7, None)])

    dispatch_result = {
        "checked": 2,
        "dispatched": 2,
        "skipped": 0,
        "failed": 0,
        "skipped_reasons": {},
    }

    class _FakeWorkflow:
        def __init__(self, session):
            self.session = session

        async def dispatch_pending_transcriptions(self, episode_ids):
            assert episode_ids == [11, 7]
            return dispatch_result

    monkeypatch.setattr(transcription_module, "TranscriptionWorkflowService", _FakeWorkflow)

    service = PodcastTaskOrchestrationService(_FakeSession())
    result = await service.process_pending_transcriptions()

    assert result["status"] == "success"
    assert result["total_candidates"] == 2
    assert result["dispatched"] == 2
