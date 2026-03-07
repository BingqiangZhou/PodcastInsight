"""Queue repository behavior tests for queue invariants and compaction."""

from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock

import pytest

from app.domains.podcast.models import PodcastQueueItem
from app.domains.podcast.repositories import PodcastQueueRepository


def _queue_item(item_id: int, episode_id: int, position: int) -> SimpleNamespace:
    return SimpleNamespace(
        id=item_id,
        episode_id=episode_id,
        position=position,
        episode=SimpleNamespace(subscription=None),
    )


def _queue_with_items(
    items: list[SimpleNamespace],
    *,
    current_episode_id: int | None,
    revision: int = 0,
) -> SimpleNamespace:
    return SimpleNamespace(
        id=1,
        user_id=1,
        items=items,
        current_episode_id=current_episode_id,
        revision=revision,
        updated_at=None,
    )


def _mock_db() -> SimpleNamespace:
    return SimpleNamespace(
        add=Mock(),
        flush=AsyncMock(),
        commit=AsyncMock(),
        delete=AsyncMock(),
        expire=Mock(),
    )


@pytest.mark.asyncio
async def test_add_or_move_to_tail_adds_new_item_without_full_rewrite() -> None:
    db = _mock_db()
    repo = PodcastQueueRepository(db=db, redis=AsyncMock())
    queue = _queue_with_items(
        [_queue_item(item_id=1, episode_id=10, position=0)],
        current_episode_id=10,
    )

    repo.get_queue_with_items = AsyncMock(side_effect=[queue, queue])
    repo._rewrite_queue_positions = AsyncMock()

    result = await repo.add_or_move_to_tail(user_id=1, episode_id=11, max_items=500)

    assert result is queue
    assert db.add.call_count == 1
    added_item = db.add.call_args.args[0]
    assert isinstance(added_item, PodcastQueueItem)
    assert added_item.episode_id == 11
    assert added_item.position == repo._queue_position_step
    assert queue.current_episode_id == 10
    repo._rewrite_queue_positions.assert_not_awaited()
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_add_or_move_to_tail_keeps_current_episode_at_head() -> None:
    db = _mock_db()
    repo = PodcastQueueRepository(db=db, redis=AsyncMock())
    head = _queue_item(item_id=1, episode_id=10, position=0)
    tail = _queue_item(item_id=2, episode_id=11, position=repo._queue_position_step)
    queue = _queue_with_items([head, tail], current_episode_id=10)

    repo.get_queue_with_items = AsyncMock(side_effect=[queue, queue])
    repo._rewrite_queue_positions = AsyncMock()

    await repo.add_or_move_to_tail(user_id=1, episode_id=10, max_items=500)

    assert head.position == 0
    assert db.add.call_count == 0
    repo._rewrite_queue_positions.assert_not_awaited()
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_activate_episode_moves_existing_item_to_head_and_sets_current() -> None:
    db = _mock_db()
    repo = PodcastQueueRepository(db=db, redis=AsyncMock())
    head = _queue_item(item_id=1, episode_id=10, position=0)
    middle = _queue_item(item_id=2, episode_id=11, position=repo._queue_position_step)
    tail = _queue_item(item_id=3, episode_id=12, position=repo._queue_position_step * 2)
    queue = _queue_with_items([head, middle, tail], current_episode_id=10)

    repo.get_queue_with_items = AsyncMock(side_effect=[queue, queue])
    repo._rewrite_queue_positions = AsyncMock()

    await repo.activate_episode(user_id=1, episode_id=11, max_items=500)

    assert middle.position == -repo._queue_position_step
    assert queue.current_episode_id == 11
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_complete_current_advances_to_next_when_current_not_head() -> None:
    db = _mock_db()
    repo = PodcastQueueRepository(db=db, redis=AsyncMock())
    first = _queue_item(item_id=1, episode_id=10, position=0)
    second = _queue_item(item_id=2, episode_id=11, position=repo._queue_position_step)
    third = _queue_item(
        item_id=3, episode_id=12, position=repo._queue_position_step * 2
    )
    queue = _queue_with_items([first, second, third], current_episode_id=11)

    repo.get_queue_with_items = AsyncMock(side_effect=[queue, queue])
    repo._rewrite_queue_positions = AsyncMock()

    await repo.complete_current(user_id=1)

    db.delete.assert_awaited_once_with(second)
    assert queue.current_episode_id == 12
    assert third.position == -repo._queue_position_step
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_complete_current_clears_current_when_queue_becomes_empty() -> None:
    db = _mock_db()
    repo = PodcastQueueRepository(db=db, redis=AsyncMock())
    only = _queue_item(item_id=1, episode_id=10, position=0)
    queue = _queue_with_items([only], current_episode_id=10)
    db.delete = AsyncMock(side_effect=lambda item: queue.items.remove(item))

    repo.get_queue_with_items = AsyncMock(side_effect=[queue, queue])
    repo._rewrite_queue_positions = AsyncMock()

    await repo.complete_current(user_id=1)

    db.delete.assert_awaited_once_with(only)
    assert queue.current_episode_id is None
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_complete_current_falls_back_to_head_when_current_missing() -> None:
    db = _mock_db()
    repo = PodcastQueueRepository(db=db, redis=AsyncMock())
    head = _queue_item(item_id=1, episode_id=10, position=0)
    next_item = _queue_item(
        item_id=2, episode_id=11, position=repo._queue_position_step
    )
    queue = _queue_with_items([head, next_item], current_episode_id=999)
    db.delete = AsyncMock(side_effect=lambda item: queue.items.remove(item))

    repo.get_queue_with_items = AsyncMock(side_effect=[queue, queue])
    repo._rewrite_queue_positions = AsyncMock()

    await repo.complete_current(user_id=1)

    db.delete.assert_awaited_once_with(head)
    assert queue.current_episode_id == 11
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_add_or_move_to_tail_compacts_positions_when_threshold_reached() -> None:
    db = _mock_db()
    repo = PodcastQueueRepository(db=db, redis=AsyncMock())
    queue = _queue_with_items(
        [
            _queue_item(
                item_id=1,
                episode_id=10,
                position=repo._queue_position_compaction_threshold - 1,
            ),
            _queue_item(
                item_id=2,
                episode_id=11,
                position=repo._queue_position_compaction_threshold,
            ),
        ],
        current_episode_id=10,
    )

    repo.get_queue_with_items = AsyncMock(side_effect=[queue, queue])
    repo._rewrite_queue_positions = AsyncMock()

    await repo.add_or_move_to_tail(user_id=1, episode_id=12, max_items=500)

    repo._rewrite_queue_positions.assert_awaited_once()
    db.commit.assert_awaited_once()


class _ExpirableQueue:
    def __init__(
        self,
        *,
        queue_id: int,
        user_id: int,
        items: list[SimpleNamespace],
        current_episode_id: int | None,
        revision: int = 0,
    ) -> None:
        self.id = queue_id
        self.user_id = user_id
        self._items = items
        self.current_episode_id = current_episode_id
        self.revision = revision
        self.updated_at = None
        self._expired = False

    @property
    def items(self) -> list[SimpleNamespace]:
        if self._expired:
            raise AssertionError("queue.items accessed after expire")
        return self._items


@pytest.mark.asyncio
async def test_remove_item_does_not_access_queue_after_expire() -> None:
    db = _mock_db()
    repo = PodcastQueueRepository(db=db, redis=AsyncMock())
    first = _queue_item(item_id=1, episode_id=10, position=0)
    second = _queue_item(item_id=2, episode_id=11, position=repo._queue_position_step)
    queue = _ExpirableQueue(
        queue_id=1,
        user_id=1,
        items=[first, second],
        current_episode_id=10,
        revision=0,
    )

    db.delete = AsyncMock(side_effect=lambda item: queue.items.remove(item))
    db.expire = Mock(side_effect=lambda obj: setattr(obj, "_expired", True))

    repo.get_queue_with_items = AsyncMock(side_effect=[queue, queue])
    repo._rewrite_queue_positions = AsyncMock()

    result = await repo.remove_item(user_id=1, episode_id=11)

    assert result is queue
    db.commit.assert_awaited_once()
    db.expire.assert_called_once_with(queue)
