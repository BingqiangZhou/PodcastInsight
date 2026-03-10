"""Feed parser data schemas.

RSS/Atom feed 解析的数据模型定义。
"""

from datetime import datetime
from enum import StrEnum
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ParseErrorCode(StrEnum):
    """Parse error codes / 解析错误代码"""
    NETWORK_ERROR = "network_error"
    PARSE_ERROR = "parse_error"
    INVALID_FORMAT = "invalid_format"
    ENCODING_ERROR = "encoding_error"
    MISSING_REQUIRED_FIELD = "missing_required_field"


class ParseError(BaseModel):
    """Parse error details / 解析错误详情"""
    code: ParseErrorCode
    message: str
    entry_id: str | None = None
    details: dict[str, Any] | None = None


class FeedInfo(BaseModel):
    """Basic feed information / Feed 基本信息"""
    title: str = ""
    description: str = ""
    link: str = ""
    author: str | None = None
    icon_url: str | None = None
    updated_at: datetime | None = None
    language: str | None = None
    raw_metadata: dict[str, Any] = Field(default_factory=dict)

    @field_validator("title", mode="before")
    @classmethod
    def validate_title(cls, v: Any) -> str:
        """Ensure title is never None / 确保标题不为空"""
        if v is None:
            return ""
        return str(v).strip() if v else ""


class FeedEntry(BaseModel):
    """Single feed entry / 单个 Feed 条目"""
    # Required fields
    id: str
    title: str

    # Content fields
    content: str = ""
    summary: str | None = None

    # Metadata
    author: str | None = None
    link: str | None = None
    image_url: str | None = None
    tags: list[str] = Field(default_factory=list)

    # Dates
    published_at: datetime | None = None
    updated_at: datetime | None = None

    # Raw data for debugging
    raw_metadata: dict[str, Any] = Field(default_factory=dict)

    @field_validator("id", mode="before")
    @classmethod
    def validate_id(cls, v: Any) -> str:
        """Generate fallback ID if missing / 如果缺少 ID 则生成备用 ID"""
        if v:
            return str(v)
        # Fallback to link or generate hash-based ID
        return ""

    @field_validator("title", mode="before")
    @classmethod
    def validate_title(cls, v: Any) -> str:
        """Ensure title has a value / 确保有标题"""
        if v:
            return str(v).strip()
        return "Untitled"

    @field_validator("content", mode="before")
    @classmethod
    def validate_content(cls, v: Any) -> str:
        """Normalize content to string / 将内容规范化为字符串"""
        if isinstance(v, str):
            return v
        if isinstance(v, list) and v:
            # Handle feedparser content list format
            return str(v[0].get("value", "")) if isinstance(v[0], dict) else str(v[0])
        return ""

    @field_validator("tags", mode="before")
    @classmethod
    def validate_tags(cls, v: Any) -> list[str]:
        """Normalize tags to list of strings / 将标签规范化为字符串列表"""
        if isinstance(v, list):
            return [str(tag.term) if hasattr(tag, "term") else str(tag) for tag in v]
        return []

    def get_unique_tags(self) -> set[str]:
        """Get unique tags as set / 获取唯一标签集合"""
        return set(self.tags)


class FeedParseResult(BaseModel):
    """Complete feed parse result / Feed 解析结果"""
    # Feed metadata
    feed_info: FeedInfo
    entries: list[FeedEntry] = Field(default_factory=list)

    # Parse status
    success: bool = True
    errors: list[ParseError] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)

    # Statistics
    total_entries: int = 0
    parsed_entries: int = 0
    skipped_entries: int = 0

    # Raw feedparser result for debugging
    raw_feed: dict[str, Any] | None = None

    def add_error(self, code: ParseErrorCode, message: str, **kwargs) -> None:
        """Add an error / 添加错误"""
        error = ParseError(
            code=code,
            message=message,
            details=kwargs if kwargs else None
        )
        self.errors.append(error)
        if code in (ParseErrorCode.NETWORK_ERROR, ParseErrorCode.PARSE_ERROR):
            self.success = False

    def add_warning(self, message: str) -> None:
        """Add a warning / 添加警告"""
        self.warnings.append(message)

    def has_errors(self) -> bool:
        """Check if result has errors / 检查是否有错误"""
        return len(self.errors) > 0

    def has_warnings(self) -> bool:
        """Check if result has warnings / 检查是否有警告"""
        return len(self.warnings) > 0


class FeedParserConfig(BaseModel):
    """Feed parser configuration / Feed 解析器配置"""
    # Parsing limits
    max_entries: int = 100
    max_content_length: int = 100000  # 100KB max content size

    # Content processing
    strip_html: bool = True
    validate_urls: bool = True

    # Error handling
    strict_mode: bool = False  # If True, fail on any entry error
    log_raw_feed: bool = False  # For debugging

    # HTTP settings
    timeout: float = 30.0
    user_agent: str = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36"

    model_config = ConfigDict(frozen=True)  # Immutable configuration


class FeedParseOptions(BaseModel):
    """Options for a single parse operation / 单次解析选项"""
    max_entries: int | None = None  # Override default max_entries
    fields: list[str] | None = None  # Specific fields to extract (None = all)

    # Content options
    include_raw_metadata: bool = False
    strip_html_content: bool = True
