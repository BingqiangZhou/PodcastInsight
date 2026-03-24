"""Admin security settings utilities."""

import logging

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.admin.models import SystemSettings
from app.core.config import settings


logger = logging.getLogger(__name__)


async def get_admin_2fa_enabled(db: AsyncSession) -> tuple[bool, str]:
    """Get admin 2FA enabled status with priority: database > environment variable.

    Args:
        db: Database session

    Returns:
        Tuple of (is_enabled, source) where source is "database" or "env"

    """
    # First, try to get from database
    result = await db.execute(
        select(SystemSettings).where(SystemSettings.key == "admin.2fa_enabled"),
    )
    setting = result.scalar_one_or_none()

    if setting and setting.value is not None:
        # Database setting takes priority
        is_enabled = setting.value.get("value", True)
        logger.debug(f"Admin 2FA setting from database: {is_enabled}")
        return is_enabled, "database"

    # Fall back to environment variable
    is_enabled = settings.ADMIN_2FA_ENABLED
    logger.debug(f"Admin 2FA setting from environment: {is_enabled}")
    return is_enabled, "env"


async def set_admin_2fa_enabled(db: AsyncSession, enabled: bool) -> SystemSettings:
    """Set admin 2FA enabled status in database.

    Args:
        db: Database session
        enabled: Whether 2FA should be enabled

    Returns:
        The created or updated SystemSettings record

    """
    # Check if setting already exists
    result = await db.execute(
        select(SystemSettings).where(SystemSettings.key == "admin.2fa_enabled"),
    )
    setting = result.scalar_one_or_none()

    if setting:
        # Update existing setting
        setting.value = {"value": enabled}
        logger.info(f"Updated admin 2FA setting in database: {enabled}")
    else:
        # Create new setting
        setting = SystemSettings(
            key="admin.2fa_enabled",
            value={"value": enabled},
            description="Admin panel 2FA toggle / 后台管理2FA开关",
            category="security",
        )
        db.add(setting)
        logger.info(f"Created admin 2FA setting in database: {enabled}")

    await db.commit()
    # No refresh needed - setting is already in session with updated values
    return setting
