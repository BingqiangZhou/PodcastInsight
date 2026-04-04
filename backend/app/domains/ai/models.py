"""AI模型配置数据模型
存储转录和文本生成模型的配置信息
"""

from enum import StrEnum

from sqlalchemy import JSON, Boolean, Column, DateTime, Index, Integer, String, Text
from sqlalchemy.sql import func

from app.core.database import Base


class ModelType(StrEnum):
    """模型类型枚举"""

    TRANSCRIPTION = "transcription"  # 转录模型
    TEXT_GENERATION = "text_generation"  # 文本生成模型（AI摘要等）


class AIModelConfig(Base):
    """AI模型配置的数据模型"""

    __tablename__ = "ai_model_configs"

    id = Column(Integer, primary_key=True)

    # 基本信息
    name = Column(String(100), nullable=False, index=True, comment="模型名称")
    display_name = Column(String(200), nullable=False, comment="显示名称")
    description = Column(Text, nullable=True, comment="模型描述")
    model_type = Column(
        String(20), nullable=False, comment="模型类型：transcription/text_generation"
    )

    # API配置
    api_url = Column(String(500), nullable=False, comment="API端点URL")
    api_key = Column(String(1000), nullable=False, comment="API密钥（加密存储）")
    api_key_encrypted = Column(Boolean, default=True, comment="API密钥是否加密")

    # 模型特定配置
    model_id = Column(String(200), nullable=False, comment="模型标识符")
    provider = Column(
        String(100),
        nullable=False,
        default="custom",
        comment="提供商：openai/siliconflow/custom等",
    )

    # 性能配置
    max_tokens = Column(Integer, nullable=True, comment="最大令牌数")
    temperature = Column(String(10), nullable=True, comment="温度参数")
    timeout_seconds = Column(Integer, default=300, comment="请求超时时间（秒）")
    max_retries = Column(Integer, default=3, comment="最大重试次数")

    # 并发配置
    max_concurrent_requests = Column(Integer, default=1, comment="最大并发请求数")
    rate_limit_per_minute = Column(Integer, default=60, comment="每分钟请求限制")

    # 成本配置
    cost_per_input_token = Column(String(20), nullable=True, comment="每输入令牌成本")
    cost_per_output_token = Column(String(20), nullable=True, comment="每输出令牌成本")

    # 额外配置（JSON格式）
    extra_config = Column(JSON, default=dict, comment="额外配置参数")

    # 状态管理
    is_active = Column(Boolean, default=True, comment="是否启用")
    is_default = Column(Boolean, default=False, comment="是否为默认模型")
    is_system = Column(Boolean, default=False, comment="是否为系统预设模型")
    priority = Column(Integer, default=1, comment="优先级（数字越小优先级越高）")

    # 使用统计
    usage_count = Column(Integer, default=0, comment="使用次数")
    success_count = Column(Integer, default=0, comment="成功次数")
    error_count = Column(Integer, default=0, comment="错误次数")
    total_tokens_used = Column(Integer, default=0, comment="总令牌使用数")

    # 时间戳
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), comment="创建时间"
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        comment="更新时间",
    )
    last_used_at = Column(
        DateTime(timezone=True), nullable=True, comment="最后使用时间"
    )

    # 索引
    __table_args__ = (
        Index("idx_model_type_active", "model_type", "is_active"),
        Index("idx_model_type_default", "model_type", "is_default"),
        Index("idx_provider_model", "provider", "model_id"),
    )

    def __repr__(self):
        return (
            f"<AIModelConfig(id={self.id}, name={self.name}, type={self.model_type})>"
        )

    def get_cost_per_input_token_float(self) -> float | None:
        """获取输入令牌成本的浮点数"""
        try:
            return (
                float(self.cost_per_input_token) if self.cost_per_input_token else None
            )
        except (ValueError, TypeError):
            return None

    def get_cost_per_output_token_float(self) -> float | None:
        """获取输出令牌成本的浮点数"""
        try:
            return (
                float(self.cost_per_output_token)
                if self.cost_per_output_token
                else None
            )
        except (ValueError, TypeError):
            return None

    def get_temperature_float(self) -> float | None:
        """获取温度参数的浮点数"""
        try:
            return float(self.temperature) if self.temperature else None
        except (ValueError, TypeError):
            return None

    def get_success_rate(self) -> float:
        """获取成功率"""
        if self.usage_count == 0:
            return 0.0
        return (self.success_count / self.usage_count) * 100
