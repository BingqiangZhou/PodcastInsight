"""Episode transcript storage model.

Separated from podcast_episodes to improve query performance
on the main table by avoiding large TEXT column scans.
"""

from datetime import UTC, datetime

from sqlalchemy import Column, DateTime, ForeignKey, Integer, Text
from sqlalchemy.orm import relationship

from app.core.database import Base


class PodcastEpisodeTranscript(Base):
    """Dedicated storage for episode transcript content.

    Separated from podcast_episodes to improve query performance
    on the main table by avoiding large TEXT column scans.
    """

    __tablename__ = "podcast_episode_transcripts"

    episode_id = Column(
        Integer, ForeignKey("podcast_episodes.id", ondelete="CASCADE"), primary_key=True
    )
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
