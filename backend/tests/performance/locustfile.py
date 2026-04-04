"""
Load Testing Configuration for Locust

Tests system performance under concurrent user load.
Run with:
  PERF_BEARER_TOKEN=<token> locust -f tests/performance/locustfile.py --host=http://localhost:8000
"""

import os
import random

from locust import HttpUser, between, task


class PodcastUser(HttpUser):
    """
    Simulates a typical podcast user interacting with the application.

    Wait time between tasks: 1-3 seconds (simulates real user behavior)
    """

    wait_time = between(1, 3)

    def on_start(self):
        """Called when a user starts. Login and get initial data."""
        token = os.getenv("PERF_BEARER_TOKEN", "")
        self.auth_headers = {"Authorization": f"Bearer {token}"} if token else {}
        self.client.get("/api/v1/health")

    @task(3)
    def view_podcast_list(self):
        """View podcast subscription list (most common action)"""
        self.client.get("/api/v1/podcasts/subscriptions", headers=self.auth_headers)

    @task(2)
    def view_episodes(self):
        """View episodes for a subscription"""
        # In a real test, you'd get actual subscription IDs
        self.client.get(
            "/api/v1/podcasts/episodes?subscription_id=1",
            headers=self.auth_headers,
        )

    @task(1)
    def search_podcasts(self):
        """Search for podcasts"""
        queries = ["technology", "news", "comedy", "science", "history"]
        query = random.choice(queries)
        self.client.get(f"/api/v1/podcasts/search?q={query}", headers=self.auth_headers)

    @task(1)
    def get_user_stats(self):
        """Get user statistics"""
        self.client.get("/api/v1/podcasts/stats", headers=self.auth_headers)


class AdminUser(HttpUser):
    """
    Simulates an admin user with different usage patterns.
    """

    wait_time = between(2, 5)

    @task
    def view_metrics(self):
        """View performance metrics (internal endpoint)"""
        self.client.get("/metrics/summary")


# Stress test user - more aggressive
class StressTestUser(HttpUser):
    """
    Simulates stress test conditions with rapid requests.
    """

    wait_time = between(0.1, 0.5)  # Very short wait time

    def on_start(self):
        token = os.getenv("PERF_BEARER_TOKEN", "")
        self.auth_headers = {"Authorization": f"Bearer {token}"} if token else {}

    @task
    def rapid_podcast_list_requests(self):
        """Rapidly request podcast list"""
        self.client.get("/api/v1/podcasts/subscriptions", headers=self.auth_headers)

    @task
    def rapid_search_requests(self):
        """Rapidly search"""
        self.client.get("/api/v1/podcasts/search?q=test", headers=self.auth_headers)
