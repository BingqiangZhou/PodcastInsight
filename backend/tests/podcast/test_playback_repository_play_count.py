"""Playback repository play_count behavior tests."""

from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock

import pytest

from app.domains.podcast.repositories import PodcastPlaybackRepository


def _mock_db() -> SimpleNamespace:
    return SimpleNamespace(
        add=Mock(),
        commit=AsyncMock(),
        refresh=AsyncMock(),
        flush=AsyncMock(),
    )


def _state(*, is_playing: bool, play_count: int, position: int = 0) -> SimpleNamespace:
    return SimpleNamespace(
        user_id=1,
        episode_id=10,
        current_position=position,
        is_playing=is_playing,
        playback_rate=1.0,
        play_count=play_count,
        last_updated_at=None,
    )


@pytest.mark.asyncio
async def test_play_count_increments_only_on_false_to_true_transition() -> None:
    db = _mock_db()
    repo = PodcastPlaybackRepository(db=db, redis=AsyncMock())
    state = _state(is_playing=False, play_count=3)
    repo.get_playback_state = AsyncMock(return_value=state)

    await repo.update_playback_progress(
        user_id=1,
        episode_id=10,
        position=30,
        is_playing=True,
        playback_rate=1.0,
    )

    assert state.play_count == 4


@pytest.mark.asyncio
async def test_play_count_does_not_increment_on_true_to_true_heartbeat() -> None:
    db = _mock_db()
    repo = PodcastPlaybackRepository(db=db, redis=AsyncMock())
    state = _state(is_playing=True, play_count=7, position=120)
    repo.get_playback_state = AsyncMock(return_value=state)

    await repo.update_playback_progress(
        user_id=1,
        episode_id=10,
        position=122,
        is_playing=True,
        playback_rate=1.0,
    )

    assert state.play_count == 7


@pytest.mark.asyncio
async def test_play_count_does_not_increment_on_true_to_false_transition() -> None:
    db = _mock_db()
    repo = PodcastPlaybackRepository(db=db, redis=AsyncMock())
    state = _state(is_playing=True, play_count=5, position=200)
    repo.get_playback_state = AsyncMock(return_value=state)

    await repo.update_playback_progress(
        user_id=1,
        episode_id=10,
        position=205,
        is_playing=False,
        playback_rate=1.0,
    )

    assert state.play_count == 5


@pytest.mark.asyncio
async def test_play_count_increments_again_after_pause_then_resume() -> None:
    db = _mock_db()
    repo = PodcastPlaybackRepository(db=db, redis=AsyncMock())
    state = _state(is_playing=True, play_count=2, position=50)
    repo.get_playback_state = AsyncMock(return_value=state)

    await repo.update_playback_progress(
        user_id=1,
        episode_id=10,
        position=60,
        is_playing=False,
        playback_rate=1.0,
    )
    await repo.update_playback_progress(
        user_id=1,
        episode_id=10,
        position=61,
        is_playing=True,
        playback_rate=1.0,
    )

    assert state.play_count == 3


@pytest.mark.asyncio
async def test_continuous_heartbeats_do_not_inflate_play_count() -> None:
    db = _mock_db()
    repo = PodcastPlaybackRepository(db=db, redis=AsyncMock())
    state = _state(is_playing=True, play_count=11, position=0)
    repo.get_playback_state = AsyncMock(return_value=state)

    for pos in range(1, 11):
        await repo.update_playback_progress(
            user_id=1,
            episode_id=10,
            position=pos,
            is_playing=True,
            playback_rate=1.0,
        )

    assert state.play_count == 11
