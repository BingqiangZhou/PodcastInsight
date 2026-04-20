"""OPML import/export helpers for admin subscription actions."""

from __future__ import annotations

import html
import re
import xml.etree.ElementTree as ET
from datetime import UTC, datetime
from urllib.parse import urlparse

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domains.podcast.models import Subscription, UserSubscription
from app.domains.podcast.services.subscription_service import PodcastSubscriptionService
from app.domains.podcast.services.task_orchestration_service import (
    PodcastTaskOrchestrationService,
)
from app.shared.schemas import SubscriptionCreate


class AdminSubscriptionsOpmlService:
    """Handle OPML import/export without owning route concerns."""

    def __init__(
        self,
        db: AsyncSession,
        task_orchestration_service_factory: type[
            PodcastTaskOrchestrationService
        ] = PodcastTaskOrchestrationService,
    ):
        self.db = db
        self._task_orchestration_service_factory = task_orchestration_service_factory

    def _task_orchestration_service(self) -> PodcastTaskOrchestrationService:
        return self._task_orchestration_service_factory(self.db)

    async def export_subscriptions_opml(self, *, request, user_id) -> tuple[str, str]:
        opml_content = await self._generate_opml_content()
        return opml_content, "stella.opml"

    async def _generate_opml_content(self) -> str:
        """Generate OPML XML content from all active subscriptions."""
        stmt = (
            select(Subscription)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    UserSubscription.is_archived.is_(False),
                    Subscription.source_type == "podcast-rss",
                ),
            )
            .order_by(Subscription.title)
        )
        result = await self.db.execute(stmt)
        subscriptions = result.scalars().all()

        lines = [
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<opml version="1.0">',
            "  <head>",
            "    <title>Stella Subscriptions</title>",
            "  </head>",
            "  <body>",
        ]
        for sub in subscriptions:
            title = html.escape(sub.title or "", quote=True)
            url = html.escape(sub.source_url or "", quote=True)
            desc = html.escape(sub.description or "", quote=True)
            lines.append(
                f'    <outline type="rss" text="{title}" title="{title}" '
                f'xmlUrl="{url}" description="{desc}" />'
            )
        lines.extend(["  </body>", "</opml>"])
        return "\n".join(lines)

    async def import_subscriptions_opml(
        self,
        *,
        request,
        user_id,
        opml_content: str,
    ) -> tuple[dict, int]:
        subscriptions_data = await self._parse_opml(opml_content)
        subscriptions_data = self._dedupe_subscriptions(subscriptions_data)

        if not subscriptions_data:
            return {
                "success": False,
                "message": "No valid RSS subscriptions found in OPML file",
            }, 400

        podcast_service = PodcastSubscriptionService(self.db, user_id=user_id)
        import_started_at = datetime.now(UTC).isoformat()

        # Pre-fetch all existing URLs in two queries to avoid N+1 in the loop
        import_urls = {sub.source_url for sub in subscriptions_data}

        user_existing_result = await self.db.execute(
            select(Subscription.id, Subscription.source_url, Subscription.title)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    UserSubscription.user_id == user_id,
                    UserSubscription.is_archived.is_(False),
                    Subscription.source_url.in_(import_urls),
                    Subscription.source_type == "podcast-rss",
                ),
            )
        )
        user_existing_by_url = {
            row.source_url: {"id": row.id, "title": row.title}
            for row in user_existing_result.all()
        }

        global_existing_result = await self.db.execute(
            select(Subscription.source_url).where(
                and_(
                    Subscription.source_url.in_(import_urls),
                    Subscription.source_type == "podcast-rss",
                ),
            )
        )
        global_existing_urls = {row.source_url for row in global_existing_result.all()}

        results = []
        success_count = 0
        updated_count = 0
        skipped_count = 0
        error_count = 0
        queued_episode_tasks = 0

        for sub_data in subscriptions_data:
            try:
                existing = user_existing_by_url.get(sub_data.source_url)
                if existing:
                    skipped_count += 1
                    results.append(
                        {
                            "source_url": sub_data.source_url,
                            "title": sub_data.title,
                            "status": "skipped",
                            "id": existing["id"],
                            "message": f"Subscription already exists: {existing['title']}",
                        },
                    )
                    continue

                existed_globally = sub_data.source_url in global_existing_urls

                subscription = await podcast_service.repo.create_or_update_subscription(
                    user_id=user_id,
                    feed_url=sub_data.source_url,
                    title=sub_data.title,
                    description=sub_data.description,
                    custom_name=None,
                    metadata={
                        "imported_via_opml": True,
                        "opml_imported_at": import_started_at,
                    },
                )

                task = self._task_orchestration_service().enqueue_opml_subscription_episodes(
                    subscription_id=subscription.id,
                    user_id=user_id,
                    source_url=sub_data.source_url,
                )
                queued_episode_tasks += 1

                status = "updated" if existed_globally else "success"
                if existed_globally:
                    updated_count += 1
                else:
                    success_count += 1

                results.append(
                    {
                        "source_url": sub_data.source_url,
                        "title": sub_data.title,
                        "status": status,
                        "id": subscription.id,
                        "message": "Subscription imported. Episode parsing queued in background.",
                        "background_task_id": task.id,
                    },
                )
            except Exception as exc:  # noqa: BLE001
                error_count += 1
                results.append(
                    {
                        "source_url": sub_data.source_url,
                        "title": sub_data.title,
                        "status": "error",
                        "message": str(exc),
                    },
                )


        return {
            "success": True,
            "message": (
                f"Import completed: {success_count} added, {updated_count} updated, "
                f"{skipped_count} skipped, {error_count} failed. "
                f"Episode parsing is running in background for {queued_episode_tasks} subscriptions."
            ),
            "results": {
                "total": len(subscriptions_data),
                "success": success_count,
                "updated": updated_count,
                "skipped": skipped_count,
                "errors": error_count,
                "total_episodes_created": 0,
                "queued_episode_tasks": queued_episode_tasks,
            },
            "details": results,
        }, 200

    async def _parse_opml(self, content: str) -> list[SubscriptionCreate]:
        try:
            return await self._parse_opml_with_etree(content)
        except ET.ParseError:
            return await self._parse_opml_with_regex(content)

    async def _parse_opml_with_etree(self, content: str) -> list[SubscriptionCreate]:
        subscriptions: list[SubscriptionCreate] = []
        root = ET.fromstring(content)
        namespaces = {"opml": "http://opml.org/spec2", "": ""}
        body = root.find(".//opml:body", namespaces) or root.find(".//body")
        if body is None:
            return []
        for outline in body.iter():
            tag_name = outline.tag.split("}")[1] if "}" in outline.tag else outline.tag
            if tag_name == "outline":
                sub_data = self._parse_outline_element(outline)
                if sub_data:
                    subscriptions.append(sub_data)
        return subscriptions

    async def _parse_opml_with_regex(self, content: str) -> list[SubscriptionCreate]:
        subscriptions: list[SubscriptionCreate] = []

        def extract_attr(tag: str, attr_name: str) -> str:
            pattern = rf'{attr_name}\s*=\s*(["\'])([^\1]*?)\1(?=\s|/?>)'
            match = re.search(pattern, tag, re.IGNORECASE)
            return match.group(2) if match else ""

        outline_pattern = re.compile(
            r"<outline\s+[^>]*?xmlUrl\s*=\s*[\"'][^\"']+[\"'][^>]*?/?>",
            re.IGNORECASE,
        )

        for match in outline_pattern.finditer(content):
            tag = match.group(0)
            xml_url = self._normalize_feed_url(extract_attr(tag, "xmlUrl"))
            if not xml_url or not xml_url.startswith(("http://", "https://")):
                continue

            title = extract_attr(tag, "title") or extract_attr(tag, "text")
            description = extract_attr(tag, "description")
            title = html.unescape(title) if title else self._fallback_title(xml_url)
            description = html.unescape(description) if description else ""

            subscriptions.append(
                SubscriptionCreate(
                    source_url=xml_url,
                    title=title.strip()[:255],
                    source_type="podcast-rss",
                    description=description.strip()[:2000] if description else "",
                    image_url=None,
                ),
            )
        return subscriptions

    def _parse_outline_element(self, outline: ET.Element) -> SubscriptionCreate | None:
        xml_url = self._normalize_feed_url(outline.get("xmlUrl", ""))
        if not xml_url or not xml_url.startswith(("http://", "https://")):
            return None

        title = outline.get("title") or outline.get("text") or ""
        description = outline.get("description") or ""
        title = html.unescape(title) if title else self._fallback_title(xml_url)
        description = html.unescape(description) if description else ""

        return SubscriptionCreate(
            source_url=xml_url,
            title=title.strip()[:255],
            source_type="podcast-rss",
            description=description.strip()[:2000] if description else "",
            image_url=None,
        )

    @staticmethod
    def _dedupe_subscriptions(
        subscriptions_data: list[SubscriptionCreate],
    ) -> list[SubscriptionCreate]:
        unique_subscriptions: list[SubscriptionCreate] = []
        seen_urls: set[str] = set()
        for sub in subscriptions_data:
            if sub.source_url in seen_urls:
                continue
            seen_urls.add(sub.source_url)
            unique_subscriptions.append(sub)
        return unique_subscriptions

    @staticmethod
    def _normalize_feed_url(feed_url: str) -> str:
        url = feed_url.strip()
        if url.startswith("feed://"):
            return f"https://{url[len('feed://') :]}"
        return url

    @staticmethod
    def _fallback_title(xml_url: str) -> str:
        try:
            parsed = urlparse(xml_url)
            return parsed.netloc or xml_url
        except Exception:
            return xml_url
