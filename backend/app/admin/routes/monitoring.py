"""Admin monitoring routes."""

from __future__ import annotations

from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse

from app.admin.auth import admin_required
from app.admin.monitoring import SystemMonitorService
from app.admin.routes._shared import get_templates
from app.core.database import check_db_readiness, get_db_pool_snapshot
from app.core.observability import build_observability_snapshot
from app.core.redis import get_redis_runtime_metrics, get_shared_redis
from app.domains.user.models import User


router = APIRouter()
templates = get_templates()
monitor_service = SystemMonitorService()


async def _runtime_observability_payload(request: Request) -> dict:
    db_pool = get_db_pool_snapshot()
    redis_runtime = await get_redis_runtime_metrics()
    readiness = {
        "db": await check_db_readiness(),
        "redis": await get_shared_redis().check_health(),
    }
    observability = build_observability_snapshot(
        performance_metrics={"summary": {}},
        db_pool=db_pool,
        redis_runtime=redis_runtime,
    )
    return {
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
