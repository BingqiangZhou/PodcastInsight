"""Shared transcription orchestration service for routes and task handlers."""

from __future__ import annotations

import logging
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis import PodcastRedis, get_shared_redis
from app.domains.podcast.models import PodcastEpisode
from app.domains.podcast.services.sync_service import PodcastSyncService
from app.domains.podcast.services.transcription_dispatch_guard import (
    TranscriptionDispatchGuard,
)
from app.domains.podcast.services.transcription_runtime_service import (
    PodcastTranscriptionRuntimeService,
)
from app.domains.podcast.services.transcription_schedule_service import (
    PodcastTranscriptionScheduleService,
    batch_transcribe_subscription,
    get_episode_transcript,
)
from app.domains.podcast.services.transcription_state_coordinator import (
    TranscriptionStateCoordinator,
)
from app.domains.podcast.services.transcription_status_projection import (
    build_transcription_status_payload,
)
from app.domains.podcast.transcription_schedule_projections import (
    BatchTranscriptionProjection,
    CheckNewEpisodesProjection,
    EpisodeTranscriptionScheduleProjection,
    EpisodeTranscriptProjection,
    PendingTranscriptionsProjection,
    TranscriptionCancelProjection,
    TranscriptionScheduleStatusProjection,
)
from app.domains.podcast.transcription_state import get_transcription_state_manager
from app.domains.podcast.transcription_types import ScheduleFrequency


logger = logging.getLogger(__name__)


class TranscriptionWorkflowService:
    """Coordinate transcription task orchestration across routes and workers."""

    def __init__(
        self,
        db: AsyncSession,
        *,
        transcription_service_factory: Callable[
            [AsyncSession], PodcastTranscriptionRuntimeService
        ] = PodcastTranscriptionRuntimeService,
        scheduler_factory: Callable[
            [AsyncSession], PodcastTranscriptionScheduleService
        ] = PodcastTranscriptionScheduleService,
        sync_service_factory: Callable[
            [AsyncSession, int], PodcastSyncService
        ] = PodcastSyncService,
        state_manager_factory: Callable[
            [], Awaitable[Any]
        ] = get_transcription_state_manager,
        redis_factory: Callable[[], PodcastRedis] = get_shared_redis,
        claim_dispatched: Callable[[AsyncSession, int], Awaitable[bool]] | None = None,
        clear_dispatched: Callable[[int], Awaitable[None]] | None = None,
    ):
        self.db = db
        self.transcription_service_factory = transcription_service_factory
        self.scheduler_factory = scheduler_factory
        self.sync_service_factory = sync_service_factory
        self.state_manager_factory = state_manager_factory
        self.redis_factory = redis_factory
        self.claim_dispatched = claim_dispatched
        self.clear_dispatched = clear_dispatched
        self.dispatch_guard = TranscriptionDispatchGuard(
            db,
            redis_factory=redis_factory,
            claim_dispatched=claim_dispatched,
            clear_dispatched=clear_dispatched,
        )
        self.state_coordinator = TranscriptionStateCoordinator(
            state_manager_factory=state_manager_factory
        )

    async def start_episode_transcription(
        self,
        episode_id: int,
        *,
        transcription_model: str | None = None,
        force_regenerate: bool = False,
        episode_lookup: Callable[[int], Awaitable[PodcastEpisode | None]],
    ) -> dict[str, Any]:
        """Start or reuse a transcription task and update redis state."""
        episode = await episode_lookup(episode_id)
        if not episode:
            raise ValueError(f"Episode {episode_id} not found")

        transcription_service = self.transcription_service_factory(self.db)
        start_result = await transcription_service.start_transcription(
            episode_id,
            transcription_model,
            force_regenerate,
        )
        task = start_result["task"]
        action = start_result["action"]

        await self.state_coordinator.mark_start_result(episode_id, task, action)

        return {"task": task, "action": action, "episode": episode}

    async def dispatch_pending_transcriptions(
        self,
        episode_ids: list[int],
    ) -> dict[str, Any]:
        """Start backlog transcriptions through the shared service entrypoint."""
        transcription_service = self.transcription_service_factory(self.db)
        dispatched_count = 0
        skipped_count = 0
        failed_count = 0
        skipped_reasons: dict[str, int] = {}

        for episode_id in episode_ids:
            try:
                result = await transcription_service.start_transcription(
                    episode_id,
                    force=False,
                )
                action = result.get("action", "unknown")
                if action in {
                    "created",
                    "redispatched_pending",
                    "redispatched_failed_with_temp",
                }:
                    dispatched_count += 1
                    continue

                skipped_count += 1
                skipped_reasons[action] = skipped_reasons.get(action, 0) + 1
            except Exception:
                failed_count += 1
                logger.exception(
                    "Failed to dispatch backlog transcription for episode %s",
                    episode_id,
                )

        return {
            "checked": len(episode_ids),
            "dispatched": dispatched_count,
            "skipped": skipped_count,
            "failed": failed_count,
            "skipped_reasons": skipped_reasons,
        }

    async def delete_episode_transcription(
        self,
        episode_id: int,
        *,
        episode_lookup: Callable[[int], Awaitable[PodcastEpisode | None]],
    ) -> dict[str, Any]:
        """Delete transcription task and cleanup redis state."""
        episode = await episode_lookup(episode_id)
        if not episode:
            raise ValueError(f"Episode {episode_id} not found")

        transcription_service = self.transcription_service_factory(self.db)
        task_id = await transcription_service.delete_episode_transcription(episode_id)
        await self.state_coordinator.cleanup_deleted_task(episode_id, task_id)

        return {"task_id": task_id, "episode": episode}

    async def get_transcription_task_status(
        self,
        task_id: int,
        *,
        episode_lookup: Callable[[int], Awaitable[PodcastEpisode | None]],
    ) -> dict[str, Any]:
        """Get task status and enforce episode access."""
        transcription_service = self.transcription_service_factory(self.db)
        task = await transcription_service.get_transcription_status(task_id)
        if not task:
            raise ValueError("Transcription task not found")

        episode = await episode_lookup(task.episode_id)
        if not episode:
            raise PermissionError(
                "You don't have permission to access this transcription task"
            )

        return build_transcription_status_payload(
            task,
            status_key=self._status_value(task.status),
        )

    async def schedule_episode_transcription(
        self,
        episode_id: int,
        *,
        frequency: ScheduleFrequency,
        force: bool,
        episode_lookup: Callable[[int], Awaitable[PodcastEpisode | None]],
    ) -> EpisodeTranscriptionScheduleProjection:
        episode = await episode_lookup(episode_id)
        if not episode:
            raise ValueError(f"Episode {episode_id} not found")
        scheduler = self.scheduler_factory(self.db)
        return await scheduler.schedule_transcription(
            episode_id=episode_id,
            frequency=frequency,
            force=force,
        )

    async def get_episode_transcript_payload(
        self,
        episode_id: int,
        *,
        episode_lookup: Callable[[int], Awaitable[PodcastEpisode | None]],
    ) -> EpisodeTranscriptProjection:
        episode = await episode_lookup(episode_id)
        if not episode:
            raise ValueError(f"Episode {episode_id} not found")

        transcript = await get_episode_transcript(self.db, episode_id)
        if not transcript:
            raise LookupError(
                "No transcription found for this episode. Please schedule transcription first."
            )

        return EpisodeTranscriptProjection(
            episode_id=episode_id,
            episode_title=episode.title,
            transcript_length=len(transcript),
            transcript=transcript,
            status="success",
        )

    async def batch_transcribe_subscription(
        self,
        subscription_id: int,
        *,
        skip_existing: bool,
        subscription_lookup: Callable[[int], Awaitable[Any | None]],
    ) -> BatchTranscriptionProjection:
        subscription = await subscription_lookup(subscription_id)
        if not subscription:
            raise ValueError(f"Subscription {subscription_id} not found")
        return await batch_transcribe_subscription(
            self.db,
            subscription_id,
            skip_existing=skip_existing,
        )

    async def get_schedule_status(
        self,
        episode_id: int,
        *,
        episode_lookup: Callable[[int], Awaitable[PodcastEpisode | None]],
    ) -> TranscriptionScheduleStatusProjection:
        episode = await episode_lookup(episode_id)
        if not episode:
            raise ValueError(f"Episode {episode_id} not found")
        scheduler = self.scheduler_factory(self.db)
        return await scheduler.get_transcription_status(episode_id)

    async def cancel_episode_transcription(
        self,
        episode_id: int,
        *,
        episode_lookup: Callable[[int], Awaitable[PodcastEpisode | None]],
    ) -> TranscriptionCancelProjection:
        episode = await episode_lookup(episode_id)
        if not episode:
            raise ValueError(f"Episode {episode_id} not found")
        scheduler = self.scheduler_factory(self.db)
        success = await scheduler.cancel_transcription(episode_id)
        return TranscriptionCancelProjection(
            success=success,
            message=(
                "Transcription cancelled"
                if success
                else "No active transcription to cancel"
            ),
        )

    async def check_and_transcribe_new_episodes(
        self,
        subscription_id: int,
        *,
        hours_since_published: int,
        subscription_lookup: Callable[[int], Awaitable[Any | None]],
    ) -> CheckNewEpisodesProjection:
        subscription = await subscription_lookup(subscription_id)
        if not subscription:
            raise ValueError(f"Subscription {subscription_id} not found")
        scheduler = self.scheduler_factory(self.db)
        return await scheduler.check_and_transcribe_new_episodes(
            subscription_id=subscription_id,
            hours_since_published=hours_since_published,
        )

    async def list_pending_transcriptions(
        self,
        *,
        episode_lookup: Callable[[int], Awaitable[PodcastEpisode | None]],
    ) -> PendingTranscriptionsProjection:
        scheduler = self.scheduler_factory(self.db)
        tasks = await scheduler.get_pending_transcriptions()
        user_tasks = []
        for task in tasks:
            episode = await episode_lookup(task.episode_id)
            if episode:
                user_tasks.append(task)
        return PendingTranscriptionsProjection(total=len(user_tasks), tasks=user_tasks)

    async def cleanup_old_temp_files(self, *, days: int = 7) -> dict[str, Any]:
        """Cleanup stale transcription temporary files via the shared service."""
        transcription_service = self.transcription_service_factory(self.db)
        return await transcription_service.cleanup_old_temp_files(days=days)

    async def reset_stale_tasks(self) -> None:
        """Reset stale in-progress tasks at application startup."""
        transcription_service = self.transcription_service_factory(self.db)
        await transcription_service.reset_stale_tasks()

    async def execute_transcription_task(
        self,
        task_id: int,
        *,
        config_db_id: int | None,
    ) -> dict[str, Any]:
        """Worker-side transcription execution flow with redis lock/progress state."""
        return await self.state_coordinator.execute_task_with_state(
            db=self.db,
            task_id=task_id,
            config_db_id=config_db_id,
            transcription_service_factory=self.transcription_service_factory,
            dispatch_guard=self.dispatch_guard,
            status_value=self._status_value,
        )

    async def trigger_episode_pipeline(
        self,
        episode_id: int,
        *,
        user_id: int,
        episode_lookup: Callable[[int], Awaitable[PodcastEpisode | None]],
    ) -> dict[str, Any]:
        """Dispatch transcription pipeline for one episode."""
        episode = await episode_lookup(episode_id)
        if episode is None:
            return {
                "status": "error",
                "message": "Episode not found",
                "episode_id": episode_id,
            }

        sync_service = self.sync_service_factory(self.db, user_id)
        transcription_task = await sync_service.trigger_transcription(episode_id)
        if not transcription_task:
            raise RuntimeError(
                f"Failed to trigger transcription for episode={episode_id}, user={user_id}"
            )

        return {
            "status": "queued",
            "episode_id": episode_id,
            "transcription_task_id": transcription_task["task_id"],
            "processed_at": datetime.now(UTC).isoformat(),
        }

    @staticmethod
    def _status_value(status: object) -> str:
        return status.value if hasattr(status, "value") else str(status)
