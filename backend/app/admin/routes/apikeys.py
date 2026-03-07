"""Admin API keys management routes module.

This module contains all routes related to AI Model Config management:
- API keys listing with filtering and pagination
- API key testing
- API key creation, editing, toggling, deletion
- API keys export/import (JSON format)
"""

import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Body, Depends, Form, HTTPException, Request, status
from fastapi.responses import HTMLResponse, JSONResponse, Response
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.admin.audit import log_admin_action
from app.admin.dependencies import admin_required
from app.admin.routes._shared import get_templates
from app.admin.services import AdminApiKeysService
from app.core.database import get_db_session
from app.core.security import (
    decrypt_data,
    decrypt_data_with_password,
    encrypt_data,
    encrypt_data_with_password,
    validate_export_password,
)
from app.domains.ai.models import AIModelConfig, ModelType
from app.domains.user.models import User


logger = logging.getLogger(__name__)

router = APIRouter()
templates = get_templates()


# ==================== API Key Management ====================


@router.get("/apikeys", response_class=HTMLResponse)
async def apikeys_page(
    request: Request,
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
    model_type_filter: str | None = None,
    page: int = 1,
    per_page: int = 10,
):
    """Display API keys management page with filtering and pagination."""
    try:
        context = await AdminApiKeysService(db).get_page_context(
            model_type_filter=model_type_filter,
            page=page,
            per_page=per_page,
        )
        return templates.TemplateResponse(
            "apikeys.html",
            {
                "request": request,
                "user": user,
                "messages": [],
                **context,
            },
        )

        # Build base query
        query = select(AIModelConfig)

        # Apply model type filter if specified
        if model_type_filter and model_type_filter in ['transcription', 'text_generation']:
            query = query.where(AIModelConfig.model_type == model_type_filter)

        # Get total count
        count_query = select(func.count()).select_from(query.subquery())
        total_count_result = await db.execute(count_query)
        total_count = total_count_result.scalar() or 0

        # Calculate pagination
        total_pages = (total_count + per_page - 1) // per_page if total_count > 0 else 1
        offset = (page - 1) * per_page

        # Get paginated results, ordered by priority then created_at
        result = await db.execute(
            query.order_by(AIModelConfig.priority.asc(), AIModelConfig.created_at.desc())
            .limit(per_page)
            .offset(offset)
        )
        apikeys = result.scalars().all()

        # Decrypt and mask API keys for display
        for config in apikeys:
            # Check if API key exists (truthy check for both string and None)
            if not config.api_key or not config.api_key.strip():
                logger.warning(f"API key for config {config.id} ({config.name}) is empty or None")
                config.api_key = '****'
            elif config.api_key_encrypted:
                try:
                    decrypted_key = decrypt_data(config.api_key)
                    # Mask the API key: show first 4 and last 4 characters
                    if len(decrypted_key) > 8:
                        config.api_key = decrypted_key[:4] + '****' + decrypted_key[-4:]
                    else:
                        logger.warning(f"Decrypted API key for config {config.id} ({config.name}) is too short: {len(decrypted_key)} chars")
                        config.api_key = '****'
                except Exception as e:
                    logger.warning(f"Failed to decrypt API key for config {config.id} ({config.name}): {type(e).__name__}: {e}. Encrypted key length: {len(config.api_key)}, starts with: {config.api_key[:20] if len(config.api_key) >= 20 else config.api_key}")
                    # Show clear message that the key needs to be re-entered
                    config.api_key = '[密钥无法解密-请重新编辑]'
            else:
                # Not encrypted - mask the original value
                if len(config.api_key) > 8:
                    config.api_key = config.api_key[:4] + '****' + config.api_key[-4:]
                else:
                    config.api_key = '****'

        return templates.TemplateResponse(
            "apikeys.html",
            {
                "request": request,
                "user": user,
                "apikeys": apikeys,
                "model_type_filter": model_type_filter or '',
                "page": page,
                "per_page": per_page,
                "total_count": total_count,
                "total_pages": total_pages,
                "messages": [],
            },
        )
    except Exception as e:
        logger.error(f"API keys page error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to load API keys",
        ) from e


@router.post("/apikeys/test")
async def test_apikey(
    request: Request,
    api_url: str = Body(...),
    api_key: str | None = Body(None),
    model_type: str = Body(...),
    name: str | None = Body(None),
    key_id: int | None = Body(None),
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Test API key connection before creating a new model config."""
    try:
        # Import the AI service for validation
        from app.domains.ai.services import AIModelConfigService

        service = AIModelConfigService(db)

        # Convert model_type string to ModelType enum
        try:
            model_type_enum = ModelType(model_type)
        except ValueError:
            return JSONResponse(
                content={"success": False, "message": f"无效的模型类型: {model_type}"},
                status_code=status.HTTP_400_BAD_REQUEST
            )

        resolved_from_db = False
        effective_api_key = (api_key or "").strip()
        if not effective_api_key:
            if not key_id:
                return JSONResponse(
                    content={
                        "success": False,
                        "message": "API key is required when key_id is not provided.",
                    },
                    status_code=status.HTTP_400_BAD_REQUEST,
                )

            result = await db.execute(
                select(AIModelConfig).where(AIModelConfig.id == key_id)
            )
            model_config = result.scalar_one_or_none()
            if not model_config:
                return JSONResponse(
                    content={
                        "success": False,
                        "message": f"Model config {key_id} not found.",
                    },
                    status_code=status.HTTP_404_NOT_FOUND,
                )

            stored_key = (model_config.api_key or "").strip()
            if not stored_key:
                return JSONResponse(
                    content={
                        "success": False,
                        "message": "Stored API key is empty. Please enter and save a new API key.",
                    },
                    status_code=status.HTTP_400_BAD_REQUEST,
                )

            if model_config.api_key_encrypted:
                try:
                    effective_api_key = decrypt_data(stored_key).strip()
                except Exception as exc:
                    logger.warning(
                        "Failed to decrypt API key for config %s (%s): %s",
                        model_config.id,
                        model_config.name,
                        exc,
                    )
                    return JSONResponse(
                        content={
                            "success": False,
                            "message": "Failed to decrypt stored API key. Please re-enter and save a new API key.",
                        },
                        status_code=status.HTTP_400_BAD_REQUEST,
                    )
            else:
                effective_api_key = stored_key

            if not effective_api_key:
                return JSONResponse(
                    content={
                        "success": False,
                        "message": "Stored API key is invalid. Please enter and save a new API key.",
                    },
                    status_code=status.HTTP_400_BAD_REQUEST,
                )

            resolved_from_db = True

        # Validate the API key
        validation_result = await service.validate_api_key(
            api_url=api_url,
            api_key=effective_api_key,
            model_id=name,
            model_type=model_type_enum
        )

        if validation_result.valid:
            logger.info(f"API key test successful for model type {model_type} by user {user.username}")
            return JSONResponse(content={
                "success": True,
                "message": "API密钥测试成功",
                "test_result": validation_result.test_result,
                "response_time_ms": validation_result.response_time_ms,
                "used_stored_key": resolved_from_db
            })
        else:
            logger.warning(f"API key test failed for model type {model_type} by user {user.username}: {validation_result.error_message}")
            return JSONResponse(
                content={
                    "success": False,
                    "message": f"API密钥测试失败: {validation_result.error_message}",
                    "error_message": validation_result.error_message
                },
                status_code=status.HTTP_400_BAD_REQUEST
            )
    except Exception as e:
        logger.error(f"API key test error: {e}")
        return JSONResponse(
            content={"success": False, "message": f"测试失败: {str(e)}"},
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
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
    db: AsyncSession = Depends(get_db_session),
):
    """Create a new AI Model Config with API key."""
    try:
        # Encrypt the API key using Fernet symmetric encryption
        encrypted_key = encrypt_data(api_key)

        # Validate encrypted key length (Fernet produces at least 44 characters)
        if len(encrypted_key) < 44:
            logger.error(f"Encryption produced invalid length: {len(encrypted_key)} for key {name}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="API key encryption failed - invalid encrypted data length"
            )

        # Create AI Model Config - use name as model_id
        new_config = AIModelConfig(
            name=name,
            display_name=display_name,
            description=description,
            model_type=model_type,
            api_url=api_url,
            api_key=encrypted_key,
            api_key_encrypted=True,
            model_id=name,  # Use name as model_id
            provider=provider,
            is_active=True,
            priority=priority,
        )
        db.add(new_config)
        await db.commit()
        await db.refresh(new_config)

        logger.info(f"AI Model Config created: {name} by user {user.username}")

        # Log audit action
        await log_admin_action(
            db=db,
            user_id=user.id,
            username=user.username,
            action="create",
            resource_type="apikey",
            resource_id=new_config.id,
            resource_name=display_name,
            details={
                "name": name,
                "model_type": model_type,
                "provider": provider,
                "priority": priority,
            },
            request=request,
        )

        # Return JSON response for AJAX handling
        return JSONResponse(content={
            "success": True,
            "message": f"模型配置 '{display_name}' 已成功创建"
        })
    except Exception as e:
        logger.error(f"Create API key error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create API key",
        ) from e


@router.put("/apikeys/{key_id}/toggle")
async def toggle_apikey(
    key_id: int,
    request: Request,
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Toggle AI Model Config active status."""
    try:
        result = await db.execute(
            select(AIModelConfig).where(AIModelConfig.id == key_id)
        )
        model_config = result.scalar_one_or_none()

        if not model_config:
            raise HTTPException(status_code=404, detail="API key not found")

        model_config.is_active = not model_config.is_active
        await db.commit()
        await db.refresh(model_config)

        logger.info(
            f"AI Model Config {key_id} toggled to {model_config.is_active} by user {user.username}"
        )

        # Log audit action
        await log_admin_action(
            db=db,
            user_id=user.id,
            username=user.username,
            action="toggle",
            resource_type="apikey",
            resource_id=key_id,
            resource_name=model_config.display_name,
            details={"is_active": model_config.is_active},
            request=request,
        )

        return JSONResponse(content={"success": True})
    except Exception as e:
        logger.error(f"Toggle API key error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to toggle API key",
        ) from e


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
    db: AsyncSession = Depends(get_db_session),
):
    """Edit an AI Model Config."""
    try:
        result = await db.execute(
            select(AIModelConfig).where(AIModelConfig.id == key_id)
        )
        model_config = result.scalar_one_or_none()

        if not model_config:
            raise HTTPException(status_code=404, detail="API key not found")

        # Store old values for audit log
        old_values = {
            "name": model_config.name,
            "display_name": model_config.display_name,
            "model_type": model_config.model_type,
            "api_url": model_config.api_url,
            "provider": model_config.provider,
            "description": model_config.description,
            "priority": model_config.priority,
        }

        # Update fields if provided
        if name is not None:
            model_config.name = name
            model_config.model_id = name  # Update model_id to match name
        if display_name is not None:
            model_config.display_name = display_name
        if model_type is not None:
            model_config.model_type = model_type
        if api_url is not None:
            model_config.api_url = api_url
        if provider is not None:
            model_config.provider = provider
        if description is not None:
            model_config.description = description
        if priority is not None:
            model_config.priority = priority
        if api_key is not None and api_key.strip():
            # Encrypt new API key
            encrypted_key = encrypt_data(api_key)
            # Validate encrypted key length (Fernet produces at least 44 characters)
            if len(encrypted_key) < 44:
                logger.error(f"Encryption produced invalid length: {len(encrypted_key)} for config {key_id}")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="API key encryption failed - invalid encrypted data length"
                )
            model_config.api_key = encrypted_key
            model_config.api_key_encrypted = True

        await db.commit()
        await db.refresh(model_config)

        logger.info(f"AI Model Config {key_id} updated by user {user.username}")

        # Log audit action
        await log_admin_action(
            db=db,
            user_id=user.id,
            username=user.username,
            action="update",
            resource_type="apikey",
            resource_id=key_id,
            resource_name=model_config.display_name,
            details={"old_values": old_values, "new_values": {
                "name": model_config.name,
                "display_name": model_config.display_name,
                "model_type": model_config.model_type,
                "priority": model_config.priority,
            }},
            request=request,
        )

        return JSONResponse(content={"success": True})
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Edit API key error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update API key",
        ) from e


@router.delete("/apikeys/{key_id}/delete")
async def delete_apikey(
    key_id: int,
    request: Request,
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Delete an AI Model Config."""
    try:
        result = await db.execute(
            select(AIModelConfig).where(AIModelConfig.id == key_id)
        )
        model_config = result.scalar_one_or_none()

        if not model_config:
            raise HTTPException(status_code=404, detail="API key not found")

        # Store name before deletion
        resource_name = model_config.display_name

        await db.delete(model_config)
        await db.commit()

        logger.info(f"AI Model Config {key_id} deleted by user {user.username}")

        # Log audit action
        await log_admin_action(
            db=db,
            user_id=user.id,
            username=user.username,
            action="delete",
            resource_type="apikey",
            resource_id=key_id,
            resource_name=resource_name,
            request=request,
        )

        return JSONResponse(content={"success": True})
    except Exception as e:
        logger.error(f"Delete API key error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete API key",
        ) from e


class ExportRequest(BaseModel):
    """Request model for API key export."""
    mode: str = "encrypted"  # "plaintext" or "encrypted"
    export_password: str | None = None  # Required for encrypted mode


@router.post("/api/apikeys/export/json")
async def export_apikeys_json(
    request: Request,
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
    export_req: ExportRequest = Body(default=ExportRequest()),
):
    """Export all API keys to JSON format.

    Args:
        export_req: Export request containing mode and password
            - mode: "plaintext" (decrypted) or "encrypted" (password-protected)
            - export_password: Required when mode="encrypted"

    API keys handling:
    - plaintext: API keys are decrypted in JSON (for trusted environments)
    - encrypted: API keys are encrypted with export password (for production)
    """
    try:
        import json

        mode = export_req.mode
        export_password = export_req.export_password

        # Validate mode
        if mode not in ["plaintext", "encrypted"]:
            return JSONResponse(
                content={"success": False, "message": f"Invalid mode: {mode}"},
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # For encrypted mode, validate password
        if mode == "encrypted":
            if not export_password:
                return JSONResponse(
                    content={"success": False, "message": "export_password is required for encrypted mode"},
                    status_code=status.HTTP_400_BAD_REQUEST
                )
            # Validate password strength
            is_valid, error_msg = validate_export_password(export_password)
            if not is_valid:
                return JSONResponse(
                    content={"success": False, "message": f"Weak password: {error_msg}"},
                    status_code=status.HTTP_400_BAD_REQUEST
                )

        # Get all API keys
        result = await db.execute(
            select(AIModelConfig).order_by(AIModelConfig.priority.asc(), AIModelConfig.created_at.desc())
        )
        apikeys = result.scalars().all()

        # Build export data
        export_data = {
            "version": "2.0",  # New version to indicate format change
            "export_mode": mode,
            "exported_at": datetime.now(timezone.utc).isoformat(),
            "exported_by": user.username,
            "total_count": len(apikeys),
            "apikeys": []
        }

        for key in apikeys:
            key_data = {
                "name": key.name,
                "display_name": key.display_name,
                "provider": key.provider,
                "model_type": key.model_type,
                "api_url": key.api_url,
                "priority": key.priority,
                "description": key.description,
                "is_active": key.is_active,
                "created_at": key.created_at.isoformat() if key.created_at else None,
            }

            # Handle API key based on mode
            if mode == "plaintext":
                # Decrypt API key for plaintext export
                try:
                    if key.api_key_encrypted:
                        decrypted_key = decrypt_data(key.api_key)
                        key_data["api_key"] = decrypted_key
                        key_data["api_key_encrypted"] = False
                    else:
                        # Already plaintext (shouldn't happen in normal operation)
                        key_data["api_key"] = key.api_key
                        key_data["api_key_encrypted"] = False
                except Exception as e:
                    logger.warning(f"Failed to decrypt API key for {key.name}: {e}")
                    key_data["api_key"] = ""
                    key_data["api_key_error"] = "Decryption failed"

            else:  # mode == "encrypted"
                # Encrypt API key with export password
                try:
                    if key.api_key_encrypted:
                        # First decrypt with SECRET_KEY, then re-encrypt with password
                        decrypted_key = decrypt_data(key.api_key)
                        encrypted_dict = encrypt_data_with_password(decrypted_key, export_password)
                        key_data["api_key_encrypted_export"] = encrypted_dict
                        key_data["api_key_encrypted_flag"] = True
                    else:
                        # Directly encrypt plaintext with password
                        encrypted_dict = encrypt_data_with_password(key.api_key, export_password)
                        key_data["api_key_encrypted_export"] = encrypted_dict
                        key_data["api_key_encrypted_flag"] = True
                except Exception as e:
                    logger.warning(f"Failed to encrypt API key for {key.name}: {e}")
                    key_data["api_key_encrypted_export"] = None
                    key_data["api_key_error"] = "Encryption failed"

            export_data["apikeys"].append(key_data)

        # Log audit action with mode details
        await log_admin_action(
            db=db,
            user_id=user.id,
            username=user.username,
            action="export_json",
            resource_type="apikey",
            details={
                "count": len(apikeys),
                "mode": mode,
                "plaintext_warning": mode == "plaintext"  # Flag for security audit
            },
            request=request,
        )

        logger.info(f"Exported {len(apikeys)} API keys to JSON (mode={mode}) by user {user.username}")

        # Add security warning for plaintext mode in filename
        mode_suffix = "_PLAINTEXT" if mode == "plaintext" else ""
        filename = f"apikeys_export{mode_suffix}_{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')}.json"

        return Response(
            content=json.dumps(export_data, indent=2, ensure_ascii=False),
            media_type="application/json",
            headers={
                "Content-Disposition": f"attachment; filename={filename}"
            }
        )
    except Exception as e:
        logger.error(f"JSON export error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to export JSON: {str(e)}",
        ) from e


@router.post("/api/apikeys/import/json")
async def import_apikeys_json(
    request: Request,
    user: User = Depends(admin_required),
    db: AsyncSession = Depends(get_db_session),
):
    """Import API keys from JSON format.

    Request body (JSON):
        file: JSON file content as string
        mode: Import mode - 'skip' (skip if exists), 'update' (update if exists), 'replace' (replace all)
        import_password: Password to decrypt encrypted exports (required for export_mode="encrypted")
        test_before_import: Whether to test API keys before importing

    Returns:
        JSON response with import statistics
    """
    try:
        import json

        # Parse request body - get raw body first for debugging
        raw_body = await request.body()
        logger.info(f"Import API received raw body (first 200 chars): {raw_body[:200] if raw_body else 'empty'}")

        if not raw_body:
            return JSONResponse(
                content={"success": False, "message": "Empty request body"},
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Parse JSON
        try:
            body = json.loads(raw_body.decode('utf-8'))
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse request JSON: {e}")
            return JSONResponse(
                content={"success": False, "message": f"Invalid JSON in request body: {str(e)}"},
                status_code=status.HTTP_400_BAD_REQUEST
            )

        file_content = body.get("file")
        mode = body.get("mode", "skip")
        import_password = body.get("import_password")

        logger.info(f"Import request: mode={mode}, has_file={bool(file_content)}, has_password={bool(import_password)}")

        if not file_content:
            logger.error(f"Request body keys: {list(body.keys())}")
            return JSONResponse(
                content={"success": False, "message": "Missing 'file' field in request body"},
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Parse JSON file content
        try:
            import_data = json.loads(file_content)
        except json.JSONDecodeError as e:
            return JSONResponse(
                content={"success": False, "message": f"Invalid JSON format: {str(e)}"},
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Validate JSON structure
        if "apikeys" not in import_data:
            return JSONResponse(
                content={"success": False, "message": "Invalid format: missing 'apikeys' field"},
                status_code=status.HTTP_400_BAD_REQUEST
            )

        apikeys_list = import_data["apikeys"]
        if not isinstance(apikeys_list, list):
            return JSONResponse(
                content={"success": False, "message": "Invalid format: 'apikeys' must be a list"},
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Detect export format version
        export_version = import_data.get("version")
        export_mode = import_data.get("export_mode", "encrypted")

        if export_version != "2.0":
            return JSONResponse(
                content={
                    "success": False,
                    "message": "Unsupported export version. Please import version 2.0 data."
                },
                status_code=status.HTTP_400_BAD_REQUEST
            )

        if export_mode not in {"plaintext", "encrypted"}:
            return JSONResponse(
                content={
                    "success": False,
                    "message": f"Invalid export_mode: {export_mode}"
                },
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Validate import password for encrypted exports
        if export_mode == "encrypted" and not import_password:
            return JSONResponse(
                content={
                    "success": False,
                    "message": "import_password is required for encrypted exports"
                },
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Import statistics
        success_count = 0
        updated_count = 0
        skipped_count = 0
        error_count = 0
        errors = []

        # Get existing API keys for comparison
        existing_result = await db.execute(select(AIModelConfig))
        existing_keys = {k.name: k for k in existing_result.scalars().all()}

        for idx, key_data in enumerate(apikeys_list):
            try:
                # Validate required fields
                required_fields = ["name", "display_name", "model_type", "api_url"]
                missing_fields = [f for f in required_fields if not key_data.get(f)]
                if missing_fields:
                    error_msg = f"Row {idx + 1}: Missing required fields: {', '.join(missing_fields)}"
                    errors.append(error_msg)
                    error_count += 1
                    continue

                # Validate model_type
                model_type = key_data.get("model_type")
                if model_type not in ["transcription", "text_generation"]:
                    error_msg = f"Row {idx + 1}: Invalid model_type '{model_type}'"
                    errors.append(error_msg)
                    error_count += 1
                    continue

                name = key_data["name"]

                # Decrypt API key based on export format
                api_key_plaintext = None

                if export_mode == "plaintext":
                    # Plaintext export (v2.0)
                    api_key_plaintext = key_data.get("api_key")
                    if not api_key_plaintext:
                        error_msg = f"Row {idx + 1}: Missing api_key in plaintext export"
                        errors.append(error_msg)
                        error_count += 1
                        continue

                elif export_mode == "encrypted":
                    # Encrypted export (v2.0)
                    encrypted_dict = key_data.get("api_key_encrypted_export")
                    if not encrypted_dict:
                        error_msg = f"Row {idx + 1}: Missing api_key_encrypted_export"
                        errors.append(error_msg)
                        error_count += 1
                        continue

                    try:
                        api_key_plaintext = decrypt_data_with_password(encrypted_dict, import_password)
                    except ValueError as e:
                        error_msg = f"Row {idx + 1}: Failed to decrypt API key: {str(e)}"
                        errors.append(error_msg)
                        error_count += 1
                        continue

                # Check if key already exists
                existing_key = existing_keys.get(name)

                if existing_key:
                    if mode == "skip":
                        skipped_count += 1
                        continue
                    elif mode == "update" or mode == "replace":
                        # Update existing key
                        if "display_name" in key_data:
                            existing_key.display_name = key_data["display_name"]
                        if "provider" in key_data:
                            existing_key.provider = key_data["provider"]
                        if "model_type" in key_data:
                            existing_key.model_type = key_data["model_type"]
                        if "api_url" in key_data:
                            existing_key.api_url = key_data["api_url"]
                        if "priority" in key_data:
                            existing_key.priority = key_data["priority"]
                        if "description" in key_data:
                            existing_key.description = key_data["description"]
                        if "is_active" in key_data:
                            existing_key.is_active = key_data["is_active"]

                        # Update API key if we successfully decrypted it
                        if api_key_plaintext:
                            encrypted_key = encrypt_data(api_key_plaintext)
                            if len(encrypted_key) < 44:
                                logger.error(f"Encryption produced invalid length for config {name}")
                                error_msg = f"Row {idx + 1}: Failed to encrypt API key"
                                errors.append(error_msg)
                                error_count += 1
                                continue
                            existing_key.api_key = encrypted_key
                            existing_key.api_key_encrypted = True

                        updated_count += 1
                    else:
                        skipped_count += 1
                        continue
                else:
                    # Create new API key
                    if api_key_plaintext:
                        encrypted_key = encrypt_data(api_key_plaintext)
                        if len(encrypted_key) < 44:
                            logger.error(f"Encryption produced invalid length for config {name}")
                            error_msg = f"Row {idx + 1}: Failed to encrypt API key"
                            errors.append(error_msg)
                            error_count += 1
                            continue
                    else:
                        encrypted_key = ""

                    new_key = AIModelConfig(
                        name=key_data["name"],
                        display_name=key_data["display_name"],
                        provider=key_data.get("provider", "custom"),
                        model_type=key_data["model_type"],
                        api_url=key_data["api_url"],
                        api_key=encrypted_key,
                        api_key_encrypted=bool(encrypted_key),
                        model_id=key_data["name"],
                        priority=key_data.get("priority", 1),
                        description=key_data.get("description"),
                        is_active=key_data.get("is_active", True),
                    )
                    db.add(new_key)
                    success_count += 1

            except Exception as e:
                error_msg = f"Row {idx + 1}: {str(e)}"
                errors.append(error_msg)
                error_count += 1

        # Commit all changes
        await db.commit()

        # Log audit action
        await log_admin_action(
            db=db,
            user_id=user.id,
            username=user.username,
            action="import_json",
            resource_type="apikey",
            details={
                "mode": mode,
                "export_version": export_version,
                "export_mode": export_mode,
                "success_count": success_count,
                "updated_count": updated_count,
                "skipped_count": skipped_count,
                "error_count": error_count,
            },
            request=request,
        )

        logger.info(
            f"Imported API keys JSON for user {user.username}: "
            f"{success_count} added, {updated_count} updated, {skipped_count} skipped, {error_count} failed"
        )

        return JSONResponse(content={
            "success": True,
            "message": (
                f"Import completed: {success_count} added, {updated_count} updated, "
                f"{skipped_count} skipped, {error_count} failed"
            ),
            "stats": {
                "success_count": success_count,
                "updated_count": updated_count,
                "skipped_count": skipped_count,
                "error_count": error_count,
                "errors": errors[:10],  # Return first 10 errors
            }
        })

    except Exception as e:
        logger.error(f"JSON import error: {e}")
        return JSONResponse(
            content={"success": False, "message": f"Import failed: {str(e)}"},
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
