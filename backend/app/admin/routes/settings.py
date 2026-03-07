"""Admin settings routes module.

This module contains all routes related to system settings management:
- Settings page
- Audio processing settings
- RSS subscription update frequency settings
- Security settings (2FA)
- Storage management and cleanup
"""

import logging

from fastapi import APIRouter, Body, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.admin.audit import log_admin_action
from app.admin.dependencies import admin_required
from app.admin.models import SystemSettings
from app.admin.routes._shared import get_templates
from app.admin.services import AdminSettingsService
from app.core.database import get_db_session
from app.domains.subscription.models import (
    Subscription,
    UpdateFrequency,
    UserSubscription,
)
from app.domains.user.models import User


logger = logging.getLogger(__name__)

router = APIRouter()
templates = get_templates()


# ==================== Settings Page ====================


@router.get("/settings", response_class=HTMLResponse)
async def settings_page(
    request: Request,
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Display system settings page."""
    try:
        return templates.TemplateResponse(
            "settings.html",
            {
                "request": request,
                "user": user,
                "messages": [],
            },
        )
    except Exception as e:
        logger.error(f"Settings page error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to load settings page",
        ) from e


# ==================== Audio Settings ====================

@router.get("/settings/api/audio")
async def get_audio_settings(
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Get audio processing settings as JSON."""
    try:
        payload = await AdminSettingsService(db).get_audio_settings()
        return JSONResponse(content=payload)
    except Exception as e:
        logger.error(f"Get audio settings error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to get audio settings",
        ) from e

@router.post("/settings/api/audio")
async def update_audio_settings(
    request: Request,
    chunk_size_mb: int = Body(..., embed=True),
    max_concurrent_threads: int = Body(..., embed=True),
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Update audio processing settings."""
    try:
        if not (5 <= chunk_size_mb <= 25):
            raise HTTPException(
                status_code=400,
                detail="chunk_size_mb must be between 5 and 25",
            )
        if not (1 <= max_concurrent_threads <= 16):
            raise HTTPException(
                status_code=400,
                detail="max_concurrent_threads must be between 1 and 16",
            )

        await AdminSettingsService(db).update_audio_settings(
            chunk_size_mb=chunk_size_mb,
            max_concurrent_threads=max_concurrent_threads,
        )
        logger.info(
            f"Audio settings updated by user {user.username}: chunk_size_mb={chunk_size_mb}, max_concurrent_threads={max_concurrent_threads}"
        )
        await log_admin_action(
            db=db,
            user_id=user.id,
            username=user.username,
            action="update",
            resource_type="system_settings",
            resource_name="Audio processing settings",
            details={
                "chunk_size_mb": chunk_size_mb,
                "max_concurrent_threads": max_concurrent_threads,
            },
            request=request,
        )
        return JSONResponse(
            content={
                "success": True,
                "message": "Settings saved",
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Update audio settings error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to update audio settings",
        ) from e


# ==================== Frequency Settings ====================


@router.get("/settings/frequency")
async def get_frequency_settings(
    request: Request,
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Get RSS subscription update frequency settings."""
    try:
        default_frequency = UpdateFrequency.HOURLY.value
        default_update_time = "00:00"
        default_day_of_week = 1
        source = "default"

        settings_result = await db.execute(
            select(SystemSettings).where(SystemSettings.key == "rss.frequency_settings")
        )
        setting = settings_result.scalar_one_or_none()
        if setting and setting.value:
            default_frequency = setting.value.get(
                "update_frequency", UpdateFrequency.HOURLY.value
            )
            default_update_time = setting.value.get("update_time", "00:00")
            default_day_of_week = setting.value.get("update_day_of_week", 1)
            source = "database"
        else:
            recent_result = await db.execute(
                select(
                    UserSubscription.update_frequency,
                    UserSubscription.update_time,
                    UserSubscription.update_day_of_week,
                )
                .where(UserSubscription.update_frequency.isnot(None))
                .group_by(
                    UserSubscription.update_frequency,
                    UserSubscription.update_time,
                    UserSubscription.update_day_of_week,
                )
                .order_by(func.count().desc())
                .limit(1)
            )
            row = recent_result.first()
            if row:
                default_frequency = row[0]
                default_update_time = row[1] or "00:00"
                default_day_of_week = row[2] or 1
                source = "user_subscription"

        return JSONResponse(
            content={
                "update_frequency": default_frequency,
                "update_time": default_update_time,
                "update_day_of_week": default_day_of_week,
                "source": source,
            }
        )

    except Exception as e:
        logger.error(f"Get frequency settings error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to get frequency settings",
        ) from e


@router.post("/settings/frequency")
async def update_frequency_settings(
    request: Request,
    update_frequency: str = Body(..., embed=True),
    update_time: str | None = Body(None, embed=True),
    update_day: int | None = Body(None, embed=True),
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Update RSS subscription update frequency settings."""
    try:
        valid_frequencies = ["HOURLY", "DAILY", "WEEKLY"]
        if update_frequency not in valid_frequencies:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid frequency. Must be one of: {valid_frequencies}",
            )

        if update_frequency in ["DAILY", "WEEKLY"] and not update_time:
            raise HTTPException(
                status_code=400,
                detail="update_time is required for DAILY and WEEKLY frequencies",
            )

        if update_frequency == "WEEKLY" and not update_day:
            raise HTTPException(
                status_code=400,
                detail="update_day is required for WEEKLY frequency",
            )

        if update_day is not None and not (1 <= update_day <= 7):
            raise HTTPException(
                status_code=400,
                detail="update_day must be between 1 and 7",
            )

        settings_data = {
            "update_frequency": update_frequency,
            "update_time": update_time if update_frequency in ["DAILY", "WEEKLY"] else None,
            "update_day_of_week": update_day if update_frequency == "WEEKLY" else None,
        }

        existing_setting = await db.execute(
            select(SystemSettings).where(SystemSettings.key == "rss.frequency_settings")
        )
        setting = existing_setting.scalar_one_or_none()

        if setting:
            setting.value = settings_data
        else:
            db.add(
                SystemSettings(
                    key="rss.frequency_settings",
                    value=settings_data,
                    description="RSS subscription update frequency settings",
                    category="subscription",
                )
            )

        user_subscriptions = (
            await db.execute(
                select(UserSubscription)
                .join(Subscription, Subscription.id == UserSubscription.subscription_id)
                .where(Subscription.source_type.in_(["rss", "podcast-rss"]))
            )
        ).scalars().all()

        total_count = 0
        for user_sub in user_subscriptions:
            user_sub.update_frequency = settings_data["update_frequency"]
            user_sub.update_time = settings_data["update_time"]
            user_sub.update_day_of_week = settings_data["update_day_of_week"]
            total_count += 1

        await db.commit()

        await log_admin_action(
            db=db,
            user_id=user.id,
            username=user.username,
            action="update",
            resource_type="subscription_frequency",
            resource_name=f"All user subscriptions (affected {total_count})",
            details=settings_data,
            request=request,
        )

        return JSONResponse(
            content={
                "success": True,
                "message": (
                    f"RSS settings saved (updated {total_count} "
                    "user-subscription mappings)"
                ),
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Update frequency settings error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to update frequency settings",
        ) from e


# ==================== Security Settings ====================


@router.get("/settings/api/security")
async def get_security_settings(
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Get security settings as JSON."""
    try:
        from app.admin.security_settings import get_admin_2fa_enabled

        # Get 2FA setting with priority
        admin_2fa_enabled, source = await get_admin_2fa_enabled(db)

        return JSONResponse(content={
            "admin_2fa_enabled": admin_2fa_enabled,
            "source": source,
        })
    except Exception as e:
        logger.error(f"Get security settings error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to get security settings",
        ) from e


@router.post("/settings/api/security")
async def update_security_settings(
    request: Request,
    admin_2fa_enabled: bool = Body(..., embed=True),
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Update security settings."""
    try:
        from app.admin.security_settings import set_admin_2fa_enabled

        # Save 2FA setting to database
        await set_admin_2fa_enabled(db, admin_2fa_enabled)

        logger.info(f"Security settings updated by user {user.username}: admin_2fa_enabled={admin_2fa_enabled}")

        # Log audit action
        await log_admin_action(
            db=db,
            user_id=user.id,
            username=user.username,
            action="update",
            resource_type="security_settings",
            resource_name="Admin 2FA Settings",
            details={
                "admin_2fa_enabled": admin_2fa_enabled,
            },
            request=request,
        )

        return JSONResponse(content={
            "success": True,
            "message": "安全设置已保存"
        })
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Update security settings error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to update security settings",
        ) from e


# ==================== Storage Management ====================


@router.get("/settings/api/storage/info")
async def get_storage_info(
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Get storage information as JSON."""
    try:
        from app.admin.storage_service import StorageCleanupService

        service = StorageCleanupService(db)
        info = await service.get_storage_info()

        return JSONResponse(content=info)
    except Exception as e:
        logger.error(f"Get storage info error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to get storage information",
        ) from e


@router.get("/settings/api/storage/cleanup/config")
async def get_cleanup_config(
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Get auto cleanup configuration as JSON."""
    try:
        from app.admin.storage_service import StorageCleanupService

        service = StorageCleanupService(db)
        config = await service.get_cleanup_config()

        return JSONResponse(content=config)
    except Exception as e:
        logger.error(f"Get cleanup config error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to get cleanup configuration",
        ) from e


@router.post("/settings/api/storage/cleanup/config")
async def update_cleanup_config(
    request: Request,
    enabled: bool = Body(..., embed=True),
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Update auto cleanup configuration."""
    try:
        from app.admin.storage_service import StorageCleanupService

        service = StorageCleanupService(db)
        result = await service.update_cleanup_config(enabled)

        if result["success"]:
            logger.info(f"Auto cleanup config updated by user {user.username}: enabled={enabled}")

            # Log audit action
            await log_admin_action(
                db=db,
                user_id=user.id,
                username=user.username,
                action="update",
                resource_type="storage_settings",
                resource_name="Auto Cleanup Settings",
                details={
                    "enabled": enabled,
                },
                request=request,
            )

        return JSONResponse(content=result)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Update cleanup config error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to update cleanup configuration",
        ) from e


@router.post("/settings/api/storage/cleanup/execute")
async def execute_cleanup(
    request: Request,
    keep_days: int = Body(1, embed=True),
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Execute manual cleanup (deletes files from yesterday and earlier, keeps only today's files)."""
    try:
        from app.admin.storage_service import StorageCleanupService

        service = StorageCleanupService(db)
        result = await service.execute_cleanup(keep_days)

        # Log audit action
        await log_admin_action(
            db=db,
            user_id=user.id,
            username=user.username,
            action="execute",
            resource_type="storage_cleanup",
            resource_name="Manual Cache Cleanup",
            details={
                "keep_days": keep_days,
                "deleted_count": result.get("total", {}).get("deleted_count", 0),
                "freed_space": result.get("total", {}).get("freed_space_human", "0 B"),
            },
            request=request,
        )

        return JSONResponse(content=result)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Execute cleanup error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to execute cleanup",
        ) from e
