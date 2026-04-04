"""AI-related FastAPI dependency providers."""

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import get_db_session_dependency


def get_ai_model_config_service(
    db: AsyncSession = Depends(get_db_session_dependency),
):
    """Provide request-scoped AI model config service."""
    from app.domains.ai.services import AIModelConfigService

    return AIModelConfigService(db)


def get_ai_client_service(
    db: AsyncSession = Depends(get_db_session_dependency),
):
    """Provide request-scoped unified AI client service."""
    from app.core.ai_client import AIClientService
    from app.domains.ai.repositories import AIModelConfigRepository
    from app.domains.ai.services.model_security_service import AIModelSecurityService

    return AIClientService(
        repo=AIModelConfigRepository(db),
        security_service=AIModelSecurityService(db),
    )


__all__ = [
    "get_ai_client_service",
    "get_ai_model_config_service",
]
