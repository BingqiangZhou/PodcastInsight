from unittest.mock import AsyncMock

import pytest

from app.domains.podcast.services import task_orchestration_service as service_module
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

    monkeypatch.setattr(service_module, "SecureRSSParser", _fail_parser)
    monkeypatch.setattr(
        PodcastTaskOrchestrationService,
        "_load_due_refresh_candidates",
        AsyncMock(side_effect=[([], 100), ([], None)]),
    )

    service = PodcastTaskOrchestrationService(session)
    result = await service.refresh_all_podcast_feeds()

    assert result["status"] == "success"
    assert result["refreshed_subscriptions"] == 0
    assert result["new_episodes"] == 0
    assert parser_created is False
