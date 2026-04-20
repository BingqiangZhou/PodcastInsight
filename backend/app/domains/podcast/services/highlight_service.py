"""Highlight services for podcast episode insights and AI-powered extraction."""

from __future__ import annotations

import asyncio
import json
import logging
import time
from datetime import UTC, date, datetime, timedelta
from typing import Any

import aiohttp
from sqlalchemy import and_, desc, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.ai_client import call_ai_api_with_retry
from app.core.database import worker_db_session
from app.core.exceptions import ValidationError
from app.core.redis import get_shared_redis
from app.domains.ai.models import ModelType
from app.domains.ai.services.base_model_manager import BaseModelManager
from app.domains.podcast.models import (
    EpisodeHighlight,
    HighlightExtractionTask,
    PodcastEpisode,
    PodcastEpisodeTranscript,
    TranscriptionTask,
)
from app.domains.subscription.models import Subscription, UserSubscription


logger = logging.getLogger(__name__)


# ── AI-powered highlight extraction (merged from highlight_extraction_service.py) ──


class HighlightModelManager(BaseModelManager):
    """Resolve and invoke text-generation models for highlight extraction."""

    def __init__(self, db: AsyncSession):
        super().__init__(
            db=db,
            model_type=ModelType.TEXT_GENERATION,
            operation_name="Highlight extraction",
        )

    async def extract_highlights(
        self,
        transcript: str,
        episode_info: dict[str, Any],
        model_name: str | None = None,
    ) -> dict[str, Any]:
        models_to_try = await self.get_models_to_try(
            model_name=model_name,
            error_message="No active text generation models available",
        )

        last_error = None
        total_processing_time = 0.0
        total_tokens_used = 0

        for model_config in models_to_try:
            try:
                logger.info(
                    "Trying highlight extraction model: %s (priority: %s)",
                    model_config.name,
                    model_config.priority,
                )
                api_key = await self.resolve_api_key(model_config)
                prompt = self._build_extraction_prompt(episode_info, transcript)

                (
                    highlights,
                    processing_time,
                    tokens_used,
                ) = await self._call_ai_api_with_retry(
                    model_config=model_config,
                    api_key=api_key,
                    prompt=prompt,
                )

                total_processing_time += processing_time
                total_tokens_used += tokens_used
                return {
                    "highlights": highlights,
                    "model_name": model_config.name,
                    "model_id": model_config.id,
                    "processing_time": total_processing_time,
                    "tokens_used": total_tokens_used,
                }
            except (aiohttp.ClientError, TimeoutError, ValueError, ValidationError, RuntimeError, OSError) as exc:  # noqa: BLE001
                last_error = exc
                logger.warning(
                    "Highlight extraction failed with model %s: %s",
                    model_config.name,
                    exc,
                )
                continue

        raise ValidationError(
            f"All highlight extraction models failed. Last error: {last_error}",
        )

    async def _parse_highlight_response(self, content: str) -> list[dict]:
        """Parse AI response content into highlights list."""
        return self._parse_highlights_response(content)

    async def _call_ai_api_with_retry(
        self,
        model_config,
        api_key: str,
        prompt: str,
    ) -> tuple[list[dict], float, int]:
        """Call AI API with retry logic using shared module."""
        highlights, processing_time, tokens_used = await call_ai_api_with_retry(
            model_config=model_config,
            api_key=api_key,
            prompt=prompt,
            response_parser=self._parse_highlight_response,
            ai_model_repo=self.ai_model_repo,
            operation_name="Highlight extraction",
        )
        return highlights, processing_time, tokens_used

    def _build_extraction_prompt(
        self,
        episode_info: dict[str, Any],
        transcript: str,
    ) -> str:
        """Build extraction prompt."""
        title = episode_info.get("title", "Unknown title")

        return f"""# Role
You are a professional podcast content analyst skilled at extracting the most valuable highlight insights from long texts.

# Task
Extract 5-10 of the most valuable highlight insights from the following podcast transcript.

# Scoring Dimensions (0-10)
1. **Insight (insight_score)**: Depth and inspiration of the viewpoint
2. **Novelty (novelty_score)**: Uniqueness and innovation of the viewpoint
3. **Actionability (actionability_score)**: Practicality and executability of the viewpoint
4. **Overall (overall_score)**: Weighted average (0.5*insight + 0.3*novelty + 0.2*actionability)

# Extraction Principles
1. **Original text priority**: Use original expressions as much as possible
2. **Completeness**: Extracted viewpoints should be complete and independent
3. **Diversity**: Cover different topics
4. **Quality first**: Better fewer than inferior

# Input
<podcast_info>
Title: {title}
</podcast_info>

<transcript>
{transcript[:80000]}
</transcript>

# Output Format (Strict JSON)
{{
  "highlights": [
    {{
      "original_text": "Original quote (must be complete)",
      "context_before": "Before context (optional)",
      "context_after": "After context (optional)",
      "insight_score": 8.5,
      "novelty_score": 7.0,
      "actionability_score": 9.0,
      "overall_score": 8.2,
      "speaker_hint": "Speaker hint (if identifiable)",
      "timestamp_hint": "Approx 15:30 (if identifiable)",
      "topic_tags": ["AI", "Startup"]
    }}
  ]
}}

# Start Analysis
Please analyze and extract highlights, output only JSON, no other content:"""

    def _parse_highlights_response(self, content: str) -> list[dict]:
        """Parse AI response and extract highlights list."""
        content = content.strip()

        # Try direct JSON parse
        try:
            result = json.loads(content)
            if isinstance(result, dict) and "highlights" in result:
                highlights = result["highlights"]
                if isinstance(highlights, list):
                    return self._validate_highlights(highlights)
        except json.JSONDecodeError:
            pass

        # Try JSON code block
        if "```json" in content:
            start = content.find("```json") + 7
            end = content.find("```", start)
            if end != -1:
                try:
                    json_str = content[start:end].strip()
                    result = json.loads(json_str)
                    if isinstance(result, dict) and "highlights" in result:
                        highlights = result["highlights"]
                        if isinstance(highlights, list):
                            return self._validate_highlights(highlights)
                except json.JSONDecodeError:
                    pass

        # Try plain code block
        if "```" in content:
            start = content.find("```") + 3
            while start < len(content) and content[start] != "\n":
                start += 1
            start += 1
            end = content.find("```", start)
            if end != -1:
                try:
                    json_str = content[start:end].strip()
                    result = json.loads(json_str)
                    if isinstance(result, dict) and "highlights" in result:
                        highlights = result["highlights"]
                        if isinstance(highlights, list):
                            return self._validate_highlights(highlights)
                except json.JSONDecodeError:
                    pass

        # Try to find first { and last }
        start = content.find("{")
        end = content.rfind("}")
        if start != -1 and end != -1 and end > start:
            try:
                json_str = content[start : end + 1]
                result = json.loads(json_str)
                if isinstance(result, dict) and "highlights" in result:
                    highlights = result["highlights"]
                    if isinstance(highlights, list):
                        return self._validate_highlights(highlights)
            except json.JSONDecodeError:
                pass

        logger.error("Failed to parse highlights response: %s", content[:500])
        raise ValidationError("Failed to parse AI highlight data")

    def _validate_highlights(self, highlights: list[dict]) -> list[dict]:
        """Validate and standardize highlight data."""
        validated = []
        for h in highlights:
            if not isinstance(h, dict):
                continue

            if "original_text" not in h or not h["original_text"]:
                continue

            validated_highlight = {
                "original_text": str(h["original_text"]),
                "context_before": str(h.get("context_before", "")),
                "context_after": str(h.get("context_after", "")),
                "insight_score": float(h.get("insight_score", 0)),
                "novelty_score": float(h.get("novelty_score", 0)),
                "actionability_score": float(h.get("actionability_score", 0)),
                "overall_score": float(h.get("overall_score", 0)),
                "speaker_hint": str(h.get("speaker_hint", "")),
                "timestamp_hint": str(h.get("timestamp_hint", "")),
                "topic_tags": list(h.get("topic_tags", [])),
            }
            validated.append(validated_highlight)

        if not validated:
            raise ValidationError("No valid highlight data found")

        return validated


class HighlightExtractionService:
    """Extract highlight insights from podcast transcripts using AI."""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.model_manager = HighlightModelManager(db)

    async def extract_highlights(
        self,
        transcript: str,
        episode_info: dict[str, Any],
        model_name: str | None = None,
    ) -> list[dict[str, Any]]:
        """Extract highlight insights from transcript text."""
        if not transcript or not transcript.strip():
            raise ValidationError("Transcript text cannot be empty")

        result = await self.model_manager.extract_highlights(
            transcript=transcript,
            episode_info=episode_info,
            model_name=model_name,
        )

        return result["highlights"]

    async def list_available_models(self):
        """List available models."""
        active_models = await self.model_manager.ai_model_repo.get_active_models(
            ModelType.TEXT_GENERATION,
        )
        return [
            {
                "id": model.id,
                "name": model.name,
                "display_name": model.display_name,
                "provider": model.provider,
                "model_id": model.model_id,
                "is_default": model.is_default,
            }
            for model in active_models
        ]

    async def extract_highlights_for_episode(
        self,
        episode_id: int,
        model_name: str | None = None,
    ) -> dict[str, Any]:
        """Extract highlights for a single episode and save to database."""
        # Get episode with transcript
        stmt = (
            select(PodcastEpisode)
            .options(
                selectinload(PodcastEpisode.subscription),
                selectinload(PodcastEpisode.transcript),
            )
            .where(PodcastEpisode.id == episode_id)
        )
        result = await self.db.execute(stmt)
        episode = result.scalar_one_or_none()

        if not episode:
            raise ValueError(f"Episode {episode_id} not found")

        # Resolve transcript content
        transcript_content = None
        if (
            episode.transcript
            and episode.transcript.transcript_content
            and episode.transcript.transcript_content.strip()
        ):
            transcript_content = episode.transcript.transcript_content
        else:
            task_stmt = (
                select(TranscriptionTask.transcript_content)
                .where(
                    and_(
                        TranscriptionTask.episode_id == episode_id,
                        TranscriptionTask.transcript_content.is_not(None),
                        TranscriptionTask.transcript_content != "",
                    ),
                )
                .order_by(TranscriptionTask.id.desc())
                .limit(1)
            )
            task_result = await self.db.execute(task_stmt)
            fallback_content = task_result.scalar_one_or_none()
            if fallback_content and fallback_content.strip():
                transcript_content = fallback_content
                if not episode.transcript:
                    self.db.add(
                        PodcastEpisodeTranscript(
                            episode_id=episode_id,
                            transcript_content=fallback_content,
                            transcript_word_count=len(fallback_content.split()),
                        )
                    )
                else:
                    episode.transcript.transcript_content = fallback_content
                    episode.transcript.transcript_word_count = len(
                        fallback_content.split()
                    )
                logger.info(
                    "Repaired missing PodcastEpisodeTranscript for episode %s",
                    episode_id,
                )

        if not transcript_content:
            raise ValidationError(
                f"No transcript content available for episode {episode_id}"
            )

        # Check if task already exists
        task_stmt = select(HighlightExtractionTask).where(
            HighlightExtractionTask.episode_id == episode_id
        )
        task_result = await self.db.execute(task_stmt)
        task = task_result.scalar_one_or_none()

        if task is None:
            task = HighlightExtractionTask(
                episode_id=episode_id,
                status="in_progress",
                started_at=datetime.now(UTC),
            )
            self.db.add(task)
            await self.db.flush()
        elif task.status == "completed":
            return {
                "episode_id": episode_id,
                "status": "already_completed",
                "highlights_count": task.highlights_count,
                "model_used": task.model_used,
            }
        elif task.status == "in_progress":
            stale_threshold = datetime.now(UTC) - timedelta(minutes=30)
            if task.started_at and task.started_at < stale_threshold:
                task.started_at = datetime.now(UTC)
                task.error_message = None
            else:
                raise ValidationError(
                    f"Highlight extraction already in progress for episode {episode_id}"
                )
        else:
            task.status = "in_progress"
            task.started_at = datetime.now(UTC)
            task.error_message = None

        await self.db.commit()

        started_at = time.time()
        try:
            episode_info = {
                "title": episode.title,
                "description": episode.description or "",
            }
            highlights = await self.extract_highlights(
                transcript=transcript_content,
                episode_info=episode_info,
                model_name=model_name,
            )

            await self.db.execute(
                update(EpisodeHighlight)
                .where(EpisodeHighlight.episode_id == episode_id)
                .values(status="archived")
            )

            for highlight_data in highlights:
                highlight = EpisodeHighlight(
                    episode_id=episode_id,
                    original_text=highlight_data["original_text"],
                    context_before=highlight_data.get("context_before", ""),
                    context_after=highlight_data.get("context_after", ""),
                    insight_score=highlight_data["insight_score"],
                    novelty_score=highlight_data["novelty_score"],
                    actionability_score=highlight_data["actionability_score"],
                    overall_score=highlight_data["overall_score"],
                    speaker_hint=highlight_data.get("speaker_hint", ""),
                    timestamp_hint=highlight_data.get("timestamp_hint", ""),
                    topic_tags=highlight_data.get("topic_tags", []),
                    model_used=highlight_data.get("model_name", ""),
                    extraction_task_id=task.id,
                )
                self.db.add(highlight)

            processing_time = time.time() - started_at

            task.status = "completed"
            task.completed_at = datetime.now(UTC)
            task.highlights_count = len(highlights)
            task.processing_time = processing_time
            task.model_used = highlights[0].get("model_name", "") if highlights else ""

            await self.db.commit()

            logger.info(
                "Successfully extracted %d highlights for episode %s in %.2fs",
                len(highlights),
                episode_id,
                processing_time,
            )

            return {
                "episode_id": episode_id,
                "status": "completed",
                "highlights_count": len(highlights),
                "processing_time": processing_time,
                "model_used": task.model_used,
            }

        except Exception as exc:
            processing_time = time.time() - started_at
            task.status = "failed"
            task.completed_at = datetime.now(UTC)
            task.error_message = str(exc)
            task.processing_time = processing_time
            await self.db.commit()
            logger.exception("Failed to extract highlights for episode %s", episode_id)
            raise

    async def extract_pending_highlights(
        self,
        *,
        max_episodes_per_run: int = 10,
    ) -> dict[str, Any]:
        """Extract highlights for episodes with transcripts but no highlights."""
        await self._reset_stale_highlight_claims()
        claimed_episode_ids = await self._claim_pending_highlight_episode_ids(
            limit=max_episodes_per_run,
        )

        if not claimed_episode_ids:
            return {
                "status": "success",
                "processed": 0,
                "failed": 0,
                "processed_at": datetime.now(UTC).isoformat(),
            }

        max_concurrent = min(5, max_episodes_per_run)
        semaphore = asyncio.Semaphore(max_concurrent)

        async def process_episode(episode_id: int) -> str:
            async with semaphore:
                try:
                    async with worker_db_session(
                        "celery-highlight-episode"
                    ) as episode_session:
                        service = HighlightExtractionService(episode_session)
                        await service.extract_highlights_for_episode(episode_id)
                    return "success"
                except ValidationError as exc:
                    if self._is_skippable_validation_error(exc):
                        logger.warning(
                            "Skipping highlight extraction for episode %s due to unmet precondition: %s",
                            episode_id,
                            exc,
                        )
                        await self._reset_claimed_highlight_status_safe(episode_id)
                        return "skipped"

                    logger.exception(
                        "Failed to extract highlights for episode %s", episode_id
                    )
                    await self._mark_highlight_extraction_failed_safe(
                        episode_id, str(exc)
                    )
                    return "failed"
                except (aiohttp.ClientError, TimeoutError, RuntimeError, OSError) as exc:
                    logger.exception(
                        "Failed to extract highlights for episode %s", episode_id
                    )
                    await self._mark_highlight_extraction_failed_safe(
                        episode_id, str(exc)
                    )
                    return "failed"

        results = await asyncio.gather(
            *[process_episode(episode_id) for episode_id in claimed_episode_ids],
            return_exceptions=True,
        )

        processed_count = sum(1 for r in results if r == "success")
        skipped_count = sum(1 for r in results if r == "skipped")
        failed_count = sum(
            1 for r in results if r == "failed" or isinstance(r, Exception)
        )

        logger.info(
            "Pending highlight extraction run completed: processed=%s failed=%s skipped=%s claimed=%s",
            processed_count,
            failed_count,
            skipped_count,
            len(claimed_episode_ids),
        )

        return {
            "status": "success",
            "processed": processed_count,
            "failed": failed_count,
            "processed_at": datetime.now(UTC).isoformat(),
        }

    @staticmethod
    def _is_skippable_validation_error(exc: ValidationError) -> bool:
        message = str(exc)
        return (
            "No transcript content available for episode" in message
            or "Highlight extraction already in progress for episode" in message
        )

    async def _reset_stale_highlight_claims(self) -> None:
        """Reset stale in-progress tasks."""
        stale_before = datetime.now(UTC) - timedelta(minutes=30)
        stmt = (
            update(HighlightExtractionTask)
            .where(
                and_(
                    HighlightExtractionTask.status == "in_progress",
                    HighlightExtractionTask.started_at < stale_before,
                ),
            )
            .values(
                status="failed",
                error_message="Task timed out",
                completed_at=datetime.now(UTC),
            )
        )
        await self.db.execute(stmt)
        await self.db.commit()

    async def _claim_pending_highlight_episode_ids(self, *, limit: int) -> list[int]:
        """Claim episodes for highlight extraction."""
        non_claimable_subquery = select(HighlightExtractionTask.episode_id).where(
            HighlightExtractionTask.status.in_(["completed", "in_progress"])
        )

        claim_stmt = (
            select(PodcastEpisode.id)
            .where(
                and_(
                    PodcastEpisode.transcript.has(
                        PodcastEpisodeTranscript.transcript_content.is_not(None),
                    ),
                    PodcastEpisode.transcript.has(
                        PodcastEpisodeTranscript.transcript_content != "",
                    ),
                    ~PodcastEpisode.id.in_(non_claimable_subquery),
                ),
            )
            .order_by(PodcastEpisode.published_at.desc(), PodcastEpisode.id.desc())
            .limit(limit)
            .with_for_update(skip_locked=True, of=PodcastEpisode)
        )
        result = await self.db.execute(claim_stmt)
        episode_ids = list(result.scalars().all())

        if not episode_ids:
            return []

        # Batch fetch existing tasks for all episode_ids
        existing_stmt = select(HighlightExtractionTask).where(
            HighlightExtractionTask.episode_id.in_(episode_ids)
        )
        existing_result = await self.db.execute(existing_stmt)
        existing_tasks = {
            task.episode_id: task for task in existing_result.scalars().all()
        }

        claimed_ids: list[int] = []
        for episode_id in episode_ids:
            existing_task = existing_tasks.get(episode_id)

            if existing_task is None:
                task = HighlightExtractionTask(
                    episode_id=episode_id,
                    status="pending",
                    started_at=None,
                )
                self.db.add(task)
                claimed_ids.append(episode_id)
            elif existing_task.status == "in_progress":
                continue
            else:
                existing_task.status = "pending"
                existing_task.started_at = None
                existing_task.error_message = None
                claimed_ids.append(episode_id)

        await self.db.commit()
        return claimed_ids

    async def _reset_claimed_highlight_status(self, episode_id: int) -> None:
        """Reset claimed status for an episode."""
        stmt = (
            update(HighlightExtractionTask)
            .where(HighlightExtractionTask.episode_id == episode_id)
            .values(status="pending")
        )
        await self.db.execute(stmt)
        await self.db.commit()

    async def _mark_highlight_extraction_failed(
        self,
        episode_id: int,
        error: str,
    ) -> None:
        """Mark highlight extraction as failed."""
        failed_at = datetime.now(UTC)
        stmt = (
            update(HighlightExtractionTask)
            .where(HighlightExtractionTask.episode_id == episode_id)
            .values(
                status="failed",
                error_message=error,
                completed_at=failed_at,
            )
        )
        await self.db.execute(stmt)
        await self.db.commit()

    async def _reset_claimed_highlight_status_safe(self, episode_id: int) -> None:
        """Reset claimed status using a fresh session."""
        async with worker_db_session("celery-highlight-reset") as session:
            stmt = (
                update(HighlightExtractionTask)
                .where(HighlightExtractionTask.episode_id == episode_id)
                .values(status="pending")
            )
            await session.execute(stmt)
            await session.commit()

    async def _mark_highlight_extraction_failed_safe(
        self,
        episode_id: int,
        error: str,
    ) -> None:
        """Mark extraction as failed using a fresh session."""
        failed_at = datetime.now(UTC)
        async with worker_db_session("celery-highlight-fail") as session:
            stmt = (
                update(HighlightExtractionTask)
                .where(HighlightExtractionTask.episode_id == episode_id)
                .values(
                    status="failed",
                    error_message=error,
                    completed_at=failed_at,
                )
            )
            await session.execute(stmt)
            await session.commit()


# ── Highlight query service (original highlight_service.py) ──


class HighlightService:
    """Service for managing podcast episode highlights."""

    def __init__(
        self,
        db: AsyncSession,
        user_id: int,
        redis: Any | None = None,
    ):
        self.db = db
        self.user_id = user_id
        self._redis = redis

    async def get_highlights(
        self,
        page: int = 1,
        per_page: int = 20,
        episode_id: int | None = None,
        min_score: float | None = None,
        date_from: date | None = None,
        date_to: date | None = None,
        favorited_only: bool = False,
    ) -> dict:
        """Get highlights with pagination and filtering."""
        # Build base query - only highlights from user's subscriptions
        base_query = (
            select(EpisodeHighlight)
            .join(PodcastEpisode, EpisodeHighlight.episode_id == PodcastEpisode.id)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, Subscription.id == UserSubscription.subscription_id)
            .where(
                and_(
                    UserSubscription.user_id == self.user_id,
                    EpisodeHighlight.status == "active",
                )
            )
        )

        # Apply filters
        if episode_id is not None:
            base_query = base_query.where(EpisodeHighlight.episode_id == episode_id)

        if min_score is not None:
            base_query = base_query.where(EpisodeHighlight.overall_score >= min_score)

        if date_from is not None:
            # Use datetime range instead of func.date() to allow index usage
            base_query = base_query.where(
                EpisodeHighlight.created_at >= datetime.combine(date_from, time.min)
            )

        if date_to is not None:
            # Use datetime range instead of func.date() to allow index usage
            base_query = base_query.where(
                EpisodeHighlight.created_at <= datetime.combine(date_to, time.max)
            )

        if favorited_only:
            base_query = base_query.where(EpisodeHighlight.is_user_favorited)

        # Get total count
        count_query = select(func.count()).select_from(base_query.subquery())
        total_result = await self.db.execute(count_query)
        total = total_result.scalar() or 0

        # Get paginated results with eager loading
        query = (
            base_query.options(
                selectinload(EpisodeHighlight.episode).selectinload(
                    PodcastEpisode.subscription
                )
            )
            .order_by(desc(EpisodeHighlight.overall_score))
            .offset((page - 1) * per_page)
            .limit(per_page)
        )

        result = await self.db.execute(query)
        highlights = result.scalars().all()

        # Build response items
        items = []
        for highlight in highlights:
            episode = highlight.episode
            subscription = episode.subscription if episode else None

            items.append(
                {
                    "id": highlight.id,
                    "episode_id": highlight.episode_id,
                    "episode_title": episode.title if episode else "Unknown Episode",
                    "subscription_title": subscription.title if subscription else None,
                    "original_text": highlight.original_text,
                    "context_before": highlight.context_before,
                    "context_after": highlight.context_after,
                    "insight_score": highlight.insight_score,
                    "novelty_score": highlight.novelty_score,
                    "actionability_score": highlight.actionability_score,
                    "overall_score": highlight.overall_score,
                    "speaker_hint": highlight.speaker_hint,
                    "timestamp_hint": highlight.timestamp_hint,
                    "topic_tags": highlight.topic_tags or [],
                    "is_user_favorited": highlight.is_user_favorited,
                    "created_at": highlight.created_at,
                }
            )

        has_more = page * per_page < total

        return {
            "items": items,
            "total": total,
            "page": page,
            "per_page": per_page,
            "has_more": has_more,
        }

    async def get_highlight_dates(self) -> dict:
        """Get list of dates that have highlights for calendar component."""
        redis = self._redis or get_shared_redis()

        async def _loader() -> list[str]:
            query = (
                select(func.date(EpisodeHighlight.created_at).label("highlight_date"))
                .join(PodcastEpisode, EpisodeHighlight.episode_id == PodcastEpisode.id)
                .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
                .join(UserSubscription, Subscription.id == UserSubscription.subscription_id)
                .where(
                    and_(
                        UserSubscription.user_id == self.user_id,
                        EpisodeHighlight.status == "active",
                    )
                )
                .distinct()
                .order_by(desc("highlight_date"))
            )
            result = await self.db.execute(query)
            dates = [str(row[0]) for row in result.all()]
            return dates

        try:
            dates = await redis.get_highlight_dates(self.user_id, _loader)
        except Exception:
            # Fallback to direct DB query if Redis is unavailable
            dates = await _loader()

        return {"dates": dates}

    async def get_stats(self) -> dict:
        """Get highlight statistics for Profile card."""
        # Single query combining count, avg, and max for better performance
        stats_query = (
            select(
                func.count(EpisodeHighlight.id).label("total"),
                func.avg(EpisodeHighlight.overall_score).label("avg_score"),
                func.max(EpisodeHighlight.created_at).label("latest_created_at"),
            )
            .join(PodcastEpisode, EpisodeHighlight.episode_id == PodcastEpisode.id)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, Subscription.id == UserSubscription.subscription_id)
            .where(
                and_(
                    UserSubscription.user_id == self.user_id,
                    EpisodeHighlight.status == "active",
                )
            )
        )
        result = await self.db.execute(stats_query)
        row = result.one()

        total_highlights = row.total or 0
        avg_score = row.avg_score or 0.0
        latest_created_at = row.latest_created_at

        latest_extraction_date = None
        if latest_created_at:
            latest_extraction_date = latest_created_at.date()

        return {
            "total_highlights": total_highlights,
            "avg_score": round(avg_score, 2),
            "latest_extraction_date": latest_extraction_date,
        }

    async def toggle_favorite(
        self,
        highlight_id: int,
        favorited: bool,
    ) -> dict:
        """Toggle favorite status for a highlight."""
        # Get highlight with ownership check
        query = (
            select(EpisodeHighlight)
            .join(PodcastEpisode, EpisodeHighlight.episode_id == PodcastEpisode.id)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, Subscription.id == UserSubscription.subscription_id)
            .where(
                and_(
                    EpisodeHighlight.id == highlight_id,
                    UserSubscription.user_id == self.user_id,
                    EpisodeHighlight.status == "active",
                )
            )
        )

        result = await self.db.execute(query)
        highlight = result.scalar_one_or_none()

        if not highlight:
            return {
                "success": False,
                "message": "Highlight not found or access denied",
                "message_en": "Highlight not found or access denied",
                "message_zh": "高光观点未找到或无权访问",
            }

        # Update favorite status
        highlight.is_user_favorited = favorited
        await self.db.commit()

        # Invalidate highlight dates cache (toggle_favorite may change dates)
        try:
            redis = self._redis or get_shared_redis()
            await redis.invalidate_highlight_dates(self.user_id)
        except Exception:
            pass  # Cache invalidation is best-effort

        return {
            "success": True,
            "id": highlight.id,
            "is_user_favorited": highlight.is_user_favorited,
        }
