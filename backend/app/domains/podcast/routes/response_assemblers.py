"""Response assembly helpers for podcast API routes."""

from __future__ import annotations

from typing import Any

from app.domains.podcast.schemas import (
    ConversationSessionListResponse,
    ConversationSessionResponse,
    DailyReportDateItem,
    HighlightListResponse,
    HighlightResponse,
    PodcastConversationHistoryResponse,
    PodcastConversationMessage,
    PodcastDailyReportDatesResponse,
    PodcastEpisodeListResponse,
    PodcastEpisodeResponse,
    PodcastFeedResponse,
    PodcastPendingTranscriptionsResponse,
    PodcastPendingTranscriptionTaskResponse,
    PodcastPlaybackHistoryItemResponse,
    PodcastPlaybackHistoryListResponse,
    PodcastPlaybackStateResponse,
    PodcastQueueItemResponse,
    PodcastQueueResponse,
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
        items=[PodcastEpisodeResponse(**episode) for episode in episodes],
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
        items=[PodcastPlaybackHistoryItemResponse(**episode) for episode in episodes],
        total=total,
        page=page,
        size=size,
        pages=(total + size - 1) // size,
        next_cursor=next_cursor,
    )


def build_conversation_session_list_response(
    sessions: list[dict[str, Any]],
) -> ConversationSessionListResponse:
    """Build the conversation session list response."""
    return ConversationSessionListResponse(
        items=[ConversationSessionResponse(**session) for session in sessions],
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


def build_daily_report_dates_response(
    payload: dict[str, Any],
) -> PodcastDailyReportDatesResponse:
    """Build the report dates response."""
    items = [DailyReportDateItem(**item) for item in payload.get("dates", [])]
    return PodcastDailyReportDatesResponse(
        items=items,
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
    summary_text = summary_result.get("summary") or summary_result.get(
        "summary_content",
        "",
    )
    model_used = summary_result.get("model_used") or summary_result.get("model_name")
    return PodcastSummaryResponse(
        episode_id=episode_id,
        summary=summary_text,
        version=summary_result["version"],
        confidence_score=None,
        transcript_used=True,
        generated_at=summary_result["generated_at"],
        word_count=len(summary_text.split()),
        model_used=model_used,
        processing_time=summary_result["processing_time"],
    )


def build_playback_state_response(
    *,
    payload: dict[str, Any],
    episode_id: int | None = None,
) -> PodcastPlaybackStateResponse:
    """Build the playback state response."""
    current_position = payload.get("current_position")
    if current_position is None:
        current_position = payload["progress"]
    return PodcastPlaybackStateResponse(
        episode_id=payload.get("episode_id", episode_id),
        current_position=current_position,
        is_playing=payload["is_playing"],
        playback_rate=payload["playback_rate"],
        play_count=payload["play_count"],
        last_updated_at=payload["last_updated_at"],
        progress_percentage=payload["progress_percentage"],
        remaining_time=payload["remaining_time"],
    )


def build_queue_response(payload: dict[str, Any]) -> PodcastQueueResponse:
    """Build the queue snapshot response."""
    return PodcastQueueResponse(
        current_episode_id=payload.get("current_episode_id"),
        revision=payload["revision"],
        updated_at=payload.get("updated_at"),
        items=[PodcastQueueItemResponse(**item) for item in payload.get("items", [])],
    )


def build_pending_transcriptions_response(
    payload: dict[str, Any],
) -> PodcastPendingTranscriptionsResponse:
    """Build the pending transcription list response."""
    return PodcastPendingTranscriptionsResponse(
        items=[
            PodcastPendingTranscriptionTaskResponse(**task)
            for task in payload.get("tasks", [])
        ],
        total=payload["total"],
    )


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


def build_highlight_list_response(payload: dict[str, Any]) -> HighlightListResponse:
    """Build the highlights list response."""
    items = [HighlightResponse(**item) for item in payload.get("items", [])]
    total = payload["total"]
    size = payload.get("per_page") or payload.get("size", 20)
    page = payload["page"]
    pages = (total + size - 1) // size if size > 0 else 0
    return HighlightListResponse(
        items=items,
        total=total,
        page=page,
        size=size,
        pages=pages,
    )
