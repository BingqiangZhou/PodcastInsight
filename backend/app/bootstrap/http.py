"""HTTP and middleware bootstrap."""

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.core.config import get_settings
from app.core.database import check_db_readiness, get_db_pool_snapshot
from app.core.exceptions import setup_exception_handlers
from app.core.middleware import (
    RequestObservabilityMiddleware,
    get_performance_middleware,
)
from app.core.middleware.rate_limit import RateLimitConfig, setup_rate_limiting
from app.core.observability import ObservabilityThresholds, build_observability_snapshot
from app.core.redis import get_redis_runtime_metrics, get_shared_redis
from app.http.errors import register_admin_http_exception_handler


logger = logging.getLogger(__name__)


def configure_middlewares(app: FastAPI) -> None:
    """Register middleware stack."""
    settings = get_settings()

    # Rate limiting middleware (added first, executes last)
    rate_limit_config = RateLimitConfig(
        requests_per_minute=settings.RATE_LIMIT_REQUESTS_PER_MINUTE,
        requests_per_hour=settings.RATE_LIMIT_REQUESTS_PER_HOUR,
        burst_size=10,
        enabled=settings.RATE_LIMIT_ENABLED,
        whitelist_paths={
            "/api/v1/health",
            "/api/v1/health/ready",
            "/health",
            "/docs",
            "/redoc",
            "/openapi.json",
            "/metrics",
            "/metrics/summary",
        },
    )
    try:
        redis_client = get_shared_redis()
        setup_rate_limiting(app, redis_client=redis_client, config=rate_limit_config)
        logger.info("Rate limiting middleware enabled with Redis backend")
    except Exception as e:
        logger.warning("Rate limiting falling back to in-memory: %s", e)
        setup_rate_limiting(app, redis_client=None, config=rate_limit_config)
        logger.info("Rate limiting middleware enabled with in-memory backend")

    app.state.performance_metrics_store = get_performance_middleware(app)
    app.add_middleware(RequestObservabilityMiddleware, slow_threshold=5.0)
    logger.debug("Request observability middleware enabled")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.ALLOWED_HOSTS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
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
    """Register health, root, and metrics routes."""
    settings = get_settings()
    observability_thresholds = ObservabilityThresholds(
        api_p95_ms=settings.OBS_ALERT_API_P95_MS,
        api_error_rate=settings.OBS_ALERT_API_ERROR_RATE,
        db_pool_occupancy_ratio=settings.OBS_ALERT_DB_POOL_OCCUPANCY_RATIO,
        redis_command_avg_ms=settings.OBS_ALERT_REDIS_COMMAND_AVG_MS,
        redis_command_max_ms=settings.OBS_ALERT_REDIS_COMMAND_MAX_MS,
        redis_cache_hit_rate_min=settings.OBS_ALERT_REDIS_CACHE_HIT_RATE_MIN,
        redis_cache_lookups_min=settings.OBS_ALERT_REDIS_CACHE_LOOKUPS_MIN,
    )

    async def build_metrics_payload() -> dict:
        middleware = get_performance_middleware(app)
        if not middleware:
            return {"error": "Performance monitoring not enabled"}

        metrics = middleware.get_metrics()
        db_pool = get_db_pool_snapshot()
        redis_runtime = await get_redis_runtime_metrics()
        observability = build_observability_snapshot(
            performance_metrics=metrics,
            db_pool=db_pool,
            redis_runtime=redis_runtime,
            thresholds=observability_thresholds,
        )
        metrics["db_pool"] = db_pool
        metrics["redis_runtime"] = redis_runtime
        metrics["observability"] = observability
        return metrics

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

    @app.get("/metrics", include_in_schema=False)
    async def get_metrics():
        return await build_metrics_payload()

    @app.get("/metrics/summary", include_in_schema=False)
    async def get_metrics_summary():
        payload = await build_metrics_payload()
        if "error" in payload:
            return payload
        return payload["observability"]
