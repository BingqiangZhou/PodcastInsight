"""Admin settings routes module."""

from fastapi import APIRouter, Body, Depends, Request
from fastapi.responses import HTMLResponse

from app.admin.auth import admin_required
from app.admin.routes._shared import get_templates, json_payload, render_admin_template
from app.admin.services import AdminSettingsService
from app.core.providers import get_admin_settings_service
from app.domains.user.models import User
from app.http.decorators import handle_admin_errors


router = APIRouter()
templates = get_templates()


@router.get("/settings", response_class=HTMLResponse)
@handle_admin_errors("load settings page")
async def settings_page(
    request: Request,
    user: User = Depends(admin_required),
):
    """Display system settings page."""
    return render_admin_template(
        templates=templates,
        template_name="settings.html",
        request=request,
        user=user,
        messages=[],
    )


@router.get("/settings/api/audio")
@handle_admin_errors("get audio settings")
async def get_audio_settings(
    _: User = Depends(admin_required),
    service: AdminSettingsService = Depends(get_admin_settings_service),
):
    """Get audio processing settings as JSON."""
    return json_payload(await service.get_audio_settings())


@router.post("/settings/api/audio")
@handle_admin_errors("update audio settings")
async def update_audio_settings(
    request: Request,
    chunk_size_mb: int = Body(..., embed=True),
    max_concurrent_threads: int = Body(..., embed=True),
    user: User = Depends(admin_required),
    service: AdminSettingsService = Depends(get_admin_settings_service),
):
    """Update audio processing settings."""
    return json_payload(
        await service.save_audio_settings(
            request=request,
            user=user,
            chunk_size_mb=chunk_size_mb,
            max_concurrent_threads=max_concurrent_threads,
        ),
    )


@router.get("/settings/frequency")
@handle_admin_errors("get frequency settings")
async def get_frequency_settings(
    _: Request,
    __: User = Depends(admin_required),
    service: AdminSettingsService = Depends(get_admin_settings_service),
):
    """Get RSS subscription update frequency settings."""
    return json_payload(await service.get_frequency_settings())


@router.post("/settings/frequency")
@handle_admin_errors("update frequency settings")
async def update_frequency_settings(
    request: Request,
    update_frequency: str = Body(..., embed=True),
    update_time: str | None = Body(None, embed=True),
    update_day: int | None = Body(None, embed=True),
    user: User = Depends(admin_required),
    service: AdminSettingsService = Depends(get_admin_settings_service),
):
    """Update RSS subscription update frequency settings."""
    return json_payload(
        await service.save_frequency_settings(
            request=request,
            user=user,
            update_frequency=update_frequency,
            update_time=update_time,
            update_day=update_day,
        ),
    )


@router.get("/settings/api/security")
@handle_admin_errors("get security settings")
async def get_security_settings(
    _: User = Depends(admin_required),
    service: AdminSettingsService = Depends(get_admin_settings_service),
):
    """Get security settings as JSON."""
    return json_payload(await service.get_security_settings())


@router.post("/settings/api/security")
@handle_admin_errors("update security settings")
async def update_security_settings(
    request: Request,
    admin_2fa_enabled: bool = Body(..., embed=True),
    user: User = Depends(admin_required),
    service: AdminSettingsService = Depends(get_admin_settings_service),
):
    """Update security settings."""
    return json_payload(
        await service.save_security_settings(
            request=request,
            user=user,
            admin_2fa_enabled=admin_2fa_enabled,
        ),
    )


@router.get("/settings/api/storage/info")
@handle_admin_errors("get storage information")
async def get_storage_info(
    _: User = Depends(admin_required),
    service: AdminSettingsService = Depends(get_admin_settings_service),
):
    """Get storage information as JSON."""
    return json_payload(await service.get_storage_info())


@router.get("/settings/api/storage/cleanup/config")
@handle_admin_errors("get cleanup configuration")
async def get_cleanup_config(
    _: User = Depends(admin_required),
    service: AdminSettingsService = Depends(get_admin_settings_service),
):
    """Get auto cleanup configuration as JSON."""
    return json_payload(await service.get_cleanup_config())


@router.post("/settings/api/storage/cleanup/config")
@handle_admin_errors("update cleanup configuration")
async def update_cleanup_config(
    request: Request,
    enabled: bool = Body(..., embed=True),
    user: User = Depends(admin_required),
    service: AdminSettingsService = Depends(get_admin_settings_service),
):
    """Update auto cleanup configuration."""
    return json_payload(
        await service.save_cleanup_config(
            request=request,
            user=user,
            enabled=enabled,
        ),
    )


@router.post("/settings/api/storage/cleanup/execute")
@handle_admin_errors("execute cleanup")
async def execute_cleanup(
    request: Request,
    keep_days: int = Body(1, embed=True),
    user: User = Depends(admin_required),
    service: AdminSettingsService = Depends(get_admin_settings_service),
):
    """Execute manual cleanup."""
    return json_payload(
        await service.run_cleanup(
            request=request,
            user=user,
            keep_days=keep_days,
        ),
    )
