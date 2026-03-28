"""AI模型配置数据访问层"""

from app.domains.ai.repositories.model_config_repository import (
    AIModelConfigRepository as _Repo,
)


# Backward-compatible alias
AIModelConfigRepository = _Repo

__all__ = ["AIModelConfigRepository"]
