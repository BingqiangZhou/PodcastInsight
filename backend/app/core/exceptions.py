"""Custom exception hierarchy.

Convention:
- Service/Repository layer: raise BaseCustomError subclasses for business errors.
- Route layer: use bilingual_http_exception() from app.http.errors for user-facing messages.
- NEVER use bare ValueError/string comparison for control flow.
"""

import asyncio
import logging
from typing import Any

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.json_encoder import CustomJSONResponse


logger = logging.getLogger(__name__)


# ── Base ─────────────────────────────────────────────────────────────────────


class BaseCustomError(Exception):
    def __init__(
        self,
        message: str,
        status_code: int = 500,
        error_code: str | None = None,
        details: dict[str, Any] | None = None,
    ):
        self.message = message
        self.status_code = status_code
        self.error_code = error_code or self.__class__.__name__
        self.details = details or {}
        super().__init__(self.message)


# ── HTTP-status exceptions ───────────────────────────────────────────────────


class NotFoundError(BaseCustomError):
    def __init__(self, message: str = "Resource not found", **kwargs):
        super().__init__(message, 404, **kwargs)


class BadRequestError(BaseCustomError):
    def __init__(self, message: str = "Bad request", **kwargs):
        super().__init__(message, 400, **kwargs)


class UnauthorizedError(BaseCustomError):
    def __init__(self, message: str = "Unauthorized", **kwargs):
        super().__init__(message, 401, **kwargs)


class ForbiddenError(BaseCustomError):
    def __init__(self, message: str = "Forbidden", **kwargs):
        super().__init__(message, 403, **kwargs)


class ConflictError(BaseCustomError):
    def __init__(self, message: str = "Resource already exists", **kwargs):
        super().__init__(message, 409, "CONFLICT", **kwargs)


class CustomValidationError(BaseCustomError):
    """Service-layer validation (named to avoid Pydantic's ValidationError)."""

    def __init__(self, message: str = "Validation failed", **kwargs):
        super().__init__(message, 400, "VALIDATION_ERROR", **kwargs)


class InternalServerError(BaseCustomError):
    def __init__(self, message: str = "Internal server error", **kwargs):
        super().__init__(message, 500, "INTERNAL_ERROR", **kwargs)


# Backward compatibility alias
ValidationError = CustomValidationError


class DatabaseError(BaseCustomError):
    def __init__(self, message: str = "Database error", **kwargs):
        super().__init__(message, 500, "DATABASE_ERROR", **kwargs)


class ExternalServiceError(BaseCustomError):
    def __init__(self, message: str = "External service error", **kwargs):
        super().__init__(message, 502, "EXTERNAL_SERVICE_ERROR", **kwargs)


# ── Domain-specific exceptions ───────────────────────────────────────────────


class EpisodeNotFoundError(NotFoundError):
    pass


class SubscriptionNotFoundError(NotFoundError):
    pass


class TranscriptionTaskNotFoundError(NotFoundError):
    pass


class QueueLimitExceededError(BadRequestError):
    pass


class EpisodeNotInQueueError(BadRequestError):
    pass


class InvalidReorderPayloadError(BadRequestError):
    pass


# ── Exception handlers ───────────────────────────────────────────────────────


async def custom_exception_handler(
    request: Request, exc: BaseCustomError
) -> CustomJSONResponse:
    logger.error(
        "Custom exception raised",
        extra={
            "event": "custom_exception",
            "exception_type": exc.__class__.__name__,
            "path": request.url.path,
            "method": request.method,
            "exc_message": str(exc.message),
            "status_code": exc.status_code,
        },
    )
    content: dict[str, Any] = {
        "detail": exc.message,
        "type": exc.error_code,
        "status_code": exc.status_code,
    }
    if exc.details:
        content["details"] = exc.details
    return CustomJSONResponse(status_code=exc.status_code, content=content)


async def http_exception_handler(
    request: Request, exc: HTTPException | StarletteHTTPException
) -> CustomJSONResponse:
    log_func = logger.warning if exc.status_code < 500 else logger.error
    log_func(
        "HTTP exception raised: %s %s -> %s [%s]",
        request.method,
        request.url.path,
        exc.status_code,
        exc.detail,
        extra={
            "event": "http_exception",
            "exception_type": exc.__class__.__name__,
            "path": request.url.path,
            "method": request.method,
            "detail": str(exc.detail),
            "status_code": exc.status_code,
        },
    )
    return CustomJSONResponse(
        status_code=exc.status_code,
        content={
            "detail": str(exc.detail),
            "type": "HTTPException",
            "status_code": exc.status_code,
        },
    )


async def validation_exception_handler(
    request: Request, exc: RequestValidationError
) -> CustomJSONResponse:
    errors = [
        {
            "field": " -> ".join(str(x) for x in error["loc"]),
            "message": error["msg"],
            "type": error["type"],
        }
        for error in exc.errors()
    ]
    logger.error(
        "Request validation failed",
        extra={
            "event": "validation_exception",
            "path": request.url.path,
            "method": request.method,
            "error_count": len(errors),
            "errors": errors,
        },
    )
    return CustomJSONResponse(
        status_code=422,
        content={
            "detail": "Validation failed",
            "type": "VALIDATION_ERROR",
            "errors": errors,
        },
    )


async def general_exception_handler(
    request: Request, exc: Exception
) -> CustomJSONResponse:
    logger.error(
        "Unhandled exception raised",
        extra={
            "event": "unhandled_exception",
            "exception_type": exc.__class__.__name__,
            "path": request.url.path,
            "method": request.method,
            "exc_message": str(exc),
        },
        exc_info=True,
    )
    return CustomJSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
            "type": "INTERNAL_SERVER_ERROR",
            "status_code": 500,
        },
    )


async def database_connection_exception_handler(
    request: Request, exc: Exception
) -> CustomJSONResponse:
    logger.error(
        "Database connection error",
        extra={
            "event": "database_connection_error",
            "exception_type": exc.__class__.__name__,
            "path": request.url.path,
            "method": request.method,
            "exc_message": str(exc),
        },
        exc_info=True,
    )
    return CustomJSONResponse(
        status_code=503,
        content={
            "detail": "Database connection error. Please try again later.",
            "type": "DATABASE_CONNECTION_ERROR",
            "status_code": 503,
            "message_en": "Database connection error. Please try again later.",
            "message_zh": "数据库连接错误，请稍后重试。",
        },
        headers={"Retry-After": "10"},
    )


async def timeout_exception_handler(
    request: Request, exc: Exception
) -> CustomJSONResponse:
    logger.warning(
        "Request timeout",
        extra={
            "event": "request_timeout",
            "exception_type": exc.__class__.__name__,
            "path": request.url.path,
            "method": request.method,
            "exc_message": str(exc),
        },
    )
    return CustomJSONResponse(
        status_code=504,
        content={
            "detail": "Request timeout. Please try again.",
            "type": "REQUEST_TIMEOUT",
            "status_code": 504,
            "message_en": "Request timeout. Please try again.",
            "message_zh": "请求超时，请重试。",
        },
    )


# ── Registration ─────────────────────────────────────────────────────────────


def setup_exception_handlers(app: FastAPI) -> None:
    app.add_exception_handler(BaseCustomError, custom_exception_handler)
    app.add_exception_handler(HTTPException, http_exception_handler)
    app.add_exception_handler(StarletteHTTPException, http_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)

    from sqlalchemy.exc import DBAPIError, InterfaceError, OperationalError

    app.add_exception_handler(OperationalError, database_connection_exception_handler)
    app.add_exception_handler(InterfaceError, database_connection_exception_handler)
    app.add_exception_handler(DBAPIError, database_connection_exception_handler)

    app.add_exception_handler(asyncio.TimeoutError, timeout_exception_handler)
    app.add_exception_handler(TimeoutError, timeout_exception_handler)

    app.add_exception_handler(Exception, general_exception_handler)
