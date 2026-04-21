"""Shared Pydantic schemas."""

from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


# Base schemas
class BaseSchema(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class TimestampedSchema(BaseSchema):
    created_at: datetime
    updated_at: datetime | None = None


# Pagination schemas
class PaginationParams(BaseSchema):
    page: int = Field(1, ge=1)
    size: int = Field(20, ge=1, le=100)

    @property
    def skip(self) -> int:
        return (self.page - 1) * self.size


class PaginatedResponse(BaseSchema):
    items: list[Any]
    total: int
    page: int
    size: int
    pages: int

    @classmethod
    def create(
        cls,
        items: list[Any],
        total: int,
        page: int,
        size: int,
    ) -> "PaginatedResponse":
        pages = (total + size - 1) // size
        return cls(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=pages,
        )


# API Response schemas
class APIResponse(BaseSchema):
    success: bool = True
    message: str | None = None
    data: Any | None = None


class ErrorResponse(BaseSchema):
    success: bool = False
    message: str
    errors: dict[str, list[str]] | None = None


# Subscription schemas
class SubscriptionBase(BaseSchema):
    title: str
    description: str | None = None
    source_type: str
    source_url: str
    image_url: str | None = None
    config: dict[str, Any] | None = {}
    fetch_interval: int = 3600


class SubscriptionCreate(SubscriptionBase):
    pass


class SubscriptionUpdate(BaseSchema):
    title: str | None = None
    description: str | None = None
    image_url: str | None = None
    config: dict[str, Any] | None = None
    fetch_interval: int | None = None
    is_active: bool | None = None


class SubscriptionResponse(SubscriptionBase, TimestampedSchema):
    id: int
    status: str
    last_fetched_at: datetime | None = None
    latest_item_published_at: datetime | None = None
    next_update_at: datetime | None = None
    error_message: str | None = None
    item_count: int = 0
