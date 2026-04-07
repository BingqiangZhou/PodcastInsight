"""Robust RSS/Atom feed parser using feedparser.

使用 feedparser 的健壮 RSS/Atom 解析器。
"""

import asyncio
import html
import logging
import re
from datetime import datetime
from typing import Any
from urllib.parse import urlparse

import aiohttp
import feedparser

from app.domains.subscription.parsers.feed_schemas import (
    FeedEntry,
    FeedInfo,
    FeedParseOptions,
    FeedParserConfig,
    FeedParseResult,
    ParseErrorCode,
)


logger = logging.getLogger(__name__)

# HTML tag pattern for stripping
_HTML_TAG_PATTERN = re.compile(r"<[^>]+>")


def strip_html_tags(text: str) -> str:
    """Strip HTML tags and decode entities / 去除 HTML 标签并解码实体

    This is a module-level utility function that can be imported and used
    across different modules without instantiating FeedParser.

    Args:
        text: Text potentially containing HTML tags

    Returns:
        Clean text with HTML tags removed and entities decoded

    """
    if not text:
        return ""

    # Remove script and style content first
    text = re.sub(
        r"<(script|style)[^>]*>.*?</\1>", "", text, flags=re.DOTALL | re.IGNORECASE
    )

    # Strip tags
    text = _HTML_TAG_PATTERN.sub(" ", text)

    # Decode HTML entities
    text = html.unescape(text)

    # Normalize whitespace
    text = re.sub(r"\s+", " ", text)

    return text.strip()


class FeedParser:
    """Enhanced RSS/Atom feed parser with robust error handling.

    增强的 RSS/Atom 解析器，具有健壮的错误处理能力。
    """

    def __init__(
        self,
        config: FeedParserConfig | None = None,
    ):
        """Initialize FeedParser.

        Args:
            config: Parser configuration (uses defaults if not provided)

        """
        self.config = config or FeedParserConfig()
        self._client: aiohttp.ClientSession | None = None

    async def __aenter__(self):
        """Async context manager entry / 异步上下文管理器入口"""
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit with cleanup / 异步上下文管理器退出并清理资源"""
        await self.close()
        return False

    async def _get_client(self) -> aiohttp.ClientSession:
        """Get or create HTTP client / 获取或创建 HTTP 客户端"""
        if self._client is None:
            headers = {
                "User-Agent": self.config.user_agent,
                "Accept": "application/rss+xml, application/rdf+xml, application/atom+xml, application/xml, text/xml",
            }
            timeout = aiohttp.ClientTimeout(total=self.config.timeout)
            connector = aiohttp.TCPConnector(limit=10)
            self._client = aiohttp.ClientSession(
                headers=headers,
                timeout=timeout,
                connector=connector,
            )
        return self._client

    async def close(self) -> None:
        """Close HTTP client / 关闭 HTTP 客户端"""
        if self._client and not self._client.closed:
            await self._client.close()
            self._client = None

    async def parse_feed(
        self,
        url: str,
        options: FeedParseOptions | None = None,
    ) -> FeedParseResult:
        """Parse a feed from URL.

        Args:
            url: Feed URL to parse
            options: Parse options to override defaults

        Returns:
            FeedParseResult with parsed data and any errors

        """
        result = FeedParseResult(
            feed_info=FeedInfo(),
            entries=[],
        )

        try:
            # Fetch feed content
            client = await self._get_client()
            async with client.get(url) as response:
                response.raise_for_status()
                content = await response.read()

            # Parse with feedparser
            return await asyncio.to_thread(
                self.parse_feed_content,
                content,
                url,
                options,
            )

        except aiohttp.ClientResponseError as e:
            logger.error(f"HTTP error fetching feed {url}: {e}")
            result.add_error(
                ParseErrorCode.NETWORK_ERROR,
                f"HTTP {e.status}: {e}",
                url=url,
                status_code=e.status,
            )
        except aiohttp.ClientError as e:
            logger.error(f"Request error fetching feed {url}: {e}")
            result.add_error(
                ParseErrorCode.NETWORK_ERROR,
                f"Request failed: {e}",
                url=url,
            )
        except Exception as e:
            logger.exception(f"Unexpected error fetching feed {url}: {e}")
            result.add_error(
                ParseErrorCode.PARSE_ERROR,
                str(e),
                url=url,
            )

        return result

    def parse_feed_content(
        self,
        content: bytes,
        url: str | None = None,
        options: FeedParseOptions | None = None,
    ) -> FeedParseResult:
        """Parse feed from content bytes.

        Args:
            content: Feed content as bytes
            url: Optional URL for error reporting
            options: Parse options to override defaults

        Returns:
            FeedParseResult with parsed data and any errors

        """
        result = FeedParseResult(
            feed_info=FeedInfo(),
            entries=[],
        )

        # Apply options
        max_entries = options.max_entries if options else None
        if max_entries is None:
            max_entries = self.config.max_entries
        strip_html = options.strip_html_content if options else self.config.strip_html
        include_raw = options.include_raw_metadata if options else False

        try:
            # Parse with feedparser
            feed = feedparser.parse(content)

            # Check for feedparser errors
            if hasattr(feed, "bozo") and feed.bozo:
                self._handle_feedparser_error(feed, result, url)

            # Store raw feed for debugging if configured
            if self.config.log_raw_feed or include_raw:
                result.raw_feed = (
                    dict(feed) if hasattr(feed, "__dict__") else {"feed": feed}
                )

            # Parse feed metadata
            result.feed_info = self._parse_feed_info(feed, url)

            # Parse entries
            entries_to_parse = (
                feed.entries[:max_entries] if hasattr(feed, "entries") else []
            )
            result.total_entries = len(feed.entries) if hasattr(feed, "entries") else 0

            for entry in entries_to_parse:
                try:
                    feed_entry = self._parse_entry(entry, strip_html, include_raw)
                    result.entries.append(feed_entry)
                    result.parsed_entries += 1
                except Exception as e:
                    logger.warning(f"Error parsing entry: {e}")
                    result.skipped_entries += 1
                    if self.config.strict_mode:
                        result.add_error(
                            ParseErrorCode.PARSE_ERROR,
                            f"Failed to parse entry: {e}",
                            entry_id=getattr(entry, "id", None),
                        )
                        break
                    result.add_warning(f"Skipped entry due to error: {e}")

        except Exception as e:
            logger.exception(f"Error parsing feed content: {e}")
            result.add_error(
                ParseErrorCode.PARSE_ERROR,
                str(e),
                url=url,
            )
            result.success = False

        return result

    def _handle_feedparser_error(
        self,
        feed: Any,
        result: FeedParseResult,
        url: str | None = None,
    ) -> None:
        """Handle feedparser bozo error / 处理 feedparser 错误"""
        if hasattr(feed, "bozo_exception"):
            exc = feed.bozo_exception
            logger.warning(f"Feedparser warning: {exc}")

            # Categorize error type
            error_code = ParseErrorCode.PARSE_ERROR
            if "XML" in str(exc) or "encoding" in str(exc).lower():
                error_code = ParseErrorCode.ENCODING_ERROR

            result.add_error(
                error_code,
                str(exc),
                url=url,
                exception_type=type(exc).__name__,
            )

    def _parse_feed_info(self, feed: Any, url: str | None) -> FeedInfo:
        """Parse feed metadata / 解析 feed 元数据"""
        feed_data = feed.get("feed", {})

        # Extract title
        title = self._get_field(feed_data, ["title", "text"], "")

        # Extract description
        description = self._get_field(
            feed_data,
            ["description", "subtitle", "tagline", "summary"],
            "",
        )

        # Extract link
        link = url or self._get_field(feed_data, ["link", "href"], "")
        if link and self.config.validate_urls:
            link = self._normalize_url(link, feed_data)

        # Extract author
        author = self._get_field(
            feed_data,
            ["author", "creator", "managingEditor", "webMaster"],
            None,
        )

        # Extract icon/logo
        icon_url = self._get_field(
            feed_data,
            ["icon", "logo", "image", "href"],
            None,
        )
        if icon_url and hasattr(icon_url, "href"):
            icon_url = icon_url.href

        # NEW: Check iTunes namespace (podcast RSS feeds)
        # feedparser stores iTunes images in various places
        if not icon_url:
            itunes_image = feed_data.get("itunes_image")
            if itunes_image:
                if isinstance(itunes_image, dict):
                    icon_url = itunes_image.get("href")
                elif isinstance(itunes_image, str):
                    icon_url = itunes_image

        # NEW: Check standard RSS image with href
        if not icon_url:
            image = feed_data.get("image")
            if image and isinstance(image, dict):
                icon_url = image.get("href") or image.get("url")

        # NEW: Check podcast_image (another feedparser field)
        if not icon_url:
            podcast_image = feed_data.get("podcast_image")
            if podcast_image:
                if isinstance(podcast_image, dict):
                    icon_url = podcast_image.get("href")
                elif isinstance(podcast_image, str):
                    icon_url = podcast_image

        # Debug logging for troubleshooting
        if not icon_url:
            image_keys = [
                k for k in feed_data if "image" in k.lower() or "icon" in k.lower()
            ]
            logger.debug(f"No image_url found. Image-related keys: {image_keys}")

        # Extract language
        language = self._get_field(feed_data, ["language"], None)

        # Extract updated date
        updated_at = self._parse_date(
            self._get_field(feed_data, ["updated_parsed", "published_parsed"], None),
        )

        # Store additional metadata
        raw_metadata = {
            k: v
            for k, v in feed_data.items()
            if k not in {"title", "description", "link", "author", "icon", "language"}
        }

        return FeedInfo(
            title=title,
            description=description,
            link=link,
            author=author,
            icon_url=icon_url,
            updated_at=updated_at,
            language=language,
            raw_metadata=raw_metadata,
        )

    def _parse_entry(
        self,
        entry: Any,
        strip_html: bool,
        include_raw: bool,
    ) -> FeedEntry:
        """Parse a single feed entry / 解析单个 feed 条目"""
        # Extract ID
        entry_id = self._get_field(entry, ["id", "guid", "link"], "")

        # Extract title
        title = self._get_field(entry, ["title"], "Untitled")

        # Extract and process content
        content = self._extract_content(entry, strip_html)
        summary = self._extract_summary(entry, strip_html)

        # Extract metadata
        author = self._get_field(
            entry,
            ["author", "creator", "name"],
            None,
        )

        link = self._get_field(entry, ["link", "href"], None)

        # Extract image
        image_url = self._extract_image_url(entry)

        # Extract tags
        tags = self._extract_tags(entry)

        # Extract dates
        published_at = self._parse_date(
            self._get_field(entry, ["published_parsed"], None),
        )
        updated_at = self._parse_date(
            self._get_field(entry, ["updated_parsed"], None),
        )

        # Raw metadata
        raw_metadata = {}
        if include_raw:
            raw_metadata = (
                dict(entry) if hasattr(entry, "__dict__") else {"entry": entry}
            )

        return FeedEntry(
            id=entry_id,
            title=title,
            content=content,
            summary=summary,
            author=author,
            link=link,
            image_url=image_url,
            tags=tags,
            published_at=published_at,
            updated_at=updated_at,
            raw_metadata=raw_metadata,
        )

    def _extract_content(self, entry: Any, strip_html: bool) -> str:
        """Extract and normalize content / 提取并规范化内容"""
        # Try multiple content fields in order of preference
        content_fields = ["content", "description", "summary", "body"]

        for field in content_fields:
            value = getattr(entry, field, None)
            if value:
                # Handle list format (feedparser content format)
                if isinstance(value, list) and value:
                    if isinstance(value[0], dict):
                        value = value[0].get("value", "")
                    else:
                        value = str(value[0])
                elif isinstance(value, dict):
                    value = value.get("value", "")

                if isinstance(value, str) and value.strip():
                    # Limit content length
                    if len(value) > self.config.max_content_length:
                        value = value[: self.config.max_content_length] + "..."

                    # Strip HTML if configured
                    if strip_html:
                        value = self._strip_html_tags(value)

                    return value.strip()

        return ""

    def _extract_summary(self, entry: Any, strip_html: bool) -> str | None:
        """Extract summary / 提取摘要"""
        summary = getattr(entry, "summary", None)
        if summary and isinstance(summary, str):
            if strip_html:
                summary = self._strip_html_tags(summary)
            return summary.strip() or None
        return None

    def _extract_image_url(self, entry: Any) -> str | None:
        """Extract image URL / 提取图片 URL"""
        # Try multiple image fields
        image_fields = ["image", "enclosure", "media_thumbnail", "media_content"]

        for field in image_fields:
            value = getattr(entry, field, None)
            if value:
                # Handle dict format
                if isinstance(value, dict):
                    # Try common keys
                    for key in ["href", "url"]:
                        if key in value:
                            return value[key]
                # Handle list format
                elif isinstance(value, list) and value:
                    if isinstance(value[0], dict):
                        return value[0].get("href") or value[0].get("url")
                # Direct string value
                elif isinstance(value, str):
                    return value

        return None

    def _extract_tags(self, entry: Any) -> list[str]:
        """Extract tags/categories / 提取标签/分类"""
        tags = []

        # Try tags field
        if hasattr(entry, "tags") and entry.tags:
            for tag in entry.tags:
                if hasattr(tag, "term"):
                    tags.append(str(tag.term))
                elif isinstance(tag, str):
                    tags.append(tag)
                elif isinstance(tag, dict):
                    term = tag.get("term") or tag.get("label")
                    if term:
                        tags.append(str(term))

        # Try categories field
        if hasattr(entry, "categories") and entry.categories:
            for cat in entry.categories:
                if isinstance(cat, str):
                    tags.append(cat)
                elif isinstance(cat, list):
                    tags.extend(str(c) for c in cat)

        # Deduplicate and return
        return list(dict.fromkeys(tags))  # Preserve order while deduplicating

    def _parse_date(self, date_value: Any) -> datetime | None:
        """Parse date from feedparser format / 解析 feedparser 格式的日期"""
        if date_value is None:
            return None

        # feedparser returns time.struct_time
        if isinstance(date_value, tuple) and len(date_value) >= 6:
            try:
                return datetime(*date_value[:6])
            except (ValueError, TypeError) as e:
                logger.warning(f"Failed to parse date {date_value}: {e}")
                return None

        # Already a datetime
        if isinstance(date_value, datetime):
            return date_value

        # Try parsing string
        if isinstance(date_value, str):
            # Common date formats - could add more
            from email.utils import parsedate_to_datetime

            try:
                return parsedate_to_datetime(date_value)
            except (ValueError, TypeError) as exc:
                logger.debug("Date parse failed for %r: %s", date_value[:80], exc)

        return None

    def _get_field(self, obj: Any, fields: list[str], default: Any = None) -> Any:
        """Get first available field from object / 从对象获取第一个可用字段"""
        for field in fields:
            value = getattr(obj, field, None)
            if value is not None:
                return value
        return default

    def _normalize_url(self, url: str, context: Any = None) -> str:
        """Normalize URL / 规范化 URL"""
        url = url.strip()

        # Handle relative URLs
        if context and not url.startswith(("http://", "https://")):
            base_link = self._get_field(context, ["link"], "")
            if base_link:
                try:
                    parsed = urlparse(base_link)
                    url = f"{parsed.scheme}://{parsed.netloc}{url}"
                except ValueError as exc:
                    logger.debug("URL normalization failed for %r: %s", base_link[:80], exc)

        return url

    def _strip_html_tags(self, text: str) -> str:
        """Strip HTML tags and decode entities / 去除 HTML 标签并解码实体"""
        return strip_html_tags(text)


async def parse_feed_url(
    url: str,
    config: FeedParserConfig | None = None,
    options: FeedParseOptions | None = None,
) -> FeedParseResult:
    """Convenience function to parse a feed from URL.

    从 URL 解析 feed 的便捷函数。

    Args:
        url: Feed URL to parse
        config: Parser configuration
        options: Parse options

    Returns:
        FeedParseResult with parsed data

    """
    parser = FeedParser(config)
    try:
        return await parser.parse_feed(url, options)
    finally:
        await parser.close()


def parse_feed_bytes(
    content: bytes,
    config: FeedParserConfig | None = None,
    options: FeedParseOptions | None = None,
) -> FeedParseResult:
    """Convenience function to parse feed from bytes.

    从字节内容解析 feed 的便捷函数。

    Args:
        content: Feed content as bytes
        config: Parser configuration
        options: Parse options

    Returns:
        FeedParseResult with parsed data

    """
    parser = FeedParser(config)
    return parser.parse_feed_content(content, options=options)
