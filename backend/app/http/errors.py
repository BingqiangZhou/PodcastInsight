"""Shared HTTP exception helpers."""

from typing import Any

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


def raise_not_found(
    entity_type: str,
    entity_id: int | str | None = None,
    *,
    message_en: str | None = None,
    message_zh: str | None = None,
) -> None:
    """Raise standardized 404 Not Found error.

    Args:
        entity_type: Type of entity (e.g., "User", "Subscription")
        entity_id: ID of the entity that was not found (optional)
        message_en: Custom English message (optional)
        message_zh: Custom Chinese message (optional)

    Raises:
        HTTPException: 404 error with bilingual message
    """
    if message_en and message_zh:
        raise bilingual_http_exception(
            message_en=message_en,
            message_zh=message_zh,
            status_code=status.HTTP_404_NOT_FOUND,
        )
    raise bilingual_http_exception(
        message_en=f"{entity_type} not found" + (f" (id={entity_id})" if entity_id else ""),
        message_zh=f"{entity_type}未找到" + (f" (id={entity_id})" if entity_id else ""),
        status_code=status.HTTP_404_NOT_FOUND,
    )


def raise_validation_error(
    field_name: str,
    reason: str,
    *,
    message_en: str | None = None,
    message_zh: str | None = None,
) -> None:
    """Raise standardized 400 Bad Request validation error.

    Args:
        field_name: Name of the invalid field
        reason: Reason for validation failure
        message_en: Custom English message (optional)
        message_zh: Custom Chinese message (optional)

    Raises:
        HTTPException: 400 error with bilingual message
    """
    if message_en and message_zh:
        raise bilingual_http_exception(
            message_en=message_en,
            message_zh=message_zh,
            status_code=status.HTTP_400_BAD_REQUEST,
        )
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


def raise_conflict(
    message_en: str,
    message_zh: str,
) -> None:
    """Raise standardized 409 Conflict error.

    Args:
        message_en: English error message
        message_zh: Chinese error message

    Raises:
        HTTPException: 409 error with bilingual message
    """
    raise bilingual_http_exception(
        message_en=message_en,
        message_zh=message_zh,
        status_code=status.HTTP_409_CONFLICT,
    )


def raise_internal_error(
    operation: str,
    exc: Exception | None = None,
) -> None:
    """Raise standardized 500 Internal Server Error.

    Args:
        operation: Description of the failed operation
        exc: The original exception (for chaining)

    Raises:
        HTTPException: 500 error with bilingual message
    """
    raise bilingual_http_exception(
        message_en=f"Internal error during {operation}",
        message_zh=f"{operation}时发生内部错误",
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
    ) from exc


def raise_bad_request(
    message_en: str,
    message_zh: str,
) -> None:
    """Raise standardized 400 Bad Request error with custom message.

    Args:
        message_en: English error message
        message_zh: Chinese error message

    Raises:
        HTTPException: 400 error with bilingual message
    """
    raise bilingual_http_exception(
        message_en=message_en,
        message_zh=message_zh,
        status_code=status.HTTP_400_BAD_REQUEST,
    )


def raise_not_implemented(
    feature: str,
) -> None:
    """Raise standardized 501 Not Implemented error.

    Args:
        feature: Description of the not implemented feature

    Raises:
        HTTPException: 501 error with bilingual message
    """
    raise bilingual_http_exception(
        message_en=f"Feature not implemented: {feature}",
        message_zh=f"功能未实现：{feature}",
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
    )


def create_error_response(
    message_en: str,
    message_zh: str,
    status_code: int = 500,
) -> dict[str, Any]:
    """Create a standardized error response dict without raising.

    Useful when you need to return an error as part of a larger response.

    Args:
        message_en: English error message
        message_zh: Chinese error message
        status_code: HTTP status code

    Returns:
        Dict with error details
    """
    return {
        "error": True,
        "status_code": status_code,
        "message_en": message_en,
        "message_zh": message_zh,
    }


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
