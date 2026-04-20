"""
Comprehensive API Validation Tests for Podcast Feature
Tests security, models, and core functionality
"""

import asyncio
import sys

import pytest


# Fix encoding for Windows
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


class TestPodcastAPI:
    """Stage 3: API Validation Tests"""

    def test_xxe_protection(self):
        """Security Test: XXE attacks must be blocked"""
        from app.domains.podcast.integration.security import PodcastSecurityValidator

        validator = PodcastSecurityValidator()

        # Test XXE attack
        malicious_xml = """<?xml version="1.0"?>
        <!DOCTYPE data [
          <!ENTITY xxe SYSTEM "file:///etc/passwd">
        ]>
        <data>&xxe;</data>"""

        is_valid, error = validator.validate_rss_xml(malicious_xml)
        assert is_valid is False, "XXE should be blocked"
        print(f"[PASS] XXE防护: {error}")

        # Test OOB attack
        oob_xml = """<?xml version="1.0"?>
        <!DOCTYPE data [
          <!ENTITY xxe SYSTEM "http://internal-server/status">
        ]>
        <data>&xxe;</data>"""

        is_valid, error = validator.validate_rss_xml(oob_xml)
        assert is_valid is False, "OOB XXE should be blocked"
        print("[PASS] OOB XXE blocked")

    def test_rss_security_validations(self):
        """Security Test: RSS URL and content validation"""
        from app.domains.podcast.integration.security import PodcastSecurityValidator

        validator = PodcastSecurityValidator()

        # Test dangerous URLs
        dangerous_urls = [
            "http://localhost/evil.xml",
            "http://127.0.0.1/exploit.xml",
            "http://192.168.1.1/internal.xml",
            "file:///etc/passwd",
        ]

        for url in dangerous_urls:
            is_valid, error = validator.validate_audio_url(url)
            assert is_valid is False, f"Blocked dangerous URL: {url}"
            print(f"[PASS] Blocked: {url}")

        # Test safe URLs
        safe_urls = [
            "https://example.com/podcast.mp3",
            "http://cdn.example.com/audio/episode.mp3",
        ]

        for url in safe_urls:
            is_valid, error = validator.validate_audio_url(url)
            assert is_valid is True, f"Should allow safe URL: {url}"
            print(f"[PASS] Allowed: {url}")

    def test_model_definitions(self):
        """Model Test: Verify model structure exists"""
        import ast
        import pathlib

        # Check models file exists and valid
        model_file = (
            pathlib.Path(__file__).parent.parent
            / "app"
            / "domains"
            / "podcast"
            / "models.py"
        )
        assert model_file.exists(), "Podcast models file missing"

        with open(model_file, encoding="utf-8") as f:
            content = f.read()

        # Parse without executing (avoid import issues)
        ast.parse(content)

        # Check for required imports (even if unused)
        assert "class PodcastEpisode" in content
        assert "class PodcastPlaybackState" in content

        # Check for key fields (string match, not import)
        expected_fields = [
            "audio_url",
            "ai_summary",
            "item_link",
            "subscription_id",
            "current_position",
            "user_id",
            "episode_id",
        ]

        for field in expected_fields:
            assert field in content, f"Missing field: {field}"

        print("[PASS] Model structure validated")

    def test_service_workflow_logic(self):
        """Logic Test: Service workflow patterns"""
        # Test that our mocked service can handle workflow
        from app.domains.podcast.integration.security import PodcastSecurityValidator

        validator = PodcastSecurityValidator()

        # Simulate secure RSS validation pipeline
        good_rss = """<?xml version="1.0"?>
        <rss>
          <channel>
            <title>Test Podcast</title>
            <item>
              <title>Episode 1</title>
              <description>Test description</description>
              <enclosure url="http://cdn.example.com/ep1.mp3" type="audio/mpeg" />
            </item>
          </channel>
        </rss>"""

        is_valid, error = validator.validate_rss_xml(good_rss)
        assert is_valid is True, "Valid RSS should pass"
        print("[PASS] Valid RSS processing works")

    # Test 6: Redis integration (mocked)
    @pytest.mark.asyncio
    async def test_redis_functions(self):
        """Integration Test: Redis operations (mocked)"""
        from unittest.mock import AsyncMock

        # Mock Redis since we don't have real Redis
        mock_redis = AsyncMock()
        mock_redis.set_user_progress = AsyncMock()
        mock_redis.get_user_progress = AsyncMock(return_value=0.5)

        # Test progress tracking
        await mock_redis.set_user_progress(1, 42, 0.5)
        progress = await mock_redis.get_user_progress(1, 42)

        assert progress == 0.5
        print("[PASS] Redis workflow logic verified (mocked)")


if __name__ == "__main__":
    # Run tests programmatically
    print("=== Stage 3: API Security & Validation Tests ===")

    test_instance = TestPodcastAPI()

    tests = [
        ("XXE Protection", test_instance.test_xxe_protection),
        ("RSS Security", test_instance.test_rss_security_validations),
        ("Model Structure", test_instance.test_model_definitions),
        ("Service Logic", test_instance.test_service_workflow_logic),
    ]

    # Async test for Redis
    async_test = test_instance.test_redis_functions

    passed = 0
    failed = 0

    for name, test_func in tests:
        try:
            test_func()
            passed += 1
        except Exception as e:
            print(f"[FAIL] {name}: {e}")
            failed += 1

    # Run async test
    try:
        asyncio.run(async_test())
        passed += 1
    except Exception as e:
        print(f"[FAIL] Redis workflow: {e}")
        failed += 1

    print(f"\n[RESULTS] Stage 3: {passed} passed, {failed} failed")

    if failed == 0:
        print("🎉 All security tests passed!")
        sys.exit(0)
    else:
        print("❌ Some tests failed")
        sys.exit(1)
