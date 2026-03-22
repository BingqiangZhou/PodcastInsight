"""Runtime validation and invocation for AI model services."""

from __future__ import annotations

import asyncio
import logging
import time
from typing import Any

from app.core.circuit_breaker import CircuitOpenError, get_circuit_breaker
from app.core.exceptions import ValidationError
from app.core.http_client import get_shared_http_session
from app.domains.ai.model_testing import (
    test_text_generation_model,
    test_transcription_model,
    validate_api_key,
)
from app.domains.ai.models import AIModelConfig, ModelType
from app.domains.ai.repositories import AIModelConfigRepository
from app.domains.ai.schemas import APIKeyValidationResponse, ModelTestResponse
from app.shared.retry_utils import calculate_backoff

from .model_security_service import AIModelSecurityService


logger = logging.getLogger(__name__)


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

        # Circuit breakers for external AI API calls
        self._transcription_breaker = get_circuit_breaker(
            "ai_transcription_api",
            failure_threshold=3,
            recovery_timeout=60.0,
        )
        self._text_generation_breaker = get_circuit_breaker(
            "ai_text_generation_api",
            failure_threshold=5,
            recovery_timeout=60.0,
        )

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
        except Exception as exc:
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
                # Use circuit breaker protection for external API calls
                async with self._transcription_breaker:
                    result = await self._call_transcription_model(
                        model, audio_file_path, language
                    )
                await self.repo.increment_usage(model.id, success=True)
                logger.info(
                    "Transcription request succeeded model=%s provider=%s priority=%s",
                    model.name,
                    model.provider,
                    model.priority,
                )
                return result, model
            except CircuitOpenError:
                # Circuit breaker is open - try next model
                logger.warning(
                    "Circuit breaker open for transcription API, skipping model %s",
                    model.name,
                )
                await self.repo.increment_usage(model.id, success=False)
                continue
            except Exception as exc:
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
        models = await self._resolve_candidate_models(
            model_type=ModelType.TEXT_GENERATION,
            model_id=model_id,
        )
        last_error = None
        for model in models:
            try:
                logger.info(
                    "Text generation model attempt model=%s provider=%s priority=%s",
                    model.name,
                    model.provider,
                    model.priority,
                )
                # Use circuit breaker protection for external API calls
                async with self._text_generation_breaker:
                    result = await self._call_text_generation_model(
                        model,
                        messages,
                        max_tokens,
                        temperature,
                    )
                await self.repo.increment_usage(model.id, success=True)
                logger.info(
                    "Text generation request succeeded model=%s provider=%s priority=%s",
                    model.name,
                    model.provider,
                    model.priority,
                )
                return result, model
            except CircuitOpenError:
                # Circuit breaker is open - try next model
                logger.warning(
                    "Circuit breaker open for text generation API, skipping model %s",
                    model.name,
                )
                await self.repo.increment_usage(model.id, success=False)
                continue
            except Exception as exc:
                last_error = exc
                await self.repo.increment_usage(model.id, success=False)
                logger.warning(
                    "Text generation model failed model=%s provider=%s priority=%s error_type=%s error=%s",
                    model.name,
                    model.provider,
                    model.priority,
                    type(exc).__name__,
                    exc,
                )

        raise ValidationError(
            f"All text generation models failed. Last error: {last_error!s}",
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
        import os

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
                with open(audio_file_path, "rb") as audio_file:
                    data.add_field(
                        "file",
                        audio_file,
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
            except Exception:
                logger.exception(
                    "Transcription request unexpected failure model=%s provider=%s audio_path=%s",
                    model.name,
                    model.provider,
                    audio_file_path,
                )
                raise

    async def _call_text_generation_model(
        self,
        model: AIModelConfig,
        messages: list[dict[str, str]],
        max_tokens: int | None = None,
        temperature: float | None = None,
    ) -> str:
        import aiohttp

        from app.core.utils import filter_thinking_content, sanitize_html

        api_key = await self.security_service.get_decrypted_api_key(model)
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }
        data = {
            "model": model.model_id,
            "messages": messages,
            "max_tokens": max_tokens or model.max_tokens or 1000,
            "temperature": temperature or model.get_temperature_float() or 0.7,
        }
        timeout = aiohttp.ClientTimeout(total=model.timeout_seconds)

        session = await get_shared_http_session()
        max_retries = 3
        base_delay = 1.0
        for attempt in range(max_retries):
            try:
                async with session.post(
                    f"{model.api_url}/chat/completions",
                    headers=headers,
                    json=data,
                    timeout=timeout,
                ) as response:
                    if response.status != 200:
                        error_text = await response.text()
                        message = f"API error: {response.status} - {error_text}"
                        if _is_retryable_http_status(response.status):
                            raise RetryableModelError(message)
                        raise ValidationError(message)

                    result = await response.json()
                    if "choices" not in result or not result["choices"]:
                        raise ValidationError("Invalid response from API")

                    raw_content = result["choices"][0]["message"]["content"].strip()
                    cleaned_content = filter_thinking_content(raw_content)
                    safe_content = sanitize_html(cleaned_content)
                    logger.debug(
                        "Filtered and sanitized content: %s -> %s chars",
                        len(raw_content),
                        len(safe_content),
                    )
                    return safe_content
            except (aiohttp.ClientError, TimeoutError, RetryableModelError) as exc:
                if attempt >= max_retries - 1:
                    logger.error(
                        "Text generation transient retries exhausted model=%s provider=%s attempts=%s error_type=%s error=%s",
                        model.name,
                        model.provider,
                        max_retries,
                        type(exc).__name__,
                        exc,
                    )
                    raise
                await asyncio.sleep(calculate_backoff(attempt, base_delay))
                logger.warning(
                    "Text generation transient error model=%s provider=%s attempt=%s/%s retryable=true error_type=%s error=%s",
                    model.name,
                    model.provider,
                    attempt + 1,
                    max_retries,
                    type(exc).__name__,
                    exc,
                )
            except ValidationError:
                raise
