"""Widen user_sessions.session_token and refresh_token to TEXT

Revision ID: 020
Revises: 019
Create Date: 2026-04-05

JWT tokens regularly exceed 255 characters, causing
StringDataRightTruncationError on login.
"""

from collections.abc import Sequence

from alembic import op


revision: str = "020"
down_revision: str | None = "019"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE user_sessions ALTER COLUMN session_token TYPE TEXT"
    )
    op.execute(
        "ALTER TABLE user_sessions ALTER COLUMN refresh_token TYPE TEXT"
    )


def downgrade() -> None:
    # Note: downgrade will fail if any token exceeds 255 chars
    op.execute(
        "ALTER TABLE user_sessions ALTER COLUMN session_token TYPE VARCHAR(255)"
    )
    op.execute(
        "ALTER TABLE user_sessions ALTER COLUMN refresh_token TYPE VARCHAR(255)"
    )
