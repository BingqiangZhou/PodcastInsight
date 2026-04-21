"""Tests for exception handlers defined in app.core.exceptions."""

import pytest
from fastapi import FastAPI, HTTPException
from httpx import ASGITransport, AsyncClient
from pydantic import BaseModel, field_validator
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.exceptions import (
    BadRequestError,
    ConflictError,
    DatabaseError,
    ExternalServiceError,
    ForbiddenError,
    NotFoundError,
    UnauthorizedError,
    ValidationError,
    setup_exception_handlers,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_app() -> FastAPI:
    """Create a minimal FastAPI app with exception handlers wired up."""
    app = FastAPI()
    setup_exception_handlers(app)
    return app


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def app_custom_exceptions() -> FastAPI:
    """App with routes that raise BaseCustomError subclasses."""

    app = _make_app()

    @app.get("/not-found")
    async def raise_not_found():
        raise NotFoundError("Item not found")

    @app.get("/not-found-default")
    async def raise_not_found_default():
        raise NotFoundError()

    @app.get("/bad-request")
    async def raise_bad_request():
        raise BadRequestError("Invalid payload")

    @app.get("/bad-request-default")
    async def raise_bad_request_default():
        raise BadRequestError()

    @app.get("/unauthorized")
    async def raise_unauthorized():
        raise UnauthorizedError("Invalid credentials")

    @app.get("/unauthorized-default")
    async def raise_unauthorized_default():
        raise UnauthorizedError()

    @app.get("/forbidden")
    async def raise_forbidden():
        raise ForbiddenError("Access denied")

    @app.get("/forbidden-default")
    async def raise_forbidden_default():
        raise ForbiddenError()

    @app.get("/conflict")
    async def raise_conflict():
        raise ConflictError("Duplicate entry")

    @app.get("/conflict-default")
    async def raise_conflict_default():
        raise ConflictError()

    @app.get("/validation")
    async def raise_validation():
        raise ValidationError("Field is required")

    @app.get("/validation-default")
    async def raise_validation_default():
        raise ValidationError()

    @app.get("/database")
    async def raise_database():
        raise DatabaseError("Query failed")

    @app.get("/database-default")
    async def raise_database_default():
        raise DatabaseError()

    @app.get("/external-service")
    async def raise_external():
        raise ExternalServiceError("Upstream timeout")

    @app.get("/external-service-default")
    async def raise_external_default():
        raise ExternalServiceError()

    @app.get("/custom-with-details")
    async def raise_custom_with_details():
        raise BadRequestError(
            "Bad request with extra info",
            details={"field": "email", "reason": "invalid format"},
        )

    return app


@pytest.fixture
def app_http_exceptions() -> FastAPI:
    """App with routes that raise HTTPException / StarletteHTTPException."""

    app = _make_app()

    @app.get("/http-404")
    async def raise_http_404():
        raise HTTPException(status_code=404, detail="Page gone")

    @app.get("/http-403")
    async def raise_http_403():
        raise HTTPException(status_code=403, detail="Forbidden page")

    @app.get("/http-500")
    async def raise_http_500():
        raise HTTPException(status_code=500, detail="Server blew up")

    @app.get("/starlette-401")
    async def raise_starlette_401():
        raise StarletteHTTPException(status_code=401, detail="No auth")

    return app


@pytest.fixture
def app_validation_error() -> FastAPI:
    """App with a route that triggers RequestValidationError via Pydantic."""

    app = _make_app()

    class ItemPayload(BaseModel):
        name: str
        age: int

        @field_validator("age")
        @classmethod
        def age_must_be_positive(cls, v: int) -> int:
            if v < 0:
                raise ValueError("age must be positive")
            return v

    @app.post("/validate")
    async def validate_endpoint(item: ItemPayload):  # noqa: ARG001
        return {"ok": True}

    return app


@pytest.fixture
def app_database_connection() -> FastAPI:
    """App with routes that raise SQLAlchemy database connection errors."""

    from sqlalchemy.exc import DBAPIError, InterfaceError, OperationalError

    app = _make_app()

    @app.get("/db-operational")
    async def raise_operational():
        raise OperationalError("stmt", params=None, orig=Exception("connection lost"))

    @app.get("/db-interface")
    async def raise_interface():
        raise InterfaceError("stmt", params=None, orig=Exception("interface broke"))

    @app.get("/db-dbapi")
    async def raise_dbapi():
        raise DBAPIError("stmt", params=None, orig=Exception("generic dbapi"))

    return app


@pytest.fixture
def app_timeout() -> FastAPI:
    """App with routes that raise timeout errors."""

    app = _make_app()

    @app.get("/async-timeout")
    async def raise_async_timeout():
        raise TimeoutError()

    @app.get("/sync-timeout")
    async def raise_sync_timeout():
        raise TimeoutError("operation took too long")

    return app


@pytest.fixture
def app_general() -> FastAPI:
    """App with a route that raises a plain Exception (catch-all)."""

    app = _make_app()

    @app.get("/boom")
    async def raise_generic():
        raise RuntimeError("something unexpected")

    return app


# ---------------------------------------------------------------------------
# Tests: custom_exception_handler  (BaseCustomError subclasses)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_not_found_error(app_custom_exceptions: FastAPI):
    transport = ASGITransport(app=app_custom_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/not-found")
    assert response.status_code == 404
    data = response.json()
    assert data["detail"] == "Item not found"
    assert data["type"] == "NotFoundError"
    assert data["status_code"] == 404


@pytest.mark.asyncio
async def test_not_found_error_default_message(app_custom_exceptions: FastAPI):
    transport = ASGITransport(app=app_custom_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/not-found-default")
    assert response.status_code == 404
    data = response.json()
    assert data["detail"] == "Resource not found"


@pytest.mark.asyncio
async def test_bad_request_error(app_custom_exceptions: FastAPI):
    transport = ASGITransport(app=app_custom_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/bad-request")
    assert response.status_code == 400
    data = response.json()
    assert data["detail"] == "Invalid payload"
    assert data["type"] == "BadRequestError"
    assert data["status_code"] == 400


@pytest.mark.asyncio
async def test_bad_request_error_default_message(app_custom_exceptions: FastAPI):
    transport = ASGITransport(app=app_custom_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/bad-request-default")
    assert response.status_code == 400
    data = response.json()
    assert data["detail"] == "Bad request"


@pytest.mark.asyncio
async def test_unauthorized_error(app_custom_exceptions: FastAPI):
    transport = ASGITransport(app=app_custom_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/unauthorized")
    assert response.status_code == 401
    data = response.json()
    assert data["detail"] == "Invalid credentials"
    assert data["type"] == "UnauthorizedError"
    assert data["status_code"] == 401


@pytest.mark.asyncio
async def test_unauthorized_error_default_message(app_custom_exceptions: FastAPI):
    transport = ASGITransport(app=app_custom_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/unauthorized-default")
    assert response.status_code == 401
    data = response.json()
    assert data["detail"] == "Unauthorized"


@pytest.mark.asyncio
async def test_forbidden_error(app_custom_exceptions: FastAPI):
    transport = ASGITransport(app=app_custom_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/forbidden")
    assert response.status_code == 403
    data = response.json()
    assert data["detail"] == "Access denied"
    assert data["type"] == "ForbiddenError"
    assert data["status_code"] == 403


@pytest.mark.asyncio
async def test_forbidden_error_default_message(app_custom_exceptions: FastAPI):
    transport = ASGITransport(app=app_custom_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/forbidden-default")
    assert response.status_code == 403
    data = response.json()
    assert data["detail"] == "Forbidden"


@pytest.mark.asyncio
async def test_conflict_error(app_custom_exceptions: FastAPI):
    transport = ASGITransport(app=app_custom_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/conflict")
    assert response.status_code == 409
    data = response.json()
    assert data["detail"] == "Duplicate entry"
    assert data["type"] == "CONFLICT"
    assert data["status_code"] == 409


@pytest.mark.asyncio
async def test_conflict_error_default_message(app_custom_exceptions: FastAPI):
    transport = ASGITransport(app=app_custom_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/conflict-default")
    assert response.status_code == 409
    data = response.json()
    assert data["detail"] == "Resource already exists"


@pytest.mark.asyncio
async def test_custom_validation_error(app_custom_exceptions: FastAPI):
    transport = ASGITransport(app=app_custom_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/validation")
    assert response.status_code == 400
    data = response.json()
    assert data["detail"] == "Field is required"
    assert data["type"] == "VALIDATION_ERROR"
    assert data["status_code"] == 400


@pytest.mark.asyncio
async def test_custom_validation_error_default_message(app_custom_exceptions: FastAPI):
    transport = ASGITransport(app=app_custom_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/validation-default")
    assert response.status_code == 400
    data = response.json()
    assert data["detail"] == "Validation failed"


@pytest.mark.asyncio
async def test_database_error(app_custom_exceptions: FastAPI):
    transport = ASGITransport(app=app_custom_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/database")
    assert response.status_code == 500
    data = response.json()
    assert data["detail"] == "Query failed"
    assert data["type"] == "DATABASE_ERROR"
    assert data["status_code"] == 500


@pytest.mark.asyncio
async def test_database_error_default_message(app_custom_exceptions: FastAPI):
    transport = ASGITransport(app=app_custom_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/database-default")
    assert response.status_code == 500
    data = response.json()
    assert data["detail"] == "Database error"


@pytest.mark.asyncio
async def test_external_service_error(app_custom_exceptions: FastAPI):
    transport = ASGITransport(app=app_custom_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/external-service")
    assert response.status_code == 502
    data = response.json()
    assert data["detail"] == "Upstream timeout"
    assert data["type"] == "EXTERNAL_SERVICE_ERROR"
    assert data["status_code"] == 502


@pytest.mark.asyncio
async def test_external_service_error_default_message(app_custom_exceptions: FastAPI):
    transport = ASGITransport(app=app_custom_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/external-service-default")
    assert response.status_code == 502
    data = response.json()
    assert data["detail"] == "External service error"


@pytest.mark.asyncio
async def test_custom_error_with_details(app_custom_exceptions: FastAPI):
    transport = ASGITransport(app=app_custom_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/custom-with-details")
    assert response.status_code == 400
    data = response.json()
    assert data["detail"] == "Bad request with extra info"
    assert data["details"] == {"field": "email", "reason": "invalid format"}


# ---------------------------------------------------------------------------
# Tests: http_exception_handler  (HTTPException / StarletteHTTPException)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_http_exception_404(app_http_exceptions: FastAPI):
    transport = ASGITransport(app=app_http_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/http-404")
    assert response.status_code == 404
    data = response.json()
    assert data["detail"] == "Page gone"
    assert data["type"] == "HTTPException"
    assert data["status_code"] == 404


@pytest.mark.asyncio
async def test_http_exception_403(app_http_exceptions: FastAPI):
    transport = ASGITransport(app=app_http_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/http-403")
    assert response.status_code == 403
    data = response.json()
    assert data["detail"] == "Forbidden page"


@pytest.mark.asyncio
async def test_http_exception_500(app_http_exceptions: FastAPI):
    transport = ASGITransport(app=app_http_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/http-500")
    assert response.status_code == 500
    data = response.json()
    assert data["detail"] == "Server blew up"


@pytest.mark.asyncio
async def test_starlette_http_exception(app_http_exceptions: FastAPI):
    transport = ASGITransport(app=app_http_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/starlette-401")
    assert response.status_code == 401
    data = response.json()
    assert data["detail"] == "No auth"
    assert data["type"] == "HTTPException"


# ---------------------------------------------------------------------------
# Tests: validation_exception_handler  (RequestValidationError)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_request_validation_error_missing_fields(app_validation_error: FastAPI):
    transport = ASGITransport(app=app_validation_error)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post("/validate", json={})
    assert response.status_code == 422
    data = response.json()
    assert data["detail"] == "Validation failed"
    assert data["type"] == "VALIDATION_ERROR"
    assert isinstance(data["errors"], list)
    assert len(data["errors"]) >= 1

    # Check that each error entry has the expected shape
    for err in data["errors"]:
        assert "field" in err
        assert "message" in err
        assert "type" in err


@pytest.mark.asyncio
async def test_request_validation_error_wrong_type(app_validation_error: FastAPI):
    transport = ASGITransport(app=app_validation_error)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/validate", json={"name": "Alice", "age": "not-a-number"}
        )
    assert response.status_code == 422
    data = response.json()
    assert data["detail"] == "Validation failed"
    assert any("age" in err["field"] for err in data["errors"])


@pytest.mark.asyncio
async def test_request_validation_error_custom_validator(app_validation_error: FastAPI):
    transport = ASGITransport(app=app_validation_error)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post("/validate", json={"name": "Alice", "age": -5})
    assert response.status_code == 422
    data = response.json()
    assert any("age" in err["field"] for err in data["errors"])


@pytest.mark.asyncio
async def test_request_validation_success(app_validation_error: FastAPI):
    transport = ASGITransport(app=app_validation_error)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post("/validate", json={"name": "Alice", "age": 30})
    assert response.status_code == 200


# ---------------------------------------------------------------------------
# Tests: database_connection_exception_handler  (SQLAlchemy errors)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_database_operational_error(app_database_connection: FastAPI):
    transport = ASGITransport(app=app_database_connection)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/db-operational")
    assert response.status_code == 503
    data = response.json()
    assert data["type"] == "DATABASE_CONNECTION_ERROR"
    assert data["status_code"] == 503
    assert "message_en" in data
    assert "message_zh" in data
    assert response.headers.get("Retry-After") == "10"


@pytest.mark.asyncio
async def test_database_interface_error(app_database_connection: FastAPI):
    transport = ASGITransport(app=app_database_connection)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/db-interface")
    assert response.status_code == 503
    data = response.json()
    assert data["type"] == "DATABASE_CONNECTION_ERROR"


@pytest.mark.asyncio
async def test_database_dbapi_error(app_database_connection: FastAPI):
    transport = ASGITransport(app=app_database_connection)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/db-dbapi")
    assert response.status_code == 503
    data = response.json()
    assert data["type"] == "DATABASE_CONNECTION_ERROR"


# ---------------------------------------------------------------------------
# Tests: timeout_exception_handler  (asyncio.TimeoutError / TimeoutError)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_asyncio_timeout_error(app_timeout: FastAPI):
    transport = ASGITransport(app=app_timeout)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/async-timeout")
    assert response.status_code == 504
    data = response.json()
    assert data["type"] == "REQUEST_TIMEOUT"
    assert data["status_code"] == 504
    assert "timeout" in data["detail"].lower()
    assert "message_en" in data
    assert "message_zh" in data


@pytest.mark.asyncio
async def test_sync_timeout_error(app_timeout: FastAPI):
    transport = ASGITransport(app=app_timeout)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/sync-timeout")
    assert response.status_code == 504
    data = response.json()
    assert data["type"] == "REQUEST_TIMEOUT"


# ---------------------------------------------------------------------------
# Tests: general_exception_handler  (catch-all Exception)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_general_exception_handler(app_general: FastAPI):
    # The Exception handler is routed through ServerErrorMiddleware which
    # always re-raises after producing a response.  Using raise_app_exceptions=False
    # lets the test client observe the response without propagating the re-raise.
    transport = ASGITransport(app=app_general, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/boom")
    assert response.status_code == 500
    data = response.json()
    assert data["detail"] == "Internal server error"
    assert data["type"] == "INTERNAL_SERVER_ERROR"
    assert data["status_code"] == 500


# ---------------------------------------------------------------------------
# Tests: response content-type is JSON with UTF-8
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_custom_error_response_content_type(app_custom_exceptions: FastAPI):
    transport = ASGITransport(app=app_custom_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/not-found")
    assert "application/json" in response.headers.get("content-type", "")


@pytest.mark.asyncio
async def test_general_error_response_content_type(app_general: FastAPI):
    transport = ASGITransport(app=app_general, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/boom")
    assert "application/json" in response.headers.get("content-type", "")


# ---------------------------------------------------------------------------
# Tests: ensure no details key when BaseCustomError.details is empty
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_custom_error_no_details_key_when_empty(app_custom_exceptions: FastAPI):
    transport = ASGITransport(app=app_custom_exceptions)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/bad-request")
    data = response.json()
    assert "details" not in data
