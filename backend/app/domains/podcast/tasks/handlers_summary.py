"""Handlers for summary generation tasks."""

from __future__ import annotations

import logging
from datetime import datetime, timezone

from sqlalchemy import select

from app.core.exceptions import ValidationError
from app.domains.podcast.models import PodcastEpisode, TranscriptionTask
from app.domains.podcast.repositories import PodcastRepository
from app.domains.podcast.summary_manager import DatabaseBackedAISummaryService


logger = logging.getLogger(__name__)


def _is_missing_transcript_validation_error(exc: ValidationError) -> bool:
    """Return True when summary generation fails due to transcript unavailability."""
    return "No transcript content available for episode" in str(exc)


async def generate_pending_summaries_handler(session) -> dict:
    """Generate summaries for pending episodes."""
    repo = PodcastRepository(session)
    summary_service = DatabaseBackedAISummaryService(session)
    max_episodes_per_run = 10
    pending_fetch_window = max_episodes_per_run * 5
    pending_episodes = await repo.get_unsummarized_episodes(limit=pending_fetch_window)
    if len(pending_episodes) > max_episodes_per_run:
        logger.info(
            "Found %s pending summaries, attempting up to %s eligible episodes this run",
            len(pending_episodes),
            max_episodes_per_run,
        )

    processed_count = 0
    failed_count = 0
    skipped_running_count = 0
    skipped_no_transcript_count = 0
    eligible_attempt_count = 0
    episodes_with_transcript = [
        episode
        for episode in pending_episodes
        if (episode.transcript_content or "").strip()
    ]
    skipped_no_transcript_count = len(pending_episodes) - len(episodes_with_transcript)

    if not episodes_with_transcript:
        return {
            "status": "success",
            "processed": 0,
            "failed": 0,
            "processed_at": datetime.now(timezone.utc).isoformat(),
        }

    candidate_episode_ids = [episode.id for episode in episodes_with_transcript]
    running_stmt = select(TranscriptionTask.episode_id).where(
        TranscriptionTask.episode_id.in_(candidate_episode_ids),
        TranscriptionTask.status.in_(["pending", "in_progress"]),
    )
    running_result = await session.execute(running_stmt)
    running_episode_ids = set(running_result.scalars().all())

    for episode in episodes_with_transcript:
        if eligible_attempt_count >= max_episodes_per_run:
            break
        try:
            if episode.id in running_episode_ids:
                skipped_running_count += 1
                continue

            eligible_attempt_count += 1
            await summary_service.generate_summary(episode.id)
            processed_count += 1
        except ValidationError as exc:
            if _is_missing_transcript_validation_error(exc):
                skipped_no_transcript_count += 1
                logger.warning(
                    "Skipping summary for episode %s because transcript is not available yet",
                    episode.id,
                )
                continue

            failed_count += 1
            logger.exception("Failed to generate summary for episode %s", episode.id)
            await repo.mark_summary_failed(episode.id, str(exc))
        except Exception as exc:
            failed_count += 1
            logger.exception("Failed to generate summary for episode %s", episode.id)
            await repo.mark_summary_failed(episode.id, str(exc))

    logger.info(
        "Pending summary run completed: processed=%s failed=%s skipped_no_transcript=%s skipped_running=%s attempted=%s total_pending=%s",
        processed_count,
        failed_count,
        skipped_no_transcript_count,
        skipped_running_count,
        eligible_attempt_count,
        len(pending_episodes),
    )

    return {
        "status": "success",
        "processed": processed_count,
        "failed": failed_count,
        "processed_at": datetime.now(timezone.utc).isoformat(),
    }


async def generate_summary_for_episode_handler(
    session,
    episode_id: int,
    user_id: int,
) -> dict:
    """Generate summary for a single episode."""
    episode_stmt = select(PodcastEpisode).where(PodcastEpisode.id == episode_id)
    episode_result = await session.execute(episode_stmt)
    episode = episode_result.scalar_one_or_none()
    if episode is None:
        return {
            "status": "error",
            "message": "Episode not found",
            "episode_id": episode_id,
        }

    summary_service = DatabaseBackedAISummaryService(session)
    summary_result = await summary_service.generate_summary(episode_id)
    summary = summary_result["summary_content"]

    return {
        "status": "success",
        "episode_id": episode_id,
        "summary": summary,
        "processed_at": datetime.now(timezone.utc).isoformat(),
    }
