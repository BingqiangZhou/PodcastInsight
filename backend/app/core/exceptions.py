"""Custom exception hierarchy.

Convention:
- Service/Repository layer: Raise BaseCustomError subclasses for business errors.
  These are caught by the global exception handler and return structured JSON responses.
- Route layer: Use bilingual HTTPException helpers from app.http.errors for user-facing messages.
- NEVER use bare ValueError/string comparison for control flow.

自定义异常处理器
"""

import logging
from typing import Any

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.circuit_breaker import CircuitOpenError
from app.core.json_encoder import CustomJSONResponse


logger = logging.getLogger(__name__)


class BaseCustomError(Exception):
    """Base custom exception.

    基础自定义异常
    """

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


class NotFoundError(BaseCustomError):
    """Resource not found exception.

    资源未找到异常
    """

    def __init__(
        self,
        message: str = "Resource not found",
        **kwargs,
    ):
        super().__init__(message, 404, **kwargs)


class BadRequestError(BaseCustomError):
    """Bad request exception.

    错误请求异常
    """

    def __init__(
        self,
        message: str = "Bad request",
        **kwargs,
    ):
        super().__init__(message, 400, **kwargs)


class UnauthorizedError(BaseCustomError):
    """Unauthorized exception.

    未授权异常
    """

    def __init__(
        self,
        message: str = "Unauthorized",
        **kwargs,
    ):
        super().__init__(message, 401, **kwargs)


class ForbiddenError(BaseCustomError):
    """Forbidden exception.

    禁止访问异常
    """

    def __init__(
        self,
        message: str = "Forbidden",
        **kwargs,
    ):
        super().__init__(message, 403, **kwargs)


class ConflictError(BaseCustomError):
    """Conflict exception.

    冲突异常
    """

    def __init__(
        self,
        message: str = "Resource already exists",
        **kwargs,
    ):
        super().__init__(message, 409, "CONFLICT", **kwargs)


class CustomValidationError(BaseCustomError):
    """Custom validation exception for service-layer validation.

    Note: Named CustomValidationError to avoid conflict with Pydantic's ValidationError.
    Use this for business logic validation in service layers.
    For route-layer validation errors, use raise_validation_error from app.http.errors.

    自定义验证异常，用于服务层验证。

    注意：命名为 CustomValidationError 以避免与 Pydantic 的 ValidationError 冲突。
    在服务层使用此异常进行业务逻辑验证。
    对于路由层的验证错误，请使用 app.http.errors 中的 raise_validation_error。
    """

    def __init__(
        self,
        message: str = "Validation failed",
        **kwargs,
    ):
        super().__init__(message, 400, "VALIDATION_ERROR", **kwargs)


# Backward compatibility alias
ValidationError = CustomValidationError


class DatabaseError(BaseCustomError):
    """Database exception.

    数据库异常
    """

    def __init__(
        self,
        message: str = "Database error",
        **kwargs,
    ):
        super().__init__(message, 500, "DATABASE_ERROR", **kwargs)


class ExternalServiceError(BaseCustomError):
    """External service error exception.

    外部服务错误异常
    """

    def __init__(
        self,
        message: str = "External service error",
        **kwargs,
    ):
        super().__init__(message, 502, "EXTERNAL_SERVICE_ERROR", **kwargs)


class FileProcessingError(BaseCustomError):
    """File processing error exception.

    文件处理错误异常
    """

    def __init__(
        self,
        message: str = "File processing error",
        **kwargs,
    ):
        super().__init__(message, 422, "FILE_PROCESSING_ERROR", **kwargs)


# ── Domain-specific exceptions ─────────────────────────────────────────────


class EpisodeNotFoundError(NotFoundError):
    """Raised when a podcast episode is not found."""

    pass


class QueueLimitExceededError(BadRequestError):
    """Raised when playback queue limit is exceeded."""

    pass


class EpisodeNotInQueueError(BadRequestError):
    """Raised when episode is not in the playback queue."""

    pass


class InvalidReorderPayloadError(BadRequestError):
    """Raised when queue reorder payload is invalid."""

    pass


class SubscriptionNotFoundError(NotFoundError):
    """Raised when a subscription is not found."""

    pass


class TranscriptionTaskNotFoundError(NotFoundError):
    """Raised when a transcription task is not found."""

    pass


class ConversationNotFoundError(NotFoundError):
    """Raised when a conversation session is not found."""

    pass


class TranscriptionAlreadyExistsError(ConflictError):
    """Raised when transcription already exists for an episode."""

    pass


class TranscriptionInProgressError(ConflictError):
    """Raised when transcription is already in progress."""

    pass


async def custom_exception_handler(
    request: Request, exc: BaseCustomError
) -> CustomJSONResponse:
    """Handle custom exceptions.

    处理自定义异常
    """
    logger.error(
        f"自定义异常: {exc.__class__.__name__} | "
        f"路径: {request.url.path} | "
        f"方法: {request.method} | "
        f"消息: {exc.message} | "
        f"状态码: {exc.status_code}",
    )

    # Build response content
    content = {
        "detail": exc.message,
        "type": exc.error_code,
        "status_code": exc.status_code,
    }

    # Add details if present
    if exc.details:
        content["details"] = exc.details

    return CustomJSONResponse(status_code=exc.status_code, content=content)


async def http_exception_handler(
    request: Request, exc: HTTPException | StarletteHTTPException
) -> CustomJSONResponse:
    """Handle HTTP exceptions.

    处理 HTTP 异常
    """
    logger.error(
        f"HTTP异常: {exc.status_code} | "
        f"路径: {request.url.path} | "
        f"方法: {request.method} | "
        f"详情: {exc.detail}",
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
    """Handle validation exceptions.

    处理验证异常
    """
    errors = []
    for error in exc.errors():
        errors.append(
            {
                "field": " -> ".join(str(x) for x in error["loc"]),
                "message": error["msg"],
                "type": error["type"],
            }
        )

    logger.error(
        f"请求验证失败: {request.url.path} | "
        f"方法: {request.method} | "
        f"错误字段: {len(errors)}个 | "
        f"错误详情: {errors}",
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
    """Handle general exceptions.

    处理通用异常
    """
    logger.error(
        f"未处理异常: {exc.__class__.__name__} | "
        f"路径: {request.url.path} | "
        f"方法: {request.method} | "
        f"消息: {exc!s}",
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


async def circuit_open_exception_handler(
    request: Request, exc: CircuitOpenError
) -> CustomJSONResponse:
    """Handle circuit breaker open exceptions.

    处理熔断器打开异常 - 返回503服务不可用
    """
    logger.warning(
        f"熔断器打开: {exc.__class__.__name__} | "
        f"路径: {request.url.path} | "
        f"方法: {request.method} | "
        f"消息: {exc!s}",
    )

    return CustomJSONResponse(
        status_code=503,
        content={
            "detail": "Service temporarily unavailable. Please try again later.",
            "type": "SERVICE_UNAVAILABLE",
            "status_code": 503,
            "message_en": "Service temporarily unavailable. Please try again later.",
            "message_zh": "服务暂时不可用，请稍后重试。",
        },
        headers={"Retry-After": "30"},
    )


async def database_connection_exception_handler(
    request: Request, exc: Exception
) -> CustomJSONResponse:
    """Handle database connection exceptions.

    处理数据库连接异常 - 返回503服务不可用
    """
    logger.error(
        f"数据库连接错误: {exc.__class__.__name__} | "
        f"路径: {request.url.path} | "
        f"方法: {request.method} | "
        f"消息: {exc!s}",
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


async def redis_connection_exception_handler(
    request: Request, exc: Exception
) -> CustomJSONResponse:
    """Handle Redis connection exceptions.

    处理Redis连接异常 - 返回503服务不可用
    """
    logger.error(
        f"Redis连接错误: {exc.__class__.__name__} | "
        f"路径: {request.url.path} | "
        f"方法: {request.method} | "
        f"消息: {exc!s}",
        exc_info=True,
    )

    return CustomJSONResponse(
        status_code=503,
        content={
            "detail": "Cache service error. Please try again later.",
            "type": "CACHE_CONNECTION_ERROR",
            "status_code": 503,
            "message_en": "Cache service error. Please try again later.",
            "message_zh": "缓存服务错误，请稍后重试。",
        },
        headers={"Retry-After": "5"},
    )


async def timeout_exception_handler(
    request: Request, exc: Exception
) -> CustomJSONResponse:
    """Handle timeout exceptions.

    处理超时异常 - 返回504网关超时
    """
    logger.warning(
        f"请求超时: {exc.__class__.__name__} | "
        f"路径: {request.url.path} | "
        f"方法: {request.method} | "
        f"消息: {exc!s}",
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


def setup_exception_handlers(app: FastAPI) -> None:
    """Setup exception handlers for the FastAPI app.

    为 FastAPI 应用设置异常处理器
    """
    import asyncio

    app.add_exception_handler(BaseCustomError, custom_exception_handler)
    app.add_exception_handler(HTTPException, http_exception_handler)
    app.add_exception_handler(StarletteHTTPException, http_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(CircuitOpenError, circuit_open_exception_handler)

    # Database connection errors
    from sqlalchemy.exc import (
        DBAPIError,
        InterfaceError,
        OperationalError,
    )

    app.add_exception_handler(OperationalError, database_connection_exception_handler)
    app.add_exception_handler(InterfaceError, database_connection_exception_handler)
    app.add_exception_handler(DBAPIError, database_connection_exception_handler)

    # Timeout errors
    app.add_exception_handler(asyncio.TimeoutError, timeout_exception_handler)
    app.add_exception_handler(TimeoutError, timeout_exception_handler)

    # Redis connection errors (ConnectionError is a base class, so we handle it carefully)
    # Note: We don't want to catch all ConnectionError as it may include network issues
    # Instead, we'll let Redis-specific errors be caught by the rate limiter's circuit breaker

    # General exception handler (must be last)
    app.add_exception_handler(Exception, general_exception_handler)


# NOTE: Convenience functions for raising HTTP exceptions have been moved to app.http.errors
# For route-layer error responses, use:
#   - raise_not_found() from app.http.errors
#   - raise_validation_error() from app.http.errors
#   - raise_unauthorized() from app.http.errors
#   - raise_forbidden() from app.http.errors
#
# For service-layer business logic errors, raise custom exception classes directly:
#   - raise NotFoundError("message")
#   - raise CustomValidationError("message")
#   - raise ConflictError("message")
