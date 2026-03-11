"""Summary consistency and sanitization tests."""

from datetime import UTC, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.domains.ai.services import TextGenerationService
from app.domains.podcast.api.routes_episodes import generate_summary
from app.domains.podcast.schemas import PodcastSummaryRequest
from app.domains.podcast.services.episode_service import PodcastEpisodeService
from app.domains.podcast.services.search_service import PodcastSearchService
from app.domains.podcast.services.summary_generation_service import (
    PodcastSummaryGenerationService,
)
from app.domains.podcast.services.summary_workflow_service import SummaryWorkflowService


class _ScalarResult:
    def __init__(self, value):
        self._value = value

    def scalar_one_or_none(self):
        return self._value


def _make_episode(*, ai_summary: str) -> SimpleNamespace:
    subscription = SimpleNamespace(
        id=11,
        title="Sub",
        description="Sub desc",
        config={
            "image_url": "https://example.com/sub.jpg",
            "author": "Author",
            "categories": ["Tech"],
        },
    )
    now = datetime.now(UTC)
    return SimpleNamespace(
        id=1,
        subscription_id=11,
        subscription=subscription,
        title="Episode",
        description="Desc",
        audio_url="https://example.com/audio.mp3",
        audio_duration=120,
        audio_file_size=1024,
        published_at=now,
        image_url=None,
        item_link="https://example.com/item",
        transcript_url=None,
        transcript_content="transcript",
        ai_summary=ai_summary,
        summary_version="1.0",
        ai_confidence_score=None,
        play_count=0,
        last_played_at=None,
        season=None,
        episode_number=None,
        explicit=False,
        status="summarized",
        metadata_json={},
        created_at=now,
        updated_at=now,
    )


@pytest.mark.asyncio
async def test_generate_summary_response_uses_persisted_episode_summary() -> None:
    service = AsyncMock()
    service.get_episode_by_id.return_value = SimpleNamespace(id=1)
    summary_workflow = AsyncMock(spec=SummaryWorkflowService)
    summary_workflow.generate_episode_summary.return_value = {
        "summary": "final summary from db",
        "version": "1.0",
        "generated_at": datetime.now(UTC),
        "model_used": "test-model",
        "processing_time": 1.23,
    }

    response = await generate_summary(
        episode_id=1,
        request=PodcastSummaryRequest(),
        service=service,
        summary_workflow=summary_workflow,
    )

    assert response.summary == "final summary from db"
    assert response.word_count == 4
    assert response.model_used == "test-model"


@pytest.mark.asyncio
async def test_update_episode_summary_filters_thinking_and_does_not_truncate() -> None:
    visible = "A" * 120000
    db = AsyncMock()
    db.execute.side_effect = [SimpleNamespace(rowcount=1), SimpleNamespace(rowcount=1)]
    db.commit = AsyncMock()
    db.rollback = AsyncMock()

    service = PodcastSummaryGenerationService(db=db)
    summary_result = {
        "summary_content": f"<think>hidden reasoning</think>{visible}",
        "model_name": "model-x",
        "processing_time": 2.5,
    }

    await service._update_episode_summary(episode_id=1, summary_result=summary_result)

    assert summary_result["summary_content"] == visible
    assert not summary_result["summary_content"].endswith("...")
    assert len(summary_result["summary_content"]) == len(visible)
    assert db.execute.await_count == 2
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_generate_summary_reuses_existing_when_lock_contended() -> None:
    db = AsyncMock()
    db.execute.return_value = _ScalarResult("<think>hidden</think>existing summary")

    service = PodcastSummaryGenerationService(db=db)
    service.model_manager = AsyncMock()

    class _FakeRedis:
        async def acquire_lock(self, *_args, **_kwargs):
            return False

        async def release_lock(self, *_args, **_kwargs):
            raise AssertionError("release_lock should not be called when lock not acquired")

    service.redis = _FakeRedis()

    result = await service.generate_summary(episode_id=1)

    assert result["reused_existing"] is True
    assert result["summary_content"] == "existing summary"
    service.model_manager.generate_summary.assert_not_called()


@pytest.mark.asyncio
async def test_episode_service_filters_summary_on_detail_response() -> None:
    db = AsyncMock()
    service = PodcastEpisodeService(db=db, user_id=1)
    episode = _make_episode(ai_summary="<thinking>internal</thinking>clean summary")

    service.repo = AsyncMock()
    service.repo.get_episode_by_id.return_value = episode
    service.repo.get_playback_state.return_value = None

    result = await service.get_episode_with_summary(episode_id=episode.id)

    assert result is not None
    assert result.ai_summary == "clean summary"


def test_search_service_filters_summary_in_list_response() -> None:
    service = PodcastSearchService(db=AsyncMock(), user_id=1)
    episode = _make_episode(ai_summary="<think>internal</think>search summary")

    result = service._build_episode_response([episode], playback_states={})

    assert result[0].ai_summary == "search summary"


def test_rule_based_summary_fallback_not_truncated() -> None:
    service = TextGenerationService(db=AsyncMock())
    long_content = "A" * 500

    result = service._rule_based_summary("Episode title", long_content)

    assert long_content in result
