"""Secure RSS Parser for Podcast Subscriptions

This module provides secure RSS/Atom feed parsing with explicit XXE/SSRF protection
and follows the architecture defined in security.py.

**Flow: RSS URL → Security Check → Safe Parse → Database Model**
"""

import logging
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

import aiohttp
from defusedxml.ElementTree import fromstring

from app.core.config import settings
from app.core.datetime_utils import ensure_timezone_aware_fetch_time
from app.core.http_client import get_shared_http_session
from app.domains.ai.llm_privacy import ContentSanitizer
from app.domains.podcast.integration.platform_detector import PlatformDetector
from app.domains.podcast.integration.security import (
    PodcastContentValidator,
    PodcastSecurityValidator,
)


logger = logging.getLogger(__name__)


@dataclass
class PodcastEpisode:
    """Structured podcast episode data"""

    title: str
    description: str
    audio_url: str
    published_at: datetime
    duration: int | None = None
    transcript_url: str | None = None
    guid: str | None = None
    image_url: str | None = None
    link: str | None = None  # <item><link> 标签，分集详情页链接


@dataclass
class PodcastFeed:
    """Structured podcast feed data"""

    title: str
    link: str
    description: str
    episodes: list[PodcastEpisode]
    last_fetched: datetime
    author: str | None = None
    language: str | None = None
    categories: list[str] = None
    explicit: bool | None = None
    image_url: str | None = None
    podcast_type: str | None = None
    platform: str | None = None


class SecureRSSParser:
    """Secure parser with complete validation pipeline"""

    def __init__(
        self,
        user_id: int,
        *,
        shared_session: aiohttp.ClientSession | None = None,
    ):
        self.user_id = user_id
        self.security = PodcastSecurityValidator()
        self.privacy = ContentSanitizer(mode=settings.LLM_CONTENT_SANITIZE_MODE)
        # Use provided session or get shared session
        self._shared_session = shared_session

    async def _get_session(self) -> aiohttp.ClientSession:
        """Get HTTP session, using shared session if available."""
        if self._shared_session is not None:
            return self._shared_session
        return await get_shared_http_session()

    async def fetch_and_parse_feed(
        self,
        feed_url: str,
        *,
        max_episodes: int | None = None,
        newer_than: datetime | None = None,
    ) -> tuple[bool, PodcastFeed | None, str | None]:
        """Complete pipeline: fetch → validate → parse

        Returns:
            Tuple[success, feed_data, error_message]

        """
        # Step 0: Detect platform
        platform = PlatformDetector.detect_platform(feed_url)
        logger.debug(
            f"User {self.user_id}: Fetching RSS from {feed_url}, platform: {platform}"
        )

        # Step 1: Validate URL
        valid_url, url_error = self.security.validate_audio_url(feed_url)
        if not valid_url:
            logger.warning(f"Invalid RSS URL: {url_error}")
            return False, None, f"Invalid URL: {url_error}"

        # Step 2: Fetch content
        xml_content, fetch_error = await self._safe_fetch(feed_url)
        if fetch_error:
            return False, None, fetch_error

        # Step 3: Security validation
        validator = PodcastContentValidator()
        validation_result = await validator.validate_rss_feed(feed_url, xml_content)
        if not validation_result["valid"]:
            logger.warning(f"Feed validation failed: {validation_result['error']}")
            return False, None, validation_result["error"]

        # Step 4: Parse safely
        try:
            feed = await self._parse_feed_securely(
                feed_url,
                xml_content,
                platform,
                max_episodes=max_episodes,
                newer_than=newer_than,
            )
            logger.debug(
                f"Successfully parsed feed: {feed.title} with {len(feed.episodes)} episodes from {platform}"
            )
            return True, feed, None
        except Exception as e:
            logger.error(f"Parsing error: {e}")
            return False, None, f"Failed to parse feed: {e}"

    async def _safe_fetch(self, url: str) -> tuple[str | None, str | None]:
        """Fetch with size and timeout limits using shared session."""
        try:
            session = await self._get_session()
            return await self._fetch_with_session(session, url)

        except aiohttp.ClientError as e:
            logger.error(f"Fetch error: {e}")
            return None, f"Could not fetch feed: {e}"

    async def _fetch_with_session(
        self,
        session: aiohttp.ClientSession,
        url: str,
    ) -> tuple[str | None, str | None]:
        async with session.get(
            url,
            headers={
                "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36",
            },
        ) as resp:
            if resp.status != 200:
                return None, f"HTTP {resp.status}"

            size = int(resp.headers.get("Content-Length", 0))
            if size > self.security.MAX_RSS_SIZE:
                return None, f"Feed too large: {size} bytes"

            content = await resp.read()
            if len(content) > self.security.MAX_RSS_SIZE:
                return None, "Content exceeds size limit"

            try:
                text_content = content.decode("utf-8")
            except UnicodeDecodeError:
                try:
                    text_content = content.decode("latin-1")
                except UnicodeDecodeError:
                    text_content = content.decode("utf-8", errors="ignore")

            return text_content, None

    async def _parse_feed_securely(
        self,
        feed_url: str,
        xml_content: str,
        platform: str,
        *,
        max_episodes: int | None = None,
        newer_than: datetime | None = None,
    ) -> PodcastFeed:
        """Parse RSS with defusedxml"""
        root = fromstring(xml_content)

        # Basic feed info
        channel = root.find("channel") if root.tag == "rss" else root
        if channel is None:
            raise ValueError("Invalid RSS structure")

        title = self._safe_text(channel.findtext("title", "Unknown"))
        link = self._safe_text(channel.findtext("link", ""))
        description = self._sanitize_description(channel.findtext("description", ""))

        # Extract iTunes namespace information
        itunes_ns = {"itunes": "http://www.itunes.com/dtds/podcast-1.0.dtd"}

        # Author
        author = self._safe_text(
            channel.findtext("itunes:author", "", namespaces=itunes_ns)
        )

        # Language
        language = self._safe_text(channel.findtext("language", ""))

        # Categories
        categories = []
        for category in channel.findall("itunes:category", namespaces=itunes_ns):
            if category.get("text"):
                categories.append(category.get("text"))

        # Explicit content
        explicit_text = self._safe_text(
            channel.findtext("itunes:explicit", "", namespaces=itunes_ns)
        )
        explicit = explicit_text.lower() == "true" if explicit_text else None

        # Podcast image - extract from multiple sources
        image_url = self._extract_channel_image_url(channel, itunes_ns)

        # Podcast type
        podcast_type = self._safe_text(
            channel.findtext("itunes:type", "", namespaces=itunes_ns)
        )

        cutoff_time = ensure_timezone_aware_fetch_time(newer_than)
        episodes = []

        for item in channel.findall("item"):
            episode = self._parse_episode(item)
            if episode:
                published_at = ensure_timezone_aware_fetch_time(episode.published_at)
                if cutoff_time and published_at and published_at <= cutoff_time:
                    break
                episodes.append(episode)
                if max_episodes is not None and len(episodes) >= max_episodes:
                    break

        # Use latest episode's published time as last_fetched, fallback to current time
        last_fetched = episodes[0].published_at if episodes else datetime.now(UTC)

        return PodcastFeed(
            title=title,
            link=link,
            description=description,
            episodes=episodes,
            last_fetched=last_fetched,
            author=author or None,
            language=language or None,
            categories=categories or None,
            explicit=explicit,
            image_url=image_url,
            podcast_type=podcast_type or None,
            platform=platform,
        )

    async def close(self) -> None:
        """Allow callers to use a unified parser cleanup path."""
        return

    def _extract_channel_image_url(self, channel, itunes_ns: dict) -> str | None:
        """Extract podcast/channel image URL from multiple possible tag formats.

        Tries in order:
        1. itunes:image (href attribute)
        2. Standard RSS <image><url>
        3. <media:thumbnail> (media namespace)
        4. <atom:link rel="self" type="image">
        5. <googleplay:image> (googleplay namespace)

        Args:
            channel: XML channel element
            itunes_ns: iTunes namespace dict

        Returns:
            Image URL string or None

        """
        # Method 1: iTunes namespace image (most common for podcasts)
        image_element = channel.find("itunes:image", namespaces=itunes_ns)
        if image_element is not None:
            href = image_element.get("href")
            if href:
                logger.debug(f"Found image via itunes:image: {href}")
                return href

        # Method 2: Standard RSS <image><url> tag
        image_element = channel.find("image")
        if image_element is not None:
            url_element = image_element.find("url")
            if url_element is not None and url_element.text:
                url = url_element.text.strip()
                if url and self._is_valid_image_url(url):
                    logger.debug(f"Found image via RSS <image><url>: {url}")
                    return url

        # Method 3: Media namespace thumbnail
        media_ns = {"media": "http://search.yahoo.com/mrss/"}
        thumbnail = channel.find("media:thumbnail", namespaces=media_ns)
        if thumbnail is not None:
            url = thumbnail.get("url")
            if url and self._is_valid_image_url(url):
                logger.debug(f"Found image via media:thumbnail: {url}")
                return url

        # Method 4: Atom link with image type
        atom_ns = {"atom": "http://www.w3.org/2005/Atom"}
        for link in channel.findall("atom:link", namespaces=atom_ns):
            rel = link.get("rel", "")
            link_type = link.get("type", "")
            href = link.get("href", "")
            if (
                (rel == "self" or "image" in link_type.lower())
                and href
                and self._is_valid_image_url(href)
            ):
                logger.debug(f"Found image via atom:link: {href}")
                return href

        # Method 5: Google Play namespace
        gplay_ns = {"gplay": "http://www.google.com/schemas/play-podcasts/1.0"}
        gplay_image = channel.find("gplay:image", namespaces=gplay_ns)
        if gplay_image is not None:
            href = gplay_image.get("href")
            if href and self._is_valid_image_url(href):
                logger.debug(f"Found image via googleplay:image: {href}")
                return href

        # Method 6: Simple image tag with src attribute (non-standard but some feeds use it)
        simple_image = channel.find("image")
        if simple_image is not None:
            src = simple_image.get("src")
            if src and self._is_valid_image_url(src):
                logger.debug(f"Found image via <image src>: {src}")
                return src

        logger.debug("No channel image found in any supported format")
        return None

    def _parse_episode(self, item) -> PodcastEpisode | None:
        """Parse a single episode item"""
        try:
            # Namespaces for iTunes and other extensions
            itunes_ns = {"itunes": "http://www.itunes.com/dtds/podcast-1.0.dtd"}

            # Title (safe)
            title = self._safe_text(item.findtext("title", "Untitled"))

            # Description - prefer content:encoded over description, use raw HTML without sanitization
            content_encoded = item.findtext(
                "content:encoded",
                "",
                namespaces={"content": "http://purl.org/rss/1.0/modules/content/"},
            )
            raw_desc = content_encoded or item.findtext("description", "")
            description = raw_desc or ""  # Use raw HTML directly

            # Extract image URL from description or iTunes namespace
            episode_image_url = None

            # First, try to extract from iTunes:image namespace
            episode_image = item.find("itunes:image", namespaces=itunes_ns)
            if episode_image is not None:
                episode_image_url = episode_image.get("href")

            # If no iTunes image, try to extract from description (for xyzfm and other platforms)
            if not episode_image_url:
                episode_image_url = self._extract_first_image_from_text(raw_desc)

            # Published date
            pub_date = item.findtext("pubDate")
            published_at = self._parse_date(pub_date)

            # Find enclosure (audio)
            enclosure = item.find("enclosure")
            if enclosure is None:
                return None  # Not a podcast episode

            audio_url = enclosure.get("url")
            if not audio_url:
                return None

            # Validate audio URL
            valid, error = self.security.validate_audio_url(audio_url)
            if not valid:
                logger.warning(f"Invalid audio URL in episode {title}: {error}")
                return None

            # Duration
            duration_text = item.findtext("itunes:duration", None, namespaces=itunes_ns)
            duration = self._parse_duration(duration_text)

            # Transcript URL (if available)
            transcript_url = None
            # Check for podcast namespace transcript
            transcript_element = item.find(
                "podcast:transcript",
                namespaces={"podcast": "https://podcastindex.org/namespace/1.0"},
            )
            if transcript_element is not None:
                transcript_url = transcript_element.get("url")
            # Also check for simple transcript URL in custom element
            if not transcript_url:
                transcript_text = item.findtext("transcript_url")
                if transcript_text:
                    transcript_url = transcript_text

            # GUID - 使用更唯一的生成策略
            guid_element = item.find("guid")
            if guid_element is not None and guid_element.text:
                # 优先使用 RSS 提供的 guid
                guid = guid_element.text
            else:
                # 后备方案：使用 audio_url 的 hash 作为 guid（因为音频链接通常是最唯一的）
                import hashlib

                audio_url_hash = hashlib.md5(audio_url.encode()).hexdigest()[:16]
                guid = f"gen_{audio_url_hash}"

            # Item link (episode detail page link)
            link_element = item.find("link")
            raw_link = link_element.text if link_element is not None else None
            item_link = self._safe_text(raw_link) if raw_link else None

            return PodcastEpisode(
                title=title,
                description=description,
                audio_url=audio_url,
                published_at=published_at,
                duration=duration,
                transcript_url=transcript_url,
                guid=guid,
                image_url=episode_image_url,
                link=item_link or None,
            )

        except Exception as e:
            logger.error(f"Error parsing episode: {e}")
            return None

    def _safe_text(self, text: str | None) -> str:
        """Clean and truncate text"""
        if not text:
            return ""
        # Remove null bytes and control characters
        text = text.replace("\x00", "").replace("\r", "")
        return text.strip()[:500]  # Limit length

    def _sanitize_description(self, text: str | None) -> str:
        """Sanitize description for podcast episodes.

        For HTML content (shownotes):
        - Apply security cleaning (remove dangerous tags/attributes)
        - Skip privacy filtering (public content, don't break HTML links)

        Privacy filtering is designed for transcripts/AI summaries, not public shownotes.
        """
        if not text:
            return ""

        # Only apply HTML security cleaning (XSS protection)
        # Skip privacy filtering to preserve HTML structure and links
        clean_text = self.security.sanitize_html_content(text)

        # Truncate to reasonable length
        return clean_text[:5000]  # Increased from 1000 to 5000 for HTML content

    def _parse_date(self, date_str: str | None) -> datetime:
        """Parse various date formats"""
        if not date_str:
            return datetime.now(UTC)
        try:
            # Handle RFC 2822 format (common in RSS)
            from email.utils import parsedate_to_datetime

            return parsedate_to_datetime(date_str)
        except (ValueError, TypeError, OSError):
            return datetime.now(UTC)

    def _parse_duration(self, duration_text: str | None) -> int | None:
        """Parse duration text to seconds"""
        if not duration_text:
            return None

        try:
            # Format: HH:MM:SS or MMM:SS or seconds
            if ":" in duration_text:
                parts = duration_text.split(":")
                if len(parts) == 3:  # HH:MM:SS
                    return int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2])
                if len(parts) == 2:  # MM:SS
                    return int(parts[0]) * 60 + int(parts[1])
            else:
                return int(duration_text)
        except (ValueError, AttributeError, IndexError):
            return None

    def _extract_first_image_from_text(self, text: str) -> str | None:
        """Extract the first image URL from text using regex patterns"""
        if not text:
            return None

        import re

        # Pattern 1: Markdown images: ![alt](url)
        markdown_pattern = r"!\[.*?\]\((https?://[^\s\)]+)\)"
        markdown_match = re.search(markdown_pattern, text)
        if markdown_match:
            url = markdown_match.group(1)
            # Validate URL
            if self._is_valid_image_url(url):
                return url

        # Pattern 2: HTML img tags: <img src="url" ...>
        html_pattern = r'<img[^>]+src=["\'](https?://[^"\']+)["\']'
        html_match = re.search(html_pattern, text, re.IGNORECASE)
        if html_match:
            url = html_match.group(1)
            # Validate URL
            if self._is_valid_image_url(url):
                return url

        # Pattern 3: Plain image URLs (standalone URLs ending with image extensions)
        url_pattern = r"(https?://[^\s]+\.(?:jpg|jpeg|png|gif|webp)(?:\?[^\s]*)?)"
        url_match = re.search(url_pattern, text, re.IGNORECASE)
        if url_match:
            url = url_match.group(1)
            # Validate URL
            if self._is_valid_image_url(url):
                return url

        return None

    def _is_valid_image_url(self, url: str) -> bool:
        """Check if URL is a valid image URL"""
        if not url:
            return False

        # Basic URL validation
        if not url.startswith(("http://", "https://")):
            return False

        # Check for common image file extensions
        image_extensions = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".svg"]
        url_lower = url.lower()

        # Either ends with image extension or contains image-like patterns
        has_extension = any(url_lower.endswith(ext) for ext in image_extensions)
        has_image_keywords = any(
            keyword in url_lower
            for keyword in ["image", "img", "photo", "pic", "cover"]
        )

        return has_extension or has_image_keywords
