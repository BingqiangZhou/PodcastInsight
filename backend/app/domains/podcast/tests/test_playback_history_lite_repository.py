from datetime import datetime, timezone
from unittest.mock import AsyncMock, Mock

import pytest

from app.domains.podcast.repositories import PodcastEpisodeRepository


def _build_rows_result(rows: list[dict]) -> Mock:
    result = Mock()
    mappings_result = Mock()
    mappings_result.all.return_value = rows
    result.mappings.return_value = mappings_result
    return result


def _build_history_row(
    subscription_image_url: str | None,
    subscription_config: dict | None,
) -> dict:
    now = datetime.now(timezone.utc)
    return {
        "id": 101,
        "subscription_id": 9,
        "subscription_title": "Test Podcast",
        "subscription_image_url": subscription_image_url,
        "subscription_config": subscription_config,
        "title": "Episode A",
        "image_url": "https://example.com/episode.jpg",
        "audio_duration": 1234,
        "playback_position": 321,
        "last_played_at": now,
        "published_at": now,
    }


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("subscription_image_url", "subscription_config", "expected"),
    [
        (
            None,
            {"image_url": "https://config.example.com/cover-a.jpg"},
            "https://config.example.com/cover-a.jpg",
        ),
        (
            "https://column.example.com/cover-b.jpg",
            {"image_url": "   "},
            "https://column.example.com/cover-b.jpg",
        ),
        (
            "https://column.example.com/cover-c.jpg",
            {"image_url": "  https://config.example.com/cover-c.jpg  "},
            "https://config.example.com/cover-c.jpg",
        ),
        (
            "   ",
            {"image_url": "    "},
            None,
        ),
        (
            "  https://column.example.com/cover-d.jpg  ",
            None,
            "https://column.example.com/cover-d.jpg",
        ),
    ],
)
async def test_get_playback_history_lite_paginated_subscription_image_fallback(
    subscription_image_url: str | None,
    subscription_config: dict | None,
    expected: str | None,
):
    db = AsyncMock()
    repository = PodcastEpisodeRepository(db)
    row = {
        **_build_history_row(subscription_image_url, subscription_config),
        "total_count": 1,
    }

    db.execute.return_value = _build_rows_result([row])

    items, total = await repository.get_playback_history_lite_paginated(
        user_id=1,
        page=1,
        size=20,
    )

    assert total == 1
    assert len(items) == 1
    assert items[0]["id"] == 101
    assert items[0]["image_url"] == "https://example.com/episode.jpg"
    assert items[0]["subscription_image_url"] == expected
    assert "subscription_config" not in items[0]
