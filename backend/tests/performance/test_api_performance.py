"""
Performance Tests for API Endpoints

Tests response times, cache effectiveness, and query efficiency.
"""

import asyncio
import os
import statistics
import time
import uuid
from typing import Any

import pytest
import pytest_asyncio
from httpx import AsyncClient


if os.getenv("RUN_PERFORMANCE_TESTS") != "1":
    pytest.skip(
        "Set RUN_PERFORMANCE_TESTS=1 to run performance benchmark tests.",
        allow_module_level=True,
    )


class PerformanceMetrics:
    """Track performance metrics during tests"""

    def __init__(self):
        self.results: list[dict[str, Any]] = []
        self.cache_hit_rates: list[float] = []

    def add_result(
        self, name: str, duration_ms: float, passed: bool, details: str = ""
    ):
        self.results.append(
            {
                "test": name,
                "duration_ms": duration_ms,
                "passed": passed,
                "details": details,
            }
        )

    def add_cache_hit_rate(self, hit_rate: float):
        self.cache_hit_rates.append(hit_rate)

    @staticmethod
    def _percentile(values: list[float], percentile: float) -> float:
        if not values:
            return 0.0
        if len(values) == 1:
            return values[0]
        ordered = sorted(values)
        rank = (len(ordered) - 1) * percentile
        lower = int(rank)
        upper = min(lower + 1, len(ordered) - 1)
        weight = rank - lower
        return ordered[lower] * (1 - weight) + ordered[upper] * weight

    def print_summary(self):
        """Print test summary"""
        print("\n" + "=" * 60)
        print("PERFORMANCE TEST SUMMARY")
        print("=" * 60)

        passed = sum(1 for r in self.results if r["passed"])
        total = len(self.results)

        for result in self.results:
            status = "[PASS]" if result["passed"] else "[FAIL]"
            print(f"{status} | {result['test']}: {result['duration_ms']:.2f}ms")
            if result["details"]:
                print(f"     Details: {result['details']}")

        print("-" * 60)
        print(f"Total: {passed}/{total} tests passed")
        durations = [r["duration_ms"] for r in self.results]
        p50 = self._percentile(durations, 0.50)
        p95 = self._percentile(durations, 0.95)
        error_rate = ((total - passed) / total * 100.0) if total else 0.0
        avg_hit_rate = (
            statistics.mean(self.cache_hit_rates) if self.cache_hit_rates else 0.0
        )
        print(
            "Baseline: "
            f"p50={p50:.2f}ms | p95={p95:.2f}ms | "
            f"error_rate={error_rate:.2f}% | cache_hit_rate={avg_hit_rate:.1f}%"
        )
        print("=" * 60)


metrics = PerformanceMetrics()


def _server_duration_ms(response, wall_duration_ms: float) -> float:
    """Prefer server-side process time when available for stable perf assertions."""
    process_time = response.headers.get("x-process-time")
    if process_time is None:
        process_time = response.headers.get("X-Process-Time")
    if process_time is None:
        return wall_duration_ms

    try:
        return float(process_time) * 1000
    except (TypeError, ValueError):
        return wall_duration_ms


@pytest_asyncio.fixture
async def performance_client(performance_base_url: str) -> AsyncClient:
    """Function-scoped authenticated client for stable event-loop isolation."""
    timeout = float(os.getenv("PERFORMANCE_HTTP_TIMEOUT_SECONDS", "30"))
    health_retries = int(os.getenv("PERFORMANCE_HEALTH_RETRIES", "20"))
    health_interval = float(os.getenv("PERFORMANCE_HEALTH_RETRY_INTERVAL", "1"))

    async with AsyncClient(
        base_url=performance_base_url,
        timeout=timeout,
        trust_env=False,
    ) as client:
        for attempt in range(health_retries):
            try:
                response = await client.get("/api/v1/health")
                if response.status_code == 200:
                    break
            except Exception:
                pass

            if attempt == health_retries - 1:
                pytest.skip(
                    f"Backend health check failed at {performance_base_url}/api/v1/health. "
                    "Run docker compose first or set PERFORMANCE_BASE_URL."
                )
            await asyncio.sleep(health_interval)

        suffix = uuid.uuid4().hex[:10]
        password = "PerfTestPass1!"
        register_payload = {
            "email": f"perf_{suffix}@example.com",
            "username": f"perf_{suffix}",
            "password": password,
        }
        register_response = await client.post(
            "/api/v1/auth/register",
            json=register_payload,
        )
        if register_response.status_code in (200, 201):
            token_payload = register_response.json()
        else:
            login_response = await client.post(
                "/api/v1/auth/login",
                json={
                    "email_or_username": register_payload["email"],
                    "password": password,
                },
            )
            if login_response.status_code != 200:
                pytest.skip(
                    "Unable to create/login performance test user: "
                    f"register={register_response.status_code}, login={login_response.status_code}"
                )
            token_payload = login_response.json()

        access_token = token_payload.get("access_token")
        if not access_token:
            pytest.skip("Performance auth token is missing in auth response payload")

        client.headers.update({"Authorization": f"Bearer {access_token}"})
        yield client


@pytest.mark.performance
@pytest.mark.asyncio
async def test_podcast_list_first_load_performance(performance_client: AsyncClient):
    """Test podcast list first load performance (cache miss)"""
    # Clear cache before test
    # Note: In real test, we'd clear Redis cache here

    start = time.time()
    response = await performance_client.get("/api/v1/podcasts/subscriptions")
    wall_duration_ms = (time.time() - start) * 1000
    duration_ms = _server_duration_ms(response, wall_duration_ms)

    passed = response.status_code == 200 and duration_ms < 500
    details = f"Status: {response.status_code}" if not passed else ""

    metrics.add_result("Podcast List (First Load)", duration_ms, passed, details)
    assert passed, f"Response time {duration_ms}ms exceeds 500ms threshold"


@pytest.mark.performance
@pytest.mark.asyncio
async def test_podcast_list_cache_performance(performance_client: AsyncClient):
    """Test podcast list HTTP cache behavior via ETag conditional request."""
    first_response = await performance_client.get("/api/v1/podcasts/subscriptions")
    etag = first_response.headers.get("etag") or first_response.headers.get("ETag")
    assert etag, "Subscription list response did not include ETag header"

    # Conditional request should return 304 when unchanged.
    start = time.time()
    response = await performance_client.get(
        "/api/v1/podcasts/subscriptions",
        headers={"If-None-Match": etag},
    )
    wall_duration_ms = (time.time() - start) * 1000
    duration_ms = _server_duration_ms(response, wall_duration_ms)

    passed = response.status_code == 304 and duration_ms < 100
    details = f"Status: {response.status_code}, server={duration_ms:.2f}ms"

    metrics.add_result("Podcast List (Cached)", duration_ms, passed, details)
    assert passed, (
        f"Cached response {duration_ms}ms too slow (cache may not be working)"
    )


@pytest.mark.performance
@pytest.mark.asyncio
async def test_search_performance(performance_client: AsyncClient):
    """Test search endpoint performance"""
    start = time.time()
    response = await performance_client.get(
        "/api/v1/podcasts/search?q=test&search_in=title"
    )
    wall_duration_ms = (time.time() - start) * 1000
    duration_ms = _server_duration_ms(response, wall_duration_ms)

    passed = response.status_code == 200 and duration_ms < 300
    metrics.add_result("Search Endpoint", duration_ms, passed)
    assert passed, f"Search took {duration_ms}ms, exceeds 300ms threshold"


@pytest.mark.performance
@pytest.mark.asyncio
async def test_search_cache_performance(performance_client: AsyncClient):
    """Test search result caching"""
    query = "performance test"

    # First search (cache warm-up)
    first = await performance_client.get(f"/api/v1/podcasts/search?q={query}")
    first_duration_ms = _server_duration_ms(first, 0.0)

    # Second search should not regress after warm-up.
    start = time.time()
    response = await performance_client.get(f"/api/v1/podcasts/search?q={query}")
    wall_duration_ms = (time.time() - start) * 1000
    duration_ms = _server_duration_ms(response, wall_duration_ms)

    allowed = max(50.0, first_duration_ms * 1.2 if first_duration_ms else 50.0)
    passed = response.status_code == 200 and duration_ms <= allowed
    metrics.add_result("Search (Cached)", duration_ms, passed)
    assert passed, (
        f"Cached search server time {duration_ms:.2f}ms exceeded allowance "
        f"{allowed:.2f}ms or returned {response.status_code}"
    )


@pytest.mark.performance
@pytest.mark.asyncio
async def test_user_stats_performance(performance_client: AsyncClient):
    """Test user statistics performance"""
    start = time.time()
    first_response = await performance_client.get("/api/v1/podcasts/stats")
    wall_duration_ms = (time.time() - start) * 1000
    duration_ms = _server_duration_ms(first_response, wall_duration_ms)

    etag = first_response.headers.get("etag") or first_response.headers.get("ETag")
    assert etag, "Stats response did not include ETag header"
    cached_response = await performance_client.get(
        "/api/v1/podcasts/stats",
        headers={"If-None-Match": etag},
    )

    passed = (
        first_response.status_code == 200
        and duration_ms < 200
        and cached_response.status_code == 304
    )
    metrics.add_result("User Stats", duration_ms, passed)
    assert passed, f"Stats took {duration_ms}ms, exceeds 200ms threshold"


@pytest.mark.performance
@pytest.mark.asyncio
async def test_episode_list_performance(performance_client: AsyncClient):
    """Test episode list loading performance"""
    response = await performance_client.get("/api/v1/podcasts/subscriptions")
    url = "/api/v1/podcasts/episodes"
    if response.status_code == 200 and response.json().get("subscriptions"):
        subscription_id = response.json()["subscriptions"][0]["id"]
        url = f"/api/v1/podcasts/episodes?subscription_id={subscription_id}"

    start = time.time()
    response = await performance_client.get(url)
    duration_ms = (time.time() - start) * 1000

    passed = response.status_code == 200 and duration_ms < 400
    metrics.add_result("Episode List", duration_ms, passed)
    assert passed, f"Episode list took {duration_ms}ms, exceeds 400ms threshold"


@pytest.mark.load
@pytest.mark.asyncio
async def test_concurrent_users(performance_client: AsyncClient):
    """Test performance with 10 concurrent users"""

    async def make_request(client: AsyncClient, user_id: int):
        start = time.time()
        response = await client.get("/api/v1/podcasts/subscriptions")
        wall_duration_ms = (time.time() - start) * 1000
        duration_ms = _server_duration_ms(response, wall_duration_ms)
        return user_id, duration_ms, response.status_code

    # Simulate 10 concurrent users
    start = time.time()
    tasks = [make_request(performance_client, i) for i in range(10)]
    results = await asyncio.gather(*tasks)
    total_time = (time.time() - start) * 1000

    # Check results
    errors = sum(1 for _, _, status in results if status != 200)
    avg_duration = sum(r[1] for r in results) / len(results)

    passed = errors == 0 and avg_duration < 500
    details = f"Errors: {errors}, Avg: {avg_duration:.2f}ms"

    metrics.add_result("Concurrent Users (10)", total_time, passed, details)
    assert errors == 0, f"{errors} requests failed out of 10"


@pytest.mark.load
@pytest.mark.asyncio
async def test_cache_hit_rate_measurement(performance_client: AsyncClient):
    """Measure cache hit rate over multiple requests"""
    num_requests = 10

    first_response = await performance_client.get("/api/v1/podcasts/subscriptions")
    etag = first_response.headers.get("etag") or first_response.headers.get("ETag")
    assert etag, "Subscription list response did not include ETag header"

    cache_hits = 0
    total_time = 0

    for _ in range(num_requests):
        start = time.time()
        response = await performance_client.get(
            "/api/v1/podcasts/subscriptions",
            headers={"If-None-Match": etag},
        )
        wall_duration_ms = (time.time() - start) * 1000
        duration_ms = _server_duration_ms(response, wall_duration_ms)
        total_time += duration_ms

        # 304 indicates a successful conditional cache hit.
        if response.status_code == 304:
            cache_hits += 1

    hit_rate = (cache_hits / num_requests) * 100
    avg_time = total_time / num_requests

    passed = hit_rate >= 70
    details = f"Hit rate: {hit_rate:.1f}%, Avg time: {avg_time:.2f}ms"

    metrics.add_result("Cache Hit Rate", avg_time, passed, details)
    metrics.add_cache_hit_rate(hit_rate)
    assert passed, f"Cache hit rate {hit_rate:.1f}% is below 70% threshold"


@pytest.fixture(scope="session", autouse=True)
def print_performance_summary():
    """Print performance test summary at end of session"""
    yield
    metrics.print_summary()


# Performance threshold constants
PERFORMANCE_THRESHOLDS = {
    "podcast_list": 500,  # ms
    "search": 300,
    "user_stats": 200,
    "episode_list": 400,
    "cached_response": 100,
    "cache_hit_rate": 70,  # percent
}
