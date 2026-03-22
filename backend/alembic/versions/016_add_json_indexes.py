"""Add GIN indexes for JSON columns to optimize JSON path queries

Revision ID: 016
Revises: 015
Create Date: 2026-03-22 00:00:00.000000

This migration adds GIN indexes with jsonb_path_ops for all JSON columns
to improve performance of JSON path queries and containment operations.

Benefits:
- 10-100x faster JSON path queries (e.g., metadata->>'key')
- Efficient containment operators (@>, ?)
- Better query plans for JSON filtering operations

PostgreSQL GIN indexes with jsonb_path_ops:
- Smaller index size than default GIN
- Optimized for @> and ? operators
- Perfect for common JSON query patterns
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "016"
down_revision: str | None = "015"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add GIN indexes for all JSON columns."""

    # Users table - settings and preferences JSON columns
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_users_settings_gin
        ON users USING GIN (settings jsonb_path_ops);
        """
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_users_preferences_gin
        ON users USING GIN (preferences jsonb_path_ops);
        """
    )

    # Podcast episodes - metadata_json column
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_podcast_episodes_metadata_gin
        ON podcast_episodes USING GIN ("metadata" jsonb_path_ops);
        """
    )

    # Transcription tasks - chunk_info column
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_transcription_tasks_chunk_info_gin
        ON transcription_tasks USING GIN (chunk_info jsonb_path_ops);
        """
    )

    # AI model configs - extra_config column
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_ai_model_configs_extra_config_gin
        ON ai_model_configs USING GIN (extra_config jsonb_path_ops);
        """
    )

    # Admin audit logs - details column
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_details_gin
        ON admin_audit_logs USING GIN (details jsonb_path_ops);
        """
    )

    # Background task runs - metadata_json column (stored as 'metadata')
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_background_task_runs_metadata_gin
        ON background_task_runs USING GIN ("metadata" jsonb_path_ops);
        """
    )

    # System settings - value column
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_system_settings_value_gin
        ON system_settings USING GIN (value jsonb_path_ops);
        """
    )

    # Episode highlights - topic_tags column
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_episode_highlights_topic_tags_gin
        ON episode_highlights USING GIN (topic_tags jsonb_path_ops);
        """
    )

    # User sessions - device_info column
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_user_sessions_device_info_gin
        ON user_sessions USING GIN (device_info jsonb_path_ops);
        """
    )

    # Add comments for documentation
    op.execute(
        """
        COMMENT ON INDEX idx_users_settings_gin IS
        'GIN index for JSON path queries on user settings';
        """
    )
    op.execute(
        """
        COMMENT ON INDEX idx_podcast_episodes_metadata_gin IS
        'GIN index for JSON path queries on episode metadata';
        """
    )
    op.execute(
        """
        COMMENT ON INDEX idx_transcription_tasks_chunk_info_gin IS
        'GIN index for JSON path queries on transcription chunk info';
        """
    )


def downgrade() -> None:
    """Remove JSON GIN indexes."""

    op.execute("DROP INDEX IF EXISTS idx_users_settings_gin;")
    op.execute("DROP INDEX IF EXISTS idx_users_preferences_gin;")
    op.execute("DROP INDEX IF EXISTS idx_podcast_episodes_metadata_gin;")
    op.execute("DROP INDEX IF EXISTS idx_transcription_tasks_chunk_info_gin;")
    op.execute("DROP INDEX IF EXISTS idx_ai_model_configs_extra_config_gin;")
    op.execute("DROP INDEX IF EXISTS idx_admin_audit_logs_details_gin;")
    op.execute("DROP INDEX IF EXISTS idx_background_task_runs_metadata_gin;")
    op.execute("DROP INDEX IF EXISTS idx_system_settings_value_gin;")
    op.execute("DROP INDEX IF EXISTS idx_episode_highlights_topic_tags_gin;")
    op.execute("DROP INDEX IF EXISTS idx_user_sessions_device_info_gin;")
