"""Admin monitoring routes."""

from __future__ import annotations

from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse

from app.admin.auth import admin_required
from app.admin.monitoring import SystemMonitorService
from app.admin.routes._shared import get_templates
from app.core.config import settings
from app.core.database import check_db_readiness, get_db_pool_snapshot
from app.core.middleware import get_performance_middleware
from app.core.observability import ObservabilityThresholds, build_observability_snapshot
from app.core.redis import get_redis_runtime_metrics, get_shared_redis
from app.domains.user.models import User


router = APIRouter()
templates = get_templates()
monitor_service = SystemMonitorService()

_thresholds = ObservabilityThresholds(
    api_p95_ms=settings.OBS_ALERT_API_P95_MS,
    api_error_rate=settings.OBS_ALERT_API_ERROR_RATE,
    db_pool_occupancy_ratio=settings.OBS_ALERT_DB_POOL_OCCUPANCY_RATIO,
    redis_command_avg_ms=settings.OBS_ALERT_REDIS_COMMAND_AVG_MS,
    redis_command_max_ms=settings.OBS_ALERT_REDIS_COMMAND_MAX_MS,
    redis_cache_hit_rate_min=settings.OBS_ALERT_REDIS_CACHE_HIT_RATE_MIN,
    redis_cache_lookups_min=settings.OBS_ALERT_REDIS_CACHE_LOOKUPS_MIN,
)


async def _runtime_observability_payload(request: Request) -> dict:
    perf_store = get_performance_middleware(request.app)
    performance_metrics = perf_store.get_metrics() if perf_store else {"summary": {}}
    db_pool = get_db_pool_snapshot()
    redis_runtime = get_redis_runtime_metrics()
    readiness = {
        "db": await check_db_readiness(),
        "redis": await get_shared_redis().check_health(),
    }
    observability = build_observability_snapshot(
        performance_metrics=performance_metrics,
        db_pool=db_pool,
        redis_runtime=redis_runtime,
        thresholds=_thresholds,
    )
    return {
        "performance_metrics": performance_metrics,
        "db_pool": db_pool,
        "redis_runtime": redis_runtime,
        "readiness": readiness,
        "observability": observability,
    }


@router.get("/monitoring", response_class=HTMLResponse)
async def monitoring_page(
    request: Request,
    user: User = Depends(admin_required),
):
    """Render monitoring dashboard page."""
    return templates.TemplateResponse(
        "monitoring.html",
        {
            "request": request,
            "user": user,
            "messages": [],
        },
    )


@router.get("/api/monitoring/all")
async def get_all_metrics(
    request: Request,
    _: User = Depends(admin_required),
):
    """Return system + runtime observability metrics."""
    payload = monitor_service.get_all_metrics()
    payload["runtime"] = await _runtime_observability_payload(request)
    return payload


@router.get("/api/monitoring/system-info")
async def get_system_info(
    _: User = Depends(admin_required),
):
    return monitor_service.get_system_info()


@router.get("/api/monitoring/cpu")
async def get_cpu_metrics(
    _: User = Depends(admin_required),
):
    return monitor_service.get_cpu_metrics()


@router.get("/api/monitoring/memory")
async def get_memory_metrics(
    _: User = Depends(admin_required),
):
    return monitor_service.get_memory_metrics()


@router.get("/api/monitoring/disk")
async def get_disk_metrics(
    _: User = Depends(admin_required),
):
    return monitor_service.get_disk_metrics()


@router.get("/api/monitoring/network")
async def get_network_metrics(
    _: User = Depends(admin_required),
):
    return monitor_service.get_network_metrics()
