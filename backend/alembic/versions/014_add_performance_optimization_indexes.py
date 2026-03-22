"""add performance optimization indexes

Revision ID: 014
Revises: 013
Create Date: 2026-03-22 00:00:00.000000

This migration adds performance optimization indexes identified by the
backend optimization analysis:
- Composite index for podcast_episodes (subscription_id, published)
- GIN index for podcast_episodes title (pg_trgm) for full-text search
- Partial index for podcast_playback_states for active users

"""

from collections.abc import Sequence

from alembic import op


# revision identifiers, used by Alembic.
revision: str = "014"
down_revision: str | None = "013"
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def upgrade() -> None:
    """Add performance optimization indexes."""

    # 1. Composite index for feed queries (podcast_episodes by subscription + published)
    # This optimizes the most common query pattern: get_feed_episodes_by_subscription_date
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_podcast_episodes_subscription_published
        ON podcast_episodes (subscription_id, published_at DESC);
        """
    )

    # 2. GIN indexes for full-text search on # Enable pg_trgm extension if not already enabled
    try:
        op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")
    except Exception:
        pass  # Extension already exists

    # Create GIN indexes for title and description
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_podcast_episodes_title_trgm
        ON podcast_episodes USING GIN (title gin_trgm_ops)
        """
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_podcast_episodes_description_trgm
        ON podcast_episodes USING GIN (description gin_trgm_ops)
        """
    )

    # 3. Partial index for active playback states
    # Optimize queries for active user playback states
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_playback_state_active_user
        ON podcast_playback_states (user_id, episode_id)
        WHERE deleted_at IS NULL
        """
    )


def downgrade() -> None:
    """Remove performance optimization indexes."""

    op.execute("DROP INDEX IF EXISTS idx_podcast_episodes_subscription_published")

    op.execute("DROP INDEX IF EXISTS idx_podcast_episodes_title_trgm")

    op.execute("DROP INDEX IF EXISTS idx_podcast_episodes_description_trgm")

    op.execute("DROP INDEX IF EXISTS idx_playback_state_active_user")
