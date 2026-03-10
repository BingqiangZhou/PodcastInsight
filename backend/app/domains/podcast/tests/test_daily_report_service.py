from datetime import UTC, date, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock

import pytest

from app.domains.podcast.services.daily_report_service import DailyReportService
from app.domains.podcast.services.daily_report_summary_extractor import (
    extract_one_line_summary,
)


class _ScalarOneOrNoneResult:
    def __init__(self, value):
        self._value = value

    def scalar_one_or_none(self):
        return self._value


class _ScalarsAllResult:
    def __init__(self, values):
        self._values = values

    def scalars(self):
        return self

    def all(self):
        return self._values


class _FakeTaskOrchestrationService:
    def __init__(self, db):
        self.db = db
        self.episode_processing_calls = []

    def enqueue_episode_processing(self, *, episode_id: int, user_id: int):
        self.episode_processing_calls.append(
            {"episode_id": episode_id, "user_id": user_id}
        )


@pytest.mark.asyncio
async def test_compute_window_utc_for_shanghai_day():
    service = DailyReportService(db=AsyncMock(), user_id=1)
    window_start, window_end = service._compute_window_utc(date(2026, 2, 20))

    assert window_start == datetime(2026, 2, 19, 16, 0, tzinfo=UTC)
    assert window_end == datetime(2026, 2, 20, 16, 0, tzinfo=UTC)


def test_published_window_boundary_is_start_inclusive_end_exclusive():
    service = DailyReportService(db=AsyncMock(), user_id=1)
    window_start, window_end = service._compute_window_utc(date(2026, 2, 20))

    at_start = window_start
    before_start = window_start - timedelta(seconds=1)
    before_end = window_end - timedelta(seconds=1)
    at_end = window_end

    assert at_start >= window_start
    assert at_start < window_end
    assert before_start < window_start
    assert before_end < window_end
    assert not (at_end < window_end)


def test_extract_one_line_summary_falls_back_to_first_sentence():
    summary = "First sentence should be used. Second sentence should be ignored."
    result = extract_one_line_summary(summary)

    assert result.startswith("First sentence should be used")


def test_extract_one_line_summary_returns_full_executive_section():
    summary = """
## 1. 一句话摘要 (Executive Summary)
这是第一句。这是第二句。
这是第三句。

## 2. 核心观点与洞察
- 后续内容
"""
    result = extract_one_line_summary(summary)

    assert result == "这是第一句。这是第二句。 这是第三句。"


def test_extract_one_line_summary_supports_numbered_heading_without_hash():
    summary = """
1. 一句话摘要
这是一整段摘要。包含第二句。
2. 核心观点与洞察
后续内容
"""
    result = extract_one_line_summary(summary)

    assert result == "这是一整段摘要。包含第二句。"


def test_extract_one_line_summary_supports_english_executive_summary():
    summary = """
### Executive Summary
This is the first sentence. This is the second sentence.

### Key Insights
Follow-up section.
"""
    result = extract_one_line_summary(summary)

    assert result == "This is the first sentence. This is the second sentence."


@pytest.mark.asyncio
async def test_generate_daily_report_triggers_async_processing_for_unsummarized():
    db = AsyncMock()
    service = DailyReportService(db=db, user_id=1)
    report = SimpleNamespace(id=10, generated_at=None, total_items=0)
    unsummarized_episode = SimpleNamespace(id=101)

    service._get_or_create_report = AsyncMock(return_value=report)
    service._list_window_summarized_episodes = AsyncMock(return_value=[])
    service._list_window_unsummarized_episodes = AsyncMock(
        return_value=[unsummarized_episode]
    )
    service._trigger_episode_processing = AsyncMock()
    service._append_item_if_needed = AsyncMock(return_value=0)
    service._count_report_items = AsyncMock(return_value=0)
    service.get_daily_report = AsyncMock(return_value={"available": True})

    result = await service.generate_daily_report(target_date=date(2026, 2, 20))

    assert result == {"available": True}
    service._trigger_episode_processing.assert_awaited_once_with(101)
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_trigger_episode_processing_uses_task_orchestration_service():
    db = AsyncMock()
    fake_task_service = _FakeTaskOrchestrationService(db)
    service = DailyReportService(
        db=db,
        user_id=7,
        task_orchestration_service_factory=lambda session: fake_task_service,
    )

    await service._trigger_episode_processing(episode_id=123)

    assert fake_task_service.episode_processing_calls == [
        {"episode_id": 123, "user_id": 7}
    ]


@pytest.mark.asyncio
async def test_generate_daily_report_marks_items_as_non_carryover():
    db = AsyncMock()
    service = DailyReportService(db=db, user_id=1)
    report = SimpleNamespace(id=9, generated_at=None, total_items=0)
    same_day_episode = SimpleNamespace(id=202)

    service._get_or_create_report = AsyncMock(return_value=report)
    service._list_window_summarized_episodes = AsyncMock(
        return_value=[same_day_episode]
    )
    service._list_window_unsummarized_episodes = AsyncMock(return_value=[])
    service._trigger_episode_processing = AsyncMock()
    service._append_item_if_needed = AsyncMock(return_value=1)
    service._count_report_items = AsyncMock(return_value=1)
    service.get_daily_report = AsyncMock(return_value={"available": True})

    await service.generate_daily_report(target_date=date(2026, 2, 21))

    service._append_item_if_needed.assert_awaited_once_with(
        report,
        same_day_episode,
        is_carryover=False,
    )


@pytest.mark.asyncio
async def test_generate_daily_report_rebuild_clears_existing_items():
    db = AsyncMock()
    service = DailyReportService(db=db, user_id=1)
    report = SimpleNamespace(id=12, generated_at=None, total_items=0)

    service._get_or_create_report = AsyncMock(return_value=report)
    service._clear_report_items = AsyncMock()
    service._list_window_summarized_episodes = AsyncMock(return_value=[])
    service._list_window_unsummarized_episodes = AsyncMock(return_value=[])
    service._trigger_episode_processing = AsyncMock()
    service._append_item_if_needed = AsyncMock(return_value=0)
    service._count_report_items = AsyncMock(return_value=0)
    service.get_daily_report = AsyncMock(return_value={"available": True})

    await service.generate_daily_report(target_date=date(2026, 2, 21), rebuild=True)

    service._clear_report_items.assert_awaited_once_with(12)


@pytest.mark.asyncio
async def test_list_window_summarized_uses_published_at_filter():
    db = AsyncMock()
    db.execute = AsyncMock(return_value=_ScalarsAllResult([]))
    service = DailyReportService(db=db, user_id=1)
    start = datetime(2026, 2, 19, 16, 0, tzinfo=UTC)
    end = datetime(2026, 2, 20, 16, 0, tzinfo=UTC)

    await service._list_window_summarized_episodes(start, end)

    stmt = db.execute.await_args.args[0]
    where_clause = str(stmt.whereclause)
    assert "podcast_episodes.published_at" in where_clause
    assert "podcast_episodes.created_at >=" not in where_clause


@pytest.mark.asyncio
async def test_list_window_unsummarized_uses_published_at_filter():
    db = AsyncMock()
    db.execute = AsyncMock(return_value=_ScalarsAllResult([]))
    service = DailyReportService(db=db, user_id=1)
    start = datetime(2026, 2, 19, 16, 0, tzinfo=UTC)
    end = datetime(2026, 2, 20, 16, 0, tzinfo=UTC)

    await service._list_window_unsummarized_episodes(start, end)

    stmt = db.execute.await_args.args[0]
    where_clause = str(stmt.whereclause)
    assert "podcast_episodes.published_at" in where_clause
    assert "podcast_episodes.created_at >=" not in where_clause


@pytest.mark.asyncio
async def test_append_item_if_needed_does_not_duplicate_episode():
    db = AsyncMock()
    db.add = Mock()
    db.flush = AsyncMock()
    db.execute = AsyncMock(
        side_effect=[
            _ScalarOneOrNoneResult(None),
            _ScalarOneOrNoneResult(1),
        ]
    )
    service = DailyReportService(db=db, user_id=1)
    now = datetime.now(UTC)

    report = SimpleNamespace(id=7)
    episode = SimpleNamespace(
        id=88,
        subscription_id=2,
        title="Episode 88",
        subscription=SimpleNamespace(title="Podcast X"),
        ai_summary="One sentence summary.",
        created_at=now,
        published_at=now,
    )

    added_first = await service._append_item_if_needed(
        report,
        episode,
        is_carryover=False,
    )
    added_second = await service._append_item_if_needed(
        report,
        episode,
        is_carryover=False,
    )

    assert added_first == 1
    assert added_second == 0
    assert db.add.call_count == 1
