"""Shared repository helper functions.

This module provides common database query patterns to reduce boilerplate
across repositories.
"""

from typing import Any, TypeVar

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.shared.schemas import PaginatedResponse


T = TypeVar("T")


async def resolve_window_total(
    db: AsyncSession,
    rows: list[Any],
    *,
    total_index: int,
    fallback_count_query: Any,
) -> int:
    """Resolve paged total via window count with empty-page fallback.

    When using window functions for pagination (e.g., func.count().over()),
    the total is included in each row. However, if the page is empty,
    we need a fallback query to get the total count.

    Args:
        db: AsyncSession for database access
        rows: Result rows from the main query
        total_index: Index of the total count column in the result row
        fallback_count_query: SQLAlchemy query to get total count

    Returns:
        Total count of items
    """
    if rows:
        return int(rows[0][total_index] or 0)
    return int(await db.scalar(fallback_count_query) or 0)


async def get_by_id(
    db: AsyncSession,
    model: type[T],
    id: int,
    *,
    id_column: str = "id",
) -> T | None:
    """Get a single record by ID.

    Args:
        db: AsyncSession for database access
        model: SQLAlchemy model class
        id: The ID to look up
        id_column: Name of the ID column (default: "id")

    Returns:
        The model instance or None if not found
    """
    column = getattr(model, id_column)
    stmt = select(model).where(column == id)
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def get_by_field(
    db: AsyncSession,
    model: type[T],
    field_name: str,
    value: Any,
) -> T | None:
    """Get a single record by a field value.

    Args:
        db: AsyncSession for database access
        model: SQLAlchemy model class
        field_name: Name of the field to filter on
        value: Value to match

    Returns:
        The model instance or None if not found
    """
    column = getattr(model, field_name)
    stmt = select(model).where(column == value)
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def get_by_field_insensitive(
    db: AsyncSession,
    model: type[T],
    field_name: str,
    value: str,
) -> T | None:
    """Get a single record by a case-insensitive field value.

    Args:
        db: AsyncSession for database access
        model: SQLAlchemy model class
        field_name: Name of the field to filter on
        value: Value to match (case-insensitive)

    Returns:
        The model instance or None if not found
    """
    column = getattr(model, field_name)
    stmt = select(model).where(func.lower(column) == func.lower(value))
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def exists_by_id(
    db: AsyncSession,
    model: type[Any],
    id: int,
    *,
    id_column: str = "id",
) -> bool:
    """Check if a record exists by ID.

    Args:
        db: AsyncSession for database access
        model: SQLAlchemy model class
        id: The ID to check
        id_column: Name of the ID column (default: "id")

    Returns:
        True if record exists, False otherwise
    """
    column = getattr(model, id_column)
    stmt = select(func.count()).select_from(model).where(column == id)
    result = await db.scalar(stmt)
    return (result or 0) > 0


async def count_records(
    db: AsyncSession,
    model: type[Any],
    *,
    filters: list[Any] | None = None,
) -> int:
    """Count records, optionally with filters.

    Args:
        db: AsyncSession for database access
        model: SQLAlchemy model class
        filters: Optional list of filter conditions

    Returns:
        Number of matching records
    """
    stmt = select(func.count()).select_from(model)
    if filters:
        stmt = stmt.where(*filters)
    result = await db.scalar(stmt)
    return result or 0


def calculate_offset(page: int, size: int) -> int:
    """Calculate offset for pagination.

    Args:
        page: Page number (1-indexed)
        size: Number of items per page

    Returns:
        Offset value for SQL query
    """
    return (page - 1) * size


def build_paginated_response(
    items: list[Any],
    total: int,
    page: int,
    size: int,
) -> PaginatedResponse:
    """Build a standardized paginated response.

    Args:
        items: List of items for current page
        total: Total number of items
        page: Current page number
        size: Items per page

    Returns:
        PaginatedResponse with items and metadata
    """
    total_pages = (total + size - 1) // size if size > 0 else 0
    return PaginatedResponse(
        items=items,
        total=total,
        page=page,
        size=size,
        pages=total_pages,
    )
