"""
AI模型配置数据模型
存储转录和文本生成模型的配置信息
"""

from datetime import datetime
from enum import StrEnum
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator
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

    id = Column(Integer, primary_key=True, index=True)

    # 基本信息
    name = Column(String(100), nullable=False, index=True, comment="模型名称")
    display_name = Column(String(200), nullable=False, comment="显示名称")
    description = Column(Text, nullable=True, comment="模型描述")
    model_type = Column(String(20), nullable=False, comment="模型类型：transcription/text_generation")

    # API配置
    api_url = Column(String(500), nullable=False, comment="API端点URL")
    api_key = Column(String(1000), nullable=False, comment="API密钥（加密存储）")
    api_key_encrypted = Column(Boolean, default=True, comment="API密钥是否加密")

    # 模型特定配置
    model_id = Column(String(200), nullable=False, comment="模型标识符")
    provider = Column(String(100), nullable=False, default="custom", comment="提供商：openai/siliconflow/custom等")

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
    created_at = Column(DateTime(timezone=True), server_default=func.now(), comment="创建时间")
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), comment="更新时间")
    last_used_at = Column(DateTime(timezone=True), nullable=True, comment="最后使用时间")

    # 索引
    __table_args__ = (
        Index('idx_model_type_active', 'model_type', 'is_active'),
        Index('idx_model_type_default', 'model_type', 'is_default'),
        Index('idx_provider_model', 'provider', 'model_id'),
    )

    def __repr__(self):
        return f"<AIModelConfig(id={self.id}, name={self.name}, type={self.model_type})>"

    def get_cost_per_input_token_float(self) -> float | None:
        """获取输入令牌成本的浮点数"""
        try:
            return float(self.cost_per_input_token) if self.cost_per_input_token else None
        except (ValueError, TypeError):
            return None

    def get_cost_per_output_token_float(self) -> float | None:
        """获取输出令牌成本的浮点数"""
        try:
            return float(self.cost_per_output_token) if self.cost_per_output_token else None
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


# Pydantic模型定义

class AIModelConfigBase(BaseModel):
    """AI模型配置基础模型"""
    name: str = Field(..., min_length=1, max_length=100, description="模型名称")
    display_name: str = Field(..., min_length=1, max_length=200, description="显示名称")
    description: str | None = Field(None, description="模型描述")
    model_type: ModelType = Field(..., description="模型类型")
    api_url: str = Field(..., min_length=1, max_length=500, description="API端点URL")
    api_key: str | None = Field(None, max_length=1000, description="API密钥")
    model_id: str = Field(..., min_length=1, max_length=200, description="模型标识符")
    provider: str = Field(default="custom", max_length=100, description="提供商")
    max_tokens: int | None = Field(None, gt=0, description="最大令牌数")
    temperature: str | None = Field(None, description="温度参数")
    timeout_seconds: int = Field(default=300, gt=0, description="请求超时时间（秒）")
    max_retries: int = Field(default=3, ge=0, description="最大重试次数")
    max_concurrent_requests: int = Field(default=1, gt=0, description="最大并发请求数")
    rate_limit_per_minute: int = Field(default=60, gt=0, description="每分钟请求限制")
    cost_per_input_token: str | None = Field(None, description="每输入令牌成本")
    cost_per_output_token: str | None = Field(None, description="每输出令牌成本")
    extra_config: dict[str, Any] | None = Field(default=dict, description="额外配置参数")
    is_active: bool = Field(default=True, description="是否启用")
    is_default: bool = Field(default=False, description="是否为默认模型")
    priority: int = Field(default=1, ge=1, le=100, description="优先级（数字越小优先级越高）")

    @field_validator('temperature')
    @classmethod
    def validate_temperature(cls, v):
        if v is not None:
            try:
                temp = float(v)
                if not 0 <= temp <= 2:
                    raise ValueError('温度参数必须在0-2之间')
            except ValueError as err:
                raise ValueError('温度参数必须是数字') from err
        return v

    @field_validator('cost_per_input_token', 'cost_per_output_token')
    @classmethod
    def validate_cost(cls, v):
        if v is not None:
            try:
                float(v)
                if float(v) < 0:
                    raise ValueError('成本不能为负数')
            except ValueError as err:
                raise ValueError('成本必须是数字') from err
        return v


class AIModelConfigCreate(AIModelConfigBase):
    """创建AI模型配置"""
    pass


class AIModelConfigUpdate(BaseModel):
    """更新AI模型配置"""
    display_name: str | None = Field(None, min_length=1, max_length=200)
    description: str | None = None
    api_url: str | None = Field(None, min_length=1, max_length=500)
    api_key: str | None = Field(None, max_length=1000)
    model_id: str | None = Field(None, min_length=1, max_length=200)
    max_tokens: int | None = Field(None, gt=0)
    temperature: str | None = None
    timeout_seconds: int | None = Field(None, gt=0)
    max_retries: int | None = Field(None, ge=0)
    max_concurrent_requests: int | None = Field(None, gt=0)
    rate_limit_per_minute: int | None = Field(None, gt=0)
    cost_per_input_token: str | None = None
    cost_per_output_token: str | None = None
    extra_config: dict[str, Any] | None = None
    is_active: bool | None = None
    is_default: bool | None = None
    priority: int | None = Field(None, ge=1, le=100)

    @field_validator('temperature')
    @classmethod
    def validate_temperature(cls, v):
        if v is not None:
            try:
                temp = float(v)
                if not 0 <= temp <= 2:
                    raise ValueError('温度参数必须在0-2之间')
            except ValueError as err:
                raise ValueError('温度参数必须是数字') from err
        return v

    @field_validator('cost_per_input_token', 'cost_per_output_token')
    @classmethod
    def validate_cost(cls, v):
        if v is not None:
            try:
                float(v)
                if float(v) < 0:
                    raise ValueError('成本不能为负数')
            except ValueError as err:
                raise ValueError('成本必须是数字') from err
        return v


class AIModelConfigResponse(AIModelConfigBase):
    """AI模型配置响应模型"""
    id: int
    api_key_encrypted: bool
    usage_count: int
    success_count: int
    error_count: int
    total_tokens_used: int
    success_rate: float = 0.0
    created_at: datetime
    updated_at: datetime
    last_used_at: datetime | None
    is_system: bool
    priority: int

    model_config = ConfigDict(from_attributes=True)

    # 隐藏真实API密钥，返回掩码后的值
    def dict(self, *args, **kwargs):
        data = super().dict(*args, **kwargs)
        if data.get('api_key'):
            data['api_key'] = self.api_key_masked
        return data

    @property
    def api_key_masked(self) -> str:
        """返回掩码后的API密钥"""
        if not self.api_key:
            return ""
        if len(self.api_key) <= 8:
            return "*" * len(self.api_key)
        return self.api_key[:4] + "*" * (len(self.api_key) - 8) + self.api_key[-4:]


class AIModelConfigList(BaseModel):
    """AI模型配置列表响应"""
    models: list[AIModelConfigResponse]
    total: int
    page: int
    size: int
    pages: int


class ModelUsageStats(BaseModel):
    """模型使用统计"""
    model_id: int
    model_name: str
    model_type: str
    usage_count: int
    success_count: int
    error_count: int
    success_rate: float
    total_tokens_used: int
    last_used_at: datetime | None
    total_cost: float | None = None


class ModelTestRequest(BaseModel):
    """模型测试请求"""
    model_id: int
    test_data: dict[str, Any] | None = Field(default=dict, description="测试数据")


class ModelTestResponse(BaseModel):
    """模型测试响应"""
    success: bool
    response_time_ms: float
    result: str | None = None
    error_message: str | None = None
