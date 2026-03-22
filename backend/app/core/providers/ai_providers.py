"""AI-related dependency providers."""

from sqlalchemy.ext.asyncio import AsyncSession

from .base_providers import get_db_session_dependency


def get_ai_model_config_service(
    db: AsyncSession = Depends(get_db_session_dependency),
):
    """Provide request-scoped AI model config service."""
    from app.domains.ai.services import AIModelConfigService

    return AIModelConfigService(db)


__all__ = [
    "get_ai_model_config_service",
]
