from datetime import UTC, datetime
from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient

from app.core.providers import (
    get_podcast_episode_service,
    get_podcast_subscription_service,
    get_token_user_id,
    get_transcription_workflow_service,
)
from app.core.security import get_token_from_request
from app.domains.podcast.transcription_schedule_projections import (
    BatchTranscriptionDetailProjection,
    BatchTranscriptionProjection,
    CheckNewEpisodesDetailProjection,
    CheckNewEpisodesProjection,
    EpisodeTranscriptionScheduleProjection,
    EpisodeTranscriptProjection,
    PendingTranscriptionsProjection,
    PendingTranscriptionTaskProjection,
    TranscriptionCancelProjection,
    TranscriptionScheduleStatusProjection,
)
from app.main import app


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture(autouse=True)
def override_auth_dependencies():
    app.dependency_overrides[get_token_from_request] = lambda: {"sub": "123"}
    app.dependency_overrides[get_token_user_id] = lambda: 123
    yield
    app.dependency_overrides.pop(get_token_from_request, None)
    app.dependency_overrides.pop(get_token_user_id, None)


@pytest.fixture
def mock_episode_service():
    service = AsyncMock()
    app.dependency_overrides[get_podcast_episode_service] = lambda: service
    yield service
    app.dependency_overrides.pop(get_podcast_episode_service, None)


@pytest.fixture
def mock_subscription_service():
    service = AsyncMock()
    app.dependency_overrides[get_podcast_subscription_service] = lambda: service
    yield service
    app.dependency_overrides.pop(get_podcast_subscription_service, None)


@pytest.fixture
def mock_workflow_service():
    service = AsyncMock()
    app.dependency_overrides[get_transcription_workflow_service] = lambda: service
    yield service
    app.dependency_overrides.pop(get_transcription_workflow_service, None)


def test_schedule_episode_transcription_returns_assembled_response(
    client: TestClient,
    mock_workflow_service: AsyncMock,
):
    now = datetime.now(UTC)
    mock_workflow_service.schedule_episode_transcription.return_value = (
        EpisodeTranscriptionScheduleProjection(
            status="scheduled",
            message="Transcription task started",
            task_id=99,
            episode_id=7,
            action="created",
            scheduled_at=now,
        )
    )

    response = client.post(
        "/api/v1/podcasts/episodes/7/transcribe/schedule",
        json={"force": False, "frequency": "manual"},
    )

    assert response.status_code == 201
    payload = response.json()
    assert payload["status"] == "scheduled"
    assert payload["task_id"] == 99
    assert payload["episode_id"] == 7


def test_get_episode_transcript_returns_assembled_response(
    client: TestClient,
    mock_workflow_service: AsyncMock,
):
    mock_workflow_service.get_episode_transcript_payload.return_value = (
        EpisodeTranscriptProjection(
            episode_id=8,
            episode_title="Episode 8",
            transcript_length=512,
            transcript="hello world",
            status="success",
        )
    )

    response = client.get("/api/v1/podcasts/episodes/8/transcript")

    assert response.status_code == 200
    payload = response.json()
    assert payload["episode_title"] == "Episode 8"
    assert payload["transcript_length"] == 512


def test_batch_transcribe_subscription_returns_assembled_response(
    client: TestClient,
    mock_workflow_service: AsyncMock,
):
    now = datetime.now(UTC)
    mock_workflow_service.batch_transcribe_subscription.return_value = (
        BatchTranscriptionProjection(
            subscription_id=4,
            total=2,
            scheduled=1,
            skipped=1,
            errors=0,
            details=[
                BatchTranscriptionDetailProjection(
                    episode_id=11,
                    episode_title="Episode 11",
                    status="scheduled",
                    task_id=301,
                    message="Transcription task started",
                    action="created",
                    scheduled_at=now,
                ),
                BatchTranscriptionDetailProjection(
                    episode_id=12,
                    episode_title="Episode 12",
                    status="skipped",
                    task_id=302,
                    message="Transcription already exists",
                    reason="Already transcribed, use force=true to regenerate",
                    action="reused_completed",
                ),
            ],
        )
    )

    response = client.post(
        "/api/v1/podcasts/subscriptions/4/transcribe/batch",
        json=True,
    )

    assert response.status_code == 201
    payload = response.json()
    assert payload["subscription_id"] == 4
    assert payload["details"][0]["status"] == "scheduled"
    assert payload["details"][1]["reason"] == (
        "Already transcribed, use force=true to regenerate"
    )


def test_get_schedule_status_returns_assembled_response(
    client: TestClient,
    mock_workflow_service: AsyncMock,
):
    now = datetime.now(UTC)
    mock_workflow_service.get_schedule_status.return_value = (
        TranscriptionScheduleStatusProjection(
            episode_id=13,
            episode_title="Episode 13",
            status="completed",
            has_transcript=True,
            transcript_preview="preview...",
            task_id=501,
            progress=100.0,
            created_at=now,
            updated_at=now,
            completed_at=now,
            transcript_word_count=120,
            has_summary=True,
            summary_word_count=30,
            error_message=None,
        )
    )

    response = client.get(
        "/api/v1/podcasts/episodes/13/transcription/schedule-status"
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "completed"
    assert payload["has_transcript"] is True
    assert payload["summary_word_count"] == 30


def test_cancel_transcription_returns_assembled_response(
    client: TestClient,
    mock_workflow_service: AsyncMock,
):
    mock_workflow_service.cancel_episode_transcription.return_value = (
        TranscriptionCancelProjection(
            success=True,
            message="Transcription cancelled",
        )
    )

    response = client.post("/api/v1/podcasts/episodes/21/transcription/cancel")

    assert response.status_code == 200
    payload = response.json()
    assert payload["success"] is True
    assert payload["message"] == "Transcription cancelled"


def test_check_new_episodes_returns_assembled_response(
    client: TestClient,
    mock_workflow_service: AsyncMock,
):
    mock_workflow_service.check_and_transcribe_new_episodes.return_value = (
        CheckNewEpisodesProjection(
            status="completed",
            message="Scheduled 1 new episodes for transcription",
            processed=2,
            scheduled=1,
            errors=1,
            details=[
                CheckNewEpisodesDetailProjection(
                    episode_id=71,
                    status="scheduled",
                    task_id=801,
                ),
                CheckNewEpisodesDetailProjection(
                    episode_id=72,
                    status="error",
                    error="boom",
                ),
            ],
        )
    )

    response = client.post(
        "/api/v1/podcasts/subscriptions/5/check-new-episodes",
        json=24,
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["processed"] == 2
    assert payload["details"][0]["task_id"] == 801
    assert payload["details"][1]["error"] == "boom"


def test_get_pending_transcriptions_returns_assembled_response(
    client: TestClient,
    mock_workflow_service: AsyncMock,
):
    now = datetime.now(UTC)
    mock_workflow_service.list_pending_transcriptions.return_value = (
        PendingTranscriptionsProjection(
            total=1,
            tasks=[
                PendingTranscriptionTaskProjection(
                    task_id=901,
                    episode_id=33,
                    status="pending",
                    progress=15.5,
                    created_at=now,
                    updated_at=now,
                )
            ],
        )
    )

    response = client.get("/api/v1/podcasts/transcriptions/pending")

    assert response.status_code == 200
    payload = response.json()
    assert payload["total"] == 1
    assert payload["tasks"][0]["task_id"] == 901
    assert payload["tasks"][0]["status"] == "pending"
