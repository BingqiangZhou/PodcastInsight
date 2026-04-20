"""Content services - summaries, highlights, daily reports."""

from __future__ import annotations

import asyncio
import json
import logging
import re
import time
from collections.abc import Callable
from datetime import UTC, date, datetime, timedelta
from typing import Any
from zoneinfo import ZoneInfo

import aiohttp
from sqlalchemy import and_, delete, desc, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.ai_client import call_ai_api_with_retry
from app.core.database import get_async_session_factory
from app.core.exceptions import ValidationError
from app.core.redis import get_shared_redis
from app.core.utils import filter_thinking_content
from app.domains.ai.models import ModelType
from app.domains.ai.services.text_generation_service import BaseModelManager
from app.domains.podcast.models import (
    EpisodeHighlight,
    HighlightExtractionTask,
    PodcastDailyReport,
    PodcastDailyReportItem,
    PodcastEpisode,
    PodcastEpisodeTranscript,
    Subscription,
    TranscriptionTask,
    UserSubscription,
)
from app.domains.podcast.parsers.feed_parser import strip_html_tags
from app.domains.podcast.repositories import PodcastSummaryRepository


logger = logging.getLogger(__name__)


class SummaryModelManager(BaseModelManager):
    """Resolve and invoke text-generation models for summaries."""

    def __init__(self, db: AsyncSession):
        super().__init__(
            db=db,
            model_type=ModelType.TEXT_GENERATION,
            operation_name="Summary generation",
        )

    async def generate_summary(
        self,
        transcript: str,
        episode_info: dict[str, Any],
        model_name: str | None = None,
        custom_prompt: str | None = None,
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
                    "Trying text generation model: %s (priority: %s)",
                    model_config.name,
                    model_config.priority,
                )
                api_key = await self.resolve_api_key(model_config)
                if not custom_prompt:
                    custom_prompt = self._build_default_prompt(episode_info, transcript)

                (
                    summary_content,
                    processing_time,
                    tokens_used,
                ) = await self._call_ai_api_with_retry(
                    model_config=model_config,
                    api_key=api_key,
                    prompt=custom_prompt,
                    episode_info=episode_info,
                )

                total_processing_time += processing_time
                total_tokens_used += tokens_used
                return {
                    "summary_content": summary_content,
                    "model_name": model_config.name,
                    "model_id": model_config.id,
                    "processing_time": total_processing_time,
                    "tokens_used": total_tokens_used,
                }
            except Exception as exc:  # noqa: BLE001
                last_error = exc
                logger.warning(
                    "Text generation failed with model %s: %s",
                    model_config.name,
                    exc,
                )
                continue

        raise ValidationError(
            f"All text generation models failed. Last error: {last_error}",
        )

    async def _parse_summary_response(self, content: str) -> str:
        """Parse AI response content into summary."""
        return filter_thinking_content(content).strip()

    async def _call_ai_api_with_retry(
        self,
        model_config,
        api_key: str,
        prompt: str,
        episode_info: dict[str, Any],
    ) -> tuple[str, float, int]:
        """Call AI API with retry logic using shared module."""
        del episode_info  # Not needed for summary generation
        summary_content, processing_time, tokens_used = await call_ai_api_with_retry(
            model_config=model_config,
            api_key=api_key,
            prompt=prompt,
            response_parser=self._parse_summary_response,
            ai_model_repo=self.ai_model_repo,
            operation_name="Summary generation",
        )
        return summary_content, processing_time, tokens_used

    def _build_default_prompt(
        self,
        episode_info: dict[str, Any],
        transcript: str,
    ) -> str:
        """构建默认的摘要提示词"""
        title = episode_info.get("title", "未知标题")
        raw_description = episode_info.get("description", "")

        # 剥离HTML标签，确保AI只看到纯文本内容
        description = strip_html_tags(raw_description)

        prompt = f"""# Role
你是一位追求极致完整性的资深播客内容分析师。你的目标是将冗长的音频转录文本转化为一份详尽、结构化且**极易阅读**的深度研报。

# Task
请根据提供的元数据和转录文本生成总结。
**核心原则**：
1. **完整性**：内容完整性高于篇幅限制，不要受限于固定的段落数量。
2. **可读性**：**严禁使用大段落纯文本（Wall of Text）**。所有信息必须通过"标题 + 列表"的形式呈现，确保用户可以快速扫描核心信息。

# Input Data
<podcast_info>
Title: {title}
Shownotes: {description}
</podcast_info>

<transcript>
{transcript}
</transcript>

# Analysis Constraints
1. **全面覆盖**：不要遗漏任何一个主要话题。如果播客讨论了 10 个不同的话题，请生成 10 个对应的小节。
2. **事实来源严格分级**：
    - **最高优先级**：<transcript>。所有的观点、数据、结论必须严格源自实际的对话转录。
    - **辅助参考**：<podcast_info> (Shownotes)。仅用于提取正确的人名拼写、专业术语。
    - **冲突处理**：如果 Shownotes 内容在 Transcript 中未出现，**坚决不写入总结**。
3. **视觉层级**：这是为了解决"阅读不便"的问题。
    - **多用列表**：主要内容必须使用无序列表（- ）或有序列表（1. ）呈现。
    - **加粗关键**：对人名、工具名、核心数据、关键结论进行**加粗**处理。

# Output Structure (Strictly Follow)

## 1. 一句话摘要 (Executive Summary)
用精炼的语言（50-100字）概括整期播客的核心主旨。

## 2. 核心观点与洞察 (Key Insights & Takeaways)
提取本期播客中所有具有独立价值的观点。
- **数量不限**：务必覆盖所有关键结论。
- **格式要求**：使用列表形式。
    - **[观点关键词]**：详细阐述。
- **逻辑分组**：如果观点较多，请使用**三级标题（###）**进行分类（例如：### 市场趋势、### 技术实现），每一类下面再列出具体观点。

## 3. 内容深度拆解 (Deep Dive / Topic Breakdown)
**这是本总结最核心的部分。** 请顺着对话的时间线或逻辑流，将长文本自然拆解为多个板块。

**【重要格式要求】**：在此部分，**禁止使用自然段落写作**。必须使用**"小标题 + 嵌套列表"**的结构。

- **切分原则**：每当对话切换到一个新的重大话题或议程时，就创建一个新的**三级标题**（例如：### 3.1 话题：...）。
- **内容呈现方式**：
    - 使用 **无序列表** 罗列该话题下的核心论点。
    - 在论点之下，使用 **缩进列表** 补充具体的论据、数据、案例或正反方观点。
    - **人名/工具/数据**：必须**加粗**显示。
    - **示例结构**：
        * **核心论点 A**
            * 细节解释：...
            * 提到的案例：**某某公司**的例子...
        * **核心论点 B**
            * 嘉宾 **[名字]** 提出的反对意见：...
            * 相关数据：增长了 **40%**...

## 4. 精彩语录与金句 (Memorable Quotes)
摘录原文中所有打动人心、发人深省或具有幽默感的原话。
- **格式要求**：使用列表形式。
- **要求**：注明说话人（如果有）和简短背景。

## 5. 适合听众与收获 (Audience & Value)
简要说明本期内容适合哪类人群深入聆听，以及他们能从中学到什么。

# Start Analysis
请开始进行详尽的分析，确保所有内容"条理化"、"列表化"，严格遵守事实分级原则：
"""
        return prompt


class PodcastSummaryGenerationService:
    """Generate and persist AI summaries for podcast episodes."""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.model_manager = SummaryModelManager(db)
        self.redis = get_shared_redis()
        self.summary_lock_ttl_seconds = 1800
        self.summary_wait_retries = 6
        self.summary_wait_interval_seconds = 1.0

    async def generate_summary(
        self,
        episode_id: int,
        model_name: str | None = None,
        custom_prompt: str | None = None,
    ) -> dict[str, Any]:
        lock_name = f"summary:{episode_id}"
        lock_acquired = await self.redis.acquire_lock(
            lock_name,
            expire=self.summary_lock_ttl_seconds,
        )
        if not lock_acquired:
            return await self._wait_for_existing_summary(episode_id)

        try:
            from sqlalchemy import select
            from sqlalchemy.orm import selectinload

            stmt = select(PodcastEpisode).where(PodcastEpisode.id == episode_id).options(
                selectinload(PodcastEpisode.transcript)
            )
            result = await self.db.execute(stmt)
            episode = result.scalar_one_or_none()
            if not episode:
                raise ValidationError(f"Episode {episode_id} not found")

            transcript_content = (
                episode.transcript.transcript_content if episode.transcript else None
            )
            if not transcript_content:
                raise ValidationError(
                    f"No transcript content available for episode {episode_id}",
                )

            episode_info = {
                "title": episode.title,
                "description": episode.description,
                "duration": episode.audio_duration,
            }
            summary_result = await self.model_manager.generate_summary(
                transcript=transcript_content,
                episode_info=episode_info,
                model_name=model_name,
                custom_prompt=custom_prompt,
            )
            await self._update_episode_summary(episode_id, summary_result)
            # Invalidate episode detail cache so next fetch picks up new summary
            try:
                await self.redis.delete_pattern(f"podcast:episode:detail:{episode_id}:*")
            except Exception as e:
                logger.warning(
                    f"Cache invalidation skipped: op=generate_summary "
                    f"cache=episode_detail episode_id={episode_id}: {e}"
                )
            return summary_result
        finally:
            await self.redis.release_lock(lock_name)

    async def _wait_for_existing_summary(self, episode_id: int) -> dict[str, Any]:
        from sqlalchemy import select

        for _ in range(self.summary_wait_retries):
            stmt = select(PodcastEpisode.ai_summary).where(
                PodcastEpisode.id == episode_id,
            )
            result = await self.db.execute(stmt)
            summary_content = result.scalar_one_or_none() or ""
            if summary_content.strip():
                return {
                    "summary_content": filter_thinking_content(summary_content),
                    "model_name": None,
                    "model_id": None,
                    "processing_time": 0.0,
                    "tokens_used": 0,
                    "reused_existing": True,
                }
            await asyncio.sleep(self.summary_wait_interval_seconds)

        raise ValidationError(
            f"Summary generation already in progress for episode {episode_id}",
        )

    async def _update_episode_summary(
        self,
        episode_id: int,
        summary_result: dict[str, Any],
    ):
        from sqlalchemy import update

        summary_content = filter_thinking_content(summary_result["summary_content"])
        summary_result["summary_content"] = summary_content
        model_name = summary_result["model_name"]
        processing_time = summary_result["processing_time"]
        word_count = len(summary_content.split())

        try:
            stmt = (
                update(PodcastEpisode)
                .where(PodcastEpisode.id == episode_id)
                .values(
                    ai_summary=summary_content,
                    summary_version="1.0",
                    status="summarized",
                    updated_at=datetime.now(UTC),
                )
            )
            await self.db.execute(stmt)

            from app.domains.podcast.models import TranscriptionTask

            stmt = (
                update(TranscriptionTask)
                .where(TranscriptionTask.episode_id == episode_id)
                .values(
                    summary_content=summary_content,
                    summary_model_used=model_name,
                    summary_word_count=word_count,
                    summary_processing_time=processing_time,
                    summary_error_message=None,
                    updated_at=datetime.now(UTC),
                )
            )
            await self.db.execute(stmt)
            await self.db.commit()
        except Exception:
            await self.db.rollback()
            raise

    async def regenerate_summary(
        self,
        episode_id: int,
        model_name: str | None = None,
        custom_prompt: str | None = None,
    ) -> dict[str, Any]:
        return await self.generate_summary(episode_id, model_name, custom_prompt)

    async def get_summary_models(self):
        return await self.model_manager.list_available_models()


DatabaseBackedAISummaryService = PodcastSummaryGenerationService


# ── Summary workflow service (merged from summary_workflow_service.py) ──


class SummaryWorkflowService:
    """Coordinate summary operations for both HTTP routes and task handlers."""

    def __init__(
        self,
        db: AsyncSession,
        *,
        repo_factory: Callable[[AsyncSession], PodcastSummaryRepository] = (
            PodcastSummaryRepository
        ),
        summary_service_factory: Callable[
            [AsyncSession],
            PodcastSummaryGenerationService,
        ] = PodcastSummaryGenerationService,
    ):
        self.db = db
        self.repo_factory = repo_factory
        self.summary_service_factory = summary_service_factory
        self.repo = repo_factory(db)
        self.summary_service = summary_service_factory(db)

    async def generate_episode_summary(
        self,
        episode_id: int,
        summary_model: str | None = None,
        custom_prompt: str | None = None,
    ) -> dict[str, Any]:
        """Generate summary and return aligned response payload parts."""
        episode = await self.repo.get_episode_by_id(episode_id)
        if not episode:
            raise ValueError(f"Episode {episode_id} not found")

        summary_result = await self.summary_service.generate_summary(
            episode_id,
            summary_model,
            custom_prompt,
        )
        episode = await self.repo.get_episode_by_id(episode_id)
        final_summary = episode.ai_summary if episode and episode.ai_summary else ""
        final_version = episode.summary_version if episode else "1.0"
        return {
            "episode_id": episode_id,
            "summary": final_summary,
            "version": final_version or "1.0",
            "model_used": summary_result["model_name"],
            "processing_time": summary_result["processing_time"],
            "generated_at": datetime.now(UTC),
        }

    async def accept_episode_summary_generation(
        self,
        episode_id: int,
    ) -> dict[str, Any]:
        """Validate and mark one episode as queued for async summary generation."""
        episode = await self.repo.get_episode_by_id(episode_id)
        if not episode:
            raise ValueError(f"Episode {episode_id} not found")
        if not episode.transcript or not episode.transcript.transcript_content:
            raise ValidationError(
                f"No transcript content available for episode {episode_id}"
            )

        accepted_at = datetime.now(UTC)
        if episode.status == "summary_generating":
            return {
                "episode_id": episode_id,
                "summary_status": "summary_generating",
                "accepted_at": accepted_at,
                "already_queued": True,
            }

        await self.db.execute(
            update(PodcastEpisode)
            .where(PodcastEpisode.id == episode_id)
            .values(
                status="summary_generating",
                updated_at=accepted_at,
            ),
        )
        await self.db.execute(
            update(TranscriptionTask)
            .where(TranscriptionTask.episode_id == episode_id)
            .values(
                summary_error_message=None,
                updated_at=accepted_at,
            ),
        )
        await self.db.commit()
        return {
            "episode_id": episode_id,
            "summary_status": "summary_generating",
            "accepted_at": accepted_at,
            "already_queued": False,
        }

    async def execute_episode_summary_generation(
        self,
        episode_id: int,
        *,
        summary_model: str | None = None,
        custom_prompt: str | None = None,
    ) -> dict[str, Any]:
        """Run one episode summary generation inside a worker context."""
        try:
            result = await self.generate_episode_summary(
                episode_id,
                summary_model=summary_model,
                custom_prompt=custom_prompt,
            )
            logger.info(
                "Episode summary generation completed: episode_id=%s model=%s",
                episode_id,
                result.get("model_used"),
            )
            return result
        except Exception as exc:
            logger.exception(
                "Episode summary generation failed: episode_id=%s", episode_id
            )
            await self._mark_episode_summary_failed(episode_id, str(exc))
            raise

    async def list_pending_summaries_for_user(
        self,
        user_id: int,
    ) -> list[dict[str, Any]]:
        """Return pending summaries for one user."""
        return await self.repo.get_pending_summaries_for_user(user_id)

    async def get_summary_models(self) -> list[dict[str, Any]]:
        """List available summary models."""
        return await self.summary_service.get_summary_models()

    async def generate_pending_summaries_run(
        self,
        *,
        max_episodes_per_run: int = 10,
    ) -> dict[str, Any]:
        """Run the pending-summary batch flow shared by Celery handlers."""
        await self._reset_stale_summary_claims()
        claimed_episode_ids = await self._claim_pending_summary_episode_ids(
            limit=max_episodes_per_run,
        )
        processed_count = 0
        failed_count = 0
        skipped_count = 0

        if not claimed_episode_ids:
            return {
                "status": "success",
                "processed": 0,
                "failed": 0,
                "processed_at": datetime.now(UTC).isoformat(),
            }

        for episode_id in claimed_episode_ids:
            try:
                session_factory = get_async_session_factory()
                async with session_factory() as episode_session:
                    summary_service = self.summary_service_factory(episode_session)
                    await summary_service.generate_summary(episode_id)
                processed_count += 1
            except ValidationError as exc:
                if self._is_skippable_validation_error(exc):
                    skipped_count += 1
                    logger.warning(
                        "Skipping summary for episode %s due to unmet generation precondition: %s",
                        episode_id,
                        exc,
                    )
                    await self._reset_claimed_summary_status(episode_id)
                    continue

                failed_count += 1
                logger.exception(
                    "Failed to generate summary for episode %s", episode_id
                )
                session_factory = get_async_session_factory()
                async with session_factory() as episode_session:
                    repo = self.repo_factory(episode_session)
                    await repo.mark_summary_failed(episode_id, str(exc))
            except Exception as exc:
                failed_count += 1
                logger.exception(
                    "Failed to generate summary for episode %s", episode_id
                )
                session_factory = get_async_session_factory()
                async with session_factory() as episode_session:
                    repo = self.repo_factory(episode_session)
                    await repo.mark_summary_failed(episode_id, str(exc))

        logger.info(
            "Pending summary run completed: processed=%s failed=%s skipped=%s claimed=%s",
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
            or "Summary generation already in progress for episode" in message
        )

    async def _reset_stale_summary_claims(self) -> None:
        stale_before = datetime.now(UTC) - timedelta(hours=1)
        stmt = (
            update(PodcastEpisode)
            .where(
                and_(
                    PodcastEpisode.status == "summary_generating",
                    PodcastEpisode.ai_summary.is_(None),
                    PodcastEpisode.updated_at < stale_before,
                ),
            )
            .values(
                status="summary_failed",
                updated_at=datetime.now(UTC),
            )
        )
        await self.db.execute(stmt)
        await self.db.commit()

    async def _claim_pending_summary_episode_ids(self, *, limit: int) -> list[int]:
        claim_stmt = (
            select(PodcastEpisode.id)
            .outerjoin(
                TranscriptionTask, TranscriptionTask.episode_id == PodcastEpisode.id
            )
            .where(
                and_(
                    PodcastEpisode.ai_summary.is_(None),
                    PodcastEpisode.status.in_(["pending_summary", "summary_failed"]),
                    PodcastEpisode.transcript.has(
                        PodcastEpisodeTranscript.transcript_content.is_not(None),
                    ),
                    PodcastEpisode.transcript.has(
                        PodcastEpisodeTranscript.transcript_content != "",
                    ),
                    or_(
                        TranscriptionTask.id.is_(None),
                        ~TranscriptionTask.status.in_(["pending", "in_progress"]),
                    ),
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

        await self.db.execute(
            update(PodcastEpisode)
            .where(PodcastEpisode.id.in_(episode_ids))
            .values(
                status="summary_generating",
                updated_at=datetime.now(UTC),
            ),
        )
        await self.db.commit()
        return episode_ids

    async def _reset_claimed_summary_status(self, episode_id: int) -> None:
        await self.db.execute(
            update(PodcastEpisode)
            .where(PodcastEpisode.id == episode_id)
            .values(
                status="pending_summary",
                updated_at=datetime.now(UTC),
            ),
        )
        await self.db.commit()

    async def _mark_episode_summary_failed(self, episode_id: int, error: str) -> None:
        failed_at = datetime.now(UTC)
        await self.db.execute(
            update(PodcastEpisode)
            .where(PodcastEpisode.id == episode_id)
            .values(
                status="summary_failed",
                updated_at=failed_at,
            ),
        )
        await self.db.execute(
            update(TranscriptionTask)
            .where(TranscriptionTask.episode_id == episode_id)
            .values(
                summary_error_message=error,
                updated_at=failed_at,
            ),
        )
        await self.db.commit()


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
                    session_factory = get_async_session_factory()
                    async with session_factory() as episode_session:
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
        session_factory = get_async_session_factory()
        async with session_factory() as session:
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
        session_factory = get_async_session_factory()
        async with session_factory() as session:
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


logger = logging.getLogger(__name__)


# ── Summary extraction helpers (merged from daily_report_summary_extractor.py) ──

_HEADING_PREFIX_RE = re.compile(
    r"^\s*(?:#{1,6}\s*|(?:\d+(?:\.\d+)*|[一二三四五六七八九十]+)\s*[\.\)\]、:：]\s*)",
    re.IGNORECASE,
)
_EXEC_SUMMARY_KEYWORD_RE = re.compile(
    r"(?:一句话摘要|Executive Summary)",
    re.IGNORECASE,
)
_MARKDOWN_HEADING_RE = re.compile(r"^\s*#{1,6}\s+\S", re.IGNORECASE)
_NUMBERED_HEADING_RE = re.compile(
    r"^\s*(?:\d+(?:\.\d+)*|[一二三四五六七八九十]+)\s*[\.\)\]、:：]\s+\S",
    re.IGNORECASE,
)
_LEADING_BULLET_RE = re.compile(r"^\s*(?:[-*]\s+|\d+[\.\)]\s+)")
_WHITESPACE_RE = re.compile(r"\s+")
_SENTENCE_RE = re.compile(r"[^。！？!?\.]+[。！？!?\.]?")


def extract_one_line_summary(ai_summary: str | None) -> str | None:
    """Extract one line summary from AI summary markdown text."""
    if not ai_summary:
        return None

    section_text = _extract_executive_summary_section(ai_summary)
    if section_text:
        return section_text

    return _extract_first_sentence(ai_summary)


def _extract_executive_summary_section(summary_text: str) -> str | None:
    section_start = _find_executive_summary_section_start(summary_text)
    if section_start is None:
        return None

    section_end = _find_next_section_heading_start(summary_text, section_start)
    section_body = summary_text[section_start:section_end]

    normalized = _WHITESPACE_RE.sub(" ", section_body).strip()
    return normalized or None


def _find_executive_summary_section_start(summary_text: str) -> int | None:
    line_start = 0
    for line in summary_text.splitlines(keepends=True):
        line_end = line_start + len(line)
        if _is_executive_summary_heading(line):
            return line_end
        line_start = line_end
    return None


def _find_next_section_heading_start(summary_text: str, section_start: int) -> int:
    line_start = section_start
    for line in summary_text[section_start:].splitlines(keepends=True):
        line_end = line_start + len(line)
        if _is_next_section_heading(line):
            return line_start
        line_start = line_end
    return len(summary_text)


def _is_executive_summary_heading(line: str) -> bool:
    text = line.strip()
    if not text:
        return False
    if not _HEADING_PREFIX_RE.match(text):
        return False
    return bool(_EXEC_SUMMARY_KEYWORD_RE.search(text))


def _is_next_section_heading(line: str) -> bool:
    text = line.strip()
    if not text:
        return False
    if _is_executive_summary_heading(line):
        return False
    return bool(
        _MARKDOWN_HEADING_RE.match(text) or _NUMBERED_HEADING_RE.match(text),
    )


def _extract_first_sentence(text: str) -> str | None:
    if not text:
        return None

    normalized = _WHITESPACE_RE.sub(" ", text).strip()
    if not normalized:
        return None

    matches = _SENTENCE_RE.findall(normalized)
    for raw_sentence in matches:
        sentence = _LEADING_BULLET_RE.sub("", raw_sentence).strip()
        sentence = sentence.strip("#").strip()
        if sentence:
            return sentence[:280]

    return None


# ── Daily report service ──


class DailyReportService:
    """Generate and query daily report snapshots for one user."""

    REPORT_TIMEZONE = "Asia/Shanghai"
    REPORT_SCHEDULE_TIME = "03:30"

    def __init__(
        self,
        db: AsyncSession,
        user_id: int,
        task_orchestration_service_factory=None,
    ):
        self.db = db
        self.user_id = user_id
        self._task_orchestration_service_factory = task_orchestration_service_factory

    def _task_orchestration_service(self):
        factory = self._task_orchestration_service_factory
        if factory is None:
            from app.domains.podcast.services.task_orchestration_service import (
                PodcastTaskOrchestrationService,
            )

            factory = PodcastTaskOrchestrationService
        return factory(self.db)

    async def generate_daily_report(
        self,
        target_date: date | None = None,
        *,
        rebuild: bool = False,
    ) -> dict:
        """Generate (or update) report snapshot for a report date."""
        report_date = self._resolve_report_date(target_date)
        window_start_utc, window_end_utc = self._compute_window_utc(report_date)
        now_utc = datetime.now(UTC)

        report = await self._get_or_create_report(report_date, now_utc)
        if rebuild:
            await self._clear_report_items(report.id)

        window_summarized = await self._list_window_summarized_episodes(
            window_start_utc,
            window_end_utc,
        )
        window_unsummarized = await self._list_window_unsummarized_episodes(
            window_start_utc,
            window_end_utc,
        )

        for episode in window_unsummarized:
            await self._trigger_episode_processing(episode.id)

        added_count = 0
        for episode in window_summarized:
            added_count += await self._append_item_if_needed(
                report,
                episode,
                is_carryover=False,
            )

        report.generated_at = now_utc
        report.total_items = await self._count_report_items(report.id)
        await self.db.commit()

        logger.info(
            "Generated daily report for user=%s report_date=%s added=%s total=%s",
            self.user_id,
            report_date,
            added_count,
            report.total_items,
        )
        return await self.get_daily_report(report_date)

    async def get_daily_report(self, target_date: date | None = None) -> dict:
        """Get one report by date; default to latest available."""
        report = await self._load_report(target_date)
        if report is None:
            return {
                "available": False,
                "report_date": None,
                "timezone": self.REPORT_TIMEZONE,
                "schedule_time_local": self.REPORT_SCHEDULE_TIME,
                "generated_at": None,
                "total_items": 0,
                "items": [],
            }

        sorted_items = sorted(report.items, key=lambda item: item.id)
        return {
            "available": True,
            "report_date": report.report_date,
            "timezone": report.timezone,
            "schedule_time_local": report.schedule_time_local,
            "generated_at": report.generated_at,
            "total_items": report.total_items,
            "items": [
                {
                    "episode_id": item.episode_id,
                    "subscription_id": item.subscription_id,
                    "episode_title": item.episode_title_snapshot,
                    "subscription_title": item.subscription_title_snapshot,
                    "one_line_summary": item.one_line_summary,
                    "is_carryover": item.is_carryover,
                    "episode_created_at": item.episode_created_at,
                    "episode_published_at": item.episode_published_at,
                }
                for item in sorted_items
            ],
        }

    async def list_report_dates(self, page: int = 1, size: int = 30) -> dict:
        """List report dates for history date selector."""
        safe_page = max(1, page)
        safe_size = min(max(1, size), 100)

        base_stmt = select(PodcastDailyReport).where(
            PodcastDailyReport.user_id == self.user_id,
        )
        count_stmt = select(func.count()).select_from(base_stmt.subquery())
        total = (await self.db.execute(count_stmt)).scalar() or 0

        stmt = (
            base_stmt.order_by(PodcastDailyReport.report_date.desc())
            .offset((safe_page - 1) * safe_size)
            .limit(safe_size)
        )
        rows = (await self.db.execute(stmt)).scalars().all()
        pages = (total + safe_size - 1) // safe_size if total else 0

        return {
            "dates": [
                {
                    "report_date": row.report_date,
                    "total_items": row.total_items,
                    "generated_at": row.generated_at,
                }
                for row in rows
            ],
            "total": total,
            "page": safe_page,
            "size": safe_size,
            "pages": pages,
        }

    def _resolve_report_date(self, target_date: date | None) -> date:
        if target_date is not None:
            return target_date
        tz = ZoneInfo(self.REPORT_TIMEZONE)
        return datetime.now(tz).date() - timedelta(days=1)

    def _compute_window_utc(self, report_date: date) -> tuple[datetime, datetime]:
        tz = ZoneInfo(self.REPORT_TIMEZONE)
        start_local = datetime.combine(report_date, time.min, tzinfo=tz)
        end_local = start_local + timedelta(days=1)
        return start_local.astimezone(UTC), end_local.astimezone(UTC)

    async def _get_or_create_report(
        self,
        report_date: date,
        now_utc: datetime,
    ) -> PodcastDailyReport:
        stmt = select(PodcastDailyReport).where(
            and_(
                PodcastDailyReport.user_id == self.user_id,
                PodcastDailyReport.report_date == report_date,
            ),
        )
        report = (await self.db.execute(stmt)).scalar_one_or_none()
        if report is not None:
            return report

        report = PodcastDailyReport(
            user_id=self.user_id,
            report_date=report_date,
            timezone=self.REPORT_TIMEZONE,
            schedule_time_local=self.REPORT_SCHEDULE_TIME,
            generated_at=now_utc,
            total_items=0,
        )
        self.db.add(report)
        await self.db.flush()
        return report

    def _base_user_episode_stmt(self):
        return (
            select(PodcastEpisode)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(
                UserSubscription,
                UserSubscription.subscription_id == Subscription.id,
            )
            .options(selectinload(PodcastEpisode.subscription))
            .where(
                and_(
                    UserSubscription.user_id == self.user_id,
                    UserSubscription.is_archived == False,  # noqa: E712
                    Subscription.source_type == "podcast-rss",
                    Subscription.status == "active",
                ),
            )
        )

    def _has_summary_expr(self):
        return and_(
            PodcastEpisode.ai_summary.isnot(None),
            func.length(func.trim(PodcastEpisode.ai_summary)) > 0,
        )

    def _missing_summary_expr(self):
        return and_(
            PodcastEpisode.ai_summary.isnot(None),
            func.length(func.trim(PodcastEpisode.ai_summary)) == 0,
        )

    async def _list_window_summarized_episodes(
        self,
        window_start_utc: datetime,
        window_end_utc: datetime,
    ) -> list[PodcastEpisode]:
        reported_exists = (
            select(PodcastDailyReportItem.id)
            .where(
                and_(
                    PodcastDailyReportItem.user_id == self.user_id,
                    PodcastDailyReportItem.episode_id == PodcastEpisode.id,
                ),
            )
            .exists()
        )

        stmt = (
            self._base_user_episode_stmt()
            .where(
                and_(
                    PodcastEpisode.published_at >= window_start_utc,
                    PodcastEpisode.published_at < window_end_utc,
                    self._has_summary_expr(),
                    ~reported_exists,
                ),
            )
            .order_by(PodcastEpisode.published_at.asc())
        )
        return list((await self.db.execute(stmt)).scalars().all())

    async def _list_window_unsummarized_episodes(
        self,
        window_start_utc: datetime,
        window_end_utc: datetime,
    ) -> list[PodcastEpisode]:
        stmt = (
            self._base_user_episode_stmt()
            .where(
                and_(
                    PodcastEpisode.published_at >= window_start_utc,
                    PodcastEpisode.published_at < window_end_utc,
                    or_(
                        PodcastEpisode.ai_summary.is_(None),
                        self._missing_summary_expr(),
                    ),
                ),
            )
            .order_by(PodcastEpisode.published_at.asc())
        )
        return list((await self.db.execute(stmt)).scalars().all())

    async def _append_item_if_needed(
        self,
        report: PodcastDailyReport,
        episode: PodcastEpisode,
        is_carryover: bool,
    ) -> int:
        existing_stmt = select(PodcastDailyReportItem.id).where(
            and_(
                PodcastDailyReportItem.user_id == self.user_id,
                PodcastDailyReportItem.episode_id == episode.id,
            ),
        )
        existing_id = (await self.db.execute(existing_stmt)).scalar_one_or_none()
        if existing_id is not None:
            return 0

        summary_line = extract_one_line_summary(episode.ai_summary)
        if not summary_line:
            return 0

        item = PodcastDailyReportItem(
            report_id=report.id,
            user_id=self.user_id,
            episode_id=episode.id,
            subscription_id=episode.subscription_id,
            episode_title_snapshot=episode.title,
            subscription_title_snapshot=episode.subscription.title
            if episode.subscription
            else None,
            one_line_summary=summary_line,
            is_carryover=is_carryover,
            episode_created_at=episode.created_at,
            episode_published_at=episode.published_at,
        )
        self.db.add(item)
        await self.db.flush()
        return 1

    async def _clear_report_items(self, report_id: int) -> None:
        stmt = delete(PodcastDailyReportItem).where(
            PodcastDailyReportItem.report_id == report_id,
        )
        await self.db.execute(stmt)
        await self.db.flush()

    async def _count_report_items(self, report_id: int) -> int:
        stmt = select(func.count(PodcastDailyReportItem.id)).where(
            PodcastDailyReportItem.report_id == report_id,
        )
        return (await self.db.execute(stmt)).scalar() or 0

    async def _load_report(self, target_date: date | None) -> PodcastDailyReport | None:
        if target_date is None:
            stmt = (
                select(PodcastDailyReport)
                .options(selectinload(PodcastDailyReport.items))
                .where(PodcastDailyReport.user_id == self.user_id)
                .order_by(PodcastDailyReport.report_date.desc())
                .limit(1)
            )
            return (await self.db.execute(stmt)).scalar_one_or_none()

        stmt = (
            select(PodcastDailyReport)
            .options(selectinload(PodcastDailyReport.items))
            .where(
                and_(
                    PodcastDailyReport.user_id == self.user_id,
                    PodcastDailyReport.report_date == target_date,
                ),
            )
            .limit(1)
        )
        return (await self.db.execute(stmt)).scalar_one_or_none()

    async def _trigger_episode_processing(self, episode_id: int) -> None:
        try:
            self._task_orchestration_service().enqueue_episode_processing(
                episode_id=episode_id,
                user_id=self.user_id,
            )
        except Exception as exc:
            logger.warning(
                "Failed to dispatch transcription/summary pipeline for episode=%s user=%s: %s",
                episode_id,
                self.user_id,
                exc,
            )