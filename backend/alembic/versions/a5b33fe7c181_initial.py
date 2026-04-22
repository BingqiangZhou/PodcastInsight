"""initial

Revision ID: a5b33fe7c181
Revises:
Create Date: 2026-04-22 19:50:11.503811

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = 'a5b33fe7c181'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

processing_status = postgresql.ENUM(
    'pending', 'processing', 'completed', 'failed',
    name='processingstatus', create_type=False,
)


def upgrade() -> None:
    processing_status.create(op.get_bind(), checkfirst=True)

    op.create_table(
        'podcasts',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('xyzrank_id', sa.String(255), unique=True, nullable=False),
        sa.Column('name', sa.String(500), nullable=False),
        sa.Column('rank', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('logo_url', sa.String(1000), nullable=True),
        sa.Column('category', sa.String(255), nullable=True),
        sa.Column('author', sa.String(500), nullable=True),
        sa.Column('rss_feed_url', sa.String(1000), nullable=True),
        sa.Column('track_count', sa.Integer(), nullable=True),
        sa.Column('avg_duration', sa.Integer(), nullable=True),
        sa.Column('avg_play_count', sa.Integer(), nullable=True),
        sa.Column('last_synced_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('is_tracked', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )

    op.create_table(
        'podcast_ranking_history',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('podcast_id', sa.Uuid(), sa.ForeignKey('podcasts.id', ondelete='CASCADE'), nullable=False),
        sa.Column('rank', sa.Integer(), nullable=False),
        sa.Column('avg_play_count', sa.Integer(), nullable=True),
        sa.Column('recorded_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index('ix_ranking_history_podcast_id', 'podcast_ranking_history', ['podcast_id'])

    op.create_table(
        'episodes',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('podcast_id', sa.Uuid(), sa.ForeignKey('podcasts.id', ondelete='CASCADE'), nullable=False),
        sa.Column('title', sa.String(1000), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('audio_url', sa.String(1000), nullable=True),
        sa.Column('duration', sa.Integer(), nullable=True),
        sa.Column('published_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('transcript_status', processing_status, nullable=True),
        sa.Column('summary_status', processing_status, nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index('ix_episodes_podcast_id', 'episodes', ['podcast_id'])

    op.create_table(
        'transcripts',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('episode_id', sa.Uuid(), sa.ForeignKey('episodes.id', ondelete='CASCADE'), unique=True, nullable=False),
        sa.Column('content', sa.Text(), nullable=True),
        sa.Column('segments', postgresql.JSONB(), nullable=True),
        sa.Column('language', sa.String(10), nullable=True),
        sa.Column('duration', sa.Integer(), nullable=True),
        sa.Column('word_count', sa.Integer(), nullable=True),
        sa.Column('model_used', sa.String(100), nullable=True),
        sa.Column('status', processing_status, nullable=False, server_default='pending'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )

    op.create_table(
        'summaries',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('episode_id', sa.Uuid(), sa.ForeignKey('episodes.id', ondelete='CASCADE'), unique=True, nullable=False),
        sa.Column('content', sa.Text(), nullable=True),
        sa.Column('key_topics', postgresql.JSONB(), nullable=True),
        sa.Column('highlights', postgresql.JSONB(), nullable=True),
        sa.Column('model_used', sa.String(100), nullable=True),
        sa.Column('provider', sa.String(100), nullable=True),
        sa.Column('status', processing_status, nullable=False, server_default='pending'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )

    op.create_table(
        'ai_provider_configs',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('name', sa.String(255), nullable=False),
        sa.Column('provider_type', sa.String(50), nullable=False),
        sa.Column('base_url', sa.String(500), nullable=False),
        sa.Column('encrypted_api_key', sa.Text(), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )

    op.create_table(
        'ai_model_configs',
        sa.Column('id', sa.Uuid(), primary_key=True),
        sa.Column('provider_id', sa.Uuid(), sa.ForeignKey('ai_provider_configs.id', ondelete='CASCADE'), nullable=False),
        sa.Column('model_name', sa.String(255), nullable=False),
        sa.Column('temperature', sa.Float(), nullable=False, server_default='0.3'),
        sa.Column('max_tokens', sa.Integer(), nullable=False, server_default='4096'),
        sa.Column('is_default', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index('ix_model_configs_provider_id', 'ai_model_configs', ['provider_id'])


def downgrade() -> None:
    op.drop_table('ai_model_configs')
    op.drop_table('ai_provider_configs')
    op.drop_table('summaries')
    op.drop_table('transcripts')
    op.drop_table('episodes')
    op.drop_table('podcast_ranking_history')
    op.drop_table('podcasts')
    processing_status.drop(op.get_bind(), checkfirst=True)
