"""Add GIN indexes for JSON columns

Revision ID: 016
Revises: 015
Create Date: 2026-03-22 00:00:00.000000

This migration converts JSON columns to JSONB and adds GIN indexes.
"""

from collections.abc import Sequence

from alembic import op


revision: str = "016"
down_revision: str | None = "015"
branch_labels: str | Sequence[str] | None
depends_on: str | Sequence[str] | None


def upgrade() -> None:
    """Convert JSON to JSONB and add GIN indexes."""

    # 1. Users table - settings and preferences
    op.execute(
        """
        ALTER TABLE users
        ALTER COLUMN settings SET DATA TYPE jsonb USING settings::jsonb
        """
    )
    op.execute(
        """
        ALTER TABLE users
        ALTER COLUMN preferences SET DATA TYPE jsonb USING preferences::jsonb
        """
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_users_settings_gin
        ON users USING GIN (settings jsonb_path_ops)
        """
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_users_preferences_gin
        ON users USING GIN (preferences jsonb_path_ops)
        """
    )

    # 2. Podcast episodes - metadata column
    op.execute(
        """
        ALTER TABLE podcast_episodes
        ALTER COLUMN "metadata" SET DATA TYPE jsonb USING "metadata"::jsonb
        """
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_podcast_episodes_metadata_gin
        ON podcast_episodes USING GIN ("metadata" jsonb_path_ops)
        """
    )

    # 3. Transcription tasks - chunk_info column
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_transcription_tasks_chunk_info_gin
        ON transcription_tasks USING GIN (chunk_info jsonb_path_ops)
        """
    )

    # 4. AI model configs - extra_config column
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_ai_model_configs_extra_config_gin
        ON ai_model_configs USING GIN (extra_config jsonb_path_ops)
        """
    )

    # 5. Admin audit logs - details column
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_details_gin
        ON admin_audit_logs USING GIN (details jsonb_path_ops)
        """
    )

    # 6. Background task runs - metadata column
    op.execute(
        """
        ALTER TABLE background_task_runs
        ALTER COLUMN "metadata" SET DATA TYPE jsonb USING "metadata"::jsonb
        """
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_background_task_runs_metadata_gin
        ON background_task_runs USING GIN ("metadata" jsonb_path_ops)
        """
    )

    # 7. System settings - value column
    op.execute(
        """
        ALTER TABLE system_settings
        ALTER COLUMN value SET DATA TYPE jsonb USING value::jsonb
        """
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_system_settings_value_gin
        ON system_settings USING GIN (value jsonb_path_ops)
        """
    )

    # 8. Episode highlights - topic_tags column
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_episode_highlights_topic_tags_gin
        ON episode_highlights USING GIN (topic_tags jsonb_path_ops)
        """
    )

    # 9. User sessions - device_info column
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_user_sessions_device_info_gin
        ON user_sessions USING GIN (device_info jsonb_path_ops)
        """
    )


def downgrade() -> None:
    """Remove JSON GIN indexes."""

    op.execute("DROP INDEX IF EXISTS idx_users_settings_gin")
    op.execute("DROP INDEX IF EXISTS idx_users_preferences_gin")
    op.execute("DROP INDEX IF EXISTS idx_podcast_episodes_metadata_gin")
    op.execute("DROP INDEX IF EXISTS idx_transcription_tasks_chunk_info_gin")
    op.execute("DROP INDEX IF EXISTS idx_ai_model_configs_extra_config_gin")
    op.execute("DROP INDEX IF EXISTS idx_admin_audit_logs_details_gin")
    op.execute("DROP INDEX IF EXISTS idx_background_task_runs_metadata_gin")
    op.execute("DROP INDEX IF EXISTS idx_system_settings_value_gin")
    op.execute("DROP INDEX IF EXISTS idx_episode_highlights_topic_tags_gin")
    op.execute("DROP INDEX IF EXISTS idx_user_sessions_device_info_gin")
