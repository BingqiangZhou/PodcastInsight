"""Admin API keys management routes module."""

import logging

from fastapi import APIRouter, Body, Depends, Form, HTTPException, Request, status
from fastapi.responses import HTMLResponse, Response
from pydantic import BaseModel

from app.admin.auth import admin_required
from app.admin.dependencies import get_admin_apikeys_service
from app.admin.routes._shared import (
    get_templates,
    json_payload,
    render_admin_template,
    require_payload,
)
from app.admin.services import AdminApiKeysService
from app.domains.user.models import User


logger = logging.getLogger(__name__)

router = APIRouter()
templates = get_templates()


class ExportRequest(BaseModel):
    """Request model for API key export."""

    mode: str = "encrypted"
    export_password: str | None = None


@router.get("/apikeys", response_class=HTMLResponse)
async def apikeys_page(
    request: Request,
    user: User = Depends(admin_required),
    service: AdminApiKeysService = Depends(get_admin_apikeys_service),
    model_type_filter: str | None = None,
    page: int = 1,
    per_page: int = 10,
):
    """Display API keys management page with filtering and pagination."""
    try:
        context = await service.get_page_context(
            model_type_filter=model_type_filter,
            page=page,
            per_page=per_page,
        )
        return render_admin_template(
            templates=templates,
            template_name="apikeys.html",
            request=request,
            user=user,
            messages=[],
            **context,
        )
    except Exception as exc:
        logger.error("API keys page error: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to load API keys",
        ) from exc


@router.post("/apikeys/test")
async def test_apikey(
    request: Request,
    api_url: str = Body(...),
    api_key: str | None = Body(None),
    model_type: str = Body(...),
    name: str | None = Body(None),
    key_id: int | None = Body(None),
    user: User = Depends(admin_required),
    service: AdminApiKeysService = Depends(get_admin_apikeys_service),
):
    """Test API key connection before creating a new model config."""
    try:
        payload, status_code = await service.test_apikey_connection(
            api_url=api_url,
            api_key=api_key,
            model_type=model_type,
            name=name,
            key_id=key_id,
            username=user.username,
        )
        return json_payload(payload, status_code=status_code)
    except Exception as exc:
        logger.error("API key test error: %s", exc)
        return json_payload(
            {"success": False, "message": f"测试失败: {exc}"},
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )


@router.post("/apikeys/create")
async def create_apikey(
    request: Request,
    name: str = Form(...),
    display_name: str = Form(...),
    model_type: str = Form(...),
    api_url: str = Form(...),
    api_key: str = Form(...),
    provider: str = Form(default="custom"),
    description: str | None = Form(None),
    priority: int = Form(default=1),
    user: User = Depends(admin_required),
    service: AdminApiKeysService = Depends(get_admin_apikeys_service),
):
    """Create a new AI Model Config with API key."""
    try:
        payload = await service.create_apikey(
            request=request,
            user=user,
            name=name,
            display_name=display_name,
            model_type=model_type,
            api_url=api_url,
            api_key=api_key,
            provider=provider,
            description=description,
            priority=priority,
        )
        return json_payload(payload)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        logger.error("Create API key error: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create API key",
        ) from exc


@router.put("/apikeys/{key_id}/toggle")
async def toggle_apikey(
    key_id: int,
    request: Request,
    user: User = Depends(admin_required),
    service: AdminApiKeysService = Depends(get_admin_apikeys_service),
):
    """Toggle AI Model Config active status."""
    try:
        payload = await service.toggle_apikey(
            request=request,
            user=user,
            key_id=key_id,
        )
        return json_payload(
            require_payload(payload, detail="API key not found"),
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Toggle API key error: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to toggle API key",
        ) from exc


@router.put("/apikeys/{key_id}/edit")
async def edit_apikey(
    key_id: int,
    request: Request,
    name: str | None = Body(None),
    display_name: str | None = Body(None),
    model_type: str | None = Body(None),
    api_url: str | None = Body(None),
    api_key: str | None = Body(None),
    provider: str | None = Body(None),
    description: str | None = Body(None),
    priority: int | None = Body(None),
    user: User = Depends(admin_required),
    service: AdminApiKeysService = Depends(get_admin_apikeys_service),
):
    """Edit an AI Model Config."""
    try:
        payload = await service.edit_apikey(
            request=request,
            user=user,
            key_id=key_id,
            name=name,
            display_name=display_name,
            model_type=model_type,
            api_url=api_url,
            api_key=api_key,
            provider=provider,
            description=description,
            priority=priority,
        )
        return json_payload(
            require_payload(payload, detail="API key not found"),
        )
    except HTTPException:
        raise
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        logger.error("Edit API key error: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update API key",
        ) from exc


@router.delete("/apikeys/{key_id}/delete")
async def delete_apikey(
    key_id: int,
    request: Request,
    user: User = Depends(admin_required),
    service: AdminApiKeysService = Depends(get_admin_apikeys_service),
):
    """Delete an AI Model Config."""
    try:
        payload = await service.delete_apikey(
            request=request,
            user=user,
            key_id=key_id,
        )
        return json_payload(
            require_payload(payload, detail="API key not found"),
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Delete API key error: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete API key",
        ) from exc


@router.post("/api/apikeys/export/json")
async def export_apikeys_json(
    request: Request,
    user: User = Depends(admin_required),
    service: AdminApiKeysService = Depends(get_admin_apikeys_service),
    export_req: ExportRequest = Body(default=ExportRequest()),
):
    """Export all API keys to JSON format."""
    try:
        result = await service.export_json(
            request=request,
            user=user,
            mode=export_req.mode,
            export_password=export_req.export_password,
        )
        if isinstance(result[0], dict):
            payload, status_code = result
            return json_payload(payload, status_code=status_code)

        content, filename = result
        return Response(
            content=content,
            media_type="application/json",
            headers={"Content-Disposition": f"attachment; filename={filename}"},
        )
    except Exception as exc:
        logger.error("JSON export error: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to export JSON: {exc}",
        ) from exc


@router.post("/api/apikeys/import/json")
async def import_apikeys_json(
    request: Request,
    user: User = Depends(admin_required),
    service: AdminApiKeysService = Depends(get_admin_apikeys_service),
):
    """Import API keys from JSON format."""
    try:
        raw_body = await request.body()
        payload, status_code = await service.import_json(
            request=request,
            user=user,
            raw_body=raw_body,
        )
        return json_payload(payload, status_code=status_code)
    except Exception as exc:
        logger.error("JSON import error: %s", exc)
        return json_payload(
            {"success": False, "message": f"Import failed: {exc}"},
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )
