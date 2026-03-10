"""Episode status safety tests for OPML/background parsing flows."""

from datetime import UTC, datetime
from unittest.mock import AsyncMock, Mock

import pytest

from app.domains.podcast.models import PodcastEpisode
from app.domains.podcast.repositories import PodcastSubscriptionRepository


class _ScalarResult:
    """Small helper to mimic SQLAlchemy scalar results in repository unit tests."""

    def __init__(self, items):
        self._items = items

    def scalars(self):
        return self

    def all(self):
        return self._items


@pytest.mark.asyncio
async def test_new_episode_defaults_to_pending_summary() -> None:
    db = AsyncMock()
    db.execute.return_value = _ScalarResult([])
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    db.add = Mock()
    repo = PodcastSubscriptionRepository(db=db, redis=AsyncMock())

    _, new_episodes = await repo.create_or_update_episodes_batch(
        subscription_id=1,
        episodes_data=[
            {
                "title": "Episode 1",
                "description": "desc",
                "audio_url": "https://example.com/ep1.mp3",
                "published_at": datetime.now(UTC),
                "audio_duration": 60,
                "transcript_url": None,
                "item_link": "https://example.com/episodes/1",
                "metadata": {"imported_via_opml": True},
            }
        ],
    )

    assert len(new_episodes) == 1
    assert new_episodes[0].status == "pending_summary"


@pytest.mark.asyncio
async def test_opml_background_reparse_does_not_override_summarized_status() -> None:
    existing_episode = PodcastEpisode(
        subscription_id=1,
        title="Existing",
        description="existing",
        audio_url="https://example.com/existing.mp3",
        published_at=datetime.now(UTC),
        item_link="https://example.com/episodes/existing",
        status="summarized",
        metadata_json={},
    )

    db = AsyncMock()
    db.execute.side_effect = [
        _ScalarResult([existing_episode]),
        _ScalarResult([existing_episode]),
    ]
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    db.add = Mock()
    repo = PodcastSubscriptionRepository(db=db, redis=AsyncMock())

    payload = [
        {
            "title": "Updated title",
            "description": "updated",
            "audio_url": "https://example.com/existing.mp3",
            "published_at": datetime.now(UTC),
            "audio_duration": 120,
            "transcript_url": None,
            "item_link": "https://example.com/episodes/existing",
            "metadata": {"imported_via_opml": True},
        }
    ]

    await repo.create_or_update_episodes_batch(subscription_id=1, episodes_data=payload)
    await repo.create_or_update_episodes_batch(subscription_id=1, episodes_data=payload)

    assert existing_episode.status == "summarized"


@pytest.mark.asyncio
async def test_pending_summary_stays_pending_summary_after_multiple_reparse() -> None:
    existing_episode = PodcastEpisode(
        subscription_id=1,
        title="Existing pending",
        description="pending",
        audio_url="https://example.com/pending.mp3",
        published_at=datetime.now(UTC),
        item_link="https://example.com/episodes/pending",
        status="pending_summary",
        metadata_json={},
    )

    db = AsyncMock()
    db.execute.side_effect = [
        _ScalarResult([existing_episode]),
        _ScalarResult([existing_episode]),
    ]
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    db.add = Mock()
    repo = PodcastSubscriptionRepository(db=db, redis=AsyncMock())

    payload = [
        {
            "title": "Pending title",
            "description": "pending desc",
            "audio_url": "https://example.com/pending.mp3",
            "published_at": datetime.now(UTC),
            "audio_duration": 180,
            "transcript_url": None,
            "item_link": "https://example.com/episodes/pending",
            "metadata": {"imported_via_opml": True},
        }
    ]

    await repo.create_or_update_episodes_batch(subscription_id=1, episodes_data=payload)
    await repo.create_or_update_episodes_batch(subscription_id=1, episodes_data=payload)

    assert existing_episode.status == "pending_summary"
