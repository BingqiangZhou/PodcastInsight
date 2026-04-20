"""Transcription State Manager - Redis-based caching and locking

Provides fast state management for podcast transcription tasks:
- Task locks to prevent duplicate processing
- Progress caching for efficient polling
- Ephemeral status storage with TTL
"""

import logging
import time
from datetime import UTC, datetime
from typing import Any

import orjson
import redis.exceptions

from app.core.redis import get_shared_redis


logger = logging.getLogger(__name__)


class ProgressLogThrottle:
    """Throttle progress logs to reduce noisy output."""

    def __init__(self, min_interval_seconds: int = 5):
        """Create a throttle with a minimum log interval."""
        self.min_interval = min_interval_seconds
        self._last_log_time: dict[str, float] = {}
        self._last_log_progress: dict[str, float] = {}

    def should_log(self, task_id: int, status: str, progress: float) -> bool:
        """Return True when a progress update should be logged."""
        key = f"{task_id}_{status}"
        current_time = time.time()

        # Compare against the previous logged timestamp and progress value.
        last_time = self._last_log_time.get(key, 0)
        last_progress = self._last_log_progress.get(key, -1)

        time_elapsed = current_time - last_time
        if time_elapsed < self.min_interval:
            return False

        progress_changed = abs(progress - last_progress) >= 5.0

        # Always log key milestones.
        milestone = (progress < 1) or (49 <= progress <= 51) or (progress >= 99)

        if progress_changed or milestone:
            self._last_log_time[key] = current_time
            self._last_log_progress[key] = progress
            return True

        return False


# Global progress throttle instance.
_progress_throttle = ProgressLogThrottle(min_interval_seconds=5)


class TranscriptionStateKeys:
    """Redis key patterns for transcription state"""

    # Task lock: prevents duplicate processing for same episode
    TASK_LOCK_NAME = "transcription:episode:{episode_id}"
    TASK_LOCK = "podcast:lock:transcription:episode:{episode_id}"
    LEGACY_TASK_LOCK_VALUE = "podcast:transcription:lock_value:{episode_id}"

    # Task progress: cached progress for fast polling (1 hour TTL)
    TASK_PROGRESS = "podcast:transcription:progress:{task_id}"

    # Episode-to-task mapping: find active task by episode_id (5 min TTL)
    EPISODE_TASK = "podcast:transcription:episode_task:{episode_id}"

    # Task status summary: lightweight status for dashboard (15 min TTL)
    TASK_STATUS = "podcast:transcription:status:{task_id}"
    ACTIVE_TASK_INDEX = "podcast:transcription:active_tasks"
    LOCK_INDEX = "podcast:transcription:lock_index"


class TranscriptionStateManager:
    """Redis-based state manager for transcription tasks

    Provides:
    1. Distributed locks to prevent duplicate processing
    2. Fast progress caching for efficient polling
    3. Episode-to-task mapping for quick lookups
    4. Automatic cleanup with TTL
    """

    def __init__(self):
        self.redis = get_shared_redis()

    @staticmethod
    def _active_task_index_key() -> str:
        return TranscriptionStateKeys.ACTIVE_TASK_INDEX

    @staticmethod
    def _lock_index_key() -> str:
        return TranscriptionStateKeys.LOCK_INDEX

    # === Redis Cache Access (convenience methods) ===

    async def get(self, key: str) -> str | None:
        """Get value from Redis cache

        Args:
            key: Cache key

        Returns:
            Value if found, None otherwise

        """
        return await self.redis.get(key)

    async def set(self, key: str, value: str, ttl: int = 3600) -> None:
        """Set value in Redis cache

        Args:
            key: Cache key
            value: Value to store
            ttl: Time to live in seconds (default 1 hour)

        """
        await self.redis.set(key, value, ttl=ttl)

    @staticmethod
    def _build_lock_owner_value(task_id: int) -> str:
        return f"task:{task_id}"

    @staticmethod
    def _parse_lock_owner_task_id(value: str | None) -> int | None:
        if not value or not value.startswith("task:"):
            return None
        task_id_str = value.split(":", 1)[1]
        return int(task_id_str) if task_id_str.isdigit() else None

    @staticmethod
    def _parse_legacy_owner_task_id(value: str | None) -> int | None:
        if not value:
            return None
        return int(value) if value.isdigit() else None

    @staticmethod
    def _task_lock_name(episode_id: int) -> str:
        return TranscriptionStateKeys.TASK_LOCK_NAME.format(episode_id=episode_id)

    @staticmethod
    def _task_lock_key(episode_id: int) -> str:
        return TranscriptionStateKeys.TASK_LOCK.format(episode_id=episode_id)

    @staticmethod
    def _legacy_task_lock_value_key(episode_id: int) -> str:
        return TranscriptionStateKeys.LEGACY_TASK_LOCK_VALUE.format(
            episode_id=episode_id,
        )

    async def _resolve_lock_owner(
        self,
        episode_id: int,
    ) -> tuple[int | None, str | None, str | None]:
        lock_key = self._task_lock_key(episode_id)
        lock_value = await self.redis.get(lock_key)
        owner_task_id = self._parse_lock_owner_task_id(lock_value)
        if owner_task_id is not None:
            return owner_task_id, "task_lock", lock_value

        legacy_key = self._legacy_task_lock_value_key(episode_id)
        legacy_value = await self.redis.get(legacy_key)
        legacy_owner = self._parse_legacy_owner_task_id(legacy_value)
        if legacy_owner is not None:
            return legacy_owner, "legacy_lock_value", lock_value

        return None, None, lock_value

    # === Lock Operations ===

    async def acquire_task_lock(
        self,
        episode_id: int,
        task_id: int,
        expire_seconds: int = 3600,
    ) -> bool:
        """Acquire a lock for processing an episode

        Args:
            episode_id: Episode to lock
            task_id: Task ID that owns the lock
            expire_seconds: Lock expiration time (default 1 hour)

        Returns:
            True if lock acquired, False if already locked

        """
        lock_value = self._build_lock_owner_value(task_id)
        lock_name = self._task_lock_name(episode_id)
        lock_key = self._task_lock_key(episode_id)
        legacy_key = self._legacy_task_lock_value_key(episode_id)

        try:
            acquired = await self.redis.acquire_lock(
                lock_name,
                expire=expire_seconds,
                value=lock_value,
            )
            if acquired:
                await self.redis.sorted_set_add(
                    self._lock_index_key(),
                    str(episode_id),
                    time.time(),
                )
                await self.redis.delete_keys(legacy_key)
                logger.info(
                    "[LOCK] Acquired lock for episode %s, task %s",
                    episode_id,
                    task_id,
                )
                return True

            (
                owner_task_id,
                owner_source,
                raw_lock_value,
            ) = await self._resolve_lock_owner(
                episode_id,
            )
            if owner_task_id == task_id:
                logger.info(
                    "[LOCK] Task %s already owns lock for episode %s",
                    task_id,
                    episode_id,
                )
                return True

            if owner_task_id is not None:
                logger.warning(
                    "[LOCK] Episode %s already locked [owned_by_task=%s source=%s]",
                    episode_id,
                    owner_task_id,
                    owner_source,
                )
                return False

            if raw_lock_value is None:
                logger.warning(
                    "[LOCK] Episode %s lock conflict with no lock key present [owner_unknown_retry_failed]",
                    episode_id,
                )
                return False

            await self.redis.delete_keys(lock_key, legacy_key)
            logger.warning(
                "[LOCK] Episode %s lock had unknown owner metadata, reclaimed and retrying once [owner_unknown_reclaimed]",
                episode_id,
            )
            retry_acquired = await self.redis.acquire_lock(
                lock_name,
                expire=expire_seconds,
                value=lock_value,
            )
            if retry_acquired:
                await self.redis.sorted_set_add(
                    self._lock_index_key(),
                    str(episode_id),
                    time.time(),
                )
                logger.info(
                    "[LOCK] Re-acquired reclaimed lock for episode %s, task %s",
                    episode_id,
                    task_id,
                )
                return True

            owner_after_retry = await self.is_episode_locked(episode_id)
            if owner_after_retry is not None:
                logger.warning(
                    "[LOCK] Episode %s still locked after reclaim retry [owner_unknown_retry_failed owned_by_task=%s]",
                    episode_id,
                    owner_after_retry,
                )
            else:
                logger.warning(
                    "[LOCK] Episode %s lock retry failed and owner remains unknown [owner_unknown_retry_failed]",
                    episode_id,
                )
            return False

        except (redis.exceptions.RedisError, orjson.JSONDecodeError, ValueError, TypeError, OSError) as e:
            logger.error(f"Failed to acquire lock for episode {episode_id}: {e}")
            return False

    async def release_task_lock(self, episode_id: int, task_id: int) -> bool:
        """Release a task lock

        Args:
            episode_id: Episode to unlock
            task_id: Task ID that owns the lock

        Returns:
            True if lock was released, False otherwise

        """
        try:
            lock_key = self._task_lock_key(episode_id)
            legacy_key = self._legacy_task_lock_value_key(episode_id)
            (
                owner_task_id,
                owner_source,
                raw_lock_value,
            ) = await self._resolve_lock_owner(
                episode_id,
            )

            if owner_task_id is not None and owner_task_id != task_id:
                logger.warning(
                    "Cannot release lock for episode %s: owned by task %s (%s), not %s",
                    episode_id,
                    owner_task_id,
                    owner_source,
                    task_id,
                )
                return False

            if owner_task_id is None and raw_lock_value is not None:
                logger.warning(
                    "Releasing lock for episode %s with unknown owner metadata [owner_unknown_reclaimed]",
                    episode_id,
                )

            await self.redis.delete_keys(lock_key, legacy_key)
            await self.redis.sorted_set_remove(self._lock_index_key(), str(episode_id))
            logger.info(
                "[LOCK] Released lock for episode %s, task %s", episode_id, task_id
            )
            return True

        except (redis.exceptions.RedisError, orjson.JSONDecodeError, ValueError, TypeError, OSError) as e:
            logger.error(f"Failed to release lock for episode {episode_id}: {e}")
            return False

    async def is_episode_locked(self, episode_id: int) -> int | None:
        """Check if an episode is locked and return the owning task ID

        Args:
            episode_id: Episode to check

        Returns:
            Task ID if locked, None if not locked

        """
        try:
            owner_task_id, _, _ = await self._resolve_lock_owner(episode_id)
            return owner_task_id
        except (redis.exceptions.RedisError, orjson.JSONDecodeError, ValueError, TypeError):
            return None

    # === Episode-to-Task Mapping ===

    async def set_episode_task(
        self,
        episode_id: int,
        task_id: int,
        ttl_seconds: int = 300,
    ) -> None:
        """Map an episode to its active task ID

        Args:
            episode_id: Episode ID
            task_id: Active transcription task ID
            ttl_seconds: Cache TTL (default 5 minutes)

        """
        key = TranscriptionStateKeys.EPISODE_TASK.format(episode_id=episode_id)
        await self.redis.set(key, str(task_id), ttl=ttl_seconds)
        logger.debug(f"Mapped episode {episode_id} to task {task_id}")

    async def get_episode_task(self, episode_id: int) -> int | None:
        """Get the active task ID for an episode

        Args:
            episode_id: Episode ID

        Returns:
            Task ID if found, None otherwise

        """
        key = TranscriptionStateKeys.EPISODE_TASK.format(episode_id=episode_id)
        task_id_str = await self.redis.get(key)
        return int(task_id_str) if task_id_str else None

    async def clear_episode_task(self, episode_id: int) -> None:
        """Clear the episode-to-task mapping (e.g., when task completes or lock is stale)

        Args:
            episode_id: Episode ID to clear

        """
        key = TranscriptionStateKeys.EPISODE_TASK.format(episode_id=episode_id)
        await self.redis.delete(key)
        logger.debug(f"Cleared episode {episode_id} task mapping")

    # === Progress Caching ===

    async def set_task_progress(
        self,
        task_id: int,
        status: str,
        progress: float,
        message: str,
        current_chunk: int = 0,
        total_chunks: int = 0,
        ttl_seconds: int = 3600,
    ) -> None:
        """Cache task progress for fast polling

        Args:
            task_id: Task ID
            status: Current status enum value
            progress: Progress percentage (0-100)
            message: Status message
            current_chunk: Current chunk being processed
            total_chunks: Total number of chunks
            ttl_seconds: Cache TTL (default 1 hour)

        """
        key = TranscriptionStateKeys.TASK_PROGRESS.format(task_id=task_id)

        progress_data = {
            "task_id": task_id,
            "status": status,
            "progress": progress,
            "message": message,
            "current_chunk": current_chunk,
            "total_chunks": total_chunks,
            "updated_at": datetime.now(UTC).isoformat(),
        }

        await self.redis.set(
            key, orjson.dumps(progress_data).decode("utf-8"), ttl=ttl_seconds
        )
        if status in {"pending", "in_progress"}:
            await self.redis.sorted_set_add(
                self._active_task_index_key(),
                str(task_id),
                time.time() + ttl_seconds,
            )
        else:
            await self.redis.sorted_set_remove(
                self._active_task_index_key(),
                str(task_id),
            )

        # Also update lightweight status
        await self.set_task_status(task_id, status, progress, ttl_seconds)

        # Use throttle to reduce log frequency (log every 5% or every 5 seconds, whichever is longer)
        if _progress_throttle.should_log(task_id, status, progress):
            logger.info(
                f"转录进度 [PROGRESS] Task {task_id}: {progress:.1f}% - {message}"
            )

    async def get_task_progress(self, task_id: int) -> dict[str, Any] | None:
        """Get cached task progress

        Args:
            task_id: Task ID

        Returns:
            Progress data dict or None if not found

        """
        key = TranscriptionStateKeys.TASK_PROGRESS.format(task_id=task_id)
        data = await self.redis.get(key)

        if data:
            try:
                return orjson.loads(data)
            except orjson.JSONDecodeError:
                logger.warning(f"Invalid cached progress data for task {task_id}")
        return None

    async def clear_task_progress(self, task_id: int) -> None:
        """Clear cached task progress

        Args:
            task_id: Task ID to clear

        """
        # Clear progress data
        progress_key = TranscriptionStateKeys.TASK_PROGRESS.format(task_id=task_id)
        await self.redis.delete(progress_key)
        await self.redis.sorted_set_remove(self._active_task_index_key(), str(task_id))

        # Clear status data
        status_key = TranscriptionStateKeys.TASK_STATUS.format(task_id=task_id)
        await self.redis.delete(status_key)

        logger.debug(f"Cleared progress cache for task {task_id}")

    # === Status Summary ===

    async def set_task_status(
        self,
        task_id: int,
        status: str,
        progress: float,
        ttl_seconds: int = 900,
    ) -> None:
        """Set lightweight task status for dashboard queries

        Args:
            task_id: Task ID
            status: Current status
            progress: Progress percentage
            ttl_seconds: Cache TTL (default 15 minutes)

        """
        key = TranscriptionStateKeys.TASK_STATUS.format(task_id=task_id)

        status_data = {
            "status": status,
            "progress": progress,
            "updated_at": datetime.now(UTC).isoformat(),
        }

        await self.redis.set(
            key, orjson.dumps(status_data).decode("utf-8"), ttl=ttl_seconds
        )

    async def get_task_status(self, task_id: int) -> dict[str, Any] | None:
        """Get lightweight task status

        Args:
            task_id: Task ID

        Returns:
            Status data dict or None if not found

        """
        key = TranscriptionStateKeys.TASK_STATUS.format(task_id=task_id)
        data = await self.redis.get(key)

        if data:
            try:
                return orjson.loads(data)
            except orjson.JSONDecodeError:
                logger.warning(f"Invalid cached status data for task {task_id}")
        return None

    # === Cleanup ===

    async def clear_task_state(self, task_id: int, episode_id: int) -> None:
        """Clear all Redis state for a completed task

        Args:
            task_id: Task ID
            episode_id: Episode ID

        """
        try:
            # Release lock
            await self.release_task_lock(episode_id, task_id)

            # Clear episode mapping
            episode_key = TranscriptionStateKeys.EPISODE_TASK.format(
                episode_id=episode_id
            )
            progress_key = TranscriptionStateKeys.TASK_PROGRESS.format(task_id=task_id)
            status_key = TranscriptionStateKeys.TASK_STATUS.format(task_id=task_id)
            dispatched_key = f"podcast:transcription:dispatched:{task_id}"
            await self.redis.delete_keys(
                episode_key,
                progress_key,
                status_key,
                dispatched_key,
            )

            logger.info(
                f"[STATE] Cleared Redis state for task {task_id}, episode {episode_id}"
            )

        except (redis.exceptions.RedisError, orjson.JSONDecodeError, ValueError, TypeError, OSError) as e:
            logger.error(f"Failed to clear state for task {task_id}: {e}")

    async def fail_task_state(
        self,
        task_id: int,
        episode_id: int,
        error_message: str,
    ) -> None:
        """Mark task as failed and clear locks

        Args:
            task_id: Task ID
            episode_id: Episode ID
            error_message: Error message

        """
        # Update progress to failed state (short TTL)
        await self.set_task_progress(
            task_id,
            "failed",
            0,
            error_message,
            ttl_seconds=300,  # 5 minutes
        )

        # Clear locks immediately
        await self.release_task_lock(episode_id, task_id)

        # Clear dispatched flag to allow re-processing if needed
        dispatched_key = f"podcast:transcription:dispatched:{task_id}"
        await self.redis.delete_keys(dispatched_key)
        logger.debug(f"Cleared dispatched flag for failed task {task_id}")

        logger.error(f"[STATE] Task {task_id} failed: {error_message}")

    # === Batch Operations ===

    async def get_active_tasks_count(self) -> int:
        """Get count of tasks currently in progress (from Redis)

        Returns:
            Number of active tasks

        """
        try:
            await self.redis.sorted_set_remove_by_score(
                self._active_task_index_key(),
                "-inf",
                time.time(),
            )
            return await self.redis.sorted_set_cardinality(
                self._active_task_index_key()
            )
        except (redis.exceptions.RedisError, orjson.JSONDecodeError, ValueError, TypeError, OSError) as e:
            logger.error(f"Failed to get active tasks count: {e}")
            return 0

    async def cleanup_stale_locks(self, max_age_seconds: int = 7200) -> int:
        """Cleanup stale locks older than max_age_seconds (2 hours default)

        Args:
            max_age_seconds: Maximum age of locks to keep

        Returns:
            Number of locks cleaned up

        """
        try:
            stale_episode_ids = await self.redis.sorted_set_range_by_score(
                self._lock_index_key(),
                "-inf",
                time.time() - max_age_seconds,
            )

            cleaned = 0
            for episode_id_str in stale_episode_ids:
                if not episode_id_str.isdigit():
                    await self.redis.sorted_set_remove(
                        self._lock_index_key(),
                        episode_id_str,
                    )
                    continue

                episode_id = int(episode_id_str)
                lock_key = self._task_lock_key(episode_id)
                ttl = await self.redis.get_ttl(lock_key)
                if ttl in (-2,) or (ttl != -1 and ttl <= max_age_seconds):
                    await self.redis.sorted_set_remove(
                        self._lock_index_key(),
                        episode_id_str,
                    )
                    continue

                deleted = await self.redis.delete_keys(
                    lock_key,
                    self._legacy_task_lock_value_key(episode_id),
                )
                await self.redis.sorted_set_remove(
                    self._lock_index_key(), episode_id_str
                )
                if deleted > 0:
                    cleaned += 1

            if cleaned > 0:
                logger.info(f"[STATE] Cleaned up {cleaned} stale locks")

            return cleaned

        except (redis.exceptions.RedisError, orjson.JSONDecodeError, ValueError, TypeError, OSError) as e:
            logger.error(f"Failed to cleanup stale locks: {e}")
            return 0


# Singleton instance
_state_manager = None


async def get_transcription_state_manager() -> TranscriptionStateManager:
    """Get singleton state manager instance"""
    global _state_manager
    if _state_manager is None:
        _state_manager = TranscriptionStateManager()
    return _state_manager
