"""Subscription API routes."""

from fastapi import APIRouter, Depends, HTTPException, Query

from app.domains.subscription.api.dependencies import get_subscription_service
from app.domains.subscription.api.response_assemblers import (
    assemble_category_payload,
    assemble_item_payload,
    assemble_paginated_subscription_response,
    assemble_subscription_response,
)
from app.domains.subscription.api.schemas import (
    BatchSubscriptionResponse,
    CategoryCreate,
    CategoryResponse,
    CategoryUpdate,
    FetchResponse,
)
from app.domains.subscription.services import SubscriptionService
from app.shared.schemas import (
    PaginatedResponse,
    PaginationParams,
    SubscriptionCreate,
    SubscriptionResponse,
    SubscriptionUpdate,
)


router = APIRouter()


# Subscription endpoints
@router.get("/", response_model=PaginatedResponse)
async def list_subscriptions(
    pagination: PaginationParams = Depends(),
    status: str | None = Query(None, description="Filter by status"),
    source_type: str | None = Query(None, description="Filter by source type"),
    service: SubscriptionService = Depends(get_subscription_service),
):
    """List user's subscriptions."""
    items, total, item_counts = await service.list_subscriptions(
        page=pagination.page,
        size=pagination.size,
        status=status,
        source_type=source_type,
    )
    return assemble_paginated_subscription_response(
        items,
        total,
        item_counts,
        pagination.page,
        pagination.size,
    )


@router.post("/", response_model=SubscriptionResponse)
async def create_subscription(
    subscription_data: SubscriptionCreate,
    service: SubscriptionService = Depends(get_subscription_service),
):
    """Create a new subscription.

    If duplicate URL or title is found, returns the existing subscription with a message.
    """
    # Check for duplicate before creation

    # Duplicate detection is now handled at service layer with many-to-many support
    # No duplicate found - create subscription
    try:
        sub = await service.create_subscription(subscription_data)
        return assemble_subscription_response(sub)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e


@router.post("/batch", response_model=BatchSubscriptionResponse)
async def create_subscriptions_batch(
    subscriptions_data: list[SubscriptionCreate],
    service: SubscriptionService = Depends(get_subscription_service),
):
    """Batch create subscriptions."""
    results = await service.create_subscriptions_batch(subscriptions_data)

    success_count = sum(1 for r in results if r["status"] == "success")
    skipped_count = sum(1 for r in results if r["status"] == "skipped")
    error_count = sum(1 for r in results if r["status"] == "error")

    return BatchSubscriptionResponse(
        results=results,
        total_requested=len(subscriptions_data),
        success_count=success_count,
        skipped_count=skipped_count,
        error_count=error_count,
    )


@router.get("/{subscription_id}", response_model=SubscriptionResponse)
async def get_subscription(
    subscription_id: int,
    service: SubscriptionService = Depends(get_subscription_service),
):
    """Get subscription by ID."""
    result = await service.get_subscription(subscription_id)
    if not result:
        raise HTTPException(status_code=404, detail="Subscription not found")
    sub, item_count = result
    return assemble_subscription_response(sub, item_count=item_count)


@router.put("/{subscription_id}", response_model=SubscriptionResponse)
async def update_subscription(
    subscription_id: int,
    subscription_data: SubscriptionUpdate,
    service: SubscriptionService = Depends(get_subscription_service),
):
    """Update subscription."""
    result = await service.update_subscription(subscription_id, subscription_data)
    if not result:
        raise HTTPException(status_code=404, detail="Subscription not found")
    sub, item_count = result
    return assemble_subscription_response(sub, item_count=item_count)


@router.delete("/{subscription_id}")
async def delete_subscription(
    subscription_id: int,
    service: SubscriptionService = Depends(get_subscription_service),
):
    """Delete subscription."""
    success = await service.delete_subscription(subscription_id)
    if not success:
        raise HTTPException(status_code=404, detail="Subscription not found")
    # TODO: Add a proper response model instead of raw dict
    return {"message": "Subscription deleted"}


@router.post("/{subscription_id}/fetch", response_model=FetchResponse)
async def fetch_subscription_items(
    subscription_id: int,
    service: SubscriptionService = Depends(get_subscription_service),
):
    """Manually trigger subscription fetch (RSS feeds only)."""
    try:
        result = await service.fetch_subscription(subscription_id)
        return FetchResponse(**result)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Fetch failed: {e!s}") from e


@router.post("/fetch-all", response_model=list[FetchResponse])
async def fetch_all_subscriptions(
    service: SubscriptionService = Depends(get_subscription_service),
):
    """Fetch all active RSS subscriptions."""
    results = await service.fetch_all_subscriptions()
    return [FetchResponse(**r) for r in results]


# Subscription Item endpoints
@router.get("/{subscription_id}/items/", response_model=PaginatedResponse)
async def get_subscription_items(
    subscription_id: int,
    pagination: PaginationParams = Depends(),
    unread_only: bool = Query(False, description="Only show unread items"),
    bookmarked_only: bool = Query(False, description="Only show bookmarked items"),
    service: SubscriptionService = Depends(get_subscription_service),
):
    """Get items from a subscription."""
    items, total = await service.get_subscription_items(
        subscription_id,
        page=pagination.page,
        size=pagination.size,
        unread_only=unread_only,
        bookmarked_only=bookmarked_only,
    )
    return PaginatedResponse.create(
        items=[assemble_item_payload(item) for item in items],
        total=total,
        page=pagination.page,
        size=pagination.size,
    )


@router.get("/items/all/", response_model=PaginatedResponse)
async def get_all_items(
    pagination: PaginationParams = Depends(),
    unread_only: bool = Query(False, description="Only show unread items"),
    bookmarked_only: bool = Query(False, description="Only show bookmarked items"),
    service: SubscriptionService = Depends(get_subscription_service),
):
    """Get all items from all subscriptions."""
    items, total = await service.get_all_items(
        page=pagination.page,
        size=pagination.size,
        unread_only=unread_only,
        bookmarked_only=bookmarked_only,
    )
    return PaginatedResponse.create(
        items=[assemble_item_payload(item) for item in items],
        total=total,
        page=pagination.page,
        size=pagination.size,
    )


@router.post("/items/{item_id}/read")
async def mark_item_as_read(
    item_id: int,
    service: SubscriptionService = Depends(get_subscription_service),
):
    """Mark an item as read."""
    # TODO: Add a proper response model instead of returning service result directly
    result = await service.mark_item_as_read(item_id)
    if not result:
        raise HTTPException(status_code=404, detail="Item not found")
    return result


@router.post("/items/{item_id}/unread")
async def mark_item_as_unread(
    item_id: int,
    service: SubscriptionService = Depends(get_subscription_service),
):
    """Mark an item as unread."""
    # TODO: Add a proper response model instead of returning service result directly
    result = await service.mark_item_as_unread(item_id)
    if not result:
        raise HTTPException(status_code=404, detail="Item not found")
    return result


@router.post("/items/{item_id}/bookmark")
async def toggle_bookmark(
    item_id: int,
    service: SubscriptionService = Depends(get_subscription_service),
):
    """Toggle item bookmark status."""
    # TODO: Add a proper response model instead of returning service result directly
    result = await service.toggle_bookmark(item_id)
    if not result:
        raise HTTPException(status_code=404, detail="Item not found")
    return result


@router.delete("/items/{item_id}")
async def delete_item(
    item_id: int,
    service: SubscriptionService = Depends(get_subscription_service),
):
    """Delete an item."""
    success = await service.delete_item(item_id)
    if not success:
        raise HTTPException(status_code=404, detail="Item not found")
    # TODO: Add a proper response model instead of raw dict
    return {"message": "Item deleted"}


@router.get("/items/unread-count")
async def get_unread_count(
    service: SubscriptionService = Depends(get_subscription_service),
):
    """Get total unread items count."""
    # TODO: Add a proper response model (e.g. UnreadCountResponse) instead of raw dict
    count = await service.get_unread_count()
    return {"unread_count": count}


# Category endpoints
@router.get("/categories/", response_model=list[CategoryResponse])
async def list_categories(
    service: SubscriptionService = Depends(get_subscription_service),
):
    """Get all user's categories."""
    categories = await service.list_categories()
    return [assemble_category_payload(c) for c in categories]


@router.post("/categories/", response_model=CategoryResponse)
async def create_category(
    category_data: CategoryCreate,
    service: SubscriptionService = Depends(get_subscription_service),
):
    """Create a new category."""
    category = await service.create_category(
        name=category_data.name,
        description=category_data.description,
        color=category_data.color,
    )
    return assemble_category_payload(category)


@router.put("/categories/{category_id}", response_model=CategoryResponse)
async def update_category(
    category_id: int,
    category_data: CategoryUpdate,
    service: SubscriptionService = Depends(get_subscription_service),
):
    """Update category."""
    update_data = category_data.model_dump(exclude_unset=True)
    category = await service.update_category(category_id, **update_data)
    if not category:
        raise HTTPException(status_code=404, detail="Category not found")
    return assemble_category_payload(category, include_created_at=False)


@router.delete("/categories/{category_id}")
async def delete_category(
    category_id: int,
    service: SubscriptionService = Depends(get_subscription_service),
):
    """Delete category."""
    success = await service.delete_category(category_id)
    if not success:
        raise HTTPException(status_code=404, detail="Category not found")
    # TODO: Add a proper response model instead of raw dict
    return {"message": "Category deleted"}


@router.post("/{subscription_id}/categories/{category_id}")
async def add_subscription_to_category(
    subscription_id: int,
    category_id: int,
    service: SubscriptionService = Depends(get_subscription_service),
):
    """Add subscription to category."""
    success = await service.add_subscription_to_category(subscription_id, category_id)
    if not success:
        raise HTTPException(
            status_code=404, detail="Subscription or category not found"
        )
    # TODO: Add a proper response model instead of raw dict
    return {"message": "Subscription added to category"}


@router.delete("/{subscription_id}/categories/{category_id}")
async def remove_subscription_from_category(
    subscription_id: int,
    category_id: int,
    service: SubscriptionService = Depends(get_subscription_service),
):
    """Remove subscription from category."""
    success = await service.remove_subscription_from_category(
        subscription_id, category_id
    )
    if not success:
        raise HTTPException(status_code=404, detail="Mapping not found")
    # TODO: Add a proper response model instead of raw dict
    return {"message": "Subscription removed from category"}
