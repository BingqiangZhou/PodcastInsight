"""Subscription API request/response schemas."""

from typing import Any

from pydantic import BaseModel, Field


class CategoryCreate(BaseModel):
    """Request model for creating a category."""

    name: str = Field(..., min_length=1, max_length=100)
    description: str | None = None
    color: str | None = Field(None, pattern=r"^#[0-9A-Fa-f]{6}$")


class CategoryResponse(BaseModel):
    """Response model for category."""

    id: int
    name: str
    description: str | None
    color: str | None
    created_at: str


class CategoryUpdate(BaseModel):
    """Request model for updating a category."""

    name: str | None = Field(None, min_length=1, max_length=100)
    description: str | None = None
    color: str | None = Field(None, pattern=r"^#[0-9A-Fa-f]{6}$")


class FetchResponse(BaseModel):
    """Response model for fetch operation."""

    subscription_id: int
    status: str
    new_items: int | None = None
    updated_items: int | None = None
    total_items: int | None = None
    error: str | None = None


class BatchSubscriptionResponse(BaseModel):
    """Response model for batch subscription creation."""

    results: list[dict[str, Any]]
    total_requested: int
    success_count: int
    skipped_count: int
    error_count: int
