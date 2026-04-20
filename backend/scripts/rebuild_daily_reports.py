"""Rebuild podcast daily reports using current generation rules.

Usage:
  uv run python scripts/rebuild_daily_reports.py --scope all-users --dry-run
  uv run python scripts/rebuild_daily_reports.py --scope all-users
"""

from __future__ import annotations

import argparse
import asyncio
import time
from collections import defaultdict
from dataclasses import dataclass
from datetime import date

from sqlalchemy import delete, select

from app.core.database import async_session_factory
from app.domains.podcast.models import PodcastDailyReport, PodcastDailyReportItem
from app.domains.podcast.services.content_service import DailyReportService


@dataclass(slots=True)
class RebuildFailure:
    user_id: int
    phase: str
    error: str


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Rebuild podcast daily reports to use same-day published_at window only."
        )
    )
    parser.add_argument(
        "--scope",
        choices=["all-users"],
        default="all-users",
        help="Rebuild scope. Currently only all-users is supported.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Only inspect and print impact. No data is changed.",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=100,
        help="User batch size for progress logging.",
    )
    return parser.parse_args()


async def _collect_user_report_dates() -> dict[int, list[date]]:
    async with async_session_factory() as session:
        stmt = select(
            PodcastDailyReport.user_id, PodcastDailyReport.report_date
        ).order_by(
            PodcastDailyReport.user_id.asc(),
            PodcastDailyReport.report_date.asc(),
        )
        rows = (await session.execute(stmt)).all()

    dates_by_user: dict[int, list[date]] = defaultdict(list)
    for user_id, report_date in rows:
        dates_by_user[user_id].append(report_date)
    return dict(dates_by_user)


async def _clear_user_reports(user_id: int) -> None:
    async with async_session_factory() as session:
        await session.execute(
            delete(PodcastDailyReportItem).where(
                PodcastDailyReportItem.user_id == user_id
            )
        )
        await session.execute(
            delete(PodcastDailyReport).where(PodcastDailyReport.user_id == user_id)
        )
        await session.commit()


async def _rebuild_user_reports(user_id: int, report_dates: list[date]) -> None:
    async with async_session_factory() as session:
        service = DailyReportService(session, user_id=user_id)
        for report_date in report_dates:
            await service.generate_daily_report(
                target_date=report_date,
                rebuild=True,
            )


def _format_seconds(value: float) -> str:
    return f"{value:.2f}s"


async def _run() -> int:
    args = _parse_args()
    started_at = time.perf_counter()

    dates_by_user = await _collect_user_report_dates()
    user_ids = sorted(dates_by_user.keys())
    total_dates = sum(len(dates) for dates in dates_by_user.values())

    print(f"[Rebuild] scope={args.scope}")
    print(
        f"[Rebuild] discovered users={len(user_ids)} total_report_dates={total_dates} "
        f"batch_size={args.batch_size}"
    )

    if args.dry_run:
        for user_id in user_ids:
            print(f"[DryRun] user={user_id} report_dates={len(dates_by_user[user_id])}")
        elapsed = _format_seconds(time.perf_counter() - started_at)
        print(f"[DryRun] completed in {elapsed}")
        return 0

    failures: list[RebuildFailure] = []
    phase_a_success_users = 0
    phase_b_success_users = 0
    rebuilt_dates = 0

    print("[Phase A] Clearing existing reports/items per user...")
    for index, user_id in enumerate(user_ids, start=1):
        if index % max(1, args.batch_size) == 0 or index == len(user_ids):
            print(f"[Phase A] progress {index}/{len(user_ids)}")
        try:
            await _clear_user_reports(user_id)
            phase_a_success_users += 1
        except Exception as exc:  # pragma: no cover - defensive logging path
            failures.append(
                RebuildFailure(user_id=user_id, phase="clear", error=str(exc))
            )

    blocked_users = {
        failure.user_id for failure in failures if failure.phase == "clear"
    }
    rebuild_user_ids = [user_id for user_id in user_ids if user_id not in blocked_users]

    print("[Phase B] Rebuilding reports per user/date...")
    for index, user_id in enumerate(rebuild_user_ids, start=1):
        if index % max(1, args.batch_size) == 0 or index == len(rebuild_user_ids):
            print(f"[Phase B] progress {index}/{len(rebuild_user_ids)}")

        user_start = time.perf_counter()
        report_dates = dates_by_user[user_id]
        try:
            await _rebuild_user_reports(user_id, report_dates)
            phase_b_success_users += 1
            rebuilt_dates += len(report_dates)
            user_elapsed = _format_seconds(time.perf_counter() - user_start)
            print(
                f"[Phase B] user={user_id} rebuilt_dates={len(report_dates)} elapsed={user_elapsed}"
            )
        except Exception as exc:  # pragma: no cover - defensive logging path
            failures.append(
                RebuildFailure(user_id=user_id, phase="rebuild", error=str(exc))
            )

    elapsed = _format_seconds(time.perf_counter() - started_at)
    print("[Rebuild] Completed")
    print(
        "[Rebuild] summary "
        f"users_total={len(user_ids)} "
        f"users_cleared={phase_a_success_users} "
        f"users_rebuilt={phase_b_success_users} "
        f"dates_rebuilt={rebuilt_dates} "
        f"failures={len(failures)} "
        f"elapsed={elapsed}"
    )

    if failures:
        print("[Rebuild] failure details:")
        for failure in failures:
            print(
                f"  - user={failure.user_id} phase={failure.phase} error={failure.error}"
            )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(_run()))
