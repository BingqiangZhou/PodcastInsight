"""Compatibility facade for AI model configuration workflows."""

from __future__ import annotations

from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.domains.ai.models import AIModelConfig, ModelType
from app.domains.ai.repositories import AIModelConfigRepository
from app.domains.ai.schemas import (
    AIModelConfigCreate,
    AIModelConfigUpdate,
    APIKeyValidationResponse,
    ModelTestResponse,
    ModelUsageStats,
)

from .model_management_service import AIModelManagementService
from .model_runtime_service import AIModelRuntimeService
from .model_security_service import AIModelSecurityService


class AIModelConfigService:
    """Thin orchestration facade preserving the historical public service API."""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.repo = AIModelConfigRepository(db)
        self.security_service = AIModelSecurityService(db)
        self.management_service = AIModelManagementService(
            repo=self.repo,
            security_service=self.security_service,
        )
        self.runtime_service = AIModelRuntimeService(
            repo=self.repo,
            security_service=self.security_service,
        )

    async def create_model(self, model_data: AIModelConfigCreate) -> AIModelConfig:
        return await self.management_service.create_model(model_data)

    async def get_model_by_id(self, model_id: int) -> AIModelConfig | None:
        return await self.management_service.get_model_by_id(model_id)

    async def get_models(
        self,
        model_type: ModelType | None = None,
        is_active: bool | None = None,
        provider: str | None = None,
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[AIModelConfig], int]:
        return await self.management_service.get_models(
            model_type=model_type,
            is_active=is_active,
            provider=provider,
            page=page,
            size=size,
        )

    async def search_models(
        self,
        query: str,
        model_type: ModelType | None = None,
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[AIModelConfig], int]:
        return await self.management_service.search_models(
            query=query,
            model_type=model_type,
            page=page,
            size=size,
        )

    async def update_model(
        self,
        model_id: int,
        model_data: AIModelConfigUpdate,
    ) -> AIModelConfig | None:
        return await self.management_service.update_model(model_id, model_data)

    async def delete_model(self, model_id: int) -> bool:
        return await self.management_service.delete_model(model_id)

    async def set_default_model(
        self,
        model_id: int,
        model_type: ModelType,
    ) -> AIModelConfig | None:
        return await self.management_service.set_default_model(model_id, model_type)

    async def get_default_model(self, model_type: ModelType) -> AIModelConfig | None:
        return await self.management_service.get_default_model(model_type)

    async def get_active_models(
        self,
        model_type: ModelType | None = None,
    ) -> list[AIModelConfig]:
        return await self.management_service.get_active_models(model_type)

    async def test_model(
        self,
        model_id: int,
        test_data: dict[str, Any] | None = None,
    ) -> ModelTestResponse:
        return await self.runtime_service.test_model(model_id, test_data)

    async def get_model_stats(self, model_id: int) -> ModelUsageStats | None:
        return await self.management_service.get_model_stats(model_id)

    async def get_type_stats(
        self,
        model_type: ModelType,
        limit: int = 20,
    ) -> list[ModelUsageStats]:
        return await self.management_service.get_type_stats(model_type, limit)

    async def init_default_models(self) -> list[AIModelConfig]:
        return await self.management_service.init_default_models()

    async def get_decrypted_api_key(self, model: AIModelConfig) -> str:
        return await self.security_service.get_decrypted_api_key(model)

    async def validate_api_key(
        self,
        api_url: str,
        api_key: str,
        model_id: str | None,
        model_type: ModelType,
    ) -> APIKeyValidationResponse:
        return await self.runtime_service.validate_api_key(
            api_url=api_url,
            api_key=api_key,
            model_id=model_id,
            model_type=model_type,
        )

    async def call_transcription_with_fallback(
        self,
        audio_file_path: str,
        language: str = "zh",
        model_id: str | None = None,
    ) -> tuple[str, AIModelConfig | None]:
        return await self.runtime_service.call_transcription_with_fallback(
            audio_file_path=audio_file_path,
            language=language,
            model_id=model_id,
        )

    async def call_text_generation_with_fallback(
        self,
        messages: list[dict[str, str]],
        max_tokens: int | None = None,
        temperature: float | None = None,
        model_id: str | None = None,
    ) -> tuple[str, AIModelConfig | None]:
        return await self.runtime_service.call_text_generation_with_fallback(
            messages=messages,
            max_tokens=max_tokens,
            temperature=temperature,
            model_id=model_id,
        )
