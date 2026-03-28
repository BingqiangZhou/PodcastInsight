"""播客相关的Pydantic schemas - API请求和响应模型"""

from datetime import date, datetime
from typing import Any, Literal

from pydantic import BaseModel, Field, field_validator, model_validator

from app.shared.schemas import BaseSchema, TimestampedSchema


# Backward-compatible aliases
PodcastBaseSchema = BaseSchema
PodcastTimestampedSchema = TimestampedSchema


# === Subscription相关 ===


class PodcastSubscriptionCreate(PodcastBaseSchema):
    """创建播客订阅请求"""

    feed_url: str = Field(
        ...,
        description="RSS feed URL",
        min_length=10,
        max_length=500,
    )

    @field_validator("feed_url")
    @classmethod
    def validate_feed_url(cls, v):
        """验证RSS feed URL格式"""
        if not v.startswith(("http://", "https://")):
            raise ValueError("Feed URL必须以http://或https://开头")
        if "rss" not in v.lower() and "feed" not in v.lower():
            # 不强制要求URL中包含rss或feed，但给出警告
            pass
        return v


class PodcastSubscriptionResponse(PodcastTimestampedSchema):
    """播客订阅响应"""

    id: int
    user_id: int
    title: str
    description: str | None = None
    source_url: str
    status: str
    last_fetched_at: datetime | None = None
    error_message: str | None = None
    fetch_interval: int | None = None
    episode_count: int | None = 0
    unplayed_count: int | None = 0
    latest_episode: dict[str, Any] | None = None
    categories: list[dict[str, Any]] | None = []
    image_url: str | None = None
    author: str | None = None

    @field_validator("categories", mode="before")
    @classmethod
    def validate_categories(cls, v):
        """处理categories字段，支持字符串列表和字典列表"""
        if not v:
            return []

        # 确保v是列表
        if isinstance(v, str):
            # 如果是单个字符串，转换为列表
            v = [v]
        elif not isinstance(v, list):
            # 如果不是列表，尝试转换
            v = [str(v)]

        result = []
        for item in v:
            if isinstance(item, str):
                result.append({"name": item})
            elif isinstance(item, dict):
                result.append(item)
            else:
                result.append({"name": str(item)})
        return result

    @model_validator(mode="before")
    @classmethod
    def validate_all_fields(cls, data):
        """对所有字段进行预验证"""
        if isinstance(data, dict):
            # 特别处理categories字段
            categories = data.get("categories")
            if categories:
                # 确保categories是字典列表格式
                processed_categories = []
                if isinstance(categories, list):
                    for cat in categories:
                        if isinstance(cat, str):
                            processed_categories.append({"name": cat})
                        elif isinstance(cat, dict):
                            processed_categories.append(cat)
                        else:
                            processed_categories.append({"name": str(cat)})
                    data["categories"] = processed_categories
                elif isinstance(categories, str):
                    data["categories"] = [{"name": categories}]
                else:
                    data["categories"] = [{"name": str(categories)}]
        return data


class PodcastSubscriptionListResponse(PodcastBaseSchema):
    """播客订阅列表响应"""

    subscriptions: list[PodcastSubscriptionResponse]
    total: int
    page: int
    size: int
    pages: int


# === Episode相关 ===


class PodcastEpisodeResponse(PodcastTimestampedSchema):
    """播客单集响应"""

    id: int
    subscription_id: int
    title: str
    description: str | None = None
    audio_url: str
    audio_duration: int | None = None
    audio_file_size: int | None = None
    published_at: datetime
    image_url: str | None = None
    item_link: str | None = None  # 分集详情页链接
    subscription_image_url: str | None = None
    transcript_url: str | None = None
    transcript_content: str | None = None
    ai_summary: str | None = None
    summary_version: str | None = None
    ai_confidence_score: float | None = None
    play_count: int = 0
    last_played_at: datetime | None = None
    season: int | None = None
    episode_number: int | None = None
    explicit: bool = False
    status: str
    metadata: dict[str, Any] | None = {}

    # 播放状态（如果用户有收听记录）
    subscription_title: str | None = None
    playback_position: int | None = None
    is_playing: bool = False
    playback_rate: float = 1.0
    is_played: bool | None = None


class PodcastEpisodeListResponse(PodcastBaseSchema):
    """播客单集列表响应"""

    episodes: list[PodcastEpisodeResponse]
    total: int
    page: int
    size: int
    pages: int
    subscription_id: int
    next_cursor: str | None = None


class PodcastPlaybackHistoryItemResponse(PodcastBaseSchema):
    """Lightweight playback history item for profile history page."""

    id: int
    subscription_id: int
    subscription_title: str | None = None
    subscription_image_url: str | None = None
    title: str
    image_url: str | None = None
    audio_duration: int | None = None
    playback_position: int | None = None
    last_played_at: datetime | None = None
    published_at: datetime


class PodcastPlaybackHistoryListResponse(PodcastBaseSchema):
    """Lightweight playback history list response."""

    episodes: list[PodcastPlaybackHistoryItemResponse]
    total: int
    page: int
    size: int
    pages: int
    next_cursor: str | None = None


class PodcastEpisodeDetailResponse(PodcastEpisodeResponse):
    """播客单集详情响应（包含更多信息）"""

    summary_status: str | None = None
    summary_error_message: str | None = None
    summary_model_used: str | None = None
    summary_processing_time: float | None = None
    subscription: dict[str, Any] | None = None
    related_episodes: list[dict[str, Any]] | None = []


class PodcastFeedResponse(PodcastBaseSchema):
    """播客信息流响应"""

    items: list[PodcastEpisodeResponse]
    has_more: bool
    next_page: int | None = None
    next_cursor: str | None = None
    total: int


# === Daily Report相关 ===


class DailyReportItem(PodcastBaseSchema):
    """Daily report item snapshot."""

    episode_id: int
    subscription_id: int
    episode_title: str
    subscription_title: str | None = None
    one_line_summary: str
    is_carryover: bool = False
    episode_created_at: datetime
    episode_published_at: datetime | None = None


class PodcastDailyReportResponse(PodcastBaseSchema):
    """Daily report response."""

    available: bool
    report_date: date | None = None
    timezone: str
    schedule_time_local: str
    generated_at: datetime | None = None
    total_items: int = 0
    items: list[DailyReportItem] = Field(default_factory=list)


class DailyReportDateItem(PodcastBaseSchema):
    """Available report date item."""

    report_date: date
    total_items: int = 0
    generated_at: datetime | None = None


class PodcastDailyReportDatesResponse(PodcastBaseSchema):
    """Paginated report date list response."""

    dates: list[DailyReportDateItem] = Field(default_factory=list)
    total: int
    page: int
    size: int
    pages: int


# === Playback相关 ===


class PodcastPlaybackUpdate(PodcastBaseSchema):
    """播放进度更新请求"""

    position: int = Field(..., ge=0, description="当前播放位置(秒)")
    is_playing: bool = Field(default=False, description="是否正在播放")
    playback_rate: float = Field(default=1.0, ge=0.5, le=3.0, description="播放倍速")


class PodcastPlaybackStateResponse(PodcastBaseSchema):
    """播放状态响应"""

    episode_id: int
    current_position: int
    is_playing: bool
    playback_rate: float
    play_count: int
    last_updated_at: datetime

    # 计算字段
    progress_percentage: float = Field(description="播放进度百分比")
    remaining_time: int = Field(description="剩余时间(秒)")


# === Category相关 ===


class PlaybackRateApplyRequest(PodcastBaseSchema):
    """Apply global/subscription playback rate preference."""

    playback_rate: float = Field(..., ge=0.5, le=3.0, description="播放倍速")
    subscription_id: int | None = Field(
        default=None,
        ge=1,
        description="订阅ID，仅按订阅设置时使用",
    )
    apply_to_subscription: bool = Field(
        default=False,
        description="是否仅应用到当前订阅",
    )


class PlaybackRateEffectiveResponse(PodcastBaseSchema):
    """Effective playback-rate response."""

    global_playback_rate: float
    subscription_playback_rate: float | None = None
    effective_playback_rate: float
    source: Literal["subscription", "global", "default"]


class PodcastQueueItemAddRequest(PodcastBaseSchema):
    """Add one episode to queue."""

    episode_id: int = Field(..., ge=1)


class PodcastQueueReorderRequest(PodcastBaseSchema):
    """Reorder queue by full episode id list."""

    episode_ids: list[int] = Field(..., min_length=0, max_length=500)


class PodcastQueueSetCurrentRequest(PodcastBaseSchema):
    """Set current queue episode."""

    episode_id: int = Field(..., ge=1)


class PodcastQueueActivateRequest(PodcastBaseSchema):
    """Ensure episode exists in queue, move to head, and set as current."""

    episode_id: int = Field(..., ge=1)


class PodcastQueueCurrentCompleteRequest(PodcastBaseSchema):
    """Complete current queue episode."""


class PodcastQueueItemResponse(PodcastBaseSchema):
    """Queue item response."""

    episode_id: int
    position: int
    playback_position: int | None = None
    title: str
    podcast_id: int
    audio_url: str
    duration: int | None = None
    published_at: datetime | None = None
    image_url: str | None = None
    subscription_title: str | None = None
    subscription_image_url: str | None = None


class PodcastQueueResponse(PodcastBaseSchema):
    """Queue snapshot response."""

    current_episode_id: int | None = None
    revision: int
    updated_at: datetime | None = None
    items: list[PodcastQueueItemResponse] = Field(default_factory=list)


# === Summary相关 ===


class PodcastSummaryRequest(PodcastBaseSchema):
    """生成AI总结请求"""

    force_regenerate: bool = Field(default=False, description="是否强制重新生成")
    use_transcript: bool | None = Field(None, description="是否使用转录文本（如果有）")
    summary_model: str | None = Field(None, description="AI总结模型名称")
    custom_prompt: str | None = Field(None, description="自定义提示词")


class PodcastSummaryStartResponse(PodcastBaseSchema):
    """AI鎬荤粨浠诲姟鍙楃悊鍝嶅簲"""

    episode_id: int
    summary_status: str
    accepted_at: datetime
    message_en: str
    message_zh: str


class PodcastSummaryResponse(PodcastBaseSchema):
    """AI总结响应"""

    episode_id: int
    summary: str
    version: str
    confidence_score: float | None = None
    transcript_used: bool
    generated_at: datetime
    word_count: int
    model_used: str | None = None  # 使用的模型名称
    processing_time: float | None = None  # 处理时间（秒）


class SummaryModelInfo(PodcastBaseSchema):
    """AI总结模型信息"""

    id: int
    name: str
    display_name: str
    provider: str
    model_id: str
    is_default: bool


class SummaryModelsResponse(PodcastBaseSchema):
    """可用总结模型列表响应"""

    models: list[SummaryModelInfo]
    total: int


class PodcastSummaryPendingResponse(PodcastBaseSchema):
    """待总结列表响应"""

    count: int
    episodes: list[dict[str, Any]]


# === Search/Filter相关 ===


class PodcastSearchFilter(PodcastBaseSchema):
    """播客搜索过滤器"""

    query: str | None = Field(None, description="搜索关键词")
    category_id: int | None = Field(None, description="分类ID")
    status: str | None = Field(None, description="状态筛选")
    has_summary: bool | None = Field(None, description="是否有AI总结")
    date_from: datetime | None = Field(None, description="开始日期")
    date_to: datetime | None = Field(None, description="结束日期")


class PodcastEpisodeFilter(PodcastSearchFilter):
    """播客单集过滤器"""

    subscription_id: int | None = Field(None, description="订阅ID")
    is_played: bool | None = Field(None, description="是否已播放")
    duration_min: int | None = Field(None, ge=0, description="最小时长(秒)")
    duration_max: int | None = Field(None, ge=0, description="最大时长(秒)")


# === Statistics相关 ===


class PodcastStatsResponse(PodcastBaseSchema):
    """播客统计响应"""

    total_subscriptions: int
    total_episodes: int
    total_playtime: int  # 总播放时间(秒)
    summaries_generated: int
    pending_summaries: int
    recently_played: list[dict[str, Any]]
    top_categories: list[dict[str, Any]]
    listening_streak: int  # 连续收听天数


# === Import/Export相关 ===


class PodcastProfileStatsResponse(PodcastBaseSchema):
    """Lightweight profile stats response."""

    total_subscriptions: int
    total_episodes: int
    summaries_generated: int
    pending_summaries: int
    played_episodes: int
    latest_daily_report_date: str | None = None
    total_highlights: int = 0


# === Transcription相关 ===


class PodcastTranscriptionRequest(PodcastBaseSchema):
    """启动转录请求"""

    force_regenerate: bool = Field(default=False, description="是否强制重新转录")
    chunk_size_mb: int | None = Field(None, ge=1, le=100, description="分片大小（MB）")
    transcription_model: str | None = Field(None, description="转录模型名称")


class PodcastTranscriptionResponse(PodcastBaseSchema):
    """转录任务响应"""

    id: int
    episode_id: int
    status: str
    progress_percentage: float = 0.0
    original_audio_url: str
    original_file_size: int | None = None
    transcript_word_count: int | None = None
    transcript_duration: int | None = None
    transcript_content: str | None = None  # ← 添加缺失的字段
    error_message: str | None = None
    error_code: str | None = None
    download_time: float | None = None
    conversion_time: float | None = None
    transcription_time: float | None = None
    chunk_size_mb: int = 10
    model_used: str | None = None
    created_at: datetime
    started_at: datetime | None = None
    completed_at: datetime | None = None
    updated_at: datetime | None = None

    # AI总结信息
    summary_content: str | None = None
    summary_model_used: str | None = None
    summary_word_count: int | None = None
    summary_processing_time: float | None = None
    summary_error_message: str | None = None

    # Debug info
    debug_message: str | None = None

    # 计算字段
    duration_seconds: int | None = None
    total_processing_time: float | None = None

    # 关联信息
    episode: dict[str, Any] | None = None

    @field_validator("status", mode="before")
    @classmethod
    def validate_status(cls, v):
        """确保状态是字符串"""
        if hasattr(v, "value"):  # 处理枚举值
            return v.value
        return str(v) if v else None


class PodcastTranscriptionDetailResponse(PodcastTranscriptionResponse):
    """转录任务详情响应"""

    chunk_info: dict[str, Any] | None = None
    transcript_content: str | None = None
    original_file_path: str | None = None

    # 格式化后的时间信息
    formatted_duration: str | None = None
    formatted_processing_time: str | None = None
    formatted_created_at: str | None = None
    formatted_started_at: str | None = None
    formatted_completed_at: str | None = None


class PodcastTranscriptionStatusResponse(PodcastBaseSchema):
    """转录状态响应"""

    task_id: int
    episode_id: int
    status: str
    progress: float = 0.0
    message: str = ""
    current_chunk: int = 0
    total_chunks: int = 0
    eta_seconds: int | None = None  # 预计剩余时间（秒）

    @field_validator("status", mode="before")
    @classmethod
    def validate_status(cls, v):
        if hasattr(v, "value"):
            return v.value
        return str(v) if v else None


class PodcastTranscriptionScheduleResponse(PodcastBaseSchema):
    """单集转录调度响应"""

    status: str
    message: str
    task_id: int | None = None
    transcript_content: str | None = None
    reason: str | None = None
    action: str | None = None
    progress: float | None = None
    current_status: str | None = None
    episode_id: int | None = None
    scheduled_at: datetime | None = None


class PodcastEpisodeTranscriptResponse(PodcastBaseSchema):
    """已存在转录文本响应"""

    episode_id: int
    episode_title: str
    transcript_length: int
    transcript: str
    status: str


class PodcastBatchTranscriptionDetailResponse(PodcastBaseSchema):
    """批量转录明细响应"""

    episode_id: int
    episode_title: str | None = None
    status: str
    message: str | None = None
    task_id: int | None = None
    transcript_content: str | None = None
    reason: str | None = None
    action: str | None = None
    progress: float | None = None
    current_status: str | None = None
    error: str | None = None
    scheduled_at: datetime | None = None


class PodcastBatchTranscriptionResponse(PodcastBaseSchema):
    """批量转录响应"""

    subscription_id: int
    total: int
    scheduled: int
    skipped: int
    errors: int
    details: list[PodcastBatchTranscriptionDetailResponse] = Field(default_factory=list)


class PodcastTranscriptionScheduleStatusResponse(PodcastBaseSchema):
    """转录调度状态响应"""

    episode_id: int
    episode_title: str
    status: str
    has_transcript: bool
    transcript_preview: str | None = None
    task_id: int | None = None
    progress: float | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None
    completed_at: datetime | None = None
    transcript_word_count: int | None = None
    has_summary: bool | None = None
    summary_word_count: int | None = None
    error_message: str | None = None


class PodcastTranscriptionCancelResponse(PodcastBaseSchema):
    """取消转录响应"""

    success: bool
    message: str


class PodcastCheckNewEpisodesDetailResponse(PodcastBaseSchema):
    """检查新节目明细响应"""

    episode_id: int
    status: str
    task_id: int | None = None
    error: str | None = None


class PodcastCheckNewEpisodesResponse(PodcastBaseSchema):
    """检查新节目并调度转录响应"""

    status: str
    message: str
    processed: int
    skipped: int | None = None
    scheduled: int | None = None
    errors: int | None = None
    details: list[PodcastCheckNewEpisodesDetailResponse] = Field(default_factory=list)


class PodcastPendingTranscriptionTaskResponse(PodcastBaseSchema):
    """待处理转录任务响应"""

    task_id: int
    episode_id: int
    status: str
    progress: float
    created_at: datetime
    updated_at: datetime | None = None


class PodcastPendingTranscriptionsResponse(PodcastBaseSchema):
    """待处理转录任务列表响应"""

    total: int
    tasks: list[PodcastPendingTranscriptionTaskResponse] = Field(default_factory=list)


# === Conversation相关 ===


class PodcastConversationMessage(PodcastBaseSchema):
    """对话消息"""

    id: int
    role: str  # 'user' or 'assistant'
    content: str
    conversation_turn: int
    created_at: str
    parent_message_id: int | None = None


class PodcastConversationSendRequest(PodcastBaseSchema):
    """发送对话消息请求"""

    message: str = Field(..., min_length=1, max_length=5000, description="用户消息内容")
    model_name: str | None = Field(None, description="使用的AI模型名称")
    session_id: int | None = Field(
        None,
        description="会话ID，不提供则使用或创建默认会话",
    )


class PodcastConversationSendResponse(PodcastBaseSchema):
    """发送对话消息响应"""

    id: int
    role: str
    content: str
    conversation_turn: int
    processing_time: float | None = None
    created_at: str


class PodcastConversationHistoryResponse(PodcastBaseSchema):
    """对话历史响应"""

    episode_id: int
    session_id: int | None = None
    messages: list[PodcastConversationMessage]
    total: int


class PodcastConversationClearResponse(PodcastBaseSchema):
    """清除对话历史响应"""

    episode_id: int
    session_id: int | None = None
    deleted_count: int


# === Conversation Session Schemas ===


class ConversationSessionResponse(PodcastBaseSchema):
    """对话会话响应"""

    id: int
    episode_id: int
    title: str
    message_count: int = 0
    created_at: datetime
    updated_at: datetime | None = None


class ConversationSessionListResponse(PodcastBaseSchema):
    """对话会话列表响应"""

    sessions: list[ConversationSessionResponse]
    total: int


class ConversationSessionCreateRequest(PodcastBaseSchema):
    """创建对话会话请求"""

    title: str | None = Field(None, max_length=255, description="会话标题")


# === Schedule Configuration Schemas ===


class ScheduleConfigUpdate(BaseModel):
    """Update subscription schedule configuration"""

    update_frequency: str = Field(
        ...,
        description="Update frequency: HOURLY, DAILY, WEEKLY",
    )
    update_time: str | None = Field(
        None,
        description="Update time in HH:MM format (24-hour)",
    )
    update_day_of_week: int | None = Field(
        None,
        ge=1,
        le=7,
        description="Day of week (1=Monday, 7=Sunday)",
    )
    fetch_interval: int | None = Field(
        None,
        ge=300,
        le=86400,
        description="Fetch interval in seconds (for HOURLY frequency)",
    )

    @field_validator("update_frequency")
    @classmethod
    def validate_frequency(cls, v):
        valid_values = ["HOURLY", "DAILY", "WEEKLY"]
        if v not in valid_values:
            raise ValueError(f"update_frequency must be one of {valid_values}")
        return v

    @field_validator("update_time")
    @classmethod
    def validate_time_format(cls, v):
        if v is not None:
            try:
                hour, minute = map(int, v.split(":"))
                if not (0 <= hour <= 23 and 0 <= minute <= 59):
                    raise ValueError("Invalid time")
            except (ValueError, AttributeError) as err:
                raise ValueError(
                    "update_time must be in HH:MM format (24-hour)",
                ) from err
        return v

    @model_validator(mode="after")
    def validate_schedule_config(self):
        """Validate that required fields are present for each frequency type"""
        if self.update_frequency == "DAILY" and not self.update_time:
            raise ValueError("update_time is required for DAILY frequency")
        if self.update_frequency == "WEEKLY" and (
            not self.update_time or not self.update_day_of_week
        ):
            raise ValueError(
                "update_time and update_day_of_week are required for WEEKLY frequency",
            )
        if self.update_frequency == "HOURLY" and not self.fetch_interval:
            # Set default fetch_interval if not provided
            self.fetch_interval = 3600
        return self


class ScheduleConfigResponse(PodcastBaseSchema):
    """Schedule configuration response"""

    id: int
    title: str
    update_frequency: str
    update_time: str | None = None
    update_day_of_week: int | None = None
    fetch_interval: int | None = None
    next_update_at: datetime | None = None
    last_updated_at: datetime | None = None


# === Bulk Delete Schemas ===


class PodcastSubscriptionBulkDelete(PodcastBaseSchema):
    """批量删除播客订阅请求"""

    subscription_ids: list[int] = Field(
        ...,
        description="订阅ID列表",
        min_length=1,
        max_length=100,
    )

    @field_validator("subscription_ids")
    @classmethod
    def validate_subscription_ids(cls, v):
        """验证订阅ID列表"""
        if not v:
            raise ValueError("订阅ID列表不能为空")
        if len(v) > 100:
            raise ValueError("一次最多删除100个订阅")
        # 去重
        unique_ids = list(set(v))
        if len(unique_ids) != len(v):
            # 只警告，不抛出错误
            pass
        return unique_ids


class PodcastSubscriptionBulkDeleteResponse(PodcastBaseSchema):
    """批量删除播客订阅响应"""

    success_count: int = Field(..., description="成功删除的订阅数量")
    failed_count: int = Field(..., description="删除失败的订阅数量")
    errors: list[dict[str, Any]] = Field(
        default_factory=list,
        description="删除失败的错误信息列表",
    )
    deleted_subscription_ids: list[int] = Field(
        default_factory=list,
        description="成功删除的订阅ID列表",
    )


# === Highlight相关 ===


class HighlightResponse(PodcastBaseSchema):
    """高光观点响应"""

    id: int
    episode_id: int
    episode_title: str
    subscription_title: str | None = None
    original_text: str
    context_before: str | None = None
    context_after: str | None = None
    insight_score: float
    novelty_score: float
    actionability_score: float
    overall_score: float
    speaker_hint: str | None = None
    timestamp_hint: str | None = None
    topic_tags: list[str] = Field(default_factory=list)
    is_user_favorited: bool = False
    created_at: datetime


class HighlightListResponse(PodcastBaseSchema):
    """高光列表响应"""

    items: list[HighlightResponse] = Field(default_factory=list)
    total: int
    page: int
    per_page: int
    has_more: bool


class HighlightDatesResponse(PodcastBaseSchema):
    """高光日期列表响应"""

    dates: list[date] = Field(default_factory=list)


class HighlightStatsResponse(PodcastBaseSchema):
    """高光统计数据响应"""

    total_highlights: int
    avg_score: float
    latest_extraction_date: date | None = None


class HighlightFavoriteRequest(PodcastBaseSchema):
    """收藏高光请求"""

    favorited: bool = Field(..., description="是否收藏")
