"""Admin service helpers for API key management pages."""

import json
import logging
from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.admin.audit import log_admin_action
from app.core.security import (
    decrypt_data,
    decrypt_data_with_password,
    encrypt_data,
    encrypt_data_with_password,
    validate_export_password,
)
from app.domains.ai.models import AIModelConfig, ModelType


logger = logging.getLogger(__name__)


class AdminApiKeysService:
    """Query and serialize admin API-key page data."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_page_context(
        self,
        *,
        model_type_filter: str | None,
        page: int,
        per_page: int,
    ) -> dict:
        query = select(AIModelConfig)
        if model_type_filter and model_type_filter in {
            "transcription",
            "text_generation",
        }:
            query = query.where(AIModelConfig.model_type == model_type_filter)

        count_query = select(func.count()).select_from(query.subquery())
        total_count_result = await self.db.execute(count_query)
        total_count = total_count_result.scalar() or 0
        total_pages = (total_count + per_page - 1) // per_page if total_count > 0 else 1
        offset = (page - 1) * per_page

        result = await self.db.execute(
            query.order_by(AIModelConfig.priority.asc(), AIModelConfig.created_at.desc())
            .limit(per_page)
            .offset(offset)
        )
        apikeys = result.scalars().all()

        for config in apikeys:
            config.api_key = self._mask_api_key_for_display(config)

        return {
            "apikeys": apikeys,
            "model_type_filter": model_type_filter or "",
            "page": page,
            "per_page": per_page,
            "total_count": total_count,
            "total_pages": total_pages,
        }

    def _mask_api_key_for_display(self, config: AIModelConfig) -> str:
        raw_key = (config.api_key or "").strip()
        if not raw_key:
            logger.warning(
                "API key for config %s (%s) is empty or None",
                config.id,
                config.name,
            )
            return "****"

        if config.api_key_encrypted:
            try:
                raw_key = decrypt_data(raw_key)
            except Exception as exc:
                logger.warning(
                    "Failed to decrypt API key for config %s (%s): %s",
                    config.id,
                    config.name,
                    exc,
                )
                return "[密钥无法解密-请重新编辑]"

        if len(raw_key) <= 8:
            return "****"
        return f"{raw_key[:4]}****{raw_key[-4:]}"

    async def test_apikey_connection(
        self,
        *,
        api_url: str,
        api_key: str | None,
        model_type: str,
        name: str | None,
        key_id: int | None,
        username: str,
    ) -> tuple[dict, int]:
        """Validate API key connectivity for admin workflows."""
        from app.domains.ai.services import AIModelConfigService

        service = AIModelConfigService(self.db)
        try:
            model_type_enum = ModelType(model_type)
        except ValueError:
            return {"success": False, "message": f"鏃犳晥鐨勬ā鍨嬬被鍨? {model_type}"}, 400

        resolved_from_db = False
        effective_api_key = (api_key or "").strip()
        if not effective_api_key:
            if not key_id:
                return {
                    "success": False,
                    "message": "API key is required when key_id is not provided.",
                }, 400

            result = await self.db.execute(
                select(AIModelConfig).where(AIModelConfig.id == key_id)
            )
            model_config = result.scalar_one_or_none()
            if not model_config:
                return {
                    "success": False,
                    "message": f"Model config {key_id} not found.",
                }, 404

            stored_key = (model_config.api_key or "").strip()
            if not stored_key:
                return {
                    "success": False,
                    "message": "Stored API key is empty. Please enter and save a new API key.",
                }, 400

            if model_config.api_key_encrypted:
                try:
                    effective_api_key = decrypt_data(stored_key).strip()
                except Exception as exc:  # noqa: BLE001
                    logger.warning(
                        "Failed to decrypt API key for config %s (%s): %s",
                        model_config.id,
                        model_config.name,
                        exc,
                    )
                    return {
                        "success": False,
                        "message": "Failed to decrypt stored API key. Please re-enter and save a new API key.",
                    }, 400
            else:
                effective_api_key = stored_key

            if not effective_api_key:
                return {
                    "success": False,
                    "message": "Stored API key is invalid. Please enter and save a new API key.",
                }, 400
            resolved_from_db = True

        validation_result = await service.validate_api_key(
            api_url=api_url,
            api_key=effective_api_key,
            model_id=name,
            model_type=model_type_enum,
        )
        if validation_result.valid:
            logger.info(
                "API key test successful for model type %s by user %s",
                model_type,
                username,
            )
            return {
                "success": True,
                "message": "API密钥测试成功",
                "test_result": validation_result.test_result,
                "response_time_ms": validation_result.response_time_ms,
                "used_stored_key": resolved_from_db,
            }, 200

        logger.warning(
            "API key test failed for model type %s by user %s: %s",
            model_type,
            username,
            validation_result.error_message,
        )
        return {
            "success": False,
            "message": f"API密钥测试失败: {validation_result.error_message}",
            "error_message": validation_result.error_message,
        }, 400

    async def create_apikey(
        self,
        *,
        request,
        user,
        name: str,
        display_name: str,
        model_type: str,
        api_url: str,
        api_key: str,
        provider: str,
        description: str | None,
        priority: int,
    ) -> dict:
        encrypted_key = encrypt_data(api_key)
        if len(encrypted_key) < 44:
            raise ValueError("API key encryption failed - invalid encrypted data length")

        new_config = AIModelConfig(
            name=name,
            display_name=display_name,
            description=description,
            model_type=model_type,
            api_url=api_url,
            api_key=encrypted_key,
            api_key_encrypted=True,
            model_id=name,
            provider=provider,
            is_active=True,
            priority=priority,
        )
        self.db.add(new_config)
        await self.db.commit()
        await self.db.refresh(new_config)

        await log_admin_action(
            db=self.db,
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
        return {
            "success": True,
            "message": f"妯″瀷閰嶇疆 '{display_name}' 宸叉垚鍔熷垱寤?",
        }

    async def toggle_apikey(self, *, request, user, key_id: int) -> dict | None:
        result = await self.db.execute(
            select(AIModelConfig).where(AIModelConfig.id == key_id)
        )
        model_config = result.scalar_one_or_none()
        if not model_config:
            return None

        model_config.is_active = not model_config.is_active
        await self.db.commit()
        await self.db.refresh(model_config)
        await log_admin_action(
            db=self.db,
            user_id=user.id,
            username=user.username,
            action="toggle",
            resource_type="apikey",
            resource_id=key_id,
            resource_name=model_config.display_name,
            details={"is_active": model_config.is_active},
            request=request,
        )
        return {"success": True}

    async def edit_apikey(
        self,
        *,
        request,
        user,
        key_id: int,
        name: str | None,
        display_name: str | None,
        model_type: str | None,
        api_url: str | None,
        api_key: str | None,
        provider: str | None,
        description: str | None,
        priority: int | None,
    ) -> dict | None:
        result = await self.db.execute(
            select(AIModelConfig).where(AIModelConfig.id == key_id)
        )
        model_config = result.scalar_one_or_none()
        if not model_config:
            return None

        old_values = {
            "name": model_config.name,
            "display_name": model_config.display_name,
            "model_type": model_config.model_type,
            "api_url": model_config.api_url,
            "provider": model_config.provider,
            "description": model_config.description,
            "priority": model_config.priority,
        }

        if name is not None:
            model_config.name = name
            model_config.model_id = name
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
            encrypted_key = encrypt_data(api_key)
            if len(encrypted_key) < 44:
                raise ValueError("API key encryption failed - invalid encrypted data length")
            model_config.api_key = encrypted_key
            model_config.api_key_encrypted = True

        await self.db.commit()
        await self.db.refresh(model_config)
        await log_admin_action(
            db=self.db,
            user_id=user.id,
            username=user.username,
            action="update",
            resource_type="apikey",
            resource_id=key_id,
            resource_name=model_config.display_name,
            details={
                "old_values": old_values,
                "new_values": {
                    "name": model_config.name,
                    "display_name": model_config.display_name,
                    "model_type": model_config.model_type,
                    "priority": model_config.priority,
                },
            },
            request=request,
        )
        return {"success": True}

    async def delete_apikey(self, *, request, user, key_id: int) -> dict | None:
        result = await self.db.execute(
            select(AIModelConfig).where(AIModelConfig.id == key_id)
        )
        model_config = result.scalar_one_or_none()
        if not model_config:
            return None

        resource_name = model_config.display_name
        await self.db.delete(model_config)
        await self.db.commit()
        await log_admin_action(
            db=self.db,
            user_id=user.id,
            username=user.username,
            action="delete",
            resource_type="apikey",
            resource_id=key_id,
            resource_name=resource_name,
            request=request,
        )
        return {"success": True}

    async def export_json(self, *, request, user, mode: str, export_password: str | None):
        if mode not in ["plaintext", "encrypted"]:
            return {"success": False, "message": f"Invalid mode: {mode}"}, 400

        if mode == "encrypted":
            if not export_password:
                return {
                    "success": False,
                    "message": "export_password is required for encrypted mode",
                }, 400
            is_valid, error_msg = validate_export_password(export_password)
            if not is_valid:
                return {"success": False, "message": f"Weak password: {error_msg}"}, 400

        result = await self.db.execute(
            select(AIModelConfig).order_by(
                AIModelConfig.priority.asc(),
                AIModelConfig.created_at.desc(),
            )
        )
        apikeys = result.scalars().all()

        export_data = {
            "version": "2.0",
            "export_mode": mode,
            "exported_at": datetime.now(UTC).isoformat(),
            "exported_by": user.username,
            "total_count": len(apikeys),
            "apikeys": [],
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
            if mode == "plaintext":
                try:
                    if key.api_key_encrypted:
                        key_data["api_key"] = decrypt_data(key.api_key)
                        key_data["api_key_encrypted"] = False
                    else:
                        key_data["api_key"] = key.api_key
                        key_data["api_key_encrypted"] = False
                except Exception:  # noqa: BLE001
                    key_data["api_key"] = ""
                    key_data["api_key_error"] = "Decryption failed"
            else:
                try:
                    if key.api_key_encrypted:
                        decrypted_key = decrypt_data(key.api_key)
                        key_data["api_key_encrypted_export"] = (
                            encrypt_data_with_password(decrypted_key, export_password)
                        )
                    else:
                        key_data["api_key_encrypted_export"] = encrypt_data_with_password(
                            key.api_key, export_password
                        )
                    key_data["api_key_encrypted_flag"] = True
                except Exception:  # noqa: BLE001
                    key_data["api_key_encrypted_export"] = None
                    key_data["api_key_error"] = "Encryption failed"

            export_data["apikeys"].append(key_data)

        await log_admin_action(
            db=self.db,
            user_id=user.id,
            username=user.username,
            action="export_json",
            resource_type="apikey",
            details={
                "count": len(apikeys),
                "mode": mode,
                "plaintext_warning": mode == "plaintext",
            },
            request=request,
        )

        mode_suffix = "_PLAINTEXT" if mode == "plaintext" else ""
        filename = f"apikeys_export{mode_suffix}_{datetime.now(UTC).strftime('%Y%m%d_%H%M%S')}.json"
        return (
            json.dumps(export_data, indent=2, ensure_ascii=False),
            filename,
        )

    async def import_json(self, *, request, user, raw_body: bytes) -> tuple[dict, int]:
        if not raw_body:
            return {"success": False, "message": "Empty request body"}, 400

        try:
            body = json.loads(raw_body.decode("utf-8"))
        except json.JSONDecodeError as exc:
            return {
                "success": False,
                "message": f"Invalid JSON in request body: {exc}",
            }, 400

        file_content = body.get("file")
        mode = body.get("mode", "skip")
        import_password = body.get("import_password")
        if not file_content:
            return {
                "success": False,
                "message": "Missing 'file' field in request body",
            }, 400

        try:
            import_data = json.loads(file_content)
        except json.JSONDecodeError as exc:
            return {"success": False, "message": f"Invalid JSON format: {exc}"}, 400

        if "apikeys" not in import_data:
            return {
                "success": False,
                "message": "Invalid format: missing 'apikeys' field",
            }, 400
        apikeys_list = import_data["apikeys"]
        if not isinstance(apikeys_list, list):
            return {
                "success": False,
                "message": "Invalid format: 'apikeys' must be a list",
            }, 400

        export_version = import_data.get("version")
        export_mode = import_data.get("export_mode", "encrypted")
        if export_version != "2.0":
            return {
                "success": False,
                "message": "Unsupported export version. Please import version 2.0 data.",
            }, 400
        if export_mode not in {"plaintext", "encrypted"}:
            return {
                "success": False,
                "message": f"Invalid export_mode: {export_mode}",
            }, 400
        if export_mode == "encrypted" and not import_password:
            return {
                "success": False,
                "message": "import_password is required for encrypted exports",
            }, 400

        success_count = 0
        updated_count = 0
        skipped_count = 0
        error_count = 0
        errors: list[str] = []

        existing_result = await self.db.execute(select(AIModelConfig))
        existing_keys = {k.name: k for k in existing_result.scalars().all()}

        for idx, key_data in enumerate(apikeys_list):
            try:
                required_fields = ["name", "display_name", "model_type", "api_url"]
                missing_fields = [f for f in required_fields if not key_data.get(f)]
                if missing_fields:
                    errors.append(
                        f"Row {idx + 1}: Missing required fields: {', '.join(missing_fields)}"
                    )
                    error_count += 1
                    continue

                model_type = key_data.get("model_type")
                if model_type not in ["transcription", "text_generation"]:
                    errors.append(f"Row {idx + 1}: Invalid model_type '{model_type}'")
                    error_count += 1
                    continue

                name = key_data["name"]
                api_key_plaintext = None
                if export_mode == "plaintext":
                    api_key_plaintext = key_data.get("api_key")
                    if not api_key_plaintext:
                        errors.append(
                            f"Row {idx + 1}: Missing api_key in plaintext export"
                        )
                        error_count += 1
                        continue
                else:
                    encrypted_dict = key_data.get("api_key_encrypted_export")
                    if not encrypted_dict:
                        errors.append(
                            f"Row {idx + 1}: Missing api_key_encrypted_export"
                        )
                        error_count += 1
                        continue
                    try:
                        api_key_plaintext = decrypt_data_with_password(
                            encrypted_dict, import_password
                        )
                    except ValueError as exc:
                        errors.append(
                            f"Row {idx + 1}: Failed to decrypt API key: {exc}"
                        )
                        error_count += 1
                        continue

                existing_key = existing_keys.get(name)
                if existing_key:
                    if mode == "skip":
                        skipped_count += 1
                        continue
                    if mode in {"update", "replace"}:
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
                        if api_key_plaintext:
                            encrypted_key = encrypt_data(api_key_plaintext)
                            if len(encrypted_key) < 44:
                                errors.append(f"Row {idx + 1}: Failed to encrypt API key")
                                error_count += 1
                                continue
                            existing_key.api_key = encrypted_key
                            existing_key.api_key_encrypted = True
                        updated_count += 1
                    else:
                        skipped_count += 1
                    continue

                encrypted_key = ""
                if api_key_plaintext:
                    encrypted_key = encrypt_data(api_key_plaintext)
                    if len(encrypted_key) < 44:
                        errors.append(f"Row {idx + 1}: Failed to encrypt API key")
                        error_count += 1
                        continue

                self.db.add(
                    AIModelConfig(
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
                )
                success_count += 1
            except Exception as exc:  # noqa: BLE001
                errors.append(f"Row {idx + 1}: {exc}")
                error_count += 1

        await self.db.commit()
        await log_admin_action(
            db=self.db,
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
        return {
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
                "errors": errors[:10],
            },
        }, 200
