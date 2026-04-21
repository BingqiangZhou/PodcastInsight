"""Admin service helpers for system settings."""

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.admin.models import SystemSettings
from app.admin.storage_service import StorageCleanupService
from app.domains.podcast.models import (
    Subscription,
    UpdateFrequency,
    UserSubscription,
)
from app.admin.settings_helpers import persist_setting


class AdminSettingsService:
    """Read and write admin-configurable system settings."""

    def __init__(self, db: AsyncSession):
        self.db = db

    @staticmethod
    def validate_audio_settings(
        *,
        chunk_size_mb: int,
        max_concurrent_threads: int,
    ) -> None:
        """Validate audio-processing admin settings input."""
        if not (5 <= chunk_size_mb <= 25):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="chunk_size_mb must be between 5 and 25",
            )
        if not (1 <= max_concurrent_threads <= 16):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="max_concurrent_threads must be between 1 and 16",
            )

    @staticmethod
    def validate_frequency_settings(
        *,
        update_frequency: str,
        update_time: str | None,
        update_day: int | None,
    ) -> None:
        """Validate RSS frequency admin settings input."""
        valid_frequencies = ["HOURLY", "DAILY", "WEEKLY"]
        if update_frequency not in valid_frequencies:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid frequency. Must be one of: {valid_frequencies}",
            )
        if update_frequency in ["DAILY", "WEEKLY"] and not update_time:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="update_time is required for DAILY and WEEKLY frequencies",
            )
        if update_time:
            try:
                hour, minute = map(int, update_time.split(":"))
            except (AttributeError, ValueError) as err:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="update_time must use HH:MM format",
                ) from err
            if not (0 <= hour <= 23 and 0 <= minute <= 59):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="update_time must use HH:MM format",
                )
        if update_frequency == "WEEKLY" and not update_day:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="update_day is required for WEEKLY frequency",
            )
        if update_day is not None and not (1 <= update_day <= 7):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="update_day must be between 1 and 7",
            )

    async def get_audio_settings(self) -> dict[str, int]:
        """Return persisted audio-processing settings with defaults."""
        chunk_size_setting = await self._get_setting("audio.chunk_size_mb")
        threads_setting = await self._get_setting("audio.max_concurrent_threads")

        chunk_size_mb = 10
        max_concurrent_threads = 2

        if chunk_size_setting and chunk_size_setting.value:
            chunk_size_mb = chunk_size_setting.value.get("value", 10)
        if threads_setting and threads_setting.value:
            max_concurrent_threads = threads_setting.value.get("value", 2)

        return {
            "chunk_size_mb": chunk_size_mb,
            "max_concurrent_threads": max_concurrent_threads,
        }

    async def update_audio_settings(
        self,
        *,
        chunk_size_mb: int,
        max_concurrent_threads: int,
    ) -> None:
        """Persist audio-processing settings."""
        await persist_setting(
            self.db,
            "audio.chunk_size_mb",
            {"value": chunk_size_mb, "min": 5, "max": 25},
            description="Audio chunk size in MB / 音频切块大小(MB)",
            category="audio",
        )
        await persist_setting(
            self.db,
            "audio.max_concurrent_threads",
            {"value": max_concurrent_threads, "min": 1, "max": 16},
            description="Maximum concurrent processing threads / 最大并发处理线程数",
            category="audio",
        )
        await self.db.commit()

    async def save_audio_settings(
        self,
        *,
        request,
        user_id,
        chunk_size_mb: int,
        max_concurrent_threads: int,
    ) -> dict[str, object]:
        """Validate, persist, and audit audio-processing settings."""
        self.validate_audio_settings(
            chunk_size_mb=chunk_size_mb,
            max_concurrent_threads=max_concurrent_threads,
        )
        await self.update_audio_settings(
            chunk_size_mb=chunk_size_mb,
            max_concurrent_threads=max_concurrent_threads,
        )
        return {"success": True, "message": "Settings saved"}

    async def get_frequency_settings(self) -> dict[str, object]:
        """Return RSS subscription frequency settings with fallback source."""
        default_frequency = UpdateFrequency.HOURLY.value
        default_update_time = "00:00"
        default_day_of_week = 1
        source = "default"

        setting = await self._get_setting("rss.frequency_settings")
        if setting and setting.value:
            default_frequency = setting.value.get(
                "update_frequency",
                UpdateFrequency.HOURLY.value,
            )
            default_update_time = setting.value.get("update_time", "00:00")
            default_day_of_week = setting.value.get("update_day_of_week", 1)
            source = "database"
        else:
            recent_result = await self.db.execute(
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
                .limit(1),
            )
            row = recent_result.first()
            if row:
                default_frequency = row[0]
                default_update_time = row[1] or "00:00"
                default_day_of_week = row[2] or 1
                source = "user_subscription"

        return {
            "update_frequency": default_frequency,
            "update_time": default_update_time,
            "update_day_of_week": default_day_of_week,
            "source": source,
        }

    async def update_frequency_settings(
        self,
        *,
        update_frequency: str,
        update_time: str | None,
        update_day: int | None,
    ) -> tuple[dict[str, object], int]:
        """Persist RSS frequency settings and fan out to user mappings."""
        settings_data = {
            "update_frequency": update_frequency,
            "update_time": update_time
            if update_frequency in ["DAILY", "WEEKLY"]
            else None,
            "update_day_of_week": update_day if update_frequency == "WEEKLY" else None,
        }

        await persist_setting(
            self.db,
            "rss.frequency_settings",
            settings_data,
            description="RSS subscription update frequency settings",
            category="subscription",
        )

        user_subscriptions = (
            (
                await self.db.execute(
                    select(UserSubscription)
                    .join(
                        Subscription,
                        Subscription.id == UserSubscription.subscription_id,
                    )
                    .where(Subscription.source_type.in_(["rss", "podcast-rss"])),
                )
            )
            .scalars()
            .all()
        )

        total_count = 0
        for user_sub in user_subscriptions:
            user_sub.update_frequency = settings_data["update_frequency"]
            user_sub.update_time = settings_data["update_time"]
            user_sub.update_day_of_week = settings_data["update_day_of_week"]
            total_count += 1

        await self.db.commit()
        return settings_data, total_count

    async def save_frequency_settings(
        self,
        *,
        request,
        user_id,
        update_frequency: str,
        update_time: str | None,
        update_day: int | None,
    ) -> dict[str, object]:
        """Validate, persist, and audit RSS frequency settings."""
        self.validate_frequency_settings(
            update_frequency=update_frequency,
            update_time=update_time,
            update_day=update_day,
        )
        settings_data, total_count = await self.update_frequency_settings(
            update_frequency=update_frequency,
            update_time=update_time,
            update_day=update_day,
        )
        return {
            "success": True,
            "message": f"RSS settings saved (updated {total_count} user-subscription mappings)",
        }

    async def get_storage_info(self) -> dict:
        """Return storage usage information."""
        return await StorageCleanupService(self.db).get_storage_info()

    async def get_cleanup_config(self) -> dict:
        """Return automatic cleanup configuration."""
        return await StorageCleanupService(self.db).get_cleanup_config()

    async def update_cleanup_config(self, enabled: bool) -> dict:
        """Persist automatic cleanup configuration."""
        return await StorageCleanupService(self.db).update_cleanup_config(enabled)

    async def save_cleanup_config(
        self,
        *,
        request,
        user_id,
        enabled: bool,
    ) -> dict:
        """Persist and audit automatic cleanup configuration."""
        result = await self.update_cleanup_config(enabled)
        if result.get("success"):
            return result

    async def execute_cleanup(self, keep_days: int) -> dict:
        """Execute storage cleanup immediately."""
        return await StorageCleanupService(self.db).execute_cleanup(keep_days)

    async def run_cleanup(
        self,
        *,
        request,
        user_id,
        keep_days: int,
    ) -> dict:
        """Execute cleanup and record the admin audit event."""
        result = await self.execute_cleanup(keep_days)
        return result

    async def _get_setting(self, key: str) -> SystemSettings | None:
        result = await self.db.execute(
            select(SystemSettings).where(SystemSettings.key == key),
        )
        return result.scalar_one_or_none()
