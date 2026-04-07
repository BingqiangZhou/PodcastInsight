"""Conversation models for podcast episode AI interactions."""

from datetime import UTC, datetime

from sqlalchemy import (
    Column,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


class ConversationSession(Base):
    """Conversation session model.

    Each episode+user can have multiple sessions, each with independent
    conversation history.
    """

    __tablename__ = "conversation_sessions"

    id = Column(Integer, primary_key=True)
    episode_id = Column(
        Integer,
        ForeignKey("podcast_episodes.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    title = Column(String(255), default="Default Conversation")

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
    """Podcast episode conversation interaction model.

    Stores user-AI conversation history based on podcast summaries,
    supporting context-preserving interactions.
    """

    __tablename__ = "podcast_conversations"

    id = Column(Integer, primary_key=True)
    episode_id = Column(
        Integer,
        ForeignKey("podcast_episodes.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    session_id = Column(
        Integer,
        ForeignKey("conversation_sessions.id", ondelete="CASCADE"),
        nullable=True,
    )

    # Conversation content
    role = Column(String(20), nullable=False)  # 'user' or 'assistant'
    content = Column(Text, nullable=False)

    # Context management
    parent_message_id = Column(
        Integer,
        ForeignKey("podcast_conversations.id", ondelete="SET NULL"),
        nullable=True,
    )  # Parent message ID for building conversation tree
    conversation_turn = Column(Integer, default=0)  # Conversation turn number

    # Metadata
    tokens_used = Column(Integer)  # Tokens used for this message
    model_used = Column(String(100))  # AI model used
    processing_time = Column(Float)  # Processing time (seconds)

    # Timestamps
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
        Index("idx_conversation_parent", "parent_message_id"),
    )

    def __repr__(self):
        return f"<PodcastConversation(id={self.id}, episode_id={self.episode_id}, role='{self.role}')>"
