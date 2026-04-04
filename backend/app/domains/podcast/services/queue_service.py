"""Podcast Queue Service - manages single persistent queue per user."""

import logging
from time import perf_counter
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import EpisodeNotFoundError
from app.domains.podcast.repositories import PodcastQueueRepository


logger = logging.getLogger(__name__)


class PodcastQueueService:
    """Service for queue operations and queue snapshot building."""

    MAX_QUEUE_ITEMS = 500

    def __init__(
        self,
        db: AsyncSession,
        user_id: int,
        *,
        repo: PodcastQueueRepository | None = None,
    ):
        self.db = db
        self.user_id = user_id
        self.repo = repo or PodcastQueueRepository(db)

    async def get_queue(self) -> dict[str, Any]:
        queue = await self.repo.get_queue_with_items(self.user_id)
        return await self._build_queue_dict(queue)

    async def add_to_queue(self, episode_id: int) -> dict[str, Any]:
        started_at = perf_counter()
        episode = await self.repo.get_episode_by_id(episode_id, self.user_id)
        if not episode:
            raise EpisodeNotFoundError("Episode not found")

        queue = await self.repo.add_or_move_to_tail(
            user_id=self.user_id,
            episode_id=episode_id,
            max_items=self.MAX_QUEUE_ITEMS,
        )
        result = await self._build_queue_dict(queue)
        logger.debug(
            "[Queue] add_to_queue user_id=%s episode_id=%s items=%s elapsed_ms=%.2f",
            self.user_id,
            episode_id,
            len(result["items"]),
            (perf_counter() - started_at) * 1000,
        )
        return result

    async def remove_from_queue(self, episode_id: int) -> dict[str, Any]:
        queue = await self.repo.remove_item(self.user_id, episode_id)
        return await self._build_queue_dict(queue)

    async def reorder_queue(self, episode_ids: list[int]) -> dict[str, Any]:
        queue = await self.repo.reorder_items(self.user_id, episode_ids)
        return await self._build_queue_dict(queue)

    async def set_current(self, episode_id: int) -> dict[str, Any]:
        queue = await self.repo.set_current(self.user_id, episode_id)
        return await self._build_queue_dict(queue)

    async def activate_episode(self, episode_id: int) -> dict[str, Any]:
        started_at = perf_counter()
        episode = await self.repo.get_episode_by_id(episode_id, self.user_id)
        if not episode:
            raise EpisodeNotFoundError("Episode not found")

        queue = await self.repo.activate_episode(
            user_id=self.user_id,
            episode_id=episode_id,
            max_items=self.MAX_QUEUE_ITEMS,
        )
        result = await self._build_queue_dict(queue)
        logger.debug(
            "[Queue] activate_episode user_id=%s episode_id=%s items=%s elapsed_ms=%.2f",
            self.user_id,
            episode_id,
            len(result["items"]),
            (perf_counter() - started_at) * 1000,
        )
        return result

    async def complete_current(self) -> dict[str, Any]:
        queue = await self.repo.complete_current(self.user_id)
        return await self._build_queue_dict(queue)

    async def _build_queue_dict(self, queue) -> dict[str, Any]:
        items: list[dict[str, Any]] = []
        ordered_items = sorted(queue.items, key=lambda item: (item.position, item.id))
        episode_ids = [item.episode_id for item in ordered_items]
        playback_states = (
            await self.repo.get_playback_states_batch(self.user_id, episode_ids)
            if episode_ids
            else {}
        )

        for item in ordered_items:
            episode = item.episode
            subscription = episode.subscription if episode else None
            subscription_image = None
            if subscription and subscription.config:
                subscription_image = subscription.config.get("image_url")
            playback_state = playback_states.get(item.episode_id)

            items.append(
                {
                    "episode_id": item.episode_id,
                    "position": item.position,
                    "playback_position": (
                        playback_state.current_position if playback_state else None
                    ),
                    "title": episode.title if episode else "",
                    "podcast_id": episode.subscription_id if episode else 0,
                    "audio_url": episode.audio_url if episode else "",
                    "duration": episode.audio_duration if episode else None,
                    "published_at": episode.published_at if episode else None,
                    "image_url": episode.image_url if episode else None,
                    "subscription_title": subscription.title if subscription else None,
                    "subscription_image_url": subscription_image,
                }
            )

        return {
            "current_episode_id": queue.current_episode_id,
            "revision": queue.revision or 0,
            "updated_at": queue.updated_at,
            "items": items,
        }
