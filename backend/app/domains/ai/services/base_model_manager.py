"""Base class for AI model managers with common patterns.

This module provides a base class that encapsulates common functionality
for managing AI model configurations, including model resolution,
API key resolution, and fallback logic.
"""

import logging
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ValidationError
from app.domains.ai.models import ModelType
from app.domains.ai.repositories import AIModelConfigRepository
from app.domains.podcast.ai_key_resolver import resolve_api_key_with_fallback


logger = logging.getLogger(__name__)


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
        """Get active model by name or highest priority.

        Args:
            model_name: Optional specific model name to use
            error_message: Custom error message if no model found

        Returns:
            The active AI model configuration

        Raises:
            ValidationError: If model not found or not active
        """
        if model_name:
            model = await self.ai_model_repo.get_by_name(model_name)
            if (
                not model
                or not model.is_active
                or model.model_type != self.model_type
            ):
                raise ValidationError(
                    f"{self.operation_name} model '{model_name}' not found or not active",
                )
            return model

        active_models = await self.ai_model_repo.get_active_models_by_priority(
            self.model_type,
        )
        if not active_models:
            msg = error_message or f"No active {self.operation_name.lower()} model found"
            raise ValidationError(msg)
        return active_models[0]

    async def get_models_to_try(
        self,
        model_name: str | None = None,
        *,
        error_message: str | None = None,
    ) -> list[Any]:
        """Get list of models to try for fallback.

        If a specific model name is provided, returns only that model.
        Otherwise, returns all active models sorted by priority.

        Args:
            model_name: Optional specific model name to use
            error_message: Custom error message if no models available

        Returns:
            List of model configurations to try

        Raises:
            ValidationError: If no models available
        """
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
        """Resolve valid API key for model with fallback.

        Args:
            model_config: Primary model configuration
            invalid_message: Custom error message if no valid key found

        Returns:
            Valid API key string

        Raises:
            ValidationError: If no valid API key found
        """
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
        """List all available models for this manager's model type.

        Returns:
            List of model info dicts
        """
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
