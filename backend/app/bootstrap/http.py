"""HTTP and middleware bootstrap."""

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.core.config import get_settings
from app.core.database import check_db_readiness
from app.core.exceptions import setup_exception_handlers
from app.core.middleware import RequestLoggingMiddleware
from app.core.redis import get_shared_redis
from app.http.errors import register_admin_http_exception_handler


logger = logging.getLogger(__name__)


def configure_middlewares(app: FastAPI) -> None:
    """Register middleware stack."""
    settings = get_settings()

    app.add_middleware(RequestLoggingMiddleware, slow_threshold=5.0)
    logger.debug("Request logging middleware enabled")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.ALLOWED_HOSTS,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "Accept", "X-Requested-With"],
    )
    from app.admin.first_run import first_run_middleware

    app.middleware("http")(first_run_middleware)


def configure_exception_handlers(app: FastAPI) -> None:
    """Register shared and admin-specific exception handlers."""
    from app.admin.csrf import CSRFException
    from app.admin.exception_handlers import csrf_exception_handler

    setup_exception_handlers(app)
    register_admin_http_exception_handler(app)
    app.add_exception_handler(CSRFException, csrf_exception_handler)


def register_internal_routes(app: FastAPI) -> None:
    """Register health and root routes."""
    settings = get_settings()

    @app.get("/")
    async def root():
        return {
            "message": "Personal AI Assistant API is running",
            "status": "healthy",
            "version": settings.VERSION,
            "docs": "/api/v1/docs",
            "health": "/health",
        }

    @app.get("/health")
    async def health_check():
        return {"status": "healthy"}

    @app.get(f"{settings.API_V1_STR}/health")
    async def health_check_v1():
        return {"status": "healthy"}

    @app.get(f"{settings.API_V1_STR}/health/ready")
    async def readiness_check():
        redis_status = await get_shared_redis().check_health()
        db_status = await check_db_readiness()
        overall_status = (
            "healthy"
            if db_status["status"] == "healthy" and redis_status["status"] == "healthy"
            else "unhealthy"
        )
        payload = {
            "status": overall_status,
            "db": db_status,
            "redis": redis_status,
        }
        status_code = 200 if overall_status == "healthy" else 503
        return JSONResponse(status_code=status_code, content=payload)
