"""drop 2fa columns and audit table

Revision ID: 1645bdeb3b85
Revises: 023
Create Date: 2026-04-20 17:29:56.900542

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '024'
down_revision: Union[str, Sequence[str], None] = '023'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Drop 2FA columns from users table
    op.drop_column('users', 'totp_secret')
    op.drop_column('users', 'is_2fa_enabled')

    # Drop admin_audit_logs table
    op.drop_table('admin_audit_logs')


def downgrade() -> None:
    """Downgrade schema."""
    # Recreate admin_audit_logs table
    op.create_table(
        'admin_audit_logs',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('username', sa.String(length=100), nullable=False),
        sa.Column('action', sa.String(length=100), nullable=False),
        sa.Column('resource_type', sa.String(length=50), nullable=False),
        sa.Column('resource_id', sa.Integer(), nullable=True),
        sa.Column('resource_name', sa.String(length=255), nullable=True),
        sa.Column('details', sa.JSON(), nullable=True),
        sa.Column('ip_address', sa.String(length=45), nullable=True),
        sa.Column('user_agent', sa.Text(), nullable=True),
        sa.Column('status', sa.String(length=20), nullable=False),
        sa.Column('error_message', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('idx_user_action', 'admin_audit_logs', ['user_id', 'action'])
    op.create_index('idx_resource', 'admin_audit_logs', ['resource_type', 'resource_id'])
    op.create_index('idx_created_at_desc', 'admin_audit_logs', ['created_at'])

    # Add 2FA columns back to users table
    op.add_column('users', sa.Column('totp_secret', sa.String(length=32), nullable=True))
    op.add_column('users', sa.Column('is_2fa_enabled', sa.Boolean(), nullable=False, server_default='false'))
