"""播客数据模型 - 扩展订阅域

基于现有subscription实体进行扩展，新增播客特定字段
"""

from datetime import UTC, datetime
from enum import StrEnum

from sqlalchemy import (
    JSON,
    Boolean,
    CheckConstraint,
    Column,
    Date,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from app.core.database import Base
from app.domains.subscription.models import Subscription


class PodcastEpisode(Base):
    """播客单集数据模型

    设计说明:
    - 不直接使用继承，而是通过外键关联到Subscription
    - 复用部分SubscriptionItem字段但独立管理播客特有的音频/总结字段
    - 保持与现有schema兼容，同时避免复杂的SQLAlchemy继承配置
    """

    __tablename__ = "podcast_episodes"

    id = Column(Integer, primary_key=True, index=True)
    subscription_id = Column(Integer, ForeignKey("subscriptions.id"), nullable=False)

    # 播客基本信息
    title = Column(String(500), nullable=False)
    description = Column(Text, nullable=True)
    published_at = Column(DateTime(timezone=True), nullable=False)

    # 音频信息
    audio_url = Column(String(500), nullable=False)
    audio_duration = Column(Integer)  # 秒
    audio_file_size = Column(Integer)  # 字节

    # 转录文本
    transcript_url = Column(String(500))
    transcript_content = Column(Text)

    # AI总结
    ai_summary = Column(Text)
    summary_version = Column(String(50))  # 用于跟踪总结版本
    ai_confidence_score = Column(Float)  # AI总结质量评分

    # 分集图像
    image_url = Column(String(500))  # 分集封面图URL

    # 分集详情页链接
    item_link = Column(
        String(500),
        unique=True,
        nullable=False,
    )  # <item><link> 标签内容，指向分集详情页

    # 播放统计（全局）
    play_count = Column(Integer, default=0)
    last_played_at = Column(DateTime(timezone=True))

    # 节目信息
    season = Column(Integer)  # 季节
    episode_number = Column(Integer)  # 集数序号
    explicit = Column(Boolean, default=False)

    # 状态和元数据
    status = Column(
        String(50),
        default="pending_summary",
    )  # pending, summarized, failed
    metadata_json = Column(
        "metadata",
        JSON,
        nullable=True,
        default={},
    )  # Renamed to avoid SQLAlchemy reserved attribute
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    # Relationships
    subscription = relationship("Subscription", back_populates="podcast_episodes")
    playback_states = relationship(
        "PodcastPlaybackState",
        back_populates="episode",
        cascade="all, delete",
    )
    queue_items = relationship(
        "PodcastQueueItem",
        back_populates="episode",
        cascade="all, delete",
    )
    daily_report_items = relationship(
        "PodcastDailyReportItem",
        back_populates="episode",
        cascade="all, delete",
    )
    transcript = relationship(
        "PodcastEpisodeTranscript",
        back_populates="episode",
        uselist=False,
        cascade="all, delete",
    )

    # Indexes
    __table_args__ = (
        Index("idx_podcast_subscription", "subscription_id"),
        Index("idx_podcast_status", "status"),
        Index("idx_podcast_published", "published_at"),
        Index(
            "idx_podcast_episodes_status_published_id", "status", "published_at", "id"
        ),
        Index("idx_podcast_episode_image", "image_url"),
        Index("idx_podcast_episodes_item_link", "item_link", unique=True),
    )

    def __repr__(self):
        return f"<PodcastEpisode(id={self.id}, title='{self.title[:30]}...', status='{self.status}')>"


class PodcastEpisodeTranscript(Base):
    """Dedicated storage for episode transcript content.

    Separated from podcast_episodes to improve query performance
    on the main table by avoiding large TEXT column scans.
    """

    __tablename__ = "podcast_episode_transcripts"

    episode_id = Column(Integer, ForeignKey("podcast_episodes.id"), primary_key=True)
    transcript_content = Column(Text, nullable=True)
    transcript_word_count = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    # Relationship
    episode = relationship("PodcastEpisode", back_populates="transcript")

    def __repr__(self):
        return f"<PodcastEpisodeTranscript(episode_id={self.episode_id}, word_count={self.transcript_word_count})>"


Subscription.podcast_episodes = relationship(
    "PodcastEpisode",
    back_populates="subscription",
    cascade="all, delete-orphan",
)


class PodcastDailyReport(Base):
    """Per-user daily report snapshot."""

    __tablename__ = "podcast_daily_reports"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    report_date = Column(Date, nullable=False)
    timezone = Column(String(64), nullable=False, default="Asia/Shanghai")
    schedule_time_local = Column(String(5), nullable=False, default="03:30")
    generated_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
    )
    total_items = Column(Integer, nullable=False, default=0)
    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
    )
    updated_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    items = relationship(
        "PodcastDailyReportItem",
        back_populates="report",
        cascade="all, delete-orphan",
        order_by="PodcastDailyReportItem.id",
    )

    __table_args__ = (
        UniqueConstraint(
            "user_id", "report_date", name="uq_podcast_daily_reports_user_date"
        ),
        Index("idx_podcast_daily_reports_user_date", "user_id", "report_date"),
        Index("idx_podcast_daily_reports_generated_at", "generated_at"),
    )


class PodcastDailyReportItem(Base):
    """Snapshot item for one episode inside a daily report."""

    __tablename__ = "podcast_daily_report_items"

    id = Column(Integer, primary_key=True, index=True)
    report_id = Column(
        Integer,
        ForeignKey("podcast_daily_reports.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    episode_id = Column(
        Integer,
        ForeignKey("podcast_episodes.id", ondelete="CASCADE"),
        nullable=False,
    )
    subscription_id = Column(Integer, nullable=False)
    episode_title_snapshot = Column(String(500), nullable=False)
    subscription_title_snapshot = Column(String(255), nullable=True)
    one_line_summary = Column(Text, nullable=False)
    is_carryover = Column(Boolean, nullable=False, default=False)
    episode_created_at = Column(DateTime(timezone=True), nullable=False)
    episode_published_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
    )

    report = relationship("PodcastDailyReport", back_populates="items")
    episode = relationship("PodcastEpisode", back_populates="daily_report_items")

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "episode_id",
            name="uq_podcast_daily_report_items_user_episode",
        ),
        Index("idx_podcast_daily_report_items_report_id", "report_id"),
        Index("idx_podcast_daily_report_items_user_id", "user_id"),
        Index("idx_podcast_daily_report_items_episode_id", "episode_id"),
    )


class PodcastPlaybackState(Base):
    """用户播放状态 - 跟踪每个用户的播客播放进度"""

    __tablename__ = "podcast_playback_states"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    episode_id = Column(
        Integer,
        ForeignKey("podcast_episodes.id", ondelete="CASCADE"),
        nullable=False,
    )

    # 播放状态
    current_position = Column(Integer, default=0)  # 当前播放位置(秒)
    is_playing = Column(Boolean, default=False)
    playback_rate = Column(Float, default=1.0, nullable=False)  # 播放速度
    last_updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    # 统计
    play_count = Column(Integer, default=0)

    # 关系
    episode = relationship("PodcastEpisode", back_populates="playback_states")
    # 注意：由于User模型未导入，仅通过repositories访问

    __table_args__ = (
        CheckConstraint(
            "playback_rate >= 0.5 AND playback_rate <= 3.0",
            name="ck_podcast_playback_states_playback_rate_range",
        ),
        # 确保每个用户-episode组合唯一
        Index("idx_user_episode_unique", "user_id", "episode_id", unique=True),
    )

    def __repr__(self):
        return f"<PlaybackState(user={self.user_id}, ep={self.episode_id}, pos={self.current_position}s)>"


class PodcastQueue(Base):
    """Per-user persistent podcast playback queue."""

    __tablename__ = "podcast_queues"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
    )
    current_episode_id = Column(
        Integer,
        ForeignKey("podcast_episodes.id", ondelete="SET NULL"),
        nullable=True,
    )
    revision = Column(Integer, default=0, nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    items = relationship(
        "PodcastQueueItem",
        back_populates="queue",
        cascade="all, delete-orphan",
        order_by="PodcastQueueItem.position",
    )
    current_episode = relationship(
        "PodcastEpisode",
        foreign_keys=[current_episode_id],
        lazy="joined",
    )

    __table_args__ = (Index("idx_podcast_queue_user", "user_id"),)

    def __repr__(self):
        return f"<PodcastQueue(user={self.user_id}, current={self.current_episode_id}, revision={self.revision})>"


class PodcastQueueItem(Base):
    """Item in a user's podcast queue."""

    __tablename__ = "podcast_queue_items"

    id = Column(Integer, primary_key=True, index=True)
    queue_id = Column(
        Integer,
        ForeignKey("podcast_queues.id", ondelete="CASCADE"),
        nullable=False,
    )
    episode_id = Column(
        Integer,
        ForeignKey("podcast_episodes.id", ondelete="CASCADE"),
        nullable=False,
    )
    position = Column(Integer, nullable=False)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    queue = relationship("PodcastQueue", back_populates="items")
    episode = relationship("PodcastEpisode", back_populates="queue_items")

    __table_args__ = (
        UniqueConstraint(
            "queue_id",
            "episode_id",
            name="uq_podcast_queue_item_episode",
        ),
        UniqueConstraint("queue_id", "position", name="uq_podcast_queue_item_position"),
        Index("idx_podcast_queue_items_queue_position", "queue_id", "position"),
    )

    def __repr__(self):
        return f"<PodcastQueueItem(queue={self.queue_id}, episode={self.episode_id}, position={self.position})>"


# 转录任务状态枚举（简化版）
class TranscriptionStatus(StrEnum):
    """转录任务状态枚举（简化版）"""

    PENDING = "pending"  # 等待开始
    IN_PROGRESS = "in_progress"  # 处理中
    COMPLETED = "completed"  # 已完成
    FAILED = "failed"  # 失败
    CANCELLED = "cancelled"  # 已取消


# 转录任务步骤枚举
class TranscriptionStep(StrEnum):
    """转录任务执行步骤枚举"""

    NOT_STARTED = "not_started"  # 未开始
    DOWNLOADING = "downloading"  # 下载音频文件
    CONVERTING = "converting"  # 格式转换为MP3
    SPLITTING = "splitting"  # 切割音频文件
    TRANSCRIBING = "transcribing"  # 语音识别转录
    MERGING = "merging"  # 合并转录结果


class TranscriptionTask(Base):
    """播客音频转录任务模型

    跟踪音频转录的整个生命周期，包括下载、转换、分割、转录和合并等阶段

    状态管理：
    - status: 整体任务状态 (PENDING, IN_PROGRESS, COMPLETED, FAILED, CANCELLED)
    - current_step: 当前执行到的步骤 (NOT_STARTED, DOWNLOADING, CONVERTING, SPLITTING, TRANSCRIBING, MERGING)
    """

    __tablename__ = "transcription_tasks"

    id = Column(Integer, primary_key=True, index=True)
    episode_id = Column(
        Integer,
        ForeignKey("podcast_episodes.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
    )

    # 任务状态（简化版）- Use explicit values to match database enum
    status = Column(
        Enum(
            "pending",
            "in_progress",
            "completed",
            "failed",
            "cancelled",
            name="transcriptionstatus",
        ),
        default="pending",
        nullable=False,
    )

    # 当前执行步骤 - Use explicit values to match database enum
    current_step = Column(
        Enum(
            "not_started",
            "downloading",
            "converting",
            "splitting",
            "transcribing",
            "merging",
            name="transcriptionstep",
        ),
        default="not_started",
        nullable=False,
    )

    # 进度百分比 0-100
    progress_percentage = Column(Float, default=0.0)

    # 文件信息
    original_audio_url = Column(String(500), nullable=False)
    original_file_path = Column(String(1000))  # 原始下载文件路径
    original_file_size = Column(Integer)  # 原始文件大小（字节）

    # 处理结果
    transcript_content = Column(Text)  # 最终转录文本
    transcript_word_count = Column(Integer)  # 转录字数
    transcript_duration = Column(Integer)  # 实际转录时长（秒）

    # AI总结结果
    summary_content = Column(Text)  # AI总结内容
    summary_model_used = Column(String(100))  # 使用的AI总结模型
    summary_word_count = Column(Integer)  # 总结字数
    summary_processing_time = Column(Float)  # 总结处理时间（秒）
    summary_error_message = Column(Text)  # 总结错误信息

    # 分片信息（JSON格式存储）
    chunk_info = Column(
        JSON,
        default=dict,
    )  # 存储分片信息，如：{"chunks": [{"index": 1, "file": "path", "size": 1024, "transcript": "..."}]}

    # 错误信息
    error_message = Column(Text)  # 错误详情
    error_code = Column(String(50))  # 错误代码

    # 性能统计
    download_time = Column(Float)  # 下载耗时（秒）
    conversion_time = Column(Float)  # 转换耗时（秒）
    transcription_time = Column(Float)  # 转录总耗时（秒）

    # 配置信息（记录任务使用的配置）
    chunk_size_mb = Column(Integer, default=10)  # 分片大小（MB）
    model_used = Column(String(100))  # 使用的转录模型

    # 时间戳 (使用 timezone-aware datetime)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
    )
    started_at = Column(DateTime(timezone=True))  # 任务开始时间
    completed_at = Column(DateTime(timezone=True))  # 任务完成时间
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    # Relationships
    episode = relationship("PodcastEpisode", backref="transcription_task")

    # Indexes
    __table_args__ = (
        Index("idx_transcription_episode", "episode_id", unique=True),
        Index("idx_transcription_status", "status"),
        Index("idx_transcription_created", "created_at"),
        Index("idx_transcription_status_updated", "status", "updated_at"),
        Index("idx_transcription_status_created", "status", "created_at"),
    )

    @property
    def duration_seconds(self) -> int | None:
        """获取任务执行时长（秒）"""
        if self.started_at and self.completed_at:
            return int((self.completed_at - self.started_at).total_seconds())
        return None

    @property
    def total_processing_time(self) -> float | None:
        """获取总处理时间（秒）"""
        total = 0
        if self.download_time:
            total += self.download_time
        if self.conversion_time:
            total += self.conversion_time
        if self.transcription_time:
            total += self.transcription_time
        return total if total > 0 else None

    def __repr__(self):
        return f"<TranscriptionTask(id={self.id}, episode_id={self.episode_id}, status='{self.status}')>"


class ConversationSession(Base):
    """对话会话模型

    每个 episode+user 可以有多个会话，每个会话包含独立的对话历史
    """

    __tablename__ = "conversation_sessions"

    id = Column(Integer, primary_key=True, index=True)
    episode_id = Column(
        Integer,
        ForeignKey("podcast_episodes.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    title = Column(String(255), default="默认对话")

    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    # Relationships
    episode = relationship("PodcastEpisode", backref="conversation_sessions")
    messages = relationship(
        "PodcastConversation",
        back_populates="session",
        cascade="all, delete-orphan",
        order_by="PodcastConversation.created_at",
    )

    __table_args__ = (
        Index("idx_session_episode_user", "episode_id", "user_id"),
        Index("idx_session_created", "created_at"),
    )

    def __repr__(self):
        return f"<ConversationSession(id={self.id}, episode_id={self.episode_id}, title='{self.title}')>"


class PodcastConversation(Base):
    """播客单集对话交互模型

    存储用户与AI基于播客摘要的对话历史，支持上下文保持的交互
    """

    __tablename__ = "podcast_conversations"

    id = Column(Integer, primary_key=True, index=True)
    episode_id = Column(
        Integer,
        ForeignKey("podcast_episodes.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    session_id = Column(
        Integer,
        ForeignKey("conversation_sessions.id", ondelete="CASCADE"),
        nullable=True,
    )

    # 对话内容
    role = Column(String(20), nullable=False)  # 'user' or 'assistant'
    content = Column(Text, nullable=False)

    # 上下文管理
    parent_message_id = Column(
        Integer,
        ForeignKey("podcast_conversations.id"),
        nullable=True,
    )  # 父消息ID，用于构建对话树
    conversation_turn = Column(Integer, default=0)  # 对话轮次

    # 元数据
    tokens_used = Column(Integer)  # 本次消息使用的token数
    model_used = Column(String(100))  # 使用的AI模型
    processing_time = Column(Float)  # 处理时间（秒）

    # 时间戳
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        index=True,
    )

    # Relationships
    episode = relationship("PodcastEpisode", backref="conversations")
    session = relationship("ConversationSession", back_populates="messages")
    parent_message = relationship(
        "PodcastConversation",
        remote_side=[id],
        backref="replies",
    )

    # Indexes
    __table_args__ = (
        Index("idx_conversation_episode", "episode_id"),
        Index("idx_conversation_user", "user_id"),
        Index("idx_conversation_session", "session_id"),
        Index("idx_conversation_created", "created_at"),
        Index("idx_conversation_turn", "episode_id", "conversation_turn"),
    )

    def __repr__(self):
        return f"<PodcastConversation(id={self.id}, episode_id={self.episode_id}, role='{self.role}')>"


class HighlightExtractionTask(Base):
    """高光提取任务

    跟踪播客单集高光观点提取的整个生命周期
    """

    __tablename__ = "highlight_extraction_tasks"

    id = Column(Integer, primary_key=True, index=True)
    episode_id = Column(
        Integer,
        ForeignKey("podcast_episodes.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )

    # 任务状态
    status = Column(
        String(20),
        default="pending",
        nullable=False,
    )
    progress = Column(Float, default=0.0)

    # 结果统计
    highlights_count = Column(Integer, default=0)
    processing_time = Column(Float)

    # 错误信息
    error_message = Column(Text)

    # 模型信息
    model_used = Column(String(100))

    # 时间戳
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
    )
    started_at = Column(DateTime(timezone=True))
    completed_at = Column(DateTime(timezone=True))

    # Relationships
    episode = relationship("PodcastEpisode", backref="highlight_extraction_task")

    # Indexes
    __table_args__ = (
        Index("idx_highlight_extraction_episode", "episode_id", unique=True),
        Index("idx_highlight_extraction_status", "status"),
        Index("idx_highlight_extraction_created", "created_at"),
    )

    def __repr__(self):
        return f"<HighlightExtractionTask(id={self.id}, episode_id={self.episode_id}, status='{self.status}')>"


class EpisodeHighlight(Base):
    """播客高光观点

    存储从播客单集中提取的核心观点和洞察
    """

    __tablename__ = "episode_highlights"

    id = Column(Integer, primary_key=True, index=True)
    episode_id = Column(
        Integer,
        ForeignKey("podcast_episodes.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # 高光内容
    original_text = Column(Text, nullable=False)  # 原文引用（核心字段）
    context_before = Column(Text)  # 前文上下文（可选）
    context_after = Column(Text)  # 后文上下文（可选）

    # 评分维度 (0-10分)
    insight_score = Column(Float, nullable=False)  # 洞察力评分
    novelty_score = Column(Float, nullable=False)  # 新颖性评分
    actionability_score = Column(Float, nullable=False)  # 可操作性评分
    overall_score = Column(Float, nullable=False)  # 综合评分

    # 元数据
    speaker_hint = Column(String(200))  # 说话人提示
    timestamp_hint = Column(String(50))  # 时间戳提示
    topic_tags = Column(JSON, default=list)  # 话题标签列表

    # 生成信息
    model_used = Column(String(100))  # 使用的LLM模型
    extraction_task_id = Column(
        Integer,
        ForeignKey("highlight_extraction_tasks.id", ondelete="SET NULL"),
        nullable=True,
    )

    # 用户交互
    is_user_favorited = Column(Boolean, default=False)  # 用户是否收藏

    # 状态
    status = Column(
        String(20),
        default="active",
    )  # active/archived/deleted

    # 时间戳
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    # Relationships
    episode = relationship("PodcastEpisode", backref="highlights")
    extraction_task = relationship("HighlightExtractionTask", backref="highlights")

    # Indexes
    __table_args__ = (
        Index("idx_episode_highlight_episode", "episode_id"),
        Index("idx_episode_highlight_status", "status"),
        Index("idx_episode_highlight_overall_score", "overall_score"),
        Index("idx_episode_highlight_favorited", "is_user_favorited"),
        Index("idx_episode_highlight_created", "created_at"),
        # Composite index for date range queries and date-ordered results
        # Note: Migration uses DESC for created_at to optimize get_highlight_dates
        Index("idx_episode_highlight_status_created", "status", "created_at"),
    )

    def __repr__(self):
        return f"<EpisodeHighlight(id={self.id}, episode_id={self.episode_id}, overall_score={self.overall_score})>"


# 辅助方法：判断订阅是否播客
def is_podcast_subscription(subscription) -> bool:
    """判断Subscription是否播客类型"""
    return subscription.source_type == "podcast-rss"
