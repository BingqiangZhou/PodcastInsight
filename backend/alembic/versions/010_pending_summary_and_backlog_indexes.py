"""add pending-summary and backlog candidate indexes

Revision ID: 010
Revises: 009
Create Date: 2026-03-10 00:00:00.000000
"""

from collections.abc import Sequence

from alembic import op


# revision identifiers, used by Alembic.
revision: str = "010"
down_revision: str | None = "009"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_podcast_episodes_status_published_id
        ON podcast_episodes (status, published_at DESC, id DESC);
        """
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_podcast_episodes_backlog_candidates
        ON podcast_episodes (published_at DESC, id DESC)
        WHERE audio_url IS NOT NULL
          AND audio_url <> ''
          AND (transcript_content IS NULL OR transcript_content = '');
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("DROP INDEX IF EXISTS idx_podcast_episodes_backlog_candidates;")
    op.execute("DROP INDEX IF EXISTS idx_podcast_episodes_status_published_id;")
