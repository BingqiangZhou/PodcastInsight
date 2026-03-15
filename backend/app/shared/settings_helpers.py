"""Shared helpers for system settings persistence."""

from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.admin.models import SystemSettings


async def persist_setting(
    db: AsyncSession,
    key: str,
    value: dict[str, Any],
    *,
    description: str | None = None,
    category: str | None = None,
) -> SystemSettings:
    """Persist a system setting with get-or-create semantics.

    Args:
        db: Database session
        key: Setting key
        value: Setting value (dict)
        description: Optional description for new settings
        category: Optional category for new settings

    Returns:
        The persisted SystemSettings instance

    """
    result = await db.execute(select(SystemSettings).where(SystemSettings.key == key))
    setting = result.scalar_one_or_none()

    if setting:
        setting.value = value
    else:
        setting = SystemSettings(
            key=key,
            value=value,
            description=description,
            category=category,
        )
        db.add(setting)

    return setting
