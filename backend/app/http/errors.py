"""Shared HTTP exception helpers."""

from fastapi import FastAPI, HTTPException, status
from fastapi.responses import RedirectResponse


def bilingual_http_exception(
    message_en: str,
    message_zh: str,
    status_code: int,
) -> HTTPException:
    """Create a bilingual HTTPException payload."""
    return HTTPException(
        status_code=status_code,
        detail={"message_en": message_en, "message_zh": message_zh},
    )


def raise_not_found(entity_type: str, entity_id: int | str) -> None:
    """Raise standardized 404 Not Found error.

    Args:
        entity_type: Type of entity (e.g., "User", "Subscription")
        entity_id: ID of the entity that was not found

    Raises:
        HTTPException: 404 error with bilingual message
    """
    raise bilingual_http_exception(
        message_en=f"{entity_type} not found",
        message_zh=f"{entity_type}未找到",
        status_code=status.HTTP_404_NOT_FOUND,
    )


def raise_validation_error(field_name: str, reason: str) -> None:
    """Raise standardized 400 Bad Request validation error.

    Args:
        field_name: Name of the invalid field
        reason: Reason for validation failure

    Raises:
        HTTPException: 400 error with bilingual message
    """
    raise bilingual_http_exception(
        message_en=f"Invalid {field_name}: {reason}",
        message_zh=f"{field_name}无效：{reason}",
        status_code=status.HTTP_400_BAD_REQUEST,
    )


def raise_unauthorized(
    message_en: str = "Unauthorized", message_zh: str = "未授权"
) -> None:
    """Raise standardized 401 Unauthorized error.

    Args:
        message_en: English error message
        message_zh: Chinese error message

    Raises:
        HTTPException: 401 error with bilingual message
    """
    raise bilingual_http_exception(
        message_en=message_en,
        message_zh=message_zh,
        status_code=status.HTTP_401_UNAUTHORIZED,
    )


def raise_forbidden(
    message_en: str = "Forbidden", message_zh: str = "禁止访问"
) -> None:
    """Raise standardized 403 Forbidden error.

    Args:
        message_en: English error message
        message_zh: Chinese error message

    Raises:
        HTTPException: 403 error with bilingual message
    """
    raise bilingual_http_exception(
        message_en=message_en,
        message_zh=message_zh,
        status_code=status.HTTP_403_FORBIDDEN,
    )


def register_admin_http_exception_handler(app: FastAPI) -> None:
    """Register admin-specific redirects and HTML error rendering."""

    @app.exception_handler(HTTPException)
    async def custom_http_exception_handler(request, exc):
        is_admin_request = request.url.path.startswith("/api/v1/admin/")

        if exc.status_code == status.HTTP_307_TEMPORARY_REDIRECT:
            return RedirectResponse(
                url=exc.headers.get("Location", "/api/v1/admin/2fa/setup"),
                status_code=status.HTTP_303_SEE_OTHER,
            )

        if (
            is_admin_request
            and exc.status_code == status.HTTP_401_UNAUTHORIZED
            and request.url.path != "/api/v1/admin/login"
        ):
            return RedirectResponse(
                url="/api/v1/admin/login",
                status_code=status.HTTP_303_SEE_OTHER,
            )

        if is_admin_request and exc.status_code >= 400:
            from fastapi.templating import Jinja2Templates

            templates = Jinja2Templates(directory="app/admin/templates")
            return templates.TemplateResponse(
                "error.html",
                {
                    "request": request,
                    "error_message": exc.detail
                    if isinstance(exc.detail, str)
                    else "An unexpected error occurred.",
                    "error_detail": f"Error code: {exc.status_code}",
                },
                status_code=exc.status_code,
            )

        from fastapi.exception_handlers import http_exception_handler

        return await http_exception_handler(request, exc)
