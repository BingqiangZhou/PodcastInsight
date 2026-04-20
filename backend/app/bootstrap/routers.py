"""Router registration bootstrap."""

from fastapi import FastAPI

from app.core.config import get_settings


def include_application_routers(app: FastAPI) -> None:
    """Register all HTTP routers without changing public API paths."""
    settings = get_settings()

    from app.admin.router import router as admin_router
    from app.domains.podcast.routes.routes import router as podcast_router
    from app.domains.podcast.routes.routes_subscriptions import (
        router as podcast_subscription_router,
    )

    app.include_router(
        podcast_router,
        prefix=f"{settings.API_V1_STR}/podcasts",
        tags=["podcasts"],
    )
    app.include_router(
        podcast_subscription_router,
        prefix=f"{settings.API_V1_STR}/podcasts/subscriptions",
        tags=["podcast-subscriptions"],
    )
    app.include_router(
        admin_router,
        prefix=f"{settings.API_V1_STR}/admin",
        tags=["admin"],
    )
