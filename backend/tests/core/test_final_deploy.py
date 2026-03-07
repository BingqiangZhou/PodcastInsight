"""Core deployment sanity tests for current podcast architecture."""

from pathlib import Path

from fastapi import APIRouter


def test_service_files_exist() -> None:
    backend_root = Path(__file__).resolve().parents[2]
    required_paths = [
        "app/domains/podcast/models.py",
        "app/domains/podcast/services/__init__.py",
        "app/domains/podcast/api/routes.py",
        "app/domains/ai/llm_privacy.py",
        "app/domains/podcast/integration/security.py",
    ]
    for file in required_paths:
        assert (backend_root / file).exists(), f"Missing required file: {file}"

    repository_module = backend_root / "app/domains/podcast/repositories.py"
    repository_package = backend_root / "app/domains/podcast/repositories/__init__.py"
    assert repository_module.exists() or repository_package.exists(), (
        "Missing required podcast repository entrypoint: "
        "expected repositories.py or repositories/__init__.py"
    )


def test_api_routes_shape() -> None:
    from app.domains.podcast.api.routes import router

    assert isinstance(router, APIRouter)
    assert router.prefix == ""

    paths = [route.path for route in router.routes]
    assert any("/episodes" in path for path in paths)
    assert any("/reports" in path for path in paths)
    assert any("/queue" in path for path in paths)


def test_repository_contract() -> None:
    from app.domains.podcast.repositories import (
        PodcastEpisodeRepository,
        PodcastPlaybackRepository,
        PodcastSubscriptionRepository,
    )

    assert hasattr(PodcastSubscriptionRepository, "create_or_update_subscription")
    assert hasattr(PodcastSubscriptionRepository, "create_or_update_episode")
    assert hasattr(PodcastEpisodeRepository, "update_ai_summary")
    assert hasattr(PodcastPlaybackRepository, "update_playback_progress")


def test_specialized_service_contracts() -> None:
    from app.domains.podcast.services.episode_service import PodcastEpisodeService
    from app.domains.podcast.services.playback_service import PodcastPlaybackService
    from app.domains.podcast.services.subscription_service import (
        PodcastSubscriptionService,
    )
    from app.domains.podcast.services.summary_generation_service import (
        PodcastSummaryGenerationService,
    )

    assert hasattr(PodcastSubscriptionService, "add_subscription")
    assert hasattr(PodcastEpisodeService, "get_episode_with_summary")
    assert hasattr(PodcastPlaybackService, "update_playback_progress")
    assert hasattr(PodcastSummaryGenerationService, "regenerate_summary")
