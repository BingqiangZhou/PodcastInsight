"""Podcast daily report routes."""

from datetime import date

from fastapi import APIRouter, Depends, Query

from app.domains.podcast.api.dependencies import get_daily_report_service
from app.domains.podcast.api.response_assemblers import (
    build_daily_report_dates_response,
    build_daily_report_response,
)
from app.domains.podcast.schemas import (
    PodcastDailyReportDatesResponse,
    PodcastDailyReportResponse,
)
from app.domains.podcast.services.daily_report_service import DailyReportService


router = APIRouter(prefix="")


@router.get(
    "/reports/daily",
    response_model=PodcastDailyReportResponse,
    summary="Get daily podcast report",
)
async def get_daily_report(
    report_date: date | None = Query(None, alias="date", description="YYYY-MM-DD"),
    service: DailyReportService = Depends(get_daily_report_service),
):
    payload = await service.get_daily_report(target_date=report_date)
    return build_daily_report_response(payload)


@router.post(
    "/reports/daily/generate",
    response_model=PodcastDailyReportResponse,
    summary="Generate daily podcast report",
)
async def generate_daily_report(
    report_date: date | None = Query(None, alias="date", description="YYYY-MM-DD"),
    rebuild: bool = Query(
        False,
        description="Rebuild report items for this date before regenerating",
    ),
    service: DailyReportService = Depends(get_daily_report_service),
):
    payload = await service.generate_daily_report(
        target_date=report_date,
        rebuild=rebuild,
    )
    return build_daily_report_response(payload)


@router.get(
    "/reports/daily/dates",
    response_model=PodcastDailyReportDatesResponse,
    summary="List available daily report dates",
)
async def list_daily_report_dates(
    page: int = Query(1, ge=1, description="Page number"),
    size: int = Query(30, ge=1, le=100, description="Page size"),
    service: DailyReportService = Depends(get_daily_report_service),
):
    payload = await service.list_report_dates(page=page, size=size)
    return build_daily_report_dates_response(payload)
