"""Podcast transcription scheduling helpers."""

import logging
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ValidationError
from app.domains.podcast.models import (
    PodcastEpisode,
    TranscriptionStatus,
    TranscriptionTask,
)
from app.domains.podcast.services.transcription_runtime_service import (
    PodcastTranscriptionRuntimeService,
)
from app.domains.podcast.transcription_schedule_projections import (
    BatchTranscriptionDetailProjection,
    BatchTranscriptionProjection,
    CheckNewEpisodesDetailProjection,
    CheckNewEpisodesProjection,
    EpisodeTranscriptionScheduleProjection,
    PendingTranscriptionTaskProjection,
    TranscriptionScheduleStatusProjection,
)
from app.domains.podcast.transcription_types import ScheduleFrequency


logger = logging.getLogger(__name__)


class PodcastTranscriptionScheduleService:
    """Scheduler facade for podcast transcription tasks."""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.transcription_service = PodcastTranscriptionRuntimeService(db)

    @staticmethod
    def _status_value(status: Any) -> str:
        return status.value if hasattr(status, "value") else str(status)

    async def schedule_transcription(
        self,
        episode_id: int,
        frequency: ScheduleFrequency = ScheduleFrequency.MANUAL,
        custom_interval: int | None = None,
        force: bool = False,
    ) -> EpisodeTranscriptionScheduleProjection:
        del frequency, custom_interval
        episode = await self._get_episode(episode_id)
        if not episode:
            raise ValidationError(f"Episode {episode_id} not found")
        start_result = await self.transcription_service.start_transcription(
            episode_id, force=force
        )
        task = start_result["task"]
        action = start_result["action"]

        if action == "reused_completed":
            return EpisodeTranscriptionScheduleProjection(
                status="skipped",
                message="Transcription already exists",
                task_id=task.id,
                transcript_content=(
                    task.transcript_content[:100] + "..."
                    if task.transcript_content
                    else None
                ),
                reason="Already transcribed, use force=true to regenerate",
                action=action,
            )
        if action in {"reused_in_progress", "reused_pending", "locked_by_other_task"}:
            return EpisodeTranscriptionScheduleProjection(
                status="processing",
                message="Transcription task already in progress",
                task_id=task.id,
                progress=task.progress_percentage,
                current_status=self._status_value(task.status),
                action=action,
            )

        return EpisodeTranscriptionScheduleProjection(
            status="scheduled",
            message="Transcription task started",
            task_id=task.id,
            episode_id=episode_id,
            scheduled_at=datetime.now(UTC),
            action=action,
        )

    async def batch_schedule_transcription(
        self,
        subscription_id: int,
        frequency: ScheduleFrequency = ScheduleFrequency.DAILY,
        limit: int | None = None,
        skip_existing: bool = True,
    ) -> list[BatchTranscriptionDetailProjection]:
        stmt = (
            select(PodcastEpisode)
            .where(PodcastEpisode.subscription_id == subscription_id)
            .order_by(PodcastEpisode.published_at.desc())
        )
        if limit:
            stmt = stmt.limit(limit)

        episodes = (await self.db.execute(stmt)).scalars().all()
        if not episodes:
            return []

        results: list[BatchTranscriptionDetailProjection] = []
        for episode in episodes:
            try:
                schedule_result = await self.schedule_transcription(
                    episode_id=episode.id,
                    frequency=frequency,
                    force=False,
                )
                if (
                    not skip_existing
                    and schedule_result.status == "skipped"
                    and schedule_result.action == "reused_completed"
                ):
                    schedule_result = await self.schedule_transcription(
                        episode_id=episode.id,
                        frequency=frequency,
                        force=True,
                    )
                results.append(
                    BatchTranscriptionDetailProjection(
                        episode_id=episode.id,
                        episode_title=episode.title,
                        **schedule_result.to_response_payload(),
                    )
                )
            except Exception as exc:  # noqa: BLE001
                results.append(
                    BatchTranscriptionDetailProjection(
                        episode_id=episode.id,
                        episode_title=episode.title,
                        status="error",
                        error=str(exc),
                    )
                )
        return results

    async def check_and_transcribe_new_episodes(
        self,
        subscription_id: int,
        hours_since_published: int = 24,
    ) -> CheckNewEpisodesProjection:
        cutoff_time = datetime.now(UTC) - timedelta(
            hours=hours_since_published
        )

        stmt = (
            select(PodcastEpisode)
            .where(
                and_(
                    PodcastEpisode.subscription_id == subscription_id,
                    PodcastEpisode.published_at >= cutoff_time,
                    or_(
                        PodcastEpisode.transcript_content.is_(None),
                        PodcastEpisode.transcript_content == "",
                    ),
                )
            )
            .order_by(PodcastEpisode.published_at.desc())
        )

        new_episodes = (await self.db.execute(stmt)).scalars().all()
        if not new_episodes:
            return CheckNewEpisodesProjection(
                status="completed",
                message="No new episodes found",
                processed=0,
                skipped=0,
            )

        results: list[CheckNewEpisodesDetailProjection] = []
        for episode in new_episodes:
            try:
                schedule_result = await self.schedule_transcription(
                    episode_id=episode.id,
                    frequency=ScheduleFrequency.MANUAL,
                    force=False,
                )
                results.append(
                    CheckNewEpisodesDetailProjection(
                        episode_id=episode.id,
                        status="scheduled",
                        task_id=schedule_result.task_id,
                    )
                )
            except Exception as exc:  # noqa: BLE001
                results.append(
                    CheckNewEpisodesDetailProjection(
                        episode_id=episode.id,
                        status="error",
                        error=str(exc),
                    )
                )

        scheduled = sum(1 for item in results if item.status == "scheduled")
        errors = sum(1 for item in results if item.status == "error")
        return CheckNewEpisodesProjection(
            status="completed",
            message=f"Scheduled {scheduled} new episodes for transcription",
            processed=len(new_episodes),
            scheduled=scheduled,
            errors=errors,
            details=results,
        )

    async def get_transcription_status(
        self, episode_id: int
    ) -> TranscriptionScheduleStatusProjection:
        episode = await self._get_episode(episode_id)
        if not episode:
            raise ValidationError(f"Episode {episode_id} not found")

        task = await self._get_existing_transcription_task(episode_id)
        if not task:
            return TranscriptionScheduleStatusProjection(
                episode_id=episode_id,
                episode_title=episode.title,
                status="not_started",
                has_transcript=episode.transcript_content is not None,
                transcript_preview=(
                    episode.transcript_content[:100] + "..."
                    if episode.transcript_content
                    else None
                ),
            )

        return TranscriptionScheduleStatusProjection(
            episode_id=episode_id,
            episode_title=episode.title,
            task_id=task.id,
            status=self._status_value(task.status),
            progress=task.progress_percentage,
            created_at=task.created_at,
            updated_at=task.updated_at,
            completed_at=task.completed_at,
            has_transcript=task.transcript_content is not None,
            transcript_preview=(
                task.transcript_content[:100] + "..."
                if self._status_value(task.status) == TranscriptionStatus.COMPLETED.value
                and task.transcript_content
                else None
            ),
            transcript_word_count=task.transcript_word_count,
            has_summary=task.summary_content is not None,
            summary_word_count=task.summary_word_count,
            error_message=task.error_message,
        )

    async def get_pending_transcriptions(self) -> list[PendingTranscriptionTaskProjection]:
        stmt = (
            select(TranscriptionTask)
            .where(
                TranscriptionTask.status.in_(
                    [
                        TranscriptionStatus.PENDING.value,
                        TranscriptionStatus.IN_PROGRESS.value,
                    ]
                )
            )
            .order_by(TranscriptionTask.created_at.desc())
        )

        tasks = (await self.db.execute(stmt)).scalars().all()
        return [
            PendingTranscriptionTaskProjection(
                task_id=task.id,
                episode_id=task.episode_id,
                status=self._status_value(task.status),
                progress=task.progress_percentage,
                created_at=task.created_at,
                updated_at=task.updated_at,
            )
            for task in tasks
        ]

    async def cancel_transcription(self, episode_id: int) -> bool:
        task = await self._get_existing_transcription_task(episode_id)
        if not task:
            return False
        return await self.transcription_service.cancel_transcription(task.id)

    async def get_transcript_from_existing(self, episode_id: int) -> str | None:
        episode = await self._get_episode(episode_id)
        if episode and episode.transcript_content:
            return episode.transcript_content

        task = await self._get_existing_transcription_task(episode_id)
        if (
            task
            and self._status_value(task.status) == TranscriptionStatus.COMPLETED.value
            and task.transcript_content
        ):
            return task.transcript_content
        return None

    async def _get_episode(self, episode_id: int) -> PodcastEpisode | None:
        stmt = select(PodcastEpisode).where(PodcastEpisode.id == episode_id)
        return (await self.db.execute(stmt)).scalar_one_or_none()

    async def _get_existing_transcription_task(
        self, episode_id: int
    ) -> TranscriptionTask | None:
        stmt = select(TranscriptionTask).where(
            TranscriptionTask.episode_id == episode_id
        )
        return (await self.db.execute(stmt)).scalar_one_or_none()


async def get_episode_transcript(db: AsyncSession, episode_id: int) -> str | None:
    scheduler = PodcastTranscriptionScheduleService(db)
    return await scheduler.get_transcript_from_existing(episode_id)


async def batch_transcribe_subscription(
    db: AsyncSession,
    subscription_id: int,
    skip_existing: bool = True,
) -> BatchTranscriptionProjection:
    scheduler = PodcastTranscriptionScheduleService(db)
    results = await scheduler.batch_schedule_transcription(
        subscription_id=subscription_id,
        skip_existing=skip_existing,
    )

    return BatchTranscriptionProjection(
        subscription_id=subscription_id,
        total=len(results),
        scheduled=sum(1 for item in results if item.status == "scheduled"),
        skipped=sum(1 for item in results if item.status == "skipped"),
        errors=sum(1 for item in results if item.status == "error"),
        details=results,
    )


TranscriptionScheduler = PodcastTranscriptionScheduleService
