"""Database-backed settings provider for reading system settings."""

from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.admin.models import SystemSettings


class DatabaseSettingsProvider:
    """Read system settings from the ``system_settings`` table."""

    async def get_setting(self, db: AsyncSession, key: str) -> dict[str, Any] | None:
        result = await db.execute(
            select(SystemSettings).where(SystemSettings.key == key),
        )
        setting = result.scalar_one_or_none()
        if setting and setting.value:
            return setting.value
        return None

    async def get_setting_value(
        self,
        db: AsyncSession,
        key: str,
        default: Any = None,
    ) -> Any:
        data = await self.get_setting(db, key)
        if data is None:
            return default
        return data.get("value", default) if isinstance(data, dict) else default
