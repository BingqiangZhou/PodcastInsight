"""Shared episode projection mapping helpers for podcast services."""

from __future__ import annotations

from typing import Any

from app.core.utils import filter_thinking_content
from app.domains.podcast.episode_projections import PodcastEpisodeProjection
from app.domains.podcast.models import PodcastEpisode


def _subscription_image_url(episode: PodcastEpisode) -> str | None:
    if episode.subscription and episode.subscription.config:
        value = episode.subscription.config.get("image_url")
        return value if isinstance(value, str) and value else None
    return None


def _is_played(playback: Any, audio_duration: int | None) -> bool:
    return bool(
        playback
        and playback.current_position
        and audio_duration
        and playback.current_position >= audio_duration * 0.9,
    )


def build_episode_response(
    episode: PodcastEpisode,
    playback: Any,
    *,
    include_extended_fields: bool,
) -> PodcastEpisodeProjection:
    """Build one typed episode projection with optional extended fields."""
    subscription_image_url = _subscription_image_url(episode)
    image_url = episode.image_url or subscription_image_url
    cleaned_summary = filter_thinking_content(episode.ai_summary)

    payload: dict[str, Any] = {
        "id": episode.id,
        "subscription_id": episode.subscription_id,
        "subscription_title": episode.subscription.title
        if episode.subscription
        else None,
        "subscription_image_url": subscription_image_url,
        "title": episode.title,
        "description": episode.description,
        "audio_url": episode.audio_url,
        "audio_duration": episode.audio_duration,
        "published_at": episode.published_at,
        "image_url": image_url,
        "ai_summary": cleaned_summary,
        "is_played": _is_played(playback, episode.audio_duration),
        "status": episode.status,
        "created_at": episode.created_at,
        "updated_at": episode.updated_at,
    }

    if not include_extended_fields:
        return PodcastEpisodeProjection.model_validate(payload)

    payload.update(
        {
            "audio_file_size": episode.audio_file_size,
            "item_link": episode.item_link,
            "transcript_url": episode.transcript_url,
            "transcript_content": episode.transcript.transcript_content if episode.transcript else None,
            "summary_version": episode.summary_version,
            "ai_confidence_score": episode.ai_confidence_score,
            "play_count": episode.play_count,
            "last_played_at": playback.last_updated_at
            if playback
            else episode.last_played_at,
            "season": episode.season,
            "episode_number": episode.episode_number,
            "explicit": episode.explicit,
            "status": episode.status,
            "metadata": episode.metadata_json,
            "playback_position": playback.current_position if playback else None,
            "is_playing": playback.is_playing if playback else False,
            "playback_rate": playback.playback_rate if playback else 1.0,
        },
    )
    return PodcastEpisodeProjection.model_validate(payload)


def build_episode_responses(
    episodes: list[PodcastEpisode],
    playback_states: dict[int, Any],
    *,
    include_extended_fields: bool,
) -> list[PodcastEpisodeProjection]:
    """Build typed episode projections for one page result."""
    return [
        build_episode_response(
            episode=episode,
            playback=playback_states.get(episode.id),
            include_extended_fields=include_extended_fields,
        )
        for episode in episodes
    ]
