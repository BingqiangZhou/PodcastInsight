"""
Database-backed AI summary generation services.
"""

import asyncio
import logging
import time
from datetime import datetime, timezone
from typing import Any

import aiohttp
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import HTTPException, ValidationError
from app.core.redis import PodcastRedis
from app.core.utils import filter_thinking_content
from app.domains.ai.models import ModelType
from app.domains.ai.repositories import AIModelConfigRepository
from app.domains.podcast.ai_key_resolver import resolve_api_key_with_fallback
from app.domains.podcast.models import PodcastEpisode
from app.domains.subscription.parsers.feed_parser import strip_html_tags


logger = logging.getLogger(__name__)


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

                summary_content, processing_time, tokens_used = (
                    await self._call_ai_api_with_retry(
                        model_config=model_config,
                        api_key=api_key,
                        prompt=custom_prompt,
                        episode_info=episode_info,
                    )
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
            prompt = prompt[:max_prompt_length] + "\n\n[鍐呭杩囬暱锛屽凡鎴柇]"

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
            if response.status != 200:
                error_text = await response.text()
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

            result = await response.json()
            if "choices" not in result or not result["choices"]:
                raise HTTPException(status_code=500, detail="Invalid response from AI API")

            content = result["choices"][0].get("message", {}).get("content")
            if not content or not isinstance(content, str):
                raise HTTPException(
                    status_code=500, detail="AI API returned empty or invalid content"
                )

            return filter_thinking_content(content).strip()

    def _build_default_prompt(
        self, episode_info: dict[str, Any], transcript: str
    ) -> str:
        title = episode_info.get("title", "鏈煡鏍囬")
        description = strip_html_tags(episode_info.get("description", ""))
        return f"""# Role
浣犳槸涓€浣嶈拷姹傛瀬鑷村畬鏁存€х殑璧勬繁鎾鍐呭鍒嗘瀽甯堛€備綘鐨勭洰鏍囨槸灏嗗啑闀跨殑闊抽杞綍鏂囨湰杞寲涓轰竴浠借灏姐€佺粨鏋勫寲涓?*鏋佹槗闃呰**鐨勬繁搴︾爺鎶ャ€?
# Input Data
<podcast_info>
Title: {title}
Shownotes: {description}
</podcast_info>

<transcript>
{transcript}
</transcript>
"""

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
        self.redis = PodcastRedis()
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
            stmt = select(PodcastEpisode.ai_summary).where(PodcastEpisode.id == episode_id)
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
                    updated_at=datetime.now(timezone.utc),
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
                    updated_at=datetime.now(timezone.utc),
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
