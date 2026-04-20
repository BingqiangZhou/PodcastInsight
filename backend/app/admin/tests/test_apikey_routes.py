from unittest.mock import ANY, AsyncMock, Mock

import pytest
from fastapi import HTTPException

from app.admin.routes.apikeys import (
    ExportRequest,
    delete_apikey,
    export_apikeys_json,
    import_apikeys_json,
    toggle_apikey,
)


def _build_request() -> Mock:
    request = Mock()
    request.client = Mock(host="127.0.0.1")
    request.headers = {"user-agent": "pytest"}
    request.body = AsyncMock(return_value=b'{"file":"{}"}')
    return request


@pytest.mark.asyncio
async def test_toggle_apikey_delegates_and_returns_json_payload():
    admin_user = Mock(id=1, username="admin")
    service = Mock()
    service.toggle_apikey = AsyncMock(return_value={"success": True})

    response = await toggle_apikey(
        key_id=3,
        request=_build_request(),
        user_id=admin_user.id,
        service=service,
    )

    assert response.status_code == 200
    service.toggle_apikey.assert_awaited_once_with(
        request=ANY,
        user_id=admin_user.id,
        key_id=3,
    )


@pytest.mark.asyncio
async def test_delete_apikey_raises_not_found_when_service_returns_none():
    admin_user = Mock(id=1, username="admin")
    service = Mock()
    service.delete_apikey = AsyncMock(return_value=None)

    with pytest.raises(HTTPException) as exc_info:
        await delete_apikey(
            key_id=9,
            request=_build_request(),
            user_id=admin_user.id,
            service=service,
        )

    assert exc_info.value.status_code == 404
    assert exc_info.value.detail == "API key not found"


@pytest.mark.asyncio
async def test_export_apikeys_json_returns_json_payload_for_validation_errors():
    admin_user = Mock(id=1, username="admin")
    service = Mock()
    service.export_json = AsyncMock(return_value=({"success": False}, 400))

    response = await export_apikeys_json(
        request=_build_request(),
        user_id=admin_user.id,
        service=service,
        export_req=ExportRequest(mode="encrypted", export_password=None),
    )

    assert response.status_code == 400
    service.export_json.assert_awaited_once_with(
        request=ANY,
        user_id=admin_user.id,
        mode="encrypted",
        export_password=None,
    )


@pytest.mark.asyncio
async def test_import_apikeys_json_returns_service_status_code():
    admin_user = Mock(id=1, username="admin")
    service = Mock()
    service.import_json = AsyncMock(return_value=({"success": True}, 202))

    response = await import_apikeys_json(
        request=_build_request(),
        user_id=admin_user.id,
        service=service,
    )

    assert response.status_code == 202
    service.import_json.assert_awaited_once_with(
        request=ANY,
        user_id=admin_user.id,
        raw_body=b'{"file":"{}"}',
    )
