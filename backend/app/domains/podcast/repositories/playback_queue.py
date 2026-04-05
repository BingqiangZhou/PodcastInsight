"""Playback and queue repository mixins.

This module uses lazy imports for subscription models to maintain domain boundaries.
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime
from time import perf_counter
from typing import TYPE_CHECKING, Any

from sqlalchemy import and_, func, select
from sqlalchemy.orm import joinedload

from app.core.exceptions import (
    EpisodeNotInQueueError,
    InvalidReorderPayloadError,
    QueueLimitExceededError,
    SubscriptionNotFoundError,
)
from app.domains.podcast.models import (
    PodcastEpisode,
    PodcastPlaybackState,
    PodcastQueue,
    PodcastQueueItem,
)
from app.domains.user.models import User


# Use TYPE_CHECKING to avoid runtime dependency on subscription domain
if TYPE_CHECKING:
    pass


logger = logging.getLogger(__name__)


def _get_user_subscription_model():
    """Lazy import UserSubscription model to maintain domain boundaries.

    Returns:
        UserSubscription model class
    """
    from app.domains.subscription.models import UserSubscription

    return UserSubscription


class PodcastPlaybackQueueRepositoryMixin:
    """Playback preference/progress and queue operations."""

    async def get_user_default_playback_rate(self, user_id: int) -> float:
        stmt = select(User.default_playback_rate).where(User.id == user_id)
        result = await self.db.execute(stmt)
        value = result.scalar_one_or_none()
        return float(value) if value is not None else 1.0

    async def get_subscription_playback_rate_preference(
        self,
        user_id: int,
        subscription_id: int,
    ) -> float | None:
        UserSubscription = _get_user_subscription_model()
        stmt = select(UserSubscription.playback_rate_preference).where(
            and_(
                *self._active_user_subscription_filters(user_id),
                UserSubscription.subscription_id == subscription_id,
            ),
        )
        result = await self.db.execute(stmt)
        value = result.scalar_one_or_none()
        return float(value) if value is not None else None

    async def get_effective_playback_rate(
        self,
        user_id: int,
        subscription_id: int | None = None,
    ) -> dict[str, Any]:
        global_rate = await self.get_user_default_playback_rate(user_id)
        subscription_rate: float | None = None
        source = "global"
        effective_rate = global_rate

        if subscription_id is not None:
            subscription_rate = await self.get_subscription_playback_rate_preference(
                user_id=user_id,
                subscription_id=subscription_id,
            )
            if subscription_rate is not None:
                source = "subscription"
                effective_rate = subscription_rate
            elif global_rate == 1.0:
                source = "default"
        elif global_rate == 1.0:
            source = "default"

        return {
            "global_playback_rate": global_rate,
            "subscription_playback_rate": subscription_rate,
            "effective_playback_rate": effective_rate,
            "source": source,
        }

    async def apply_playback_rate_preference(
        self,
        user_id: int,
        playback_rate: float,
        apply_to_subscription: bool,
        subscription_id: int | None = None,
    ) -> dict[str, Any]:
        UserSubscription = _get_user_subscription_model()
        if apply_to_subscription:
            if subscription_id is None:
                raise ValueError("SUBSCRIPTION_ID_REQUIRED")

            stmt = select(UserSubscription).where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    UserSubscription.subscription_id == subscription_id,
                ),
            )
            result = await self.db.execute(stmt)
            user_sub = result.scalar_one_or_none()
            if user_sub is None:
                raise SubscriptionNotFoundError("Subscription not found")

            user_sub.playback_rate_preference = playback_rate
            await self.db.commit()
            return await self.get_effective_playback_rate(user_id, subscription_id)

        user_stmt = select(User).where(User.id == user_id)
        user_result = await self.db.execute(user_stmt)
        user = user_result.scalar_one_or_none()
        if user is None:
            raise ValueError("USER_NOT_FOUND")

        user.default_playback_rate = playback_rate

        if subscription_id is not None:
            sub_stmt = select(UserSubscription).where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    UserSubscription.subscription_id == subscription_id,
                ),
            )
            sub_result = await self.db.execute(sub_stmt)
            user_sub = sub_result.scalar_one_or_none()
            if user_sub is None:
                raise SubscriptionNotFoundError("Subscription not found")
            user_sub.playback_rate_preference = None

        await self.db.commit()
        return await self.get_effective_playback_rate(user_id, subscription_id)

    async def get_subscription_episodes_batch(
        self,
        subscription_ids: list[int],
        limit_per_subscription: int = 3,
    ) -> dict[int, list[PodcastEpisode]]:
        if not subscription_ids:
            return {}

        ranked_subquery = (
            select(
                PodcastEpisode.id.label("episode_id"),
                func.row_number()
                .over(
                    partition_by=PodcastEpisode.subscription_id,
                    order_by=(
                        PodcastEpisode.published_at.desc(),
                        PodcastEpisode.id.desc(),
                    ),
                )
                .label("row_number"),
            )
            .where(PodcastEpisode.subscription_id.in_(subscription_ids))
            .subquery()
        )

        stmt = (
            select(PodcastEpisode)
            .join(ranked_subquery, ranked_subquery.c.episode_id == PodcastEpisode.id)
            .where(ranked_subquery.c.row_number <= limit_per_subscription)
            .order_by(
                PodcastEpisode.subscription_id.asc(),
                PodcastEpisode.published_at.desc(),
                PodcastEpisode.id.desc(),
            )
        )

        result = await self.db.execute(stmt)
        rows = result.scalars().all()

        episodes_by_sub: dict[int, list[PodcastEpisode]] = {}
        for episode in rows:
            episodes_by_sub.setdefault(episode.subscription_id, []).append(episode)
        return episodes_by_sub

    async def update_playback_progress(
        self,
        user_id: int,
        episode_id: int,
        position: int,
        is_playing: bool = False,
        playback_rate: float = 1.0,
    ) -> PodcastPlaybackState:
        # Use SELECT ... FOR UPDATE to prevent race condition on concurrent
        # progress updates for the same user+episode pair.
        stmt = (
            select(PodcastPlaybackState)
            .where(
                PodcastPlaybackState.user_id == user_id,
                PodcastPlaybackState.episode_id == episode_id,
            )
            .with_for_update()
        )
        result = await self.db.execute(stmt)
        state = result.scalar_one_or_none()

        if state is not None:
            was_playing = bool(state.is_playing)
            state.current_position = position
            state.playback_rate = playback_rate
            if not was_playing and is_playing:
                state.play_count += 1
            state.is_playing = is_playing
            state.last_updated_at = datetime.now(UTC)
            await self.db.flush()
        else:
            state = PodcastPlaybackState(
                user_id=user_id,
                episode_id=episode_id,
                current_position=position,
                is_playing=is_playing,
                playback_rate=playback_rate,
                play_count=1 if is_playing else 0,
                last_updated_at=datetime.now(UTC),
            )
            self.db.add(state)
            await self.db.flush()

        await self.db.commit()

        if self.redis:
            await self.redis.set_user_progress(user_id, episode_id, position / 100)

        return state

    async def get_or_create_queue(self, user_id: int) -> PodcastQueue:
        # Use FOR UPDATE to prevent concurrent queue creation for the same user.
        stmt = select(PodcastQueue).where(
            PodcastQueue.user_id == user_id,
        ).with_for_update()
        result = await self.db.execute(stmt)
        queue = result.scalar_one_or_none()
        if queue is not None:
            return queue

        # Savepoint isolates the INSERT so a concurrent creation that already
        # committed (unique constraint on user_id) can be caught gracefully.
        async with self.db.begin_nested():
            queue = PodcastQueue(user_id=user_id, revision=0)
            self.db.add(queue)
            await self.db.flush()

        return queue

    async def get_queue_with_items(self, user_id: int) -> PodcastQueue:
        queue = await self.get_or_create_queue(user_id)
        stmt = (
            select(PodcastQueue)
            .options(
                joinedload(PodcastQueue.items)
                .joinedload(PodcastQueueItem.episode)
                .joinedload(PodcastEpisode.subscription),
                joinedload(PodcastQueue.current_episode),
            )
            .where(PodcastQueue.id == queue.id)
        )
        result = await self.db.execute(stmt)
        return result.unique().scalar_one()

    async def _refresh_queue_with_items(self, queue: PodcastQueue) -> PodcastQueue:
        """Refresh queue with all relations loaded efficiently.

        This is more efficient than get_queue_with_items when we already have
        the queue object, as it avoids the initial get_or_create_queue query.
        """
        stmt = (
            select(PodcastQueue)
            .options(
                joinedload(PodcastQueue.items)
                .joinedload(PodcastQueueItem.episode)
                .joinedload(PodcastEpisode.subscription),
                joinedload(PodcastQueue.current_episode),
            )
            .where(PodcastQueue.id == queue.id)
        )
        result = await self.db.execute(stmt)
        return result.unique().scalar_one()

    @staticmethod
    def _sorted_queue_items(queue: PodcastQueue) -> list[PodcastQueueItem]:
        return sorted(queue.items, key=lambda item: (item.position, item.id))

    def _queue_needs_compaction(self, items: list[PodcastQueueItem]) -> bool:
        if not items:
            return False

        head_position = items[0].position
        tail_position = items[-1].position
        threshold = self._queue_position_compaction_threshold
        return head_position <= -threshold or tail_position >= threshold

    async def _rewrite_queue_positions(
        self,
        items: list[PodcastQueueItem],
        *,
        start: int = 0,
        step: int | None = None,
    ) -> None:
        """Rewrite queue positions with a single flush for better performance."""
        if not items:
            return

        position_step = step or self._queue_position_step
        # Directly assign final positions without intermediate flush
        for idx, item in enumerate(items):
            item.position = start + (idx * position_step)
        # Single flush at the end for batch efficiency
        await self.db.flush()

    @staticmethod
    def _touch_queue(queue: PodcastQueue) -> None:
        queue.revision = (queue.revision or 0) + 1
        queue.updated_at = datetime.now(UTC)

    @staticmethod
    def _resolve_next_episode_id_after_removal(
        ordered_items_before: list[PodcastQueueItem],
        removed_index: int,
        ordered_items_after: list[PodcastQueueItem],
    ) -> int | None:
        candidate_episode_id: int | None = None
        next_index = removed_index + 1
        if next_index < len(ordered_items_before):
            candidate_episode_id = ordered_items_before[next_index].episode_id

        if candidate_episode_id is not None and any(
            item.episode_id == candidate_episode_id for item in ordered_items_after
        ):
            return candidate_episode_id

        if ordered_items_after:
            return ordered_items_after[0].episode_id
        return None

    async def _ensure_current_at_head(
        self,
        queue: PodcastQueue,
        ordered_items: list[PodcastQueueItem],
    ) -> bool:
        if not ordered_items:
            if queue.current_episode_id is not None:
                queue.current_episode_id = None
                return True
            return False

        current_id = queue.current_episode_id
        if current_id is None:
            queue.current_episode_id = ordered_items[0].episode_id
            return True

        current_item = next(
            (item for item in ordered_items if item.episode_id == current_id),
            None,
        )
        if current_item is None:
            queue.current_episode_id = ordered_items[0].episode_id
            return True

        head_item = ordered_items[0]
        if current_item.id == head_item.id:
            return False

        current_item.position = head_item.position - self._queue_position_step
        await self.db.flush()
        return True

    async def _finalize_queue_mutation(
        self,
        queue: PodcastQueue,
        ordered_items: list[PodcastQueueItem],
        *,
        changed: bool,
        expire_queue_after_commit: bool = False,
    ) -> tuple[list[PodcastQueueItem], bool]:
        if await self._ensure_current_at_head(queue, ordered_items):
            changed = True

        ordered_items = self._sorted_queue_items(queue)
        if self._queue_needs_compaction(ordered_items):
            await self._rewrite_queue_positions(
                ordered_items,
                step=self._queue_position_step,
            )
            changed = True
            ordered_items = self._sorted_queue_items(queue)

        if changed:
            self._touch_queue(queue)
            await self.db.commit()
            if expire_queue_after_commit:
                self.db.expire(queue)

        return ordered_items, changed

    def _queue_operation_log(
        self,
        operation: str,
        *,
        user_id: int,
        queue_size: int,
        revision_before: int,
        revision_after: int,
        elapsed_ms: float,
    ) -> None:
        logger.debug(
            "[Queue] operation=%s user_id=%s queue_size=%s revision_before=%s revision_after=%s elapsed_ms=%.2f",
            operation,
            user_id,
            queue_size,
            revision_before,
            revision_after,
            elapsed_ms,
        )

    async def add_or_move_to_tail(
        self,
        user_id: int,
        episode_id: int,
        max_items: int = 500,
    ) -> PodcastQueue:
        started_at = perf_counter()
        queue = await self.get_queue_with_items(user_id)
        revision_before = queue.revision or 0
        ordered_items = self._sorted_queue_items(queue)
        existing = next(
            (item for item in ordered_items if item.episode_id == episode_id),
            None,
        )
        changed = False

        if existing is None and len(ordered_items) >= max_items:
            raise QueueLimitExceededError("Queue has reached its limit")

        tail_position = ordered_items[-1].position if ordered_items else 0

        if existing is not None:
            if (
                queue.current_episode_id != episode_id
                and existing.position != tail_position
            ):
                existing.position = tail_position + self._queue_position_step
                await self.db.flush()
                changed = True
        else:
            self.db.add(
                PodcastQueueItem(
                    queue_id=queue.id,
                    episode_id=episode_id,
                    position=tail_position + self._queue_position_step
                    if ordered_items
                    else 0,
                ),
            )
            await self.db.flush()
            changed = True

        ordered_items = self._sorted_queue_items(queue)
        _, changed = await self._finalize_queue_mutation(
            queue,
            ordered_items,
            changed=changed,
        )

        self._queue_operation_log(
            "add_or_move_to_tail",
            user_id=user_id,
            queue_size=len(self._sorted_queue_items(queue)),
            revision_before=revision_before,
            revision_after=(revision_before + 1) if changed else revision_before,
            elapsed_ms=(perf_counter() - started_at) * 1000,
        )
        return await self._refresh_queue_with_items(queue)

    async def remove_item(self, user_id: int, episode_id: int) -> PodcastQueue:
        started_at = perf_counter()
        queue = await self.get_queue_with_items(user_id)
        revision_before = queue.revision or 0
        ordered_items_before = self._sorted_queue_items(queue)

        target = next(
            (item for item in ordered_items_before if item.episode_id == episode_id),
            None,
        )
        if not target:
            return queue

        removed_index = ordered_items_before.index(target)
        await self.db.delete(target)
        await self.db.flush()
        ordered_items = self._sorted_queue_items(queue)
        changed = True

        if queue.current_episode_id == episode_id:
            queue.current_episode_id = self._resolve_next_episode_id_after_removal(
                ordered_items_before,
                removed_index,
                ordered_items,
            )

        ordered_items, changed = await self._finalize_queue_mutation(
            queue,
            ordered_items,
            changed=changed,
            expire_queue_after_commit=True,
        )

        self._queue_operation_log(
            "remove_item",
            user_id=user_id,
            queue_size=len(ordered_items),
            revision_before=revision_before,
            revision_after=(revision_before + 1) if changed else revision_before,
            elapsed_ms=(perf_counter() - started_at) * 1000,
        )
        return await self._refresh_queue_with_items(queue)

    async def activate_episode(
        self,
        user_id: int,
        episode_id: int,
        max_items: int = 500,
    ) -> PodcastQueue:
        started_at = perf_counter()
        queue = await self.get_queue_with_items(user_id)
        revision_before = queue.revision or 0
        ordered_items = self._sorted_queue_items(queue)
        existing = next(
            (item for item in ordered_items if item.episode_id == episode_id),
            None,
        )
        changed = False

        if existing is None and len(ordered_items) >= max_items:
            raise QueueLimitExceededError("Queue has reached its limit")

        if existing is None:
            head_position = ordered_items[0].position if ordered_items else 0
            self.db.add(
                PodcastQueueItem(
                    queue_id=queue.id,
                    episode_id=episode_id,
                    position=head_position - self._queue_position_step
                    if ordered_items
                    else 0,
                ),
            )
            await self.db.flush()
            changed = True
            ordered_items = self._sorted_queue_items(queue)
        else:
            head_item = ordered_items[0] if ordered_items else None
            if head_item is not None and existing.id != head_item.id:
                existing.position = head_item.position - self._queue_position_step
                await self.db.flush()
                changed = True
                ordered_items = self._sorted_queue_items(queue)

        if queue.current_episode_id != episode_id:
            queue.current_episode_id = episode_id
            changed = True

        _, changed = await self._finalize_queue_mutation(
            queue,
            ordered_items,
            changed=changed,
        )

        self._queue_operation_log(
            "activate_episode",
            user_id=user_id,
            queue_size=len(self._sorted_queue_items(queue)),
            revision_before=revision_before,
            revision_after=(revision_before + 1) if changed else revision_before,
            elapsed_ms=(perf_counter() - started_at) * 1000,
        )
        return await self._refresh_queue_with_items(queue)

    async def reorder_items(
        self,
        user_id: int,
        ordered_episode_ids: list[int],
    ) -> PodcastQueue:
        started_at = perf_counter()
        queue = await self.get_queue_with_items(user_id)
        revision_before = queue.revision or 0
        ordered_items = self._sorted_queue_items(queue)

        current_ids = [item.episode_id for item in ordered_items]
        if len(set(ordered_episode_ids)) != len(ordered_episode_ids):
            raise InvalidReorderPayloadError("Invalid reorder payload")
        if set(current_ids) != set(ordered_episode_ids):
            raise InvalidReorderPayloadError("Invalid reorder payload")
        if len(current_ids) != len(ordered_episode_ids):
            raise InvalidReorderPayloadError("Invalid reorder payload")

        changed = current_ids != ordered_episode_ids
        desired_current = ordered_episode_ids[0] if ordered_episode_ids else None
        if changed:
            item_map = {item.episode_id: item for item in ordered_items}
            reordered_items = [
                item_map[episode_id] for episode_id in ordered_episode_ids
            ]
            await self._rewrite_queue_positions(
                reordered_items,
                step=self._queue_position_step,
            )

        if queue.current_episode_id != desired_current:
            queue.current_episode_id = desired_current
            changed = True

        _, changed = await self._finalize_queue_mutation(
            queue,
            self._sorted_queue_items(queue),
            changed=changed,
        )

        self._queue_operation_log(
            "reorder_items",
            user_id=user_id,
            queue_size=len(current_ids),
            revision_before=revision_before,
            revision_after=(revision_before + 1) if changed else revision_before,
            elapsed_ms=(perf_counter() - started_at) * 1000,
        )
        return await self._refresh_queue_with_items(queue)

    async def set_current(self, user_id: int, episode_id: int) -> PodcastQueue:
        started_at = perf_counter()
        queue = await self.get_queue_with_items(user_id)
        revision_before = queue.revision or 0
        ordered_items = self._sorted_queue_items(queue)
        target = next(
            (item for item in ordered_items if item.episode_id == episode_id),
            None,
        )
        if target is None:
            raise EpisodeNotInQueueError("Episode not in queue")

        changed = False
        head_item = ordered_items[0] if ordered_items else None
        if head_item is not None and target.id != head_item.id:
            target.position = head_item.position - self._queue_position_step
            await self.db.flush()
            changed = True

        if queue.current_episode_id != episode_id:
            queue.current_episode_id = episode_id
            changed = True

        ordered_items, changed = await self._finalize_queue_mutation(
            queue,
            self._sorted_queue_items(queue),
            changed=changed,
        )

        self._queue_operation_log(
            "set_current",
            user_id=user_id,
            queue_size=len(ordered_items),
            revision_before=revision_before,
            revision_after=(revision_before + 1) if changed else revision_before,
            elapsed_ms=(perf_counter() - started_at) * 1000,
        )
        return await self._refresh_queue_with_items(queue)

    async def complete_current(self, user_id: int) -> PodcastQueue:
        started_at = perf_counter()
        queue = await self.get_queue_with_items(user_id)
        revision_before = queue.revision or 0
        ordered_items_before = self._sorted_queue_items(queue)

        if not ordered_items_before:
            return queue

        target_index = 0
        if queue.current_episode_id is not None:
            current_index = next(
                (
                    idx
                    for idx, item in enumerate(ordered_items_before)
                    if item.episode_id == queue.current_episode_id
                ),
                None,
            )
            if current_index is not None:
                target_index = current_index

        target = ordered_items_before[target_index]
        await self.db.delete(target)
        await self.db.flush()
        ordered_items = self._sorted_queue_items(queue)
        queue.current_episode_id = self._resolve_next_episode_id_after_removal(
            ordered_items_before,
            target_index,
            ordered_items,
        )

        ordered_items, changed = await self._finalize_queue_mutation(
            queue,
            ordered_items,
            changed=True,
            expire_queue_after_commit=True,
        )

        self._queue_operation_log(
            "complete_current",
            user_id=user_id,
            queue_size=len(ordered_items),
            revision_before=revision_before,
            revision_after=(revision_before + 1) if changed else revision_before,
            elapsed_ms=(perf_counter() - started_at) * 1000,
        )
        return await self._refresh_queue_with_items(queue)
