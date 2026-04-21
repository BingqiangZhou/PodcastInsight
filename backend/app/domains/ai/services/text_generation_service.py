"""AI-powered text generation, runtime invocation, and base model management.

Consolidates the former text_generation_service, model_runtime_service,
and base_model_manager into a single module.
"""

from __future__ import annotations

import asyncio
import logging
import os
import time
from typing import Any

import aiofiles
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.ai_client import AIClientService
from app.core.exceptions import ValidationError
from app.core.http_client import get_shared_http_session
from app.core.utils import calculate_backoff
from app.domains.ai.model_testing import (
    test_text_generation_model,
    test_transcription_model,
    validate_api_key,
)
from app.domains.ai.models import AIModelConfig, ModelType
from app.domains.ai.repositories import AIModelConfigRepository
from app.domains.ai.schemas import APIKeyValidationResponse, ModelTestResponse
from app.domains.podcast.ai_key_resolver import resolve_api_key_with_fallback

from .model_config_service import AIModelSecurityService


logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# BaseModelManager -- shared model resolution / API-key fallback patterns
# ---------------------------------------------------------------------------


class BaseModelManager:
    """Base class providing common model management functionality.

    This class encapsulates shared patterns for:
    - Model resolution by name or priority
    - API key resolution with fallback
    - Active model listing

    Subclasses should implement:
    - Specific generation/extraction methods
    - Prompt building logic
    - Response parsing logic
    """

    def __init__(
        self,
        db: AsyncSession,
        model_type: ModelType,
        operation_name: str = "AI operation",
    ):
        """Initialize the model manager.

        Args:
            db: AsyncSession for database access
            model_type: The type of AI model this manager handles
            operation_name: Human-readable name for logging (e.g., "Highlight extraction")
        """
        self.db = db
        self.model_type = model_type
        self.operation_name = operation_name
        self.ai_model_repo = AIModelConfigRepository(db)

    async def get_active_model(
        self,
        model_name: str | None = None,
        *,
        error_message: str | None = None,
    ) -> Any:
        """Get active model by name or highest priority."""
        if model_name:
            model = await self.ai_model_repo.get_by_name(model_name)
            if not model or not model.is_active or model.model_type != self.model_type:
                raise ValidationError(
                    f"{self.operation_name} model '{model_name}' not found or not active",
                )
            return model

        active_models = await self.ai_model_repo.get_active_models_by_priority(
            self.model_type,
        )
        if not active_models:
            msg = (
                error_message or f"No active {self.operation_name.lower()} model found"
            )
            raise ValidationError(msg)
        return active_models[0]

    async def get_models_to_try(
        self,
        model_name: str | None = None,
        *,
        error_message: str | None = None,
    ) -> list[Any]:
        """Get list of models to try for fallback."""
        if model_name:
            model = await self.get_active_model(model_name, error_message=error_message)
            return [model]

        models = await self.ai_model_repo.get_active_models_by_priority(
            self.model_type,
        )
        if not models:
            msg = error_message or f"No active {self.model_type.value} models available"
            raise ValidationError(msg)
        return models

    async def resolve_api_key(
        self,
        model_config: Any,
        *,
        invalid_message: str | None = None,
    ) -> str:
        """Resolve valid API key for model with fallback."""
        active_models = await self.ai_model_repo.get_active_models(
            self.model_type,
        )

        msg = invalid_message or (
            f"No valid API key found. Model '{model_config.name}' has a "
            "placeholder/invalid API key, and no alternative models with "
            f"valid API keys were found for {self.operation_name}."
        )

        try:
            return resolve_api_key_with_fallback(
                primary_model=model_config,
                fallback_models=active_models,
                logger=logger,
                invalid_message=msg,
            )
        except ValueError as exc:
            raise ValidationError(str(exc)) from exc

    async def list_available_models(self) -> list[dict[str, Any]]:
        """List all available models for this manager's model type."""
        active_models = await self.ai_model_repo.get_active_models(
            self.model_type,
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


# ---------------------------------------------------------------------------
# AIModelRuntimeService -- runtime validation, testing, and fallback calls
# ---------------------------------------------------------------------------


class RetryableModelError(Exception):
    """Transient model invocation error that can be retried."""


def _is_retryable_http_status(status_code: int) -> bool:
    return status_code >= 500 or status_code in {408, 409, 425, 429}


class AIModelRuntimeService:
    """Handle model testing, validation, and runtime fallback invocations."""

    def __init__(
        self,
        repo: AIModelConfigRepository,
        security_service: AIModelSecurityService,
    ):
        self.repo = repo
        self.security_service = security_service

    async def test_model(
        self,
        model_id: int,
        test_data: dict[str, Any] | None = None,
    ) -> ModelTestResponse:
        if test_data is None:
            test_data = {}

        model = await self.repo.get_by_id(model_id)
        if not model:
            raise ValidationError(f"Model {model_id} not found")
        if not model.is_active:
            raise ValidationError(f"Model {model_id} is not active")

        api_key = await self.security_service.get_decrypted_api_key(model)
        started_at = time.time()

        try:
            if model.model_type == ModelType.TRANSCRIPTION:
                result = await test_transcription_model(model, api_key, test_data)
            else:
                result = await test_text_generation_model(model, api_key, test_data)

            await self.repo.increment_usage(model_id, success=True)
            return ModelTestResponse(
                success=True,
                response_time_ms=(time.time() - started_at) * 1000,
                result=result,
            )
        except (ValueError, RuntimeError, OSError) as exc:
            await self.repo.increment_usage(model_id, success=False)
            logger.error("Model test failed: %s", exc)
            return ModelTestResponse(
                success=False,
                response_time_ms=(time.time() - started_at) * 1000,
                error_message=str(exc),
            )

    async def validate_api_key(
        self,
        api_url: str,
        api_key: str,
        model_id: str | None,
        model_type: ModelType,
    ) -> APIKeyValidationResponse:
        return await validate_api_key(api_url, api_key, model_id, model_type)

    async def call_transcription_with_fallback(
        self,
        audio_file_path: str,
        language: str = "zh",
        model_id: str | None = None,
    ) -> tuple[str, AIModelConfig | None]:
        models = await self._resolve_candidate_models(
            model_type=ModelType.TRANSCRIPTION,
            model_id=model_id,
        )
        last_error = None
        for model in models:
            try:
                logger.info(
                    "Transcription model attempt model=%s provider=%s priority=%s",
                    model.name,
                    model.provider,
                    model.priority,
                )
                result = await self._call_transcription_model(
                    model,
                    audio_file_path,
                    language,
                )
                await self.repo.increment_usage(model.id, success=True)
                logger.info(
                    "Transcription request succeeded model=%s provider=%s priority=%s",
                    model.name,
                    model.provider,
                    model.priority,
                )
                return result, model
            except (RetryableModelError, ValidationError, OSError, ValueError, RuntimeError) as exc:
                last_error = exc
                await self.repo.increment_usage(model.id, success=False)
                logger.warning(
                    "Transcription model failed model=%s provider=%s priority=%s error_type=%s error=%s",
                    model.name,
                    model.provider,
                    model.priority,
                    type(exc).__name__,
                    exc,
                )

        raise ValidationError(
            f"All transcription models failed. Last error: {last_error!s}",
        )

    async def call_text_generation_with_fallback(
        self,
        messages: list[dict[str, str]],
        max_tokens: int | None = None,
        temperature: float | None = None,
        model_id: str | None = None,
    ) -> tuple[str, AIModelConfig | None]:
        ai_client = AIClientService(
            repo=self.repo,
            security_service=self.security_service,
        )

        # Resolve model_id (accept both int and str forms)
        resolved_model_id: int | None = None
        if isinstance(model_id, int):
            resolved_model_id = model_id
        elif isinstance(model_id, str) and model_id:
            resolved_model_id = (
                int(model_id) if model_id.lstrip("-").isdigit() else None
            )

        return await ai_client.call_with_fallback(
            messages,
            model_type=ModelType.TEXT_GENERATION,
            model_id=resolved_model_id,
            max_tokens=max_tokens,
            temperature=temperature,
            operation_name="Text generation",
        )

    async def _resolve_candidate_models(
        self,
        *,
        model_type: ModelType,
        model_id: str | None,
    ) -> list[AIModelConfig]:
        if model_id:
            model = await self.repo.get_by_id(model_id)
            if not model or not model.is_active:
                raise ValidationError(f"Model {model_id} not found or not active")
            return [model]

        models = await self.repo.get_active_models_by_priority(model_type)
        if not models:
            if model_type == ModelType.TRANSCRIPTION:
                raise ValidationError("No active transcription models available")
            raise ValidationError("No active text generation models available")
        return models

    async def _call_transcription_model(
        self,
        model: AIModelConfig,
        audio_file_path: str,
        language: str = "zh",
    ) -> str:

        import aiohttp

        api_key = await self.security_service.get_decrypted_api_key(model)
        headers = {"Authorization": f"Bearer {api_key}"}
        timeout = aiohttp.ClientTimeout(total=model.timeout_seconds)
        session = await get_shared_http_session()
        data = aiohttp.FormData()
        data.add_field("model", model.model_id)
        data.add_field("language", language)

        api_endpoint = (
            "https://api.openai.com/v1/audio/transcriptions"
            if model.provider == "openai"
            else model.api_url
        )
        max_retries = 3
        base_delay = 1.0
        for attempt in range(max_retries):
            try:
                async with aiofiles.open(audio_file_path, "rb") as f:
                    audio_content = await f.read()
                data.add_field(
                    "file",
                    audio_content,
                    filename=os.path.basename(audio_file_path),
                    content_type="audio/mpeg",
                )
                async with session.post(
                    api_endpoint,
                    headers=headers,
                    data=data,
                    timeout=timeout,
                ) as response:
                    if response.status != 200:
                        error_text = await response.text()
                        message = f"API error: {response.status} - {error_text}"
                        if _is_retryable_http_status(response.status):
                            raise RetryableModelError(message)
                        raise ValidationError(message)

                    result = await response.json()
                    if "text" not in result:
                        raise Exception(
                            "Invalid response format: missing 'text' field",
                        )
                    return result["text"].strip()
            except (aiohttp.ClientError, TimeoutError, RetryableModelError) as exc:
                if attempt >= max_retries - 1:
                    logger.exception(
                        "Transcription transient retries exhausted model=%s provider=%s attempts=%s audio_path=%s error_type=%s",
                        model.name,
                        model.provider,
                        max_retries,
                        audio_file_path,
                        type(exc).__name__,
                    )
                    raise
                await asyncio.sleep(calculate_backoff(attempt, base_delay))
                logger.warning(
                    "Transcription transient error model=%s provider=%s attempt=%s/%s retryable=true error_type=%s error=%s",
                    model.name,
                    model.provider,
                    attempt + 1,
                    max_retries,
                    type(exc).__name__,
                    exc,
                )
            except ValidationError:
                raise
            except (OSError, KeyError, TypeError, AttributeError):
                logger.exception(
                    "Transcription request unexpected failure model=%s provider=%s audio_path=%s",
                    model.name,
                    model.provider,
                    audio_file_path,
                )
                raise


# ---------------------------------------------------------------------------
# TextGenerationService -- application-level text generation orchestration
# ---------------------------------------------------------------------------


class TextGenerationService:
    """Generate AI-backed summaries and text outputs for application workflows."""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.repo = AIModelConfigRepository(db)
        self.security_service = AIModelSecurityService(db)

    async def generate_podcast_summary(
        self,
        episode_title: str,
        content: str,
        content_type: str = "transcript",
        max_tokens: int | None = None,
    ) -> str:

        model_configs = await self.repo.get_active_models_by_priority(
            ModelType.TEXT_GENERATION,
        )
        if not model_configs:
            logger.warning(
                "No active text generation models configured, using rule-based summary",
            )
            return self._rule_based_summary(episode_title, content)

        messages = [
            {"role": "system", "content": self._system_prompt()},
            {
                "role": "user",
                "content": self._user_prompt(
                    episode_title=episode_title,
                    content=content,
                    content_type=content_type,
                ),
            },
        ]

        async def fallback() -> str:
            return self._rule_based_summary(episode_title, content)

        ai_client = AIClientService(
            repo=self.repo,
            security_service=self.security_service,
        )

        result, _model = await ai_client.call_with_fallback(
            messages,
            model_type=ModelType.TEXT_GENERATION,
            max_tokens=max_tokens,
            temperature=0.7,
            operation_name="Podcast summary generation",
            fallback_handler=fallback,
        )
        return result

    def _system_prompt(self) -> str:
        return """
你是一位专业的播客总结专家。你的任务是从播客单集内容中提取最有价值的信息。

请提取以下信息：
1. 主要话题和讨论点
2. 关键见解和结论
3. 可执行的建议
4. 需要进一步研究的领域

输出格式：
## 主要话题
[3-5个要点]

## 关键见解
[深入洞察]

## 行动建议
[具体步骤]

## 扩展思考
[关联问题]
"""

    def _user_prompt(
        self, *, episode_title: str, content: str, content_type: str
    ) -> str:
        return f"""
播客标题: {episode_title}
内容类型: {content_type}
内容: {content[:2000]}

请提供详细总结（150-300字）。
"""

    def _rule_based_summary(self, episode_title: str, content: str) -> str:
        sentences = content.split("。")
        summary_sentences = sentences[:3] if len(sentences) >= 3 else sentences
        summary = "。".join(summary_sentences).strip()

        if not summary:
            summary = f"《{episode_title}》的内容暂无总结。"

        return f"""
## 播客概览
节目名称: {episode_title}

## 内容摘要
{summary}

## 说明
此为系统自动生成的概要，完整总结正在处理中。
"""
