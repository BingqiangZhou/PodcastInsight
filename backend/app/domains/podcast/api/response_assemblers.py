"""Response assembly helpers for podcast API routes."""

from __future__ import annotations

from typing import Any

from app.domains.podcast.episode_projections import (
    EpisodeProjectionLike,
    PodcastEpisodeDetailProjection,
    episode_projection_to_payload,
)
from app.domains.podcast.playback_queue_projections import (
    PlaybackStateProjectionLike,
    QueueProjectionLike,
    playback_state_projection_to_payload,
    queue_projection_to_payload,
)
from app.domains.podcast.schedule_projections import (
    ScheduleProjectionLike,
    schedule_projection_to_payload,
)
from app.domains.podcast.schemas import (
    ConversationSessionListResponse,
    ConversationSessionResponse,
    DailyReportDateItem,
    HighlightDatesResponse,
    HighlightListResponse,
    HighlightResponse,
    HighlightStatsResponse,
    PlaybackRateEffectiveResponse,
    PodcastBatchTranscriptionResponse,
    PodcastCheckNewEpisodesResponse,
    PodcastConversationClearResponse,
    PodcastConversationHistoryResponse,
    PodcastConversationMessage,
    PodcastConversationSendResponse,
    PodcastDailyReportDatesResponse,
    PodcastDailyReportResponse,
    PodcastEpisodeDetailResponse,
    PodcastEpisodeListResponse,
    PodcastEpisodeResponse,
    PodcastEpisodeTranscriptResponse,
    PodcastFeedResponse,
    PodcastPendingTranscriptionsResponse,
    PodcastPendingTranscriptionTaskResponse,
    PodcastPlaybackHistoryItemResponse,
    PodcastPlaybackHistoryListResponse,
    PodcastPlaybackStateResponse,
    PodcastProfileStatsResponse,
    PodcastQueueItemResponse,
    PodcastQueueResponse,
    PodcastStatsResponse,
    PodcastSummaryPendingResponse,
    PodcastSummaryResponse,
    PodcastSummaryStartResponse,
    PodcastTranscriptionCancelResponse,
    PodcastTranscriptionScheduleResponse,
    PodcastTranscriptionScheduleStatusResponse,
    ScheduleConfigResponse,
    SummaryModelInfo,
    SummaryModelsResponse,
)
from app.domains.podcast.transcription_schedule_projections import (
    BatchTranscriptionProjectionLike,
    CheckNewEpisodesProjectionLike,
    EpisodeTranscriptionScheduleProjectionLike,
    EpisodeTranscriptProjectionLike,
    PendingTranscriptionsProjectionLike,
    TranscriptionCancelProjectionLike,
    TranscriptionScheduleStatusProjectionLike,
    batch_transcription_projection_to_payload,
    check_new_episodes_projection_to_payload,
    episode_transcript_projection_to_payload,
    episode_transcription_schedule_projection_to_payload,
    pending_transcriptions_projection_to_payload,
    transcription_cancel_projection_to_payload,
    transcription_schedule_status_projection_to_payload,
)


def _episode_payloads(
    episodes: list[EpisodeProjectionLike],
) -> list[dict[str, Any]]:
    return [episode_projection_to_payload(episode) for episode in episodes]


def build_feed_response(
    episodes: list[EpisodeProjectionLike],
    *,
    has_more: bool,
    next_page: int | None,
    next_cursor: str | None,
    total: int,
) -> PodcastFeedResponse:
    """Build the feed response envelope."""
    return PodcastFeedResponse(
        items=[
            PodcastEpisodeResponse(**episode) for episode in _episode_payloads(episodes)
        ],
        has_more=has_more,
        next_page=next_page,
        next_cursor=next_cursor,
        total=total,
    )


def build_episode_list_response(
    episodes: list[EpisodeProjectionLike],
    *,
    total: int,
    page: int,
    size: int,
    subscription_id: int,
    next_cursor: str | None = None,
) -> PodcastEpisodeListResponse:
    """Build the paginated episode list response."""
    return PodcastEpisodeListResponse(
        items=[
            PodcastEpisodeResponse(**episode) for episode in _episode_payloads(episodes)
        ],
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
        items=[
            PodcastPlaybackHistoryItemResponse(**episode) for episode in episodes
        ],
        total=total,
        page=page,
        size=size,
        pages=(total + size - 1) // size,
        next_cursor=next_cursor,
    )


def build_episode_detail_response(
    episode: PodcastEpisodeDetailProjection | dict[str, Any],
) -> PodcastEpisodeDetailResponse:
    """Build the detailed episode response."""
    return PodcastEpisodeDetailResponse(**episode_projection_to_payload(episode))


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
        items=[build_conversation_session_response(session) for session in sessions],
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


def build_summary_start_response(
    *,
    episode_id: int,
    summary_status: str,
    accepted_at,
    message_en: str,
    message_zh: str,
) -> PodcastSummaryStartResponse:
    """Build the async summary queue acknowledgement response."""
    return PodcastSummaryStartResponse(
        episode_id=episode_id,
        summary_status=summary_status,
        accepted_at=accepted_at,
        message_en=message_en,
        message_zh=message_zh,
    )


def build_playback_state_response(
    *,
    payload: PlaybackStateProjectionLike,
    episode_id: int | None = None,
) -> PodcastPlaybackStateResponse:
    """Build the playback state response."""
    normalized = playback_state_projection_to_payload(payload)
    current_position = normalized.get("current_position")
    if current_position is None:
        current_position = normalized["progress"]
    return PodcastPlaybackStateResponse(
        episode_id=normalized.get("episode_id", episode_id),
        current_position=current_position,
        is_playing=normalized["is_playing"],
        playback_rate=normalized["playback_rate"],
        play_count=normalized["play_count"],
        last_updated_at=normalized["last_updated_at"],
        progress_percentage=normalized["progress_percentage"],
        remaining_time=normalized["remaining_time"],
    )


def build_existing_playback_state_response(
    payload: PlaybackStateProjectionLike,
) -> PodcastPlaybackStateResponse:
    """Build playback state response from an already-shaped payload."""
    return PodcastPlaybackStateResponse(**playback_state_projection_to_payload(payload))


def build_queue_response(payload: QueueProjectionLike) -> PodcastQueueResponse:
    """Build the queue snapshot response."""
    normalized = queue_projection_to_payload(payload)
    return PodcastQueueResponse(
        current_episode_id=normalized.get("current_episode_id"),
        revision=normalized["revision"],
        updated_at=normalized.get("updated_at"),
        items=[
            PodcastQueueItemResponse(**item) for item in normalized.get("items", [])
        ],
    )


def build_effective_playback_rate_response(
    payload: dict[str, Any],
) -> PlaybackRateEffectiveResponse:
    """Build the effective playback-rate response."""
    return PlaybackRateEffectiveResponse(**payload)


def build_schedule_config_response(
    payload: ScheduleProjectionLike,
) -> ScheduleConfigResponse:
    """Build one subscription schedule response."""
    return ScheduleConfigResponse(**schedule_projection_to_payload(payload))


def build_schedule_config_list_response(
    payloads: list[ScheduleProjectionLike],
) -> list[ScheduleConfigResponse]:
    """Build a list of subscription schedule responses."""
    return [build_schedule_config_response(payload) for payload in payloads]


def build_transcription_schedule_response(
    payload: EpisodeTranscriptionScheduleProjectionLike,
) -> PodcastTranscriptionScheduleResponse:
    """Build the episode transcription scheduling response."""
    return PodcastTranscriptionScheduleResponse(
        **episode_transcription_schedule_projection_to_payload(payload),
    )


def build_episode_transcript_response(
    payload: EpisodeTranscriptProjectionLike,
) -> PodcastEpisodeTranscriptResponse:
    """Build the episode transcript response."""
    return PodcastEpisodeTranscriptResponse(
        **episode_transcript_projection_to_payload(payload)
    )


def build_batch_transcription_response(
    payload: BatchTranscriptionProjectionLike,
) -> PodcastBatchTranscriptionResponse:
    """Build the batch transcription response."""
    return PodcastBatchTranscriptionResponse(
        **batch_transcription_projection_to_payload(payload)
    )


def build_transcription_schedule_status_response(
    payload: TranscriptionScheduleStatusProjectionLike,
) -> PodcastTranscriptionScheduleStatusResponse:
    """Build the transcription schedule-status response."""
    return PodcastTranscriptionScheduleStatusResponse(
        **transcription_schedule_status_projection_to_payload(payload),
    )


def build_transcription_cancel_response(
    payload: TranscriptionCancelProjectionLike,
) -> PodcastTranscriptionCancelResponse:
    """Build the transcription cancellation response."""
    return PodcastTranscriptionCancelResponse(
        **transcription_cancel_projection_to_payload(payload)
    )


def build_check_new_episodes_response(
    payload: CheckNewEpisodesProjectionLike,
) -> PodcastCheckNewEpisodesResponse:
    """Build the recently-published episode scheduling response."""
    return PodcastCheckNewEpisodesResponse(
        **check_new_episodes_projection_to_payload(payload)
    )


def build_pending_transcriptions_response(
    payload: PendingTranscriptionsProjectionLike,
) -> PodcastPendingTranscriptionsResponse:
    """Build the pending transcription list response."""
    normalized = pending_transcriptions_projection_to_payload(payload)
    return PodcastPendingTranscriptionsResponse(
        items=[
            PodcastPendingTranscriptionTaskResponse(**task)
            for task in normalized.get("tasks", [])
        ],
        total=normalized["total"],
    )


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


def build_highlight_dates_response(payload: dict[str, Any]) -> HighlightDatesResponse:
    """Build the highlight dates response."""
    return HighlightDatesResponse(dates=payload.get("dates", []))


def build_highlight_stats_response(payload: dict[str, Any]) -> HighlightStatsResponse:
    """Build the highlight stats response."""
    return HighlightStatsResponse(**payload)
