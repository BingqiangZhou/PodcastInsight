"""Shared helpers for podcast transcription route modules."""

from fastapi import HTTPException, status

from app.domains.podcast.models import PodcastEpisode
from app.domains.podcast.schemas import PodcastTranscriptionResponse
from app.domains.podcast.services.episode_service import PodcastEpisodeService


def status_value(status_obj) -> str:
    """Normalize enum-like status values to strings."""
    return status_obj.value if hasattr(status_obj, "value") else str(status_obj)


async def validate_episode_and_permission(
    episode_id: int,
    episode_service: PodcastEpisodeService,
) -> PodcastEpisode:
    """Validate episode existence and user ownership."""
    episode = await episode_service.get_episode_by_id(episode_id)
    if not episode:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Episode {episode_id} not found",
        )
    return episode


def build_transcription_response(task, episode) -> PodcastTranscriptionResponse:
    """Build standard transcription response."""
    return PodcastTranscriptionResponse(
        id=task.id,
        episode_id=task.episode_id,
        status=status_value(task.status),
        progress_percentage=task.progress_percentage,
        original_audio_url=task.original_audio_url,
        original_file_size=task.original_file_size,
        transcript_word_count=task.transcript_word_count,
        transcript_duration=task.transcript_duration,
        transcript_content=task.transcript_content,
        error_message=task.error_message,
        error_code=task.error_code,
        download_time=task.download_time,
        conversion_time=task.conversion_time,
        transcription_time=task.transcription_time,
        chunk_size_mb=task.chunk_size_mb,
        model_used=task.model_used,
        created_at=task.created_at,
        started_at=task.started_at,
        completed_at=task.completed_at,
        updated_at=task.updated_at,
        duration_seconds=task.duration_seconds,
        total_processing_time=task.total_processing_time,
        summary_content=task.summary_content,
        summary_model_used=task.summary_model_used,
        summary_word_count=task.summary_word_count,
        summary_processing_time=task.summary_processing_time,
        summary_error_message=task.summary_error_message,
        debug_message=(task.chunk_info or {}).get("debug_message"),
        episode={
            "id": episode.id,
            "title": episode.title,
            "audio_url": episode.audio_url,
            "audio_duration": episode.audio_duration,
        },
    )
