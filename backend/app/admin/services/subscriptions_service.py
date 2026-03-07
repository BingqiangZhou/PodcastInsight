"""Thin coordinator for admin subscription page and action services."""

from __future__ import annotations

from sqlalchemy.ext.asyncio import AsyncSession

from app.admin.services.subscriptions_command_service import (
    AdminSubscriptionsCommandService,
)
from app.admin.services.subscriptions_opml_service import AdminSubscriptionsOpmlService
from app.admin.services.subscriptions_query_service import (
    AdminSubscriptionsQueryService,
)


class AdminSubscriptionsService:
    """Compose query, command, and OPML admin subscription services."""

    def __init__(self, db: AsyncSession):
        self.query = AdminSubscriptionsQueryService(db)
        self.command = AdminSubscriptionsCommandService(db)
        self.opml = AdminSubscriptionsOpmlService(db)

    async def get_page_context(self, **kwargs):
        return await self.query.get_page_context(**kwargs)

    async def update_frequency(self, **kwargs):
        return await self.command.update_frequency(**kwargs)

    async def edit_subscription(self, **kwargs):
        return await self.command.edit_subscription(**kwargs)

    async def test_subscription_url(self, **kwargs):
        return await self.command.test_subscription_url(**kwargs)

    async def test_all_subscriptions(self, **kwargs):
        return await self.command.test_all_subscriptions(**kwargs)

    async def delete_subscription(self, **kwargs):
        return await self.command.delete_subscription(**kwargs)

    async def refresh_subscription(self, **kwargs):
        return await self.command.refresh_subscription(**kwargs)

    async def batch_refresh_subscriptions(self, **kwargs):
        return await self.command.batch_refresh_subscriptions(**kwargs)

    async def batch_toggle_subscriptions(self, **kwargs):
        return await self.command.batch_toggle_subscriptions(**kwargs)

    async def batch_delete_subscriptions(self, **kwargs):
        return await self.command.batch_delete_subscriptions(**kwargs)

    async def export_subscriptions_opml(self, **kwargs):
        return await self.opml.export_subscriptions_opml(**kwargs)

    async def import_subscriptions_opml(self, **kwargs):
        return await self.opml.import_subscriptions_opml(**kwargs)
