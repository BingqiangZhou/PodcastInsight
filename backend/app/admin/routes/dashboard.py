"""Admin dashboard route module."""

import logging

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.admin.auth import admin_required
from app.admin.routes._shared import get_templates
from app.core.database import get_db_session


logger = logging.getLogger(__name__)

router = APIRouter()
templates = get_templates()


@router.get("/", response_class=HTMLResponse)
async def dashboard(
    request: Request,
    user_id: int = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Display admin dashboard."""
    from app.admin.services.dashboard_service import get_dashboard_context

    try:
        context = await get_dashboard_context(db)

        return templates.TemplateResponse(
            request,
            "dashboard.html",
            {
                "request": request,
                **context,
                "messages": [],
            },
        )
    except Exception as e:
        logger.error(f"Dashboard error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to load dashboard",
        ) from e
