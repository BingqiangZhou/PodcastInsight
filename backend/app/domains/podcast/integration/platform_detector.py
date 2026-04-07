"""Podcast Platform Detection Utility

Detects and validates podcast platform sources (Xiaoyuzhou, Ximalaya, etc.)
"""

import logging
import re
from urllib.parse import urlparse

logger = logging.getLogger(__name__)


class PodcastPlatform:
    """Podcast platform identifiers"""

    XIAOYUZHOU = "xiaoyuzhou"
    XIMALAYA = "ximalaya"
    GENERIC = "generic"


class PlatformDetector:
    """Detect podcast platform from feed URL"""

    # Platform URL patterns
    PLATFORM_PATTERNS = {
        PodcastPlatform.XIAOYUZHOU: [
            r"xiaoyuzhou\.fm",
            r"xiaoyuzhoufm\.com",
        ],
        PodcastPlatform.XIMALAYA: [
            r"ximalaya\.com",
            r"xmcdn\.com",
        ],
    }

    @classmethod
    def detect_platform(cls, feed_url: str) -> str:
        """Detect platform from feed URL

        Args:
            feed_url: RSS feed URL

        Returns:
            Platform identifier (xiaoyuzhou, ximalaya, or generic)

        """
        try:
            parsed = urlparse(feed_url)
            hostname = parsed.hostname or ""

            for platform, patterns in cls.PLATFORM_PATTERNS.items():
                for pattern in patterns:
                    if re.search(pattern, hostname, re.IGNORECASE):
                        return platform

            return PodcastPlatform.GENERIC

        except ValueError as exc:
            logger.debug("Platform detection failed for %r: %s", feed_url[:80], exc)
            return PodcastPlatform.GENERIC

    @classmethod
    def validate_platform_url(
        cls, feed_url: str, platform: str
    ) -> tuple[bool, str | None]:
        """Validate URL format for specific platform

        Args:
            feed_url: RSS feed URL
            platform: Expected platform

        Returns:
            Tuple of (is_valid, error_message)

        """
        if platform == PodcastPlatform.XIMALAYA:
            return cls._validate_ximalaya_url(feed_url)
        if platform == PodcastPlatform.XIAOYUZHOU:
            return cls._validate_xiaoyuzhou_url(feed_url)
        return True, None

    @classmethod
    def _validate_ximalaya_url(cls, url: str) -> tuple[bool, str | None]:
        """Validate Ximalaya RSS feed URL format"""
        # Expected format: https://www.ximalaya.com/album/{album_id}.xml
        pattern = r"https?://(?:www\.)?ximalaya\.com/album/\d+\.xml"
        if re.match(pattern, url, re.IGNORECASE):
            return True, None

        # Also accept generic ximalaya RSS URLs
        if "ximalaya.com" in url.lower() and (".xml" in url or "rss" in url.lower()):
            return True, None

        return (
            False,
            "Invalid Ximalaya RSS URL format. Expected: https://www.ximalaya.com/album/{album_id}.xml",
        )

    @classmethod
    def _validate_xiaoyuzhou_url(cls, url: str) -> tuple[bool, str | None]:
        """Validate Xiaoyuzhou RSS feed URL format"""
        if "xiaoyuzhou" in url.lower() and (".xml" in url or "rss" in url.lower()):
            return True, None
        return False, "Invalid Xiaoyuzhou RSS URL format"
