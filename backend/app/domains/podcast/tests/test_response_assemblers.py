from datetime import UTC, datetime

from app.domains.podcast.api.response_assemblers import (
    build_conversation_clear_response,
    build_conversation_history_response,
    build_conversation_send_response,
    build_conversation_session_list_response,
    build_daily_report_dates_response,
    build_daily_report_response,
    build_effective_playback_rate_response,
    build_episode_detail_response,
    build_episode_list_response,
    build_existing_playback_state_response,
    build_feed_response,
    build_pending_summaries_response,
    build_playback_history_list_response,
    build_playback_state_response,
    build_podcast_profile_stats_response,
    build_podcast_stats_response,
    build_queue_response,
    build_schedule_config_list_response,
    build_schedule_config_response,
    build_summary_models_response,
    build_summary_response,
)
from app.domains.podcast.playback_queue_projections import (
    PodcastPlaybackStateProjection,
    PodcastQueueProjection,
)
from app.domains.podcast.schedule_projections import ScheduleConfigProjection


def _episode_payload(now: datetime) -> dict:
    return {
        "id": 1,
        "subscription_id": 2,
        "title": "Episode 1",
        "description": "desc",
        "audio_url": "https://example.com/audio.mp3",
        "audio_duration": 1200,
        "published_at": now,
        "image_url": "https://example.com/ep.jpg",
        "subscription_image_url": "https://example.com/sub.jpg",
        "ai_summary": "summary",
        "summary_version": "v1",
        "ai_confidence_score": 0.9,
        "play_count": 0,
        "last_played_at": None,
        "season": None,
        "episode_number": None,
        "explicit": False,
        "status": "published",
        "metadata": {},
        "subscription_title": "Podcast",
        "playback_position": 30,
        "is_playing": False,
        "playback_rate": 1.0,
        "is_played": False,
        "created_at": now,
        "updated_at": now,
    }


def test_build_feed_response_wraps_episode_items():
    now = datetime.now(UTC)

    response = build_feed_response(
        [_episode_payload(now)],
        has_more=True,
        next_page=None,
        next_cursor="cursor-1",
        total=7,
    )

    assert response.total == 7
    assert response.has_more is True
    assert response.next_cursor == "cursor-1"
    assert response.items[0].title == "Episode 1"


def test_build_episode_list_response_sets_pagination():
    now = datetime.now(UTC)

    response = build_episode_list_response(
        [_episode_payload(now)],
        total=21,
        page=2,
        size=10,
        subscription_id=5,
        next_cursor="cursor-2",
    )

    assert response.page == 2
    assert response.size == 10
    assert response.pages == 3
    assert response.subscription_id == 5
    assert response.next_cursor == "cursor-2"


def test_build_playback_history_list_response_uses_lightweight_items():
    now = datetime.now(UTC)

    response = build_playback_history_list_response(
        [
            {
                "id": 11,
                "subscription_id": 2,
                "subscription_title": "Podcast",
                "subscription_image_url": None,
                "title": "Episode 11",
                "image_url": None,
                "audio_duration": 1800,
                "playback_position": 45,
                "last_played_at": now,
                "published_at": now,
            }
        ],
        total=1,
        page=1,
        size=20,
    )

    assert response.total == 1
    assert response.pages == 1
    assert response.episodes[0].playback_position == 45


def test_build_episode_detail_response_preserves_detail_fields():
    now = datetime.now(UTC)
    payload = _episode_payload(now)
    payload["subscription"] = {"id": 2, "title": "Podcast"}
    payload["related_episodes"] = [{"id": 9}]

    response = build_episode_detail_response(payload)

    assert response.subscription == {"id": 2, "title": "Podcast"}
    assert response.related_episodes == [{"id": 9}]


def test_build_conversation_responses_wrap_payloads():
    now = datetime.now(UTC)

    session_list = build_conversation_session_list_response(
        [
            {
                "id": 3,
                "episode_id": 9,
                "title": "Session A",
                "message_count": 2,
                "created_at": now,
                "updated_at": now,
            }
        ]
    )
    history = build_conversation_history_response(
        episode_id=9,
        session_id=3,
        messages=[
            {
                "id": 1,
                "role": "user",
                "content": "Hello",
                "conversation_turn": 0,
                "created_at": now.isoformat(),
            }
        ],
    )
    send = build_conversation_send_response(
        {
            "id": 2,
            "role": "assistant",
            "content": "Hi",
            "conversation_turn": 1,
            "processing_time": 0.2,
            "created_at": now.isoformat(),
        }
    )
    clear = build_conversation_clear_response(
        episode_id=9,
        session_id=3,
        deleted_count=4,
    )

    assert session_list.total == 1
    assert session_list.sessions[0].message_count == 2
    assert history.total == 1
    assert history.messages[0].content == "Hello"
    assert send.role == "assistant"
    assert clear.deleted_count == 4


def test_build_stats_and_report_responses():
    now = datetime.now(UTC)

    stats = build_podcast_stats_response(
        {
            "total_subscriptions": 3,
            "total_episodes": 8,
            "total_playtime": 900,
            "summaries_generated": 4,
            "pending_summaries": 2,
            "recently_played": [],
            "top_categories": [],
            "listening_streak": 5,
        }
    )
    profile_stats = build_podcast_profile_stats_response(
        {
            "total_subscriptions": 3,
            "total_episodes": 8,
            "summaries_generated": 4,
            "pending_summaries": 2,
            "played_episodes": 6,
        }
    )
    report = build_daily_report_response(
        {
            "available": True,
            "report_date": now.date(),
            "timezone": "UTC",
            "schedule_time_local": "09:00",
            "generated_at": now,
            "total_items": 1,
            "items": [
                {
                    "episode_id": 1,
                    "subscription_id": 2,
                    "episode_title": "Episode",
                    "subscription_title": "Podcast",
                    "one_line_summary": "summary",
                    "is_carryover": False,
                    "episode_created_at": now,
                    "episode_published_at": now,
                }
            ],
        }
    )
    report_dates = build_daily_report_dates_response(
        {
            "dates": [
                {
                    "report_date": now.date(),
                    "total_items": 1,
                    "generated_at": now,
                }
            ],
            "total": 1,
            "page": 1,
            "size": 30,
            "pages": 1,
        }
    )

    assert stats.listening_streak == 5
    assert profile_stats.played_episodes == 6
    assert report.available is True
    assert report.items[0].episode_title == "Episode"
    assert report_dates.dates[0].total_items == 1


def test_build_summary_and_playback_responses():
    now = datetime.now(UTC)

    summary = build_summary_response(
        episode_id=9,
        summary_result={
            "summary": "alpha beta gamma",
            "version": "v2",
            "generated_at": now,
            "model_name": "gpt-test",
            "processing_time": 1.2,
        },
    )
    playback = build_playback_state_response(
        episode_id=9,
        payload={
            "progress": 33,
            "is_playing": True,
            "playback_rate": 1.25,
            "play_count": 4,
            "last_updated_at": now,
            "progress_percentage": 12.5,
            "remaining_time": 240,
        },
    )
    existing_playback = build_existing_playback_state_response(
        {
            "episode_id": 9,
            "current_position": 33,
            "is_playing": True,
            "playback_rate": 1.25,
            "play_count": 4,
            "last_updated_at": now,
            "progress_percentage": 12.5,
            "remaining_time": 240,
        }
    )
    effective_rate = build_effective_playback_rate_response(
        {
            "global_playback_rate": 1.0,
            "subscription_playback_rate": 1.25,
            "effective_playback_rate": 1.25,
            "source": "subscription",
        }
    )

    assert summary.word_count == 3
    assert playback.current_position == 33
    assert existing_playback.episode_id == 9
    assert effective_rate.source == "subscription"


def test_build_summary_response_accepts_model_used_key():
    now = datetime.now(UTC)

    summary = build_summary_response(
        episode_id=9,
        summary_result={
            "summary": "alpha beta gamma",
            "version": "v2",
            "generated_at": now,
            "model_used": "workflow-model",
            "processing_time": 1.2,
        },
    )

    assert summary.model_used == "workflow-model"
    assert summary.word_count == 3


def test_build_playback_and_queue_responses_from_projections():
    now = datetime.now(UTC)

    playback = build_playback_state_response(
        payload=PodcastPlaybackStateProjection(
            episode_id=7,
            current_position=80,
            is_playing=False,
            playback_rate=1.0,
            play_count=2,
            last_updated_at=now,
            progress_percentage=50.0,
            remaining_time=80,
        )
    )
    queue = build_queue_response(
        PodcastQueueProjection.model_validate(
            {
                "current_episode_id": 7,
                "revision": 3,
                "updated_at": now,
                "items": [
                    {
                        "episode_id": 7,
                        "position": 0,
                        "playback_position": 80,
                        "title": "Episode 7",
                        "podcast_id": 4,
                        "audio_url": "https://example.com/audio.mp3",
                        "duration": 160,
                        "published_at": now,
                        "image_url": None,
                        "subscription_title": "Podcast",
                        "subscription_image_url": None,
                    }
                ],
            }
        )
    )

    assert playback.episode_id == 7
    assert queue.revision == 3
    assert queue.items[0].episode_id == 7


def test_build_pending_and_model_responses():
    pending = build_pending_summaries_response([
        {"id": 1, "title": "Episode 1"},
        {"id": 2, "title": "Episode 2"},
    ])
    models = build_summary_models_response(
        [
            {
                "id": 1,
                "name": "default",
                "display_name": "Default",
                "provider": "openai",
                "model_id": "gpt-test",
                "is_default": True,
            }
        ]
    )

    assert pending.count == 2
    assert models.total == 1
    assert models.models[0].name == "default"


def test_build_schedule_config_responses_from_projections():
    now = datetime.now(UTC)
    projection = ScheduleConfigProjection(
        id=5,
        title="Podcast 5",
        update_frequency="DAILY",
        update_time="08:30",
        update_day_of_week=None,
        fetch_interval=3600,
        next_update_at=now,
        last_updated_at=now,
    )

    single = build_schedule_config_response(projection)
    listing = build_schedule_config_list_response([projection])

    assert single.id == 5
    assert single.update_time == "08:30"
    assert listing[0].title == "Podcast 5"
