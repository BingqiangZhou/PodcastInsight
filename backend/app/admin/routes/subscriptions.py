"""Admin subscription routes module.

This module contains all routes related to RSS subscription management:
- Subscriptions listing with filtering and pagination
- Subscription editing, deletion, and refresh
- Batch operations (refresh, toggle, delete)
- RSS feed testing (single and batch)
"""

import asyncio
import html
import logging
import re
import time
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from urllib.parse import urlparse

from fastapi import APIRouter, Body, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse, Response
from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.admin.audit import log_admin_action
from app.admin.dependencies import admin_required
from app.admin.models import SystemSettings
from app.admin.routes._shared import get_templates
from app.admin.services import AdminSubscriptionsService
from app.core.database import get_db_session
from app.domains.podcast.services.subscription_service import PodcastSubscriptionService
from app.domains.subscription.models import (
    Subscription,
    SubscriptionStatus,
    UpdateFrequency,
    UserSubscription,
)
from app.domains.subscription.services import SubscriptionService
from app.domains.user.models import User
from app.shared.schemas import SubscriptionCreate


logger = logging.getLogger(__name__)

router = APIRouter()
templates = get_templates()


# ==================== RSS Subscription Management ====================


@router.get("/subscriptions", response_class=HTMLResponse)
async def subscriptions_page(
    request: Request,
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
    page: int = 1,
    per_page: int = 10,
    status_filter: str | None = None,
    search_query: str | None = None,
    user_filter: str | None = None,
):
    """Display RSS subscriptions management page with pagination and status filter."""
    try:
        context = await AdminSubscriptionsService(db).get_page_context(
            page=page,
            per_page=per_page,
            status_filter=status_filter,
            search_query=search_query,
            user_filter=user_filter,
        )
        return templates.TemplateResponse(
            "subscriptions.html",
            {
                "request": request,
                "user": user,
                "messages": [],
                **context,
            },
        )
    except Exception as e:
        logger.error(f"Subscriptions page error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to load subscriptions",
        ) from e


@router.post("/subscriptions/update-frequency")
async def update_subscription_frequency(
    request: Request,
    update_frequency: str = Body(...),
    update_time: str | None = Body(None),
    update_day: int | None = Body(None),
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Update update frequency settings for all RSS subscriptions."""
    try:
        if update_frequency not in [
            UpdateFrequency.HOURLY.value,
            UpdateFrequency.DAILY.value,
            UpdateFrequency.WEEKLY.value,
        ]:
            raise HTTPException(
                status_code=400,
                detail="Invalid update frequency",
            )

        if update_frequency in [UpdateFrequency.DAILY.value, UpdateFrequency.WEEKLY.value]:
            if not update_time:
                raise HTTPException(
                    status_code=400,
                    detail="Update time is required for DAILY and WEEKLY frequency",
                )
            try:
                hour, minute = map(int, update_time.split(":"))
                if not (0 <= hour <= 23 and 0 <= minute <= 59):
                    raise ValueError
            except (ValueError, AttributeError) as err:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid time format. Use HH:MM",
                ) from err

        day_of_week = None
        if update_frequency == UpdateFrequency.WEEKLY.value:
            if not update_day or not (1 <= update_day <= 7):
                raise HTTPException(
                    status_code=400,
                    detail="Invalid day of week. Must be 1-7",
                )
            day_of_week = update_day

        settings_data = {
            "update_frequency": update_frequency,
            "update_time": (
                update_time
                if update_frequency
                in [UpdateFrequency.DAILY.value, UpdateFrequency.WEEKLY.value]
                else None
            ),
            "update_day_of_week": (
                day_of_week if update_frequency == UpdateFrequency.WEEKLY.value else None
            ),
        }

        setting_result = await db.execute(
            select(SystemSettings).where(SystemSettings.key == "rss.frequency_settings")
        )
        setting = setting_result.scalar_one_or_none()
        if setting:
            setting.value = settings_data
        else:
            db.add(
                SystemSettings(
                    key="rss.frequency_settings",
                    value=settings_data,
                    description="RSS subscription update frequency settings",
                    category="subscription",
                )
            )

        user_subscriptions = (
            await db.execute(
                select(UserSubscription)
                .join(Subscription, Subscription.id == UserSubscription.subscription_id)
                .where(Subscription.source_type.in_(["rss", "podcast-rss"]))
            )
        ).scalars().all()

        update_count = 0
        for user_sub in user_subscriptions:
            user_sub.update_frequency = settings_data["update_frequency"]
            user_sub.update_time = settings_data["update_time"]
            user_sub.update_day_of_week = settings_data["update_day_of_week"]
            update_count += 1

        await db.commit()

        await log_admin_action(
            db=db,
            user_id=user.id,
            username=user.username,
            action="update",
            resource_type="subscription_frequency",
            resource_name=f"All user subscriptions ({update_count})",
            details=settings_data,
            request=request,
        )

        return JSONResponse(
            content={
                "success": True,
                "message": f"Updated frequency settings for {update_count} user subscriptions",
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Update subscription frequency error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to update frequency settings",
        ) from e


@router.put("/subscriptions/{sub_id}/edit")
async def edit_subscription(
    sub_id: int,
    request: Request,
    title: str | None = Body(None),
    source_url: str | None = Body(None),
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Edit a subscription and re-test connection."""
    try:
        result = await db.execute(select(Subscription).where(Subscription.id == sub_id))
        subscription = result.scalar_one_or_none()

        if not subscription:
            raise HTTPException(status_code=404, detail="Subscription not found")

        # Update fields
        if title is not None:
            subscription.title = title
        if source_url is not None:
            subscription.source_url = source_url

        # Always test the connection after editing to ensure feed is valid
        from app.domains.subscription.parsers.feed_parser import (
            FeedParserConfig,
            parse_feed_url,
        )

        config = FeedParserConfig(
            max_entries=10,
            strip_html=True,
            strict_mode=False,
            log_raw_feed=False
        )

        try:
            test_result = await parse_feed_url(subscription.source_url, config=config)

            # Update status based on test result
            if test_result and test_result.success and test_result.entries:
                subscription.status = SubscriptionStatus.ACTIVE
                subscription.error_message = None
                logger.info(f"Subscription {sub_id} ({subscription.title}) connection test successful after edit")
            else:
                subscription.status = SubscriptionStatus.ERROR
                error_msg = test_result.errors[0] if test_result and test_result.errors else "No entries found or invalid feed"
                subscription.error_message = error_msg
                logger.warning(f"Subscription {sub_id} ({subscription.title}) connection test failed after edit: {error_msg}")
        except Exception as e:
            subscription.status = SubscriptionStatus.ERROR
            subscription.error_message = str(e)
            logger.error(f"Subscription {sub_id} ({subscription.title}) connection test error after edit: {e}")

        await db.commit()
        await db.refresh(subscription)

        logger.info(f"Subscription {sub_id} edited by user {user.username}, status: {subscription.status}")

        # Log audit action
        await log_admin_action(
            db=db,
            user_id=user.id,
            username=user.username,
            action="update",
            resource_type="subscription",
            resource_id=sub_id,
            resource_name=subscription.title,
            details={
                "title": title,
                "source_url": source_url,
                "status": subscription.status,
                "error_message": subscription.error_message
            },
            request=request,
        )

        return JSONResponse(content={
            "success": True,
            "status": subscription.status,
            "error_message": subscription.error_message
        })
    except Exception as e:
        logger.error(f"Edit subscription error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to edit subscription",
        ) from e


@router.post("/subscriptions/test-url")
async def test_subscription_url(
    request: Request,
    source_url: str = Body(..., embed=True),
    user: User = Depends(admin_required),
):
    """Test RSS feed URL before saving."""
    try:
        from app.domains.subscription.parsers.feed_parser import (
            FeedParseOptions,
            FeedParser,
            FeedParserConfig,
        )

        # Configure parser (same as backend subscription service, uses default user_agent)
        config = FeedParserConfig(
            max_entries=10000,  # 增加到10000以获取更真实的条目数
            strip_html=True,
            strict_mode=False,
            log_raw_feed=False
        )

        options = FeedParseOptions(
            strip_html_content=True,
            include_raw_metadata=False
        )

        # Test the RSS feed URL
        parser = FeedParser(config)
        start_time = time.time()

        try:
            result = await parser.parse_feed(source_url, options=options)
            response_time_ms = int((time.time() - start_time) * 1000)

            await parser.close()

            # Check for errors (use method call, not property)
            if not result.success or result.has_errors():
                error_messages = [err.message for err in result.errors] if result.errors else []
                return JSONResponse(
                    content={
                        "success": False,
                        "message": f"RSS feed test failed: {error_messages[0] if error_messages else 'Failed to parse feed'}",
                        "error_message": error_messages[0] if error_messages else "Failed to parse feed",
                    },
                    status_code=400
                )

            logger.info(f"RSS feed test successful for {source_url} by user {user.username}")
            return JSONResponse(content={
                "success": True,
                "message": "RSS feed test successful",
                "feed_title": result.feed_info.title or "Untitled",
                "feed_description": result.feed_info.description or "",
                "entry_count": len(result.entries),
                "response_time_ms": response_time_ms
            })

        except Exception as e:
            await parser.close()
            raise e

    except Exception as e:
        logger.error(f"RSS feed test error: {e}")
        return JSONResponse(
            content={"success": False, "message": f"Test failed: {str(e)}"},
            status_code=500
        )


@router.post("/subscriptions/test-all")
async def test_all_subscriptions(
    request: Request,
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Test all RSS subscriptions and disable failed ones."""
    try:
        from app.domains.subscription.parsers.feed_parser import (
            FeedParserConfig,
            parse_feed_url,
        )

        # Get all subscriptions (admin page only shows RSS subscriptions)
        result = await db.execute(
            select(Subscription)
            .order_by(Subscription.created_at.desc())
        )
        subscriptions = result.scalars().all()

        if not subscriptions:
            return JSONResponse(content={
                "success": True,
                "message": "没有RSS订阅需要测试",
                "total_count": 0,
                "success_count": 0,
                "failed_count": 0,
                "disabled_count": 0,
                "failed_items": [],
            })

        # Configure parser (uses default user_agent from FeedParserConfig)
        config = FeedParserConfig(
            max_entries=10,
            strip_html=True,
            strict_mode=False,
            log_raw_feed=False
        )

        success_count = 0
        failed_count = 0
        disabled_count = 0
        failed_items = []
        subscriptions_to_disable = []

        logger.info(f"Starting test for {len(subscriptions)} subscriptions")

        # Define async function to test a single subscription with timeout
        async def test_single_subscription(subscription: Subscription, timeout: int = 15):
            """Test a single subscription with timeout."""
            try:
                start_time = time.time()
                # Use asyncio.wait_for to add timeout
                result = await asyncio.wait_for(
                    parse_feed_url(subscription.source_url, config=config),
                    timeout=timeout
                )
                response_time_ms = int((time.time() - start_time) * 1000)

                if result and result.success and result.entries:
                    return {
                        "id": subscription.id,
                        "title": subscription.title,
                        "source_url": subscription.source_url,
                        "success": True,
                        "response_time_ms": response_time_ms,
                    }
                else:
                    error_msg = result.errors[0] if result and result.errors else "No entries found or invalid feed"
                    return {
                        "id": subscription.id,
                        "title": subscription.title,
                        "source_url": subscription.source_url,
                        "success": False,
                        "error": error_msg,
                    }
            except asyncio.TimeoutError:
                return {
                    "id": subscription.id,
                    "title": subscription.title,
                    "source_url": subscription.source_url,
                    "success": False,
                    "error": f"Timeout after {timeout} seconds",
                }
            except Exception as e:
                return {
                    "id": subscription.id,
                    "title": subscription.title,
                    "source_url": subscription.source_url,
                    "success": False,
                    "error": str(e),
                }

        # Test all subscriptions concurrently with a limit of 5 concurrent requests (avoid rate limiting)
        semaphore = asyncio.Semaphore(5)

        async def test_with_semaphore(subscription):
            async with semaphore:
                return await test_single_subscription(subscription)

        # Run all tests concurrently
        test_results = await asyncio.gather(
            *[test_with_semaphore(sub) for sub in subscriptions],
            return_exceptions=True
        )

        # Process results
        for i, result in enumerate(test_results):
            if isinstance(result, Exception):
                # Handle unexpected exceptions
                subscription = subscriptions[i]
                failed_count += 1
                error_msg = f"Unexpected error: {str(result)}"
                failed_items.append({
                    "id": subscription.id,
                    "title": subscription.title,
                    "source_url": subscription.source_url,
                    "error": error_msg
                })
                if subscription.status == SubscriptionStatus.ACTIVE:
                    subscriptions_to_disable.append(subscription.id)
                logger.error(f"Subscription {subscription.id} ({subscription.title}) unexpected error: {result}")
            elif result["success"]:
                success_count += 1
                logger.info(f"Subscription {result['id']} ({result['title']}) test passed in {result.get('response_time_ms', 0)}ms")
            else:
                failed_count += 1
                failed_items.append({
                    "id": result["id"],
                    "title": result["title"],
                    "source_url": result["source_url"],
                    "error": result["error"]
                })
                # Mark for disabling if currently active
                subscription = subscriptions[i]
                if subscription.status == SubscriptionStatus.ACTIVE:
                    subscriptions_to_disable.append(subscription.id)
                logger.warning(f"Subscription {result['id']} ({result['title']}) test failed: {result['error']}")

        # Disable failed subscriptions
        if subscriptions_to_disable:
            await db.execute(
                update(Subscription)
                .where(Subscription.id.in_(subscriptions_to_disable))
                .values(status=SubscriptionStatus.ERROR)
            )
            await db.commit()
            disabled_count = len(subscriptions_to_disable)

        total_count = len(subscriptions)

        logger.info(f"Test all subscriptions completed: {success_count}/{total_count} passed, {failed_count} failed, {disabled_count} disabled by user {user.username}")

        # Log audit action
        await log_admin_action(
            db=db,
            user_id=user.id,
            username=user.username,
            action="test_all",
            resource_type="subscription",
            resource_name="All RSS subscriptions",
            details={
                "total_count": total_count,
                "success_count": success_count,
                "failed_count": failed_count,
                "disabled_count": disabled_count,
            },
            request=request,
        )

        return JSONResponse(content={
            "success": True,
            "message": f"测试完成: {success_count}/{total_count} 通过, {failed_count} 失败, {disabled_count} 已禁用",
            "total_count": total_count,
            "success_count": success_count,
            "failed_count": failed_count,
            "disabled_count": disabled_count,
            "failed_items": failed_items,
        })

    except Exception as e:
        logger.error(f"Test all subscriptions error: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to test subscriptions: {str(e)}",
        ) from e


@router.delete("/subscriptions/{sub_id}/delete")
async def delete_subscription(
    sub_id: int,
    request: Request,
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Delete a subscription (with proper handling of podcast-related data)."""
    try:
        result = await db.execute(select(Subscription).where(Subscription.id == sub_id))
        subscription = result.scalar_one_or_none()

        if not subscription:
            raise HTTPException(status_code=404, detail="Subscription not found")

        # Store name before deletion
        resource_name = subscription.title
        is_podcast = subscription.source_type == "podcast-rss"

        # If it's a podcast subscription, delete related data first
        if is_podcast:
            from app.domains.podcast.models import (
                PodcastConversation,
                PodcastEpisode,
                PodcastPlaybackState,
                TranscriptionTask,
            )

            # Get all episode IDs for this subscription
            ep_result = await db.execute(
                select(PodcastEpisode.id).where(
                    PodcastEpisode.subscription_id == sub_id
                )
            )
            episode_ids = [row[0] for row in ep_result.fetchall()]

            # Delete in dependency order (no explicit transaction, use existing session)
            if episode_ids:
                # 1. conversations
                await db.execute(
                    delete(PodcastConversation).where(
                        PodcastConversation.episode_id.in_(episode_ids)
                    )
                )
                # 2. playback states
                await db.execute(
                    delete(PodcastPlaybackState).where(
                        PodcastPlaybackState.episode_id.in_(episode_ids)
                    )
                )
                # 3. transcription tasks
                await db.execute(
                    delete(TranscriptionTask).where(
                        TranscriptionTask.episode_id.in_(episode_ids)
                    )
                )

            # 4. episodes
            await db.execute(
                delete(PodcastEpisode).where(
                    PodcastEpisode.subscription_id == sub_id
                )
            )

        # 5. Finally delete the subscription
        await db.execute(
            delete(Subscription).where(Subscription.id == sub_id)
        )

        # Commit all deletions
        await db.commit()

        logger.info(f"Subscription {sub_id} deleted by user {user.username}")

        # Log audit action (after commit)
        await log_admin_action(
            db=db,
            user_id=user.id,
            username=user.username,
            action="delete",
            resource_type="subscription",
            resource_id=sub_id,
            resource_name=resource_name,
            request=request,
        )

        return JSONResponse(content={"success": True})
    except Exception as e:
        await db.rollback()
        logger.error(f"Delete subscription error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to delete subscription",
        ) from e


@router.post("/subscriptions/{sub_id}/refresh")
async def refresh_subscription(
    sub_id: int,
    request: Request,
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Manually refresh a subscription."""
    try:
        result = await db.execute(select(Subscription).where(Subscription.id == sub_id))
        subscription = result.scalar_one_or_none()

        if not subscription:
            raise HTTPException(status_code=404, detail="Subscription not found")

        # TODO: Trigger background task to refresh subscription
        # For now, just update the last_fetched_at timestamp
        subscription.last_fetched_at = datetime.now(timezone.utc)
        await db.commit()
        await db.refresh(subscription)

        logger.info(f"Subscription {sub_id} refresh triggered by user {user.username}")

        # Log audit action
        await log_admin_action(
            db=db,
            user_id=user.id,
            username=user.username,
            action="update",
            resource_type="subscription",
            resource_id=sub_id,
            resource_name=subscription.title,
            details={"action": "refresh"},
            request=request,
        )

        return JSONResponse(content={"success": True})
    except Exception as e:
        logger.error(f"Refresh subscription error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to refresh subscription",
        ) from e


# ==================== Subscription Batch Operations ====================


@router.post("/subscriptions/batch/refresh")
async def batch_refresh_subscriptions(
    request: Request,
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Batch refresh subscriptions."""
    try:
        # Get IDs from request body
        body = await request.json()
        ids = body.get("ids", [])

        if not ids:
            raise HTTPException(status_code=400, detail="No subscription IDs provided")

        # Convert all IDs to integers to ensure type matching
        ids = [int(id_) for id_ in ids]

        # Update last_fetched_at for all selected subscriptions
        result = await db.execute(
            select(Subscription).where(Subscription.id.in_(ids))
        )
        subscriptions = result.scalars().all()

        for subscription in subscriptions:
            subscription.last_fetched_at = datetime.now(timezone.utc)

        await db.commit()

        logger.info(f"Batch refresh {len(subscriptions)} subscriptions by user {user.username}")

        # Log audit action
        await log_admin_action(
            db=db,
            user_id=user.id,
            username=user.username,
            action="batch_refresh",
            resource_type="subscription",
            details={"count": len(subscriptions), "ids": ids},
            request=request,
        )

        return Response(status_code=200)
    except Exception as e:
        logger.error(f"Batch refresh error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to batch refresh subscriptions",
        ) from e


@router.post("/subscriptions/batch/toggle")
async def batch_toggle_subscriptions(
    request: Request,
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Batch toggle subscription status."""
    try:
        # Get IDs from request body
        body = await request.json()
        ids = body.get("ids", [])

        if not ids:
            raise HTTPException(status_code=400, detail="No subscription IDs provided")

        # Convert all IDs to integers to ensure type matching
        ids = [int(id_) for id_ in ids]

        # Toggle is_active for all selected subscriptions
        result = await db.execute(
            select(Subscription).where(Subscription.id.in_(ids))
        )
        subscriptions = result.scalars().all()

        for subscription in subscriptions:
            subscription.is_active = not subscription.is_active

        await db.commit()

        logger.info(f"Batch toggle {len(subscriptions)} subscriptions by user {user.username}")

        # Log audit action
        await log_admin_action(
            db=db,
            user_id=user.id,
            username=user.username,
            action="batch_toggle",
            resource_type="subscription",
            details={"count": len(subscriptions), "ids": ids},
            request=request,
        )

        return Response(status_code=200)
    except Exception as e:
        logger.error(f"Batch toggle error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to batch toggle subscriptions",
        ) from e


@router.post("/subscriptions/batch/delete")
async def batch_delete_subscriptions(
    request: Request,
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Batch delete subscriptions."""
    try:
        # Get IDs from request body
        body = await request.json()
        ids = body.get("ids", [])

        if not ids:
            raise HTTPException(status_code=400, detail="No subscription IDs provided")

        # Convert all IDs to integers to ensure type matching
        ids = [int(id_) for id_ in ids]

        # Delete all selected subscriptions
        result = await db.execute(
            select(Subscription).where(Subscription.id.in_(ids))
        )
        subscriptions = result.scalars().all()

        # Import podcast models if needed
        from app.domains.podcast.models import (
            PodcastConversation,
            PodcastEpisode,
            PodcastPlaybackState,
            TranscriptionTask,
        )

        # Delete each subscription with proper handling of podcast-related data
        for subscription in subscriptions:
            sub_id = subscription.id
            is_podcast = subscription.source_type == "podcast-rss"

            if is_podcast:
                # Get all episode IDs for this subscription
                ep_result = await db.execute(
                    select(PodcastEpisode.id).where(
                        PodcastEpisode.subscription_id == sub_id
                    )
                )
                episode_ids = [row[0] for row in ep_result.fetchall()]

                # Delete in dependency order
                if episode_ids:
                    # 1. conversations
                    await db.execute(
                        delete(PodcastConversation).where(
                            PodcastConversation.episode_id.in_(episode_ids)
                        )
                    )
                    # 2. playback states
                    await db.execute(
                        delete(PodcastPlaybackState).where(
                            PodcastPlaybackState.episode_id.in_(episode_ids)
                        )
                    )
                    # 3. transcription tasks
                    await db.execute(
                        delete(TranscriptionTask).where(
                            TranscriptionTask.episode_id.in_(episode_ids)
                        )
                    )

                # 4. episodes
                await db.execute(
                    delete(PodcastEpisode).where(
                        PodcastEpisode.subscription_id == sub_id
                    )
                )

            # 5. Finally delete the subscription
            await db.execute(
                delete(Subscription).where(Subscription.id == sub_id)
            )

        await db.commit()

        logger.info(f"Batch delete {len(subscriptions)} subscriptions by user {user.username}")

        # Log audit action
        await log_admin_action(
            db=db,
            user_id=user.id,
            username=user.username,
            action="batch_delete",
            resource_type="subscription",
            details={"count": len(subscriptions), "ids": ids},
            request=request,
        )

        return Response(status_code=200)
    except Exception as e:
        await db.rollback()
        logger.error(f"Batch delete error: {e}")
        raise HTTPException(
            status_code=500,
            detail={
                "message_en": "Failed to batch delete subscriptions",
                "message_zh": "批量删除订阅失败"
            },
        ) from e


# ==================== OPML Export/Import ====================


@router.get("/api/subscriptions/export/opml")
async def export_subscriptions_opml(
    request: Request,
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Export all RSS subscriptions to OPML format.

    导出所有RSS订阅为OPML格式。
    """
    try:
        # Create subscription service (export all subscriptions for admin)
        service = SubscriptionService(db, user_id=user.id)

        # Generate OPML content - export ALL subscriptions regardless of user_id
        opml_content = await service.generate_opml_content(user_id=None)

        # Log audit action
        await log_admin_action(
            db=db,
            user_id=user.id,
            username=user.username,
            action="export_opml",
            resource_type="subscription",
            details={"format": "opml", "filename": "stella.opml"},
            request=request,
        )

        logger.info(f"Exported OPML for user {user.username}")

        # Return as downloadable file
        return Response(
            content=opml_content,
            media_type="application/xml; charset=utf-8",
            headers={
                "Content-Disposition": 'attachment; filename="stella.opml"'
            }
        )

    except Exception as e:
        logger.error(f"OPML export error: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to export OPML: {str(e)}",
        ) from e


@router.post("/api/subscriptions/import/opml")
async def import_subscriptions_opml(
    request: Request,
    opml_content: str = Body(..., embed=True, description="OPML file content"),
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Import RSS subscriptions from OPML.

    This endpoint performs a fast import for subscription records and queues
    episode parsing to background workers, so the HTTP request can return early.
    """
    from sqlalchemy import and_, select

    from app.domains.podcast.tasks.opml_import import process_opml_subscription_episodes

    # Constants
    max_title_length = 255
    max_description_length = 2000

    def normalize_feed_url(feed_url: str) -> str:
        """Normalize feed:// URLs to https:// for parser compatibility."""
        url = feed_url.strip()
        if url.startswith("feed://"):
            return f"https://{url[len('feed://'):]}"
        return url

    async def parse_outline_element(outline: ET.Element) -> SubscriptionCreate | None:
        """Parse a single outline element into SubscriptionCreate."""
        xml_url = normalize_feed_url(outline.get("xmlUrl", ""))
        if not xml_url:
            return None

        title = outline.get("title") or outline.get("text") or ""
        description = outline.get("description") or ""

        if title:
            title = html.unescape(title)
        if description:
            description = html.unescape(description)

        if not title:
            try:
                parsed = urlparse(xml_url)
                title = parsed.netloc or xml_url
            except Exception:
                title = xml_url

        if not xml_url.startswith(("http://", "https://")):
            logger.warning(f"Skipping invalid URL: {xml_url}")
            return None

        title = title.strip()[:max_title_length]
        description = description.strip()[:max_description_length] if description else ""

        return SubscriptionCreate(
            source_url=xml_url,
            title=title,
            source_type="podcast-rss",
            description=description,
            image_url=None,
        )

    async def parse_opml_with_etree(content: str) -> list[SubscriptionCreate]:
        """Parse OPML using ElementTree (primary method)."""
        subscriptions: list[SubscriptionCreate] = []

        try:
            root = ET.fromstring(content)
            namespaces = {
                "opml": "http://opml.org/spec2",
                "": "",
            }

            body = root.find(".//opml:body", namespaces) or root.find(".//body")
            if body is None:
                logger.warning("No body element found in OPML")
                return []

            for outline in body.iter():
                tag_name = outline.tag
                if "}" in tag_name:
                    tag_name = tag_name.split("}")[1]

                if tag_name == "outline":
                    sub_data = await parse_outline_element(outline)
                    if sub_data:
                        subscriptions.append(sub_data)

        except ET.ParseError as e:
            logger.warning(f"ElementTree parsing failed: {e}")
            raise

        return subscriptions

    async def parse_opml_with_regex(content: str) -> list[SubscriptionCreate]:
        """Fallback regex-based OPML parser for malformed XML."""
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
            xml_url = normalize_feed_url(extract_attr(tag, "xmlUrl"))
            if not xml_url:
                continue

            if not xml_url.startswith(("http://", "https://")):
                continue

            title = extract_attr(tag, "title") or extract_attr(tag, "text")
            description = extract_attr(tag, "description")

            if title:
                title = html.unescape(title)
            if description:
                description = html.unescape(description)

            if not title:
                try:
                    parsed = urlparse(xml_url)
                    title = parsed.netloc or xml_url
                except Exception:
                    title = xml_url

            title = title.strip()[:max_title_length]
            description = (
                description.strip()[:max_description_length] if description else ""
            )

            subscriptions.append(
                SubscriptionCreate(
                    source_url=xml_url,
                    title=title,
                    source_type="podcast-rss",
                    description=description,
                    image_url=None,
                )
            )

        return subscriptions

    try:
        subscriptions_data: list[SubscriptionCreate] = []

        try:
            subscriptions_data = await parse_opml_with_etree(opml_content)
            logger.info(f"Parsed {len(subscriptions_data)} subscriptions using ElementTree")
        except ET.ParseError:
            logger.info("ElementTree failed, using regex fallback")
            subscriptions_data = await parse_opml_with_regex(opml_content)
            logger.info(f"Parsed {len(subscriptions_data)} subscriptions using regex fallback")

        unique_subscriptions: list[SubscriptionCreate] = []
        seen_urls: set[str] = set()
        for sub in subscriptions_data:
            if sub.source_url in seen_urls:
                continue
            seen_urls.add(sub.source_url)
            unique_subscriptions.append(sub)
        subscriptions_data = unique_subscriptions

        if not subscriptions_data:
            return JSONResponse(
                status_code=400,
                content={"success": False, "message": "No valid RSS subscriptions found in OPML file"},
            )

        podcast_service = PodcastSubscriptionService(db, user_id=user.id)
        import_started_at = datetime.now(timezone.utc).isoformat()

        results = []
        success_count = 0
        updated_count = 0
        skipped_count = 0
        error_count = 0
        queued_episode_tasks = 0
        total_episodes_created = 0

        for sub_data in subscriptions_data:
            try:
                existing = await podcast_service.repo.get_subscription_by_url(user.id, sub_data.source_url)
                if existing:
                    skipped_count += 1
                    results.append(
                        {
                            "source_url": sub_data.source_url,
                            "title": sub_data.title,
                            "status": "skipped",
                            "id": existing.id,
                            "message": f"Subscription already exists: {existing.title}",
                        }
                    )
                    continue

                global_existing_stmt = select(Subscription.id).where(
                    and_(
                        Subscription.source_url == sub_data.source_url,
                        Subscription.source_type == "podcast-rss",
                    )
                )
                global_existing_result = await db.execute(global_existing_stmt)
                existed_globally = global_existing_result.scalar_one_or_none() is not None

                subscription = await podcast_service.repo.create_or_update_subscription(
                    user_id=user.id,
                    feed_url=sub_data.source_url,
                    title=sub_data.title,
                    description=sub_data.description,
                    custom_name=None,
                    metadata={
                        "imported_via_opml": True,
                        "opml_imported_at": import_started_at,
                    },
                )

                task = process_opml_subscription_episodes.delay(
                    subscription_id=subscription.id,
                    user_id=user.id,
                    source_url=sub_data.source_url,
                )
                queued_episode_tasks += 1

                if existed_globally:
                    updated_count += 1
                    status = "updated"
                else:
                    success_count += 1
                    status = "success"

                results.append(
                    {
                        "source_url": sub_data.source_url,
                        "title": sub_data.title,
                        "status": status,
                        "id": subscription.id,
                        "message": "Subscription imported. Episode parsing queued in background.",
                        "background_task_id": task.id,
                    }
                )
            except Exception as e:
                error_count += 1
                logger.error(f"OPML import DB/task error for {sub_data.source_url}: {e}")
                results.append(
                    {
                        "source_url": sub_data.source_url,
                        "title": sub_data.title,
                        "status": "error",
                        "message": str(e),
                    }
                )

        await log_admin_action(
            db=db,
            user_id=user.id,
            username=user.username,
            action="import_opml",
            resource_type="subscription",
            details={
                "total": len(subscriptions_data),
                "success": success_count,
                "updated": updated_count,
                "skipped": skipped_count,
                "errors": error_count,
                "total_episodes_created": total_episodes_created,
                "queued_episode_tasks": queued_episode_tasks,
            },
            request=request,
        )

        logger.info(
            f"Imported OPML for user {user.username}: "
            f"{success_count} added, {updated_count} updated, {skipped_count} skipped, {error_count} failed. "
            f"Background episode tasks queued: {queued_episode_tasks}"
        )

        return JSONResponse(
            content={
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
                    "total_episodes_created": total_episodes_created,
                    "queued_episode_tasks": queued_episode_tasks,
                },
                "details": results,
            }
        )

    except Exception as e:
        logger.error(f"OPML import error: {e}")
        return JSONResponse(
            status_code=500,
            content={"success": False, "message": f"Import failed: {str(e)}"},
        )
