"""Celery route snapshot tests for podcast task queues."""

from app.core.celery_app import celery_app


def test_transcription_and_summary_routes_are_explicit():
    routes = celery_app.conf.task_routes or {}

    transcription_task = "app.domains.podcast.tasks.transcription.process_podcast_episode_with_transcription"
    summary_task = (
        "app.domains.podcast.tasks.summary_generation.generate_summary_for_episode"
    )

    assert transcription_task in routes
    assert routes[transcription_task]["queue"] == "transcription"

    assert summary_task in routes
    assert routes[summary_task]["queue"] == "ai_generation"
