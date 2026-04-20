from __future__ import annotations

import fnmatch

import pytest

from app.domains.podcast.transcription_state import TranscriptionStateManager


class _FakeRedisClient:
    def __init__(self) -> None:
        self.store: dict[str, str] = {}
        self.ttl_map: dict[str, int] = {}
        self.deleted_calls: list[tuple[str, ...]] = []
        self.sorted_sets: dict[str, dict[str, float]] = {}

    async def get(self, key: str) -> str | None:
        return self.store.get(key)

    async def delete(self, *keys: str) -> int:
        self.deleted_calls.append(tuple(keys))
        deleted = 0
        for key in keys:
            if key in self.store:
                deleted += 1
                del self.store[key]
            self.ttl_map.pop(key, None)
        return deleted

    async def scan_iter(self, match: str):
        keys = [key for key in self.store if fnmatch.fnmatch(key, match)]
        for key in keys:
            yield key

    async def ttl(self, key: str) -> int:
        return self.ttl_map.get(key, -2)


class _FakePodcastRedis:
    def __init__(self, client: _FakeRedisClient) -> None:
        self.client = client
        self.acquire_lock_calls: list[tuple[str, int, str]] = []
        self.acquire_lock_results: list[bool] = []

    async def acquire_lock(
        self, lock_name: str, expire: int = 300, value: str = "1"
    ) -> bool:
        self.acquire_lock_calls.append((lock_name, expire, value))
        key = f"podcast:lock:{lock_name}"

        if self.acquire_lock_results:
            result = self.acquire_lock_results.pop(0)
            if result:
                self.client.store[key] = value
                self.client.ttl_map[key] = expire
            return result

        if key in self.client.store:
            return False

        self.client.store[key] = value
        self.client.ttl_map[key] = expire
        return True

    async def get(self, key: str) -> str | None:
        return await self.client.get(key)

    async def set(self, key: str, value: str, ttl: int = 3600) -> bool:
        self.client.store[key] = value
        self.client.ttl_map[key] = ttl
        return True

    async def delete(self, key: str) -> bool:
        return bool(await self.client.delete(key))

    async def delete_keys(self, *keys: str) -> int:
        return await self.client.delete(*keys)

    async def scan_keys(self, pattern: str) -> list[str]:
        return [key async for key in self.client.scan_iter(match=pattern)]

    async def get_ttl(self, key: str) -> int:
        return await self.client.ttl(key)

    async def sorted_set_add(self, key: str, member: str, score: float) -> int:
        bucket = self.client.sorted_sets.setdefault(key, {})
        is_new = member not in bucket
        bucket[member] = score
        return 1 if is_new else 0

    async def sorted_set_remove(self, key: str, *members: str) -> int:
        bucket = self.client.sorted_sets.setdefault(key, {})
        removed = 0
        for member in members:
            if member in bucket:
                removed += 1
                del bucket[member]
        return removed

    async def sorted_set_cardinality(self, key: str) -> int:
        return len(self.client.sorted_sets.get(key, {}))

    async def sorted_set_range_by_score(
        self, key: str, min_score: float | str, max_score: float | str
    ) -> list[str]:
        bucket = self.client.sorted_sets.get(key, {})
        lower = float("-inf") if min_score == "-inf" else float(min_score)
        upper = float("inf") if max_score == "+inf" else float(max_score)
        return [
            member
            for member, score in sorted(bucket.items(), key=lambda item: item[1])
            if lower <= score <= upper
        ]

    async def sorted_set_remove_by_score(
        self, key: str, min_score: float | str, max_score: float | str
    ) -> int:
        members = await self.sorted_set_range_by_score(key, min_score, max_score)
        return await self.sorted_set_remove(key, *members)


def _build_state_manager() -> tuple[TranscriptionStateManager, _FakePodcastRedis]:
    manager = TranscriptionStateManager()
    client = _FakeRedisClient()
    fake_redis = _FakePodcastRedis(client)
    manager.redis = fake_redis
    return manager, fake_redis


@pytest.mark.asyncio
async def test_is_episode_locked_reads_new_owner_format() -> None:
    manager, fake_redis = _build_state_manager()
    fake_redis.client.store["podcast:lock:transcription:episode:60329"] = "task:42"

    locked_task_id = await manager.is_episode_locked(60329)

    assert locked_task_id == 42


@pytest.mark.asyncio
async def test_is_episode_locked_falls_back_to_legacy_lock_value() -> None:
    manager, fake_redis = _build_state_manager()
    fake_redis.client.store["podcast:lock:transcription:episode:60329"] = "1"
    fake_redis.client.store["podcast:transcription:lock_value:60329"] = "77"

    locked_task_id = await manager.is_episode_locked(60329)

    assert locked_task_id == 77


@pytest.mark.asyncio
async def test_acquire_task_lock_reclaims_unknown_owner_and_retries_once() -> None:
    manager, fake_redis = _build_state_manager()
    lock_key = "podcast:lock:transcription:episode:60329"
    fake_redis.client.store[lock_key] = "1"
    fake_redis.client.ttl_map[lock_key] = 60
    fake_redis.acquire_lock_results = [False, True]

    acquired = await manager.acquire_task_lock(60329, 88, expire_seconds=120)

    assert acquired is True
    assert fake_redis.client.store[lock_key] == "task:88"
    assert fake_redis.acquire_lock_calls == [
        ("transcription:episode:60329", 120, "task:88"),
        ("transcription:episode:60329", 120, "task:88"),
    ]


@pytest.mark.asyncio
async def test_release_task_lock_rejects_foreign_owner() -> None:
    manager, fake_redis = _build_state_manager()
    fake_redis.client.store["podcast:lock:transcription:episode:60329"] = "task:99"

    released = await manager.release_task_lock(60329, 100)

    assert released is False
    assert "podcast:lock:transcription:episode:60329" in fake_redis.client.store


@pytest.mark.asyncio
async def test_release_task_lock_cleans_legacy_key_for_matching_owner() -> None:
    manager, fake_redis = _build_state_manager()
    fake_redis.client.store["podcast:lock:transcription:episode:60329"] = "task:11"
    fake_redis.client.store["podcast:transcription:lock_value:60329"] = "11"

    released = await manager.release_task_lock(60329, 11)

    assert released is True
    assert "podcast:lock:transcription:episode:60329" not in fake_redis.client.store
    assert "podcast:transcription:lock_value:60329" not in fake_redis.client.store


@pytest.mark.asyncio
async def test_get_active_tasks_count_reads_sorted_set_index() -> None:
    manager, _fake_redis = _build_state_manager()

    await manager.set_task_progress(41, "in_progress", 35.0, "working", ttl_seconds=120)

    assert await manager.get_active_tasks_count() == 1

    await manager.clear_task_progress(41)

    assert await manager.get_active_tasks_count() == 0


@pytest.mark.asyncio
async def test_cleanup_stale_locks_uses_indexed_episode_ids() -> None:
    manager, fake_redis = _build_state_manager()
    lock_key = "podcast:lock:transcription:episode:60329"
    legacy_key = "podcast:transcription:lock_value:60329"
    fake_redis.client.store[lock_key] = "task:42"
    fake_redis.client.store[legacy_key] = "42"
    fake_redis.client.ttl_map[lock_key] = -1
    fake_redis.client.sorted_sets["podcast:transcription:lock_index"] = {"60329": 0.0}

    cleaned = await manager.cleanup_stale_locks(max_age_seconds=7200)

    assert cleaned == 1
    assert lock_key not in fake_redis.client.store
    assert legacy_key not in fake_redis.client.store
    assert fake_redis.client.sorted_sets["podcast:transcription:lock_index"] == {}
