"""
Database-backed AI summary generation services.
"""

import asyncio
import json
import logging
import time
from datetime import UTC, datetime
from typing import Any

import aiohttp
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import HTTPException, ValidationError
from app.core.redis import get_shared_redis
from app.core.utils import filter_thinking_content
from app.domains.ai.models import ModelType
from app.domains.ai.repositories import AIModelConfigRepository
from app.domains.podcast.ai_key_resolver import resolve_api_key_with_fallback
from app.domains.podcast.models import PodcastEpisode
from app.domains.subscription.parsers.feed_parser import strip_html_tags


logger = logging.getLogger(__name__)


def _looks_like_html_error_page(text: str) -> bool:
    lowered = text.lower()
    markers = (
        "<!doctype html",
        "<html",
        "<head",
        "cloudflare",
        "524: a timeout occurred",
        "/cdn-cgi/",
    )
    return any(marker in lowered for marker in markers)


class SummaryModelManager:
    """Resolve and invoke text-generation models for summaries."""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.ai_model_repo = AIModelConfigRepository(db)

    async def get_active_summary_model(self, model_name: str | None = None):
        if model_name:
            model = await self.ai_model_repo.get_by_name(model_name)
            if (
                not model
                or not model.is_active
                or model.model_type != ModelType.TEXT_GENERATION
            ):
                raise ValidationError(
                    f"Summary model '{model_name}' not found or not active"
                )
            return model

        active_models = await self.ai_model_repo.get_active_models_by_priority(
            ModelType.TEXT_GENERATION
        )
        if not active_models:
            raise ValidationError("No active summary model found")
        return active_models[0]

    async def generate_summary(
        self,
        transcript: str,
        episode_info: dict[str, Any],
        model_name: str | None = None,
        custom_prompt: str | None = None,
    ) -> dict[str, Any]:
        if model_name:
            model = await self.get_active_summary_model(model_name)
            models_to_try = [model]
        else:
            models_to_try = await self.ai_model_repo.get_active_models_by_priority(
                ModelType.TEXT_GENERATION
            )
            if not models_to_try:
                raise ValidationError("No active text generation models available")

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
                api_key = await self._get_api_key(model_config)
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
            f"All text generation models failed. Last error: {last_error}"
        )

    async def _call_ai_api_with_retry(
        self, model_config, api_key: str, prompt: str, episode_info: dict[str, Any]
    ) -> tuple[str, float, int]:
        max_retries = 3
        base_delay = 2

        for attempt in range(max_retries):
            attempt_start = time.time()
            try:
                summary_content = await self._call_ai_api(
                    model_config=model_config,
                    api_key=api_key,
                    prompt=prompt,
                    episode_info=episode_info,
                )
                processing_time = time.time() - attempt_start
                tokens_used = len(prompt.split()) + len(summary_content.split())
                await self.ai_model_repo.increment_usage(
                    model_config.id, success=True, tokens_used=tokens_used
                )
                return summary_content, processing_time, tokens_used
            except Exception as exc:  # noqa: BLE001
                await self.ai_model_repo.increment_usage(model_config.id, success=False)
                if attempt < max_retries - 1:
                    await asyncio.sleep(base_delay * (2**attempt))
                    continue
                raise Exception(
                    f"Model {model_config.name} failed after {max_retries} attempts: {exc}"
                ) from exc

        raise Exception("Unexpected error in _call_ai_api_with_retry")

    async def _call_ai_api(
        self, model_config, api_key: str, prompt: str, episode_info: dict[str, Any]
    ) -> str:
        del episode_info
        max_prompt_length = 100000
        if len(prompt) > max_prompt_length:
            prompt = prompt[:max_prompt_length] + "\n\n[内容过长，已截断]"

        api_url = model_config.api_url
        if not api_url.endswith("/chat/completions"):
            api_url = (
                f"{api_url}chat/completions"
                if api_url.endswith("/")
                else f"{api_url}/chat/completions"
            )

        timeout = aiohttp.ClientTimeout(total=model_config.timeout_seconds)
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }
        data = {
            "model": model_config.model_id,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": model_config.get_temperature_float() or 0.7,
        }
        if model_config.max_tokens is not None:
            data["max_tokens"] = model_config.max_tokens
        if model_config.extra_config:
            data.update(model_config.extra_config)

        async with (
            aiohttp.ClientSession(timeout=timeout) as session,
            session.post(api_url, headers=headers, json=data) as response,
        ):
            response_text = await response.text()
            content_type = response.headers.get("Content-Type", "")

            if "text/html" in content_type.lower() or (
                _looks_like_html_error_page(response_text)
                and "application/json" not in content_type.lower()
            ):
                raise HTTPException(
                    status_code=500,
                    detail=(
                        "AI summary provider returned an HTML error page "
                        "instead of JSON response"
                    ),
                )

            if response.status != 200:
                error_text = response_text
                if response.status == 400:
                    raise HTTPException(
                        status_code=500,
                        detail=(
                            "AI API bad request (400). Possible causes: invalid model ID, "
                            f"malformed request, or prompt too long. Error: {error_text[:200]}"
                        ),
                    )
                if response.status == 401:
                    raise HTTPException(
                        status_code=500,
                        detail="AI API authentication failed (401). Check API key configuration.",
                    )
                raise HTTPException(
                    status_code=500,
                    detail=f"AI summary API error: {response.status} - {error_text[:200]}",
                )

            try:
                result = json.loads(response_text)
            except json.JSONDecodeError as exc:
                raise HTTPException(
                    status_code=500,
                    detail="AI summary provider returned non-JSON response",
                ) from exc

            if "choices" not in result or not result["choices"]:
                raise HTTPException(
                    status_code=500, detail="Invalid response from AI API"
                )

            content = result["choices"][0].get("message", {}).get("content")
            if not content or not isinstance(content, str):
                raise HTTPException(
                    status_code=500, detail="AI API returned empty or invalid content"
                )

            if _looks_like_html_error_page(content):
                raise HTTPException(
                    status_code=500,
                    detail=(
                        "AI summary provider returned HTML error content "
                        "inside the completion payload"
                    ),
                )

            return filter_thinking_content(content).strip()

    def _build_default_prompt(
        self, episode_info: dict[str, Any], transcript: str
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

    async def _get_api_key(self, model_config) -> str:
        active_models = await self.ai_model_repo.get_active_models(
            ModelType.TEXT_GENERATION
        )
        try:
            return resolve_api_key_with_fallback(
                primary_model=model_config,
                fallback_models=active_models,
                logger=logger,
                invalid_message=(
                    f"No valid API key found. Model '{model_config.name}' has a "
                    "placeholder/invalid API key, and no alternative models with "
                    "valid API keys were found. Please configure a valid API key "
                    "for at least one TEXT_GENERATION model."
                ),
            )
        except ValueError as exc:
            raise ValidationError(str(exc)) from exc

    async def list_available_models(self):
        active_models = await self.ai_model_repo.get_active_models(
            ModelType.TEXT_GENERATION
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
            lock_name, expire=self.summary_lock_ttl_seconds
        )
        if not lock_acquired:
            return await self._wait_for_existing_summary(episode_id)

        try:
            from sqlalchemy import select

            stmt = select(PodcastEpisode).where(PodcastEpisode.id == episode_id)
            result = await self.db.execute(stmt)
            episode = result.scalar_one_or_none()
            if not episode:
                raise ValidationError(f"Episode {episode_id} not found")

            transcript_content = episode.transcript_content
            if not transcript_content:
                raise ValidationError(
                    f"No transcript content available for episode {episode_id}"
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
            return summary_result
        finally:
            await self.redis.release_lock(lock_name)

    async def _wait_for_existing_summary(self, episode_id: int) -> dict[str, Any]:
        from sqlalchemy import select

        for _ in range(self.summary_wait_retries):
            stmt = select(PodcastEpisode.ai_summary).where(
                PodcastEpisode.id == episode_id
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
            f"Summary generation already in progress for episode {episode_id}"
        )

    async def _update_episode_summary(
        self, episode_id: int, summary_result: dict[str, Any]
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
