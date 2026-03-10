from datetime import UTC, datetime

import pytest

from app.domains.podcast.integration.secure_rss_parser import SecureRSSParser


def _build_feed_xml() -> str:
    return """
    <rss version="2.0">
      <channel>
        <title>Example Feed</title>
        <link>https://example.com</link>
        <description>Example</description>
        <item>
          <title>Episode 3</title>
          <link>https://example.com/episodes/3</link>
          <pubDate>Tue, 10 Mar 2026 10:00:00 GMT</pubDate>
          <enclosure url="https://cdn.example.com/audio-3.mp3" type="audio/mpeg" />
        </item>
        <item>
          <title>Episode 2</title>
          <link>https://example.com/episodes/2</link>
          <pubDate>Tue, 09 Mar 2026 10:00:00 GMT</pubDate>
          <enclosure url="https://cdn.example.com/audio-2.mp3" type="audio/mpeg" />
        </item>
        <item>
          <title>Episode 1</title>
          <link>https://example.com/episodes/1</link>
          <pubDate>Tue, 08 Mar 2026 10:00:00 GMT</pubDate>
          <enclosure url="https://cdn.example.com/audio-1.mp3" type="audio/mpeg" />
        </item>
      </channel>
    </rss>
    """


@pytest.mark.asyncio
async def test_secure_rss_parser_applies_max_episode_limit():
    parser = SecureRSSParser(user_id=1)
    feed = await parser._parse_feed_securely(
        "https://example.com/feed.xml",
        _build_feed_xml(),
        "generic",
        max_episodes=2,
    )

    assert [episode.title for episode in feed.episodes] == ["Episode 3", "Episode 2"]


@pytest.mark.asyncio
async def test_secure_rss_parser_stops_once_items_are_not_newer_than_cutoff():
    parser = SecureRSSParser(user_id=1)
    feed = await parser._parse_feed_securely(
        "https://example.com/feed.xml",
        _build_feed_xml(),
        "generic",
        newer_than=datetime(2026, 3, 9, 10, 0, tzinfo=UTC),
    )

    assert [episode.title for episode in feed.episodes] == ["Episode 3"]
