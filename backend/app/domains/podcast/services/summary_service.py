"""Database-backed AI summary generation services."""

from __future__ import annotations

import asyncio
import logging
from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import and_, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.ai_client import call_ai_api_with_retry
from app.core.database import worker_db_session
from app.core.exceptions import ValidationError
from app.core.redis import get_shared_redis
from app.core.utils import filter_thinking_content
from app.domains.ai.models import ModelType
from app.domains.ai.services.base_model_manager import BaseModelManager
from app.domains.podcast.models import (
    PodcastEpisode,
    PodcastEpisodeTranscript,
    TranscriptionTask,
)
from app.domains.podcast.repositories import PodcastSummaryRepository
from app.domains.subscription.parsers.feed_parser import strip_html_tags


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
            from app.core.redis import safe_cache_invalidate

            await safe_cache_invalidate(
                lambda: self.redis.invalidate_episode_detail(episode_id),
                log_warning=logger.warning,
                error_message=(
                    f"Cache invalidation skipped: op=generate_summary "
                    f"cache=episode_detail episode_id={episode_id}"
                ),
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
                async with worker_db_session(
                    "celery-summary-episode"
                ) as episode_session:
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
                async with worker_db_session(
                    "celery-summary-episode"
                ) as episode_session:
                    repo = self.repo_factory(episode_session)
                    await repo.mark_summary_failed(episode_id, str(exc))
            except Exception as exc:
                failed_count += 1
                logger.exception(
                    "Failed to generate summary for episode %s", episode_id
                )
                async with worker_db_session(
                    "celery-summary-episode"
                ) as episode_session:
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
