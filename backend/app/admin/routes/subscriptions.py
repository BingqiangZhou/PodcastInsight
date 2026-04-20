"""Admin subscription routes module."""

import logging

from fastapi import APIRouter, Body, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse

from app.admin.auth import admin_required
from app.admin.dependencies import get_admin_subscriptions_service
from app.admin.routes._shared import (
    empty_response,
    get_templates,
    json_payload,
    render_admin_template,
    require_payload,
    xml_download_response,
)
from app.admin.services import AdminSubscriptionsService


logger = logging.getLogger(__name__)

router = APIRouter()
templates = get_templates()


@router.get("/subscriptions", response_class=HTMLResponse)
async def subscriptions_page(
    request: Request,
    user_id: int = Depends(admin_required),
    service: AdminSubscriptionsService = Depends(get_admin_subscriptions_service),
    page: int = 1,
    per_page: int = 10,
    status_filter: str | None = None,
    search_query: str | None = None,
    user_filter: str | None = None,
):
    """Display RSS subscriptions management page with pagination and status filter."""
    try:
        context = await service.get_page_context(
            page=page,
            per_page=per_page,
            status_filter=status_filter,
            search_query=search_query,
            user_filter=user_filter,
        )
        return render_admin_template(
            templates=templates,
            template_name="subscriptions.html",
            request=request,
            user_id=user_id,
            messages=[],
            **context,
        )
    except Exception as exc:
        logger.error("Subscriptions page error: %s", exc)
        raise HTTPException(
            status_code=500, detail="Failed to load subscriptions"
        ) from exc


@router.post("/subscriptions/update-frequency")
async def update_subscription_frequency(
    request: Request,
    update_frequency: str = Body(...),
    update_time: str | None = Body(None),
    update_day: int | None = Body(None),
    user_id: int = Depends(admin_required),
    service: AdminSubscriptionsService = Depends(get_admin_subscriptions_service),
):
    """Update update frequency settings for all RSS subscriptions."""
    try:
        payload = await service.update_frequency(
            request=request,
            user_id=user_id,
            update_frequency=update_frequency,
            update_time=update_time,
            update_day=update_day,
        )
        return json_payload(payload)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Update subscription frequency error: %s", exc)
        raise HTTPException(
            status_code=500, detail="Failed to update frequency settings"
        ) from exc


@router.put("/subscriptions/{sub_id}/edit")
async def edit_subscription(
    sub_id: int,
    request: Request,
    title: str | None = Body(None),
    source_url: str | None = Body(None),
    user_id: int = Depends(admin_required),
    service: AdminSubscriptionsService = Depends(get_admin_subscriptions_service),
):
    """Edit a subscription and re-test connection."""
    try:
        payload = await service.edit_subscription(
            request=request,
            user_id=user_id,
            sub_id=sub_id,
            title=title,
            source_url=source_url,
        )
        return json_payload(
            require_payload(payload, detail="Subscription not found"),
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Edit subscription error: %s", exc)
        raise HTTPException(
            status_code=500, detail="Failed to edit subscription"
        ) from exc


@router.post("/subscriptions/test-url")
async def test_subscription_url(
    request: Request,
    source_url: str = Body(..., embed=True),
    user_id: int = Depends(admin_required),
    service: AdminSubscriptionsService = Depends(get_admin_subscriptions_service),
):
    """Test RSS feed URL before saving."""
    del request
    try:
        payload, status_code = await service.test_subscription_url(
            source_url=source_url,
            username="admin",
        )
        return json_payload(payload, status_code=status_code)
    except Exception as exc:
        logger.error("RSS feed test error: %s", exc)
        return json_payload(
            {"success": False, "message": f"Test failed: {exc}"},
            status_code=500,
        )


@router.post("/subscriptions/test-all")
async def test_all_subscriptions(
    request: Request,
    user_id: int = Depends(admin_required),
    service: AdminSubscriptionsService = Depends(get_admin_subscriptions_service),
):
    """Test all RSS subscriptions and disable failed ones."""
    try:
        payload = await service.test_all_subscriptions(request=request, user_id=user_id)
        return json_payload(payload)
    except Exception as exc:
        logger.error("Test all subscriptions error: %s", exc)
        raise HTTPException(
            status_code=500, detail=f"Failed to test subscriptions: {exc}"
        ) from exc


@router.delete("/subscriptions/{sub_id}/delete")
async def delete_subscription(
    sub_id: int,
    request: Request,
    user_id: int = Depends(admin_required),
    service: AdminSubscriptionsService = Depends(get_admin_subscriptions_service),
):
    """Delete a subscription (with proper handling of podcast-related data)."""
    try:
        payload = await service.delete_subscription(
            request=request, user_id=user_id, sub_id=sub_id
        )
        return json_payload(
            require_payload(payload, detail="Subscription not found"),
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Delete subscription error: %s", exc)
        raise HTTPException(
            status_code=500, detail="Failed to delete subscription"
        ) from exc


@router.post("/subscriptions/{sub_id}/refresh")
async def refresh_subscription(
    sub_id: int,
    request: Request,
    user_id: int = Depends(admin_required),
    service: AdminSubscriptionsService = Depends(get_admin_subscriptions_service),
):
    """Manually refresh a subscription."""
    try:
        payload = await service.refresh_subscription(
            request=request, user_id=user_id, sub_id=sub_id
        )
        return json_payload(
            require_payload(payload, detail="Subscription not found"),
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Refresh subscription error: %s", exc)
        raise HTTPException(
            status_code=500, detail="Failed to refresh subscription"
        ) from exc


@router.post("/subscriptions/batch/refresh")
async def batch_refresh_subscriptions(
    request: Request,
    user_id: int = Depends(admin_required),
    service: AdminSubscriptionsService = Depends(get_admin_subscriptions_service),
):
    """Batch refresh subscriptions."""
    try:
        await service.batch_refresh_subscriptions(request=request, user_id=user_id)
        return empty_response()
    except Exception as exc:
        logger.error("Batch refresh error: %s", exc)
        raise HTTPException(
            status_code=500, detail="Failed to batch refresh subscriptions"
        ) from exc


@router.post("/subscriptions/batch/toggle")
async def batch_toggle_subscriptions(
    request: Request,
    user_id: int = Depends(admin_required),
    service: AdminSubscriptionsService = Depends(get_admin_subscriptions_service),
):
    """Batch toggle subscription status."""
    try:
        await service.batch_toggle_subscriptions(request=request, user_id=user_id)
        return empty_response()
    except Exception as exc:
        logger.error("Batch toggle error: %s", exc)
        raise HTTPException(
            status_code=500, detail="Failed to batch toggle subscriptions"
        ) from exc


@router.post("/subscriptions/batch/delete")
async def batch_delete_subscriptions(
    request: Request,
    user_id: int = Depends(admin_required),
    service: AdminSubscriptionsService = Depends(get_admin_subscriptions_service),
):
    """Batch delete subscriptions."""
    try:
        await service.batch_delete_subscriptions(request=request, user_id=user_id)
        return empty_response()
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Batch delete error: %s", exc)
        raise HTTPException(
            status_code=500,
            detail={
                "message_en": "Failed to batch delete subscriptions",
                "message_zh": "批量删除订阅失败",
            },
        ) from exc


@router.get("/api/subscriptions/export/opml")
async def export_subscriptions_opml(
    request: Request,
    user_id: int = Depends(admin_required),
    service: AdminSubscriptionsService = Depends(get_admin_subscriptions_service),
):
    """Export all RSS subscriptions to OPML format."""
    try:
        opml_content, filename = await service.export_subscriptions_opml(
            request=request,
            user_id=user_id,
        )
        return xml_download_response(content=opml_content, filename=filename)
    except Exception as exc:
        logger.error("OPML export error: %s", exc)
        raise HTTPException(
            status_code=500, detail=f"Failed to export OPML: {exc}"
        ) from exc


@router.post("/api/subscriptions/import/opml")
async def import_subscriptions_opml(
    request: Request,
    opml_content: str = Body(..., embed=True, description="OPML file content"),
    user_id: int = Depends(admin_required),
    service: AdminSubscriptionsService = Depends(get_admin_subscriptions_service),
):
    """Import RSS subscriptions from OPML."""
    try:
        payload, status_code = await service.import_subscriptions_opml(
            request=request,
            user_id=user_id,
            opml_content=opml_content,
        )
        return json_payload(payload, status_code=status_code)
    except Exception as exc:
        logger.error("OPML import error: %s", exc)
        return json_payload(
            status_code=500,
            payload={"success": False, "message": f"Import failed: {exc}"},
        )
