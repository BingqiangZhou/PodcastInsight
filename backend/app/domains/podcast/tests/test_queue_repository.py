from dataclasses import dataclass, field
from unittest.mock import AsyncMock, Mock

import pytest

from app.domains.podcast.repositories import PodcastEpisodeRepository


@dataclass
class _FakeQueueItem:
    id: int
    episode_id: int
    position: int


@dataclass
class _FakeQueue:
    current_episode_id: int | None
    revision: int = 0
    items: list[_FakeQueueItem] = field(default_factory=list)
    updated_at: object | None = None


def _build_repository(queue: _FakeQueue) -> PodcastEpisodeRepository:
    db = AsyncMock()
    db.expire = Mock()

    async def _delete(item: _FakeQueueItem) -> None:
        queue.items.remove(item)

    db.delete.side_effect = _delete
    repository = PodcastEpisodeRepository(db)
    repository.get_queue_with_items = AsyncMock(side_effect=[queue, queue])  # type: ignore[method-assign]
    return repository


def _queue_items(*items: tuple[int, int, int]) -> list[_FakeQueueItem]:
    return [
        _FakeQueueItem(id=item_id, episode_id=episode_id, position=position)
        for item_id, episode_id, position in items
    ]


def _episode_ids(queue: _FakeQueue, repository: PodcastEpisodeRepository) -> list[int]:
    return [item.episode_id for item in repository._sorted_queue_items(queue)]


@pytest.mark.asyncio
async def test_remove_item_advances_to_following_episode_when_current_removed():
    queue = _FakeQueue(
        current_episode_id=1,
        items=_queue_items((1, 1, 0), (2, 2, 1024), (3, 3, 2048)),
    )
    repository = _build_repository(queue)

    result = await repository.remove_item(user_id=1, episode_id=1)

    assert result.current_episode_id == 2
    assert _episode_ids(result, repository) == [2, 3]
    assert result.revision == 1
    repository.db.commit.assert_awaited_once()
    repository.db.expire.assert_called_once_with(queue)


@pytest.mark.asyncio
async def test_remove_item_clears_current_when_last_item_removed():
    queue = _FakeQueue(
        current_episode_id=5,
        items=_queue_items((1, 5, 0)),
    )
    repository = _build_repository(queue)

    result = await repository.remove_item(user_id=1, episode_id=5)

    assert result.current_episode_id is None
    assert _episode_ids(result, repository) == []
    assert result.revision == 1


@pytest.mark.asyncio
async def test_remove_item_keeps_current_when_non_current_item_removed():
    queue = _FakeQueue(
        current_episode_id=1,
        items=_queue_items((1, 1, 0), (2, 2, 1024), (3, 3, 2048)),
    )
    repository = _build_repository(queue)

    result = await repository.remove_item(user_id=1, episode_id=3)

    assert result.current_episode_id == 1
    assert _episode_ids(result, repository) == [1, 2]
    assert result.revision == 1


@pytest.mark.asyncio
async def test_complete_current_advances_from_current_episode_even_if_not_at_head():
    queue = _FakeQueue(
        current_episode_id=2,
        items=_queue_items((1, 1, 0), (2, 2, 1024), (3, 3, 2048)),
    )
    repository = _build_repository(queue)

    result = await repository.complete_current(user_id=1)

    assert result.current_episode_id == 3
    assert _episode_ids(result, repository) == [3, 1]
    assert result.revision == 1
    repository.db.commit.assert_awaited_once()
    repository.db.expire.assert_called_once_with(queue)


@pytest.mark.asyncio
async def test_complete_current_clears_current_when_queue_becomes_empty():
    queue = _FakeQueue(
        current_episode_id=9,
        items=_queue_items((1, 9, 0)),
    )
    repository = _build_repository(queue)

    result = await repository.complete_current(user_id=1)

    assert result.current_episode_id is None
    assert _episode_ids(result, repository) == []
    assert result.revision == 1
