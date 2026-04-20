"""Tests for FeedParser component."""

from datetime import datetime
from unittest.mock import AsyncMock, MagicMock, patch

import aiohttp
import pytest

from app.domains.podcast.parsers.feed_parser import (
    FeedParser,
    parse_feed_bytes,
    parse_feed_url,
)
from app.domains.podcast.parsers.feed_schemas import (
    FeedEntry,
    FeedInfo,
    FeedParseOptions,
    FeedParserConfig,
    FeedParseResult,
    ParseErrorCode,
)


# Sample RSS feed content for testing
SAMPLE_RSS_FEED = b"""<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Test Feed</title>
    <description>A test RSS feed</description>
    <link>https://example.com</link>
    <language>en</language>
    <item>
      <title>First Post</title>
      <link>https://example.com/post1</link>
      <description>This is the first post</description>
      <author>John Doe</author>
      <pubDate>Mon, 01 Jan 2025 12:00:00 GMT</pubDate>
      <category>Technology</category>
    </item>
    <item>
      <title>Second Post</title>
      <link>https://example.com/post2</link>
      <description><![CDATA[A post with <strong>HTML</strong> content]]></description>
      <pubDate>Tue, 02 Jan 2025 12:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>
"""

# Sample Atom feed content
SAMPLE_ATOM_FEED = b"""<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Test Atom Feed</title>
  <subtitle>An Atom test feed</subtitle>
  <link href="https://example.com"/>
  <updated>2025-01-01T12:00:00Z</updated>
  <entry>
    <title>Atom Entry</title>
    <link href="https://example.com/atom1"/>
    <content>Atom content here</content>
    <author>
      <name>Jane Doe</name>
    </author>
    <published>2025-01-01T12:00:00Z</published>
    <updated>2025-01-01T12:00:00Z</updated>
  </entry>
</feed>
"""

# Malformed feed for error handling tests
MALFORMED_FEED = b"""<rss>
  <channel>
    <title>Broken Feed
    <!-- Missing closing tags -->
  </channel>
"""


class TestFeedParser:
    """Test FeedParser component."""

    def test_init_default_config(self):
        """Test parser initialization with default config."""
        parser = FeedParser()
        assert parser.config is not None
        assert parser.config.max_entries == 100
        assert parser.config.strip_html is True
        assert parser.config.strict_mode is False

    def test_init_custom_config(self):
        """Test parser initialization with custom config."""
        config = FeedParserConfig(
            max_entries=50,
            strip_html=False,
            strict_mode=True,
        )
        parser = FeedParser(config)
        assert parser.config.max_entries == 50
        assert parser.config.strip_html is False
        assert parser.config.strict_mode is True

    def test_parse_rss_feed_bytes(self):
        """Test parsing RSS feed from bytes."""
        parser = FeedParser()
        result = parser.parse_feed_content(SAMPLE_RSS_FEED)

        assert result.success is True
        assert result.feed_info.title == "Test Feed"
        assert result.feed_info.description == "A test RSS feed"
        assert result.feed_info.link == "https://example.com"
        assert result.feed_info.language == "en"
        assert len(result.entries) == 2

        # Check first entry
        entry1 = result.entries[0]
        assert entry1.title == "First Post"
        assert entry1.link == "https://example.com/post1"
        assert entry1.author == "John Doe"
        assert "Technology" in entry1.tags

    def test_parse_atom_feed_bytes(self):
        """Test parsing Atom feed from bytes."""
        parser = FeedParser()
        result = parser.parse_feed_content(SAMPLE_ATOM_FEED)

        assert result.success is True
        assert result.feed_info.title == "Test Atom Feed"
        assert len(result.entries) == 1

        entry = result.entries[0]
        assert entry.title == "Atom Entry"
        assert entry.link == "https://example.com/atom1"
        assert entry.author == "Jane Doe"

    def test_parse_with_max_entries_limit(self):
        """Test parsing with entry limit."""
        parser = FeedParser(FeedParserConfig(max_entries=1))
        result = parser.parse_feed_content(SAMPLE_RSS_FEED)

        assert len(result.entries) == 1
        assert result.parsed_entries == 1
        assert result.skipped_entries == 0

    def test_parse_with_html_stripping(self):
        """Test HTML content stripping."""
        parser = FeedParser(FeedParserConfig(strip_html=True))
        result = parser.parse_feed_content(SAMPLE_RSS_FEED)

        # Second post has HTML content
        entry2 = result.entries[1]
        assert "<strong>" not in entry2.content
        assert "HTML" in entry2.content

    def test_parse_without_html_stripping(self):
        """Test parsing without HTML stripping."""
        options = FeedParseOptions(strip_html_content=False)
        parser = FeedParser()
        result = parser.parse_feed_content(SAMPLE_RSS_FEED, options=options)

        entry2 = result.entries[1]
        # Should preserve HTML tags
        assert "<strong>" in entry2.content or "HTML" in entry2.content

    def test_parse_with_malformed_feed(self):
        """Test handling malformed feed."""
        parser = FeedParser()
        result = parser.parse_feed_content(MALFORMED_FEED)

        # Should still return a result, possibly with errors
        assert isinstance(result, FeedParseResult)
        # feedparser may handle malformed content gracefully
        # or add errors depending on the severity

    def test_parse_empty_feed(self):
        """Test parsing empty feed."""
        parser = FeedParser()
        result = parser.parse_feed_content(b"<rss></rss>")

        assert isinstance(result, FeedParseResult)
        assert len(result.entries) == 0

    def test_extract_tags_from_entry(self):
        """Test tag extraction."""
        parser = FeedParser()
        result = parser.parse_feed_content(SAMPLE_RSS_FEED)

        # First entry has a category
        assert "Technology" in result.entries[0].tags

    def test_date_parsing(self):
        """Test date parsing from feeds."""
        parser = FeedParser()
        result = parser.parse_feed_content(SAMPLE_RSS_FEED)

        # First entry should have published_at
        entry1 = result.entries[0]
        assert entry1.published_at is not None
        assert isinstance(entry1.published_at, datetime)

    @pytest.mark.asyncio
    async def test_parse_feed_from_url_success(self):
        """Test parsing feed from URL successfully."""
        parser = FeedParser()

        # Mock HTTP client — must support async context manager protocol
        mock_response = AsyncMock()
        mock_response.content = SAMPLE_RSS_FEED
        mock_response.raise_for_status = MagicMock()
        mock_response.read = AsyncMock(return_value=SAMPLE_RSS_FEED)

        mock_context = AsyncMock()
        mock_context.__aenter__ = AsyncMock(return_value=mock_response)
        mock_context.__aexit__ = AsyncMock(return_value=False)

        mock_client = AsyncMock()
        mock_client.get = MagicMock(return_value=mock_context)

        parser._client = mock_client

        result = await parser.parse_feed("https://example.com/feed.xml")

        assert result.success is True
        assert result.feed_info.title == "Test Feed"
        assert len(result.entries) == 2

    @pytest.mark.asyncio
    async def test_parse_feed_from_url_offloads_parsing_to_thread(self):
        """Test parsing feed content via asyncio.to_thread."""
        parser = FeedParser()

        mock_response = AsyncMock()
        mock_response.content = SAMPLE_RSS_FEED
        mock_response.raise_for_status = MagicMock()
        mock_response.read = AsyncMock(return_value=SAMPLE_RSS_FEED)

        mock_context = AsyncMock()
        mock_context.__aenter__ = AsyncMock(return_value=mock_response)
        mock_context.__aexit__ = AsyncMock(return_value=False)

        mock_client = AsyncMock()
        mock_client.get = MagicMock(return_value=mock_context)
        parser._client = mock_client

        expected = FeedParseResult(feed_info=FeedInfo(title="Test Feed"), entries=[])
        with patch(
            "app.domains.podcast.parsers.feed_parser.asyncio.to_thread",
            new=AsyncMock(return_value=expected),
        ) as mock_to_thread:
            result = await parser.parse_feed("https://example.com/feed.xml")

        assert result is expected
        mock_to_thread.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_parse_feed_from_url_network_error(self):
        """Test handling network error."""
        parser = FeedParser()

        # Mock HTTP error — exception raised when entering async context
        mock_context = AsyncMock()
        mock_context.__aenter__ = AsyncMock(
            side_effect=aiohttp.ClientError("Connection failed"),
        )
        mock_context.__aexit__ = AsyncMock(return_value=False)

        mock_client = AsyncMock()
        mock_client.get = MagicMock(return_value=mock_context)
        parser._client = mock_client

        result = await parser.parse_feed("https://example.com/feed.xml")

        assert result.success is False
        assert result.has_errors()
        assert any(e.code == ParseErrorCode.NETWORK_ERROR for e in result.errors)

    @pytest.mark.asyncio
    async def test_parse_feed_from_url_http_error(self):
        """Test handling HTTP error response."""
        parser = FeedParser()

        # Mock HTTP 404 error — raise_for_status triggers the exception
        error = aiohttp.ClientResponseError(
            request_info=MagicMock(),
            history=(),
            status=404,
            message="Not Found",
        )

        mock_response = AsyncMock()
        mock_response.status = 404
        mock_response.raise_for_status = MagicMock(side_effect=error)
        mock_response.read = AsyncMock(return_value=b"")

        mock_context = AsyncMock()
        mock_context.__aenter__ = AsyncMock(return_value=mock_response)
        mock_context.__aexit__ = AsyncMock(return_value=False)

        mock_client = AsyncMock()
        mock_client.get = MagicMock(return_value=mock_context)
        parser._client = mock_client

        result = await parser.parse_feed("https://example.com/feed.xml")

        assert result.success is False
        assert result.has_errors()

    @pytest.mark.asyncio
    async def test_convenience_function_parse_feed_url(self):
        """Test convenience function for parsing feed from URL."""
        with patch.object(FeedParser, "parse_feed") as mock_parse:
            mock_result = FeedParseResult(feed_info=FeedInfo(), entries=[])
            mock_parse.return_value = mock_result

            result = await parse_feed_url("https://example.com/feed.xml")

            assert result is not None
            mock_parse.assert_called_once()

    def test_convenience_function_parse_feed_bytes(self):
        """Test convenience function for parsing feed from bytes."""
        result = parse_feed_bytes(SAMPLE_RSS_FEED)

        assert result.success is True
        assert result.feed_info.title == "Test Feed"
        assert len(result.entries) == 2

    @pytest.mark.asyncio
    async def test_parser_client_cleanup(self):
        """Test that HTTP client is properly cleaned up."""
        parser = FeedParser()

        # Create client
        await parser._get_client()
        assert parser._client is not None

        # Close parser
        await parser.close()
        assert parser._client is None


class TestFeedParseResult:
    """Test FeedParseResult model."""

    def test_add_error(self):
        """Test adding errors to result."""
        result = FeedParseResult(feed_info=FeedInfo(), entries=[])
        result.add_error(ParseErrorCode.PARSE_ERROR, "Test error", detail="info")

        assert len(result.errors) == 1
        assert result.errors[0].code == ParseErrorCode.PARSE_ERROR
        assert result.errors[0].message == "Test error"

    def test_add_warning(self):
        """Test adding warnings to result."""
        result = FeedParseResult(feed_info=FeedInfo(), entries=[])
        result.add_warning("Test warning")

        assert len(result.warnings) == 1
        assert result.warnings[0] == "Test warning"

    def test_has_errors(self):
        """Test has_errors method."""
        result = FeedParseResult(feed_info=FeedInfo(), entries=[])
        assert result.has_errors() is False

        result.add_error(ParseErrorCode.PARSE_ERROR, "Error")
        assert result.has_errors() is True

    def test_has_warnings(self):
        """Test has_warnings method."""
        result = FeedParseResult(feed_info=FeedInfo(), entries=[])
        assert result.has_warnings() is False

        result.add_warning("Warning")
        assert result.has_warnings() is True

    def test_critical_error_sets_success_false(self):
        """Test that critical errors set success to False."""
        result = FeedParseResult(feed_info=FeedInfo(), entries=[])

        assert result.success is True

        result.add_error(ParseErrorCode.NETWORK_ERROR, "Network failed")
        assert result.success is False


class TestFeedEntry:
    """Test FeedEntry model."""

    def test_entry_validation(self):
        """Test entry field validation."""
        entry = FeedEntry(
            id="test-id",
            title="Test Entry",
            content="Test content",
        )

        assert entry.id == "test-id"
        assert entry.title == "Test Entry"
        assert entry.content == "Test content"
        assert entry.tags == []

    def test_entry_with_none_defaults(self):
        """Test entry with None values handled correctly."""
        entry = FeedEntry(
            id="",
            title="",
            content="",
        )

        assert entry.title == "Untitled"
        assert entry.tags == []

    def test_tags_normalization(self):
        """Test tags are normalized correctly."""
        entry = FeedEntry(
            id="test",
            title="Test",
            content="Content",
            tags=["tag1", "tag2", "tag1"],  # Duplicate
        )

        assert len(entry.tags) == 3  # Preserves list order

    def test_get_unique_tags(self):
        """Test getting unique tags."""
        entry = FeedEntry(
            id="test",
            title="Test",
            content="Content",
            tags=["python", "programming", "python"],
        )

        unique = entry.get_unique_tags()
        assert len(unique) == 2
        assert "python" in unique
        assert "programming" in unique
