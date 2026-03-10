from unittest.mock import AsyncMock

import pytest

from app.domains.subscription.services import SubscriptionService
from app.domains.user import models as _user_models  # noqa: F401


@pytest.mark.asyncio
async def test_subscription_service_get_subscription():
    service = SubscriptionService(AsyncMock(), user_id=11)
    expected = object()
    service.repo.get_subscription_by_id = AsyncMock(return_value=expected)

    await service.get_subscription(5)

    # get_subscription also does a count query; just verify it called the repo
    service.repo.get_subscription_by_id.assert_awaited_once_with(11, 5)


@pytest.mark.asyncio
async def test_subscription_service_fetch_all_subscriptions():
    service = SubscriptionService(AsyncMock(), user_id=11)
    service.repo.get_user_subscriptions = AsyncMock(return_value=([], 0, {}))

    result = await service.fetch_all_subscriptions()

    assert result == []
    service.repo.get_user_subscriptions.assert_awaited_once()


@pytest.mark.asyncio
async def test_subscription_service_create_category():
    service = SubscriptionService(AsyncMock(), user_id=11)
    expected = {"id": 1, "name": "Tech"}
    service.repo.create_category = AsyncMock(return_value=expected)

    result = await service.create_category("Tech", "desc", "#ffffff")

    assert result is expected
    service.repo.create_category.assert_awaited_once_with(11, "Tech", "desc", "#ffffff")


@pytest.mark.asyncio
async def test_generate_opml_content_filters_to_user_non_archived_subscriptions():
    class _ScalarCollection:
        def __init__(self, values):
            self._values = values

        def all(self):
            return self._values

    class _ExecuteResult:
        def __init__(self, values):
            self._values = values

        def scalars(self):
            return _ScalarCollection(self._values)

    db = AsyncMock()
    db.execute = AsyncMock(return_value=_ExecuteResult([]))

    service = SubscriptionService(db, user_id=11)
    opml_content = await service.generate_opml_content(user_id=11)
    query_sql = str(db.execute.await_args.args[0]).lower()

    assert "user_subscriptions.user_id" in query_sql
    assert "user_subscriptions.is_archived is false" in query_sql
    assert "<totalsubscriptions>0</totalsubscriptions>" in opml_content.lower()
