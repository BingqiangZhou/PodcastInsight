"""Response assembly helpers for podcast API routes."""

from __future__ import annotations

from typing import Any

from app.domains.podcast.schemas import (
    DailyReportDateItem,
    ConversationSessionListResponse,
    ConversationSessionResponse,
    PlaybackRateEffectiveResponse,
    PodcastConversationClearResponse,
    PodcastConversationHistoryResponse,
    PodcastConversationMessage,
    PodcastConversationSendResponse,
    PodcastDailyReportDatesResponse,
    PodcastDailyReportResponse,
    PodcastEpisodeDetailResponse,
    PodcastEpisodeListResponse,
    PodcastEpisodeResponse,
    PodcastFeedResponse,
    PodcastPlaybackHistoryItemResponse,
    PodcastPlaybackHistoryListResponse,
    PodcastPlaybackStateResponse,
    PodcastProfileStatsResponse,
    PodcastStatsResponse,
    PodcastSummaryPendingResponse,
    PodcastSummaryResponse,
    SummaryModelInfo,
    SummaryModelsResponse,
)


def build_feed_response(
    episodes: list[dict[str, Any]],
    *,
    has_more: bool,
    next_page: int | None,
    next_cursor: str | None,
    total: int,
) -> PodcastFeedResponse:
    """Build the feed response envelope."""
    return PodcastFeedResponse(
        items=[PodcastEpisodeResponse(**episode) for episode in episodes],
        has_more=has_more,
        next_page=next_page,
        next_cursor=next_cursor,
        total=total,
    )


def build_episode_list_response(
    episodes: list[dict[str, Any]],
    *,
    total: int,
    page: int,
    size: int,
    subscription_id: int,
    next_cursor: str | None = None,
) -> PodcastEpisodeListResponse:
    """Build the paginated episode list response."""
    return PodcastEpisodeListResponse(
        episodes=[PodcastEpisodeResponse(**episode) for episode in episodes],
        total=total,
        page=page,
        size=size,
        pages=(total + size - 1) // size,
        subscription_id=subscription_id,
        next_cursor=next_cursor,
    )


def build_playback_history_list_response(
    episodes: list[dict[str, Any]],
    *,
    total: int,
    page: int,
    size: int,
    next_cursor: str | None = None,
) -> PodcastPlaybackHistoryListResponse:
    """Build the lightweight playback history response."""
    return PodcastPlaybackHistoryListResponse(
        episodes=[PodcastPlaybackHistoryItemResponse(**episode) for episode in episodes],
        total=total,
        page=page,
        size=size,
        pages=(total + size - 1) // size,
        next_cursor=next_cursor,
    )


def build_episode_detail_response(
    episode: dict[str, Any],
) -> PodcastEpisodeDetailResponse:
    """Build the detailed episode response."""
    return PodcastEpisodeDetailResponse(**episode)


def build_conversation_session_response(
    session: dict[str, Any],
) -> ConversationSessionResponse:
    """Build one conversation session response."""
    return ConversationSessionResponse(**session)


def build_conversation_session_list_response(
    sessions: list[dict[str, Any]],
) -> ConversationSessionListResponse:
    """Build the conversation session list response."""
    return ConversationSessionListResponse(
        sessions=[build_conversation_session_response(session) for session in sessions],
        total=len(sessions),
    )


def build_conversation_history_response(
    *,
    episode_id: int,
    session_id: int | None,
    messages: list[dict[str, Any]],
) -> PodcastConversationHistoryResponse:
    """Build the conversation history response."""
    message_responses = [PodcastConversationMessage(**message) for message in messages]
    return PodcastConversationHistoryResponse(
        episode_id=episode_id,
        session_id=session_id,
        messages=message_responses,
        total=len(message_responses),
    )


def build_conversation_send_response(
    payload: dict[str, Any],
) -> PodcastConversationSendResponse:
    """Build the conversation send response."""
    return PodcastConversationSendResponse(**payload)


def build_conversation_clear_response(
    *,
    episode_id: int,
    session_id: int | None,
    deleted_count: int,
) -> PodcastConversationClearResponse:
    """Build the conversation clear response."""
    return PodcastConversationClearResponse(
        episode_id=episode_id,
        session_id=session_id,
        deleted_count=deleted_count,
    )


def build_podcast_stats_response(payload: dict[str, Any]) -> PodcastStatsResponse:
    """Build the podcast stats response."""
    return PodcastStatsResponse(**payload)


def build_podcast_profile_stats_response(
    payload: dict[str, Any],
) -> PodcastProfileStatsResponse:
    """Build the podcast profile stats response."""
    return PodcastProfileStatsResponse(**payload)


def build_daily_report_response(payload: dict[str, Any]) -> PodcastDailyReportResponse:
    """Build the daily report response."""
    return PodcastDailyReportResponse(**payload)


def build_daily_report_dates_response(
    payload: dict[str, Any],
) -> PodcastDailyReportDatesResponse:
    """Build the report dates response."""
    dates = [DailyReportDateItem(**item) for item in payload.get("dates", [])]
    return PodcastDailyReportDatesResponse(
        dates=dates,
        total=payload["total"],
        page=payload["page"],
        size=payload["size"],
        pages=payload["pages"],
    )


def build_summary_response(
    *,
    episode_id: int,
    summary_result: dict[str, Any],
) -> PodcastSummaryResponse:
    """Build the episode summary response."""
    summary_text = summary_result["summary"]
    return PodcastSummaryResponse(
        episode_id=episode_id,
        summary=summary_text,
        version=summary_result["version"],
        confidence_score=None,
        transcript_used=True,
        generated_at=summary_result["generated_at"],
        word_count=len(summary_text.split()),
        model_used=summary_result["model_name"],
        processing_time=summary_result["processing_time"],
    )


def build_playback_state_response(
    *,
    episode_id: int,
    payload: dict[str, Any],
) -> PodcastPlaybackStateResponse:
    """Build the playback state response."""
    return PodcastPlaybackStateResponse(
        episode_id=episode_id,
        current_position=payload["progress"],
        is_playing=payload["is_playing"],
        playback_rate=payload["playback_rate"],
        play_count=payload["play_count"],
        last_updated_at=payload["last_updated_at"],
        progress_percentage=payload["progress_percentage"],
        remaining_time=payload["remaining_time"],
    )


def build_existing_playback_state_response(
    payload: dict[str, Any],
) -> PodcastPlaybackStateResponse:
    """Build playback state response from an already-shaped payload."""
    return PodcastPlaybackStateResponse(**payload)


def build_effective_playback_rate_response(
    payload: dict[str, Any],
) -> PlaybackRateEffectiveResponse:
    """Build the effective playback-rate response."""
    return PlaybackRateEffectiveResponse(**payload)


def build_pending_summaries_response(
    episodes: list[dict[str, Any]],
) -> PodcastSummaryPendingResponse:
    """Build the pending summaries response."""
    return PodcastSummaryPendingResponse(count=len(episodes), episodes=episodes)


def build_summary_models_response(
    models: list[dict[str, Any]],
) -> SummaryModelsResponse:
    """Build the summary models response."""
    model_infos = [
        SummaryModelInfo(
            id=model["id"],
            name=model["name"],
            display_name=model["display_name"],
            provider=model["provider"],
            model_id=model["model_id"],
            is_default=model["is_default"],
        )
        for model in models
    ]
    return SummaryModelsResponse(models=model_infos, total=len(model_infos))