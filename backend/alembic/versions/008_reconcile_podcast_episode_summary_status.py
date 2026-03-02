"""reconcile podcast episode summary status values

Revision ID: 008
Revises: 007
Create Date: 2026-03-02 00:00:00.000000
"""

from collections.abc import Sequence

from alembic import op


# revision identifiers, used by Alembic.
revision: str = "008"
down_revision: str | None = "007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        """
        UPDATE podcast_episodes
        SET status = 'pending_summary',
            updated_at = NOW()
        WHERE ai_summary IS NULL
          AND transcript_content IS NOT NULL
          AND status = 'completed';
        """
    )
    op.execute(
        """
        UPDATE podcast_episodes
        SET status = 'summarized',
            updated_at = NOW()
        WHERE ai_summary IS NOT NULL
          AND status <> 'summarized'
          AND status <> 'summary_failed';
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    return None
