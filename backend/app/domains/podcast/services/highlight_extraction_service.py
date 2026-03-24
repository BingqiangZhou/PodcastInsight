"""高光提取服务 - 从播客转录中提取高光观点"""

import json
import logging
import time
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import and_, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.ai_client import call_ai_api_with_retry
from app.core.database import worker_db_session
from app.core.exceptions import ValidationError
from app.domains.ai.models import ModelType
from app.domains.ai.services.base_model_manager import BaseModelManager
from app.domains.podcast.models import (
    EpisodeHighlight,
    HighlightExtractionTask,
    PodcastEpisode,
)


logger = logging.getLogger(__name__)


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
            except Exception as exc:  # noqa: BLE001
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
        """构建提取提示词"""
        title = episode_info.get("title", "未知标题")

        return f"""# Role
你是一位专业的播客内容分析师，擅长从长文本中提取最具价值的高光观点。

# Task
从以下播客转录文本中提取5-10个最具价值的高光观点原文。

# 评分维度 (0-10分)
1. **洞察力 (insight_score)**: 观点的深度和启发性
2. **新颖性 (novelty_score)**: 观点的独特性和创新性
3. **可操作性 (actionability_score)**: 观点的实用性和可执行性
4. **综合评分 (overall_score)**: 加权平均 (0.5*洞察力 + 0.3*新颖性 + 0.2*可操作性)

# 提取原则
1. **原文优先**: 尽量使用原文表达，保持原汁原味
2. **完整性**: 提取的观点应当是完整的、独立的
3. **多样性**: 覆盖不同话题
4. **质量优先**: 宁缺毋滥

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
      "original_text": "原文引用（必须完整）",
      "context_before": "前文上下文（可选）",
      "context_after": "后文上下文（可选）",
      "insight_score": 8.5,
      "novelty_score": 7.0,
      "actionability_score": 9.0,
      "overall_score": 8.2,
      "speaker_hint": "说话人提示（如可识别）",
      "timestamp_hint": "约15:30（如可识别）",
      "topic_tags": ["AI", "创业"]
    }}
  ]
}}

# Start Analysis
请分析并提取高光观点，只输出JSON，不要其他内容："""

    def _parse_highlights_response(self, content: str) -> list[dict]:
        """解析AI响应，提取高光列表"""
        content = content.strip()

        # 尝试直接解析JSON
        try:
            result = json.loads(content)
            if isinstance(result, dict) and "highlights" in result:
                highlights = result["highlights"]
                if isinstance(highlights, list):
                    return self._validate_highlights(highlights)
        except json.JSONDecodeError:
            pass

        # 尝试提取JSON代码块
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

        # 尝试提取普通代码块
        if "```" in content:
            start = content.find("```") + 3
            # 跳过语言标识
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

        # 尝试找到第一个 { 和最后一个 }
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
        raise ValidationError("无法解析AI返回的高光数据")

    def _validate_highlights(self, highlights: list[dict]) -> list[dict]:
        """验证并标准化高光数据"""
        validated = []
        for h in highlights:
            if not isinstance(h, dict):
                continue

            # 确保必需字段存在
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
            raise ValidationError("未找到有效的高光数据")

        return validated


class HighlightExtractionService:
    """高光提取服务 - 从播客转录中提取高光观点"""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.model_manager = HighlightModelManager(db)

    async def extract_highlights(
        self,
        transcript: str,
        episode_info: dict[str, Any],
        model_name: str | None = None,
    ) -> list[dict[str, Any]]:
        """
        从转录文本中提取高光观点

        Args:
            transcript: 转录文本
            episode_info: {"title": str, "description": str}
            model_name: 指定模型名称（可选）

        Returns:
            高光列表，每个包含：
            - original_text: 原文引用
            - context_before: 前文上下文
            - context_after: 后文上下文
            - insight_score: 洞察力评分 (0-10)
            - novelty_score: 新颖性评分 (0-10)
            - actionability_score: 可操作性评分 (0-10)
            - overall_score: 综合评分 (0-10)
            - speaker_hint: 说话人提示
            - timestamp_hint: 时间戳提示
            - topic_tags: 话题标签列表
        """
        if not transcript or not transcript.strip():
            raise ValidationError("转录文本不能为空")

        result = await self.model_manager.extract_highlights(
            transcript=transcript,
            episode_info=episode_info,
            model_name=model_name,
        )

        return result["highlights"]

    async def list_available_models(self):
        """列出可用的模型"""
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
        """Extract highlights for a single episode and save to database.

        Args:
            episode_id: The episode ID
            model_name: Optional model name to use

        Returns:
            Dict with extraction results
        """
        # Get episode with transcript
        stmt = (
            select(PodcastEpisode)
            .options(selectinload(PodcastEpisode.subscription))
            .where(PodcastEpisode.id == episode_id)
        )
        result = await self.db.execute(stmt)
        episode = result.scalar_one_or_none()

        if not episode:
            raise ValueError(f"Episode {episode_id} not found")

        if not episode.transcript_content or not episode.transcript_content.strip():
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
            # Create new task
            task = HighlightExtractionTask(
                episode_id=episode_id,
                status="in_progress",
                started_at=datetime.now(UTC),
            )
            self.db.add(task)
            await self.db.flush()
        elif task.status == "completed":
            # Already completed, return existing
            return {
                "episode_id": episode_id,
                "status": "already_completed",
                "highlights_count": task.highlights_count,
                "model_used": task.model_used,
            }
        elif task.status == "in_progress":
            # Check if this is a stale task (started more than 30 minutes ago)
            # If so, reset and continue; otherwise skip
            # Aligned with Celery task timeout (25 min hard limit)
            stale_threshold = datetime.now(UTC) - timedelta(minutes=30)
            if task.started_at and task.started_at < stale_threshold:
                # Stale task, reset and continue processing
                task.started_at = datetime.now(UTC)
                task.error_message = None
            else:
                # Recently started by another worker, skip
                raise ValidationError(
                    f"Highlight extraction already in progress for episode {episode_id}"
                )
        else:
            # Failed or pending, reset to in_progress
            task.status = "in_progress"
            task.started_at = datetime.now(UTC)
            task.error_message = None

        await self.db.commit()

        started_at = time.time()
        try:
            # Extract highlights using AI
            episode_info = {
                "title": episode.title,
                "description": episode.description or "",
            }
            highlights = await self.extract_highlights(
                transcript=episode.transcript_content,
                episode_info=episode_info,
                model_name=model_name,
            )

            # Clear existing highlights for this episode
            await self.db.execute(
                update(EpisodeHighlight)
                .where(EpisodeHighlight.episode_id == episode_id)
                .values(status="archived")
            )

            # Save new highlights
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

            # Update task status
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
        """Extract highlights for episodes with transcripts but no highlights.

        Uses concurrent processing with semaphore for rate limiting.
        Each episode gets an isolated database session to prevent transaction conflicts.

        Args:
            max_episodes_per_run: Maximum episodes to process in one run

        Returns:
            Dict with processing results
        """
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

        # Limit concurrency to avoid overwhelming AI API and database
        max_concurrent = min(5, max_episodes_per_run)
        semaphore = asyncio.Semaphore(max_concurrent)

        async def process_episode(episode_id: int) -> str:
            """Process a single episode with isolated session.

            Returns: 'success', 'skipped', or 'failed'
            """
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
                    await self._mark_highlight_extraction_failed_safe(episode_id, str(exc))
                    return "failed"
                except Exception as exc:
                    logger.exception(
                        "Failed to extract highlights for episode %s", episode_id
                    )
                    await self._mark_highlight_extraction_failed_safe(episode_id, str(exc))
                    return "failed"

        # Process all episodes concurrently
        results = await asyncio.gather(
            *[process_episode(episode_id) for episode_id in claimed_episode_ids],
            return_exceptions=True,
        )

        # Count results
        processed_count = sum(1 for r in results if r == "success")
        skipped_count = sum(1 for r in results if r == "skipped")
        failed_count = sum(1 for r in results if r == "failed" or isinstance(r, Exception))

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
        """Reset stale in-progress tasks.

        Tasks are considered stale if started more than 30 minutes ago,
        aligned with Celery task timeout (25 min hard limit).
        """
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
        """Claim episodes for highlight extraction.

        Find episodes that:
        - Have transcript content
        - Don't have a completed or in-progress highlight extraction task
        """
        # Subquery to find episodes with non-claimable task status
        # (completed = already done, in_progress = currently being processed)
        non_claimable_subquery = select(HighlightExtractionTask.episode_id).where(
            HighlightExtractionTask.status.in_(["completed", "in_progress"])
        )

        claim_stmt = (
            select(PodcastEpisode.id)
            .where(
                and_(
                    PodcastEpisode.transcript_content.is_not(None),
                    PodcastEpisode.transcript_content != "",
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

        # Create or reset tasks for claimed episodes
        # Note: We set status to "pending" here, and extract_highlights_for_episode()
        # will set it to "in_progress" when it starts processing.
        # This avoids the conflict where we set "in_progress" here but then
        # extract_highlights_for_episode() detects it and throws "already in progress".
        claimed_ids: list[int] = []
        for episode_id in episode_ids:
            # Check if task exists
            existing_stmt = select(HighlightExtractionTask).where(
                HighlightExtractionTask.episode_id == episode_id
            )
            existing_result = await self.db.execute(existing_stmt)
            existing_task = existing_result.scalar_one_or_none()

            if existing_task is None:
                task = HighlightExtractionTask(
                    episode_id=episode_id,
                    status="pending",
                    started_at=None,  # Will be set when processing starts
                )
                self.db.add(task)
                claimed_ids.append(episode_id)
            elif existing_task.status == "in_progress":
                # Should not happen due to query filter, but defensive check
                # This episode is already being processed, skip it
                continue
            else:
                # Failed or pending, reset to pending (not in_progress!)
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
        """Reset claimed status using a fresh session.

        This method creates a new database session to avoid transaction isolation
        issues when called from within a different session context.
        """
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
        """Mark extraction as failed using a fresh session.

        This method creates a new database session to avoid transaction isolation
        issues when called from within a different session context.
        """
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
