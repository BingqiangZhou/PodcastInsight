from types import SimpleNamespace
from unittest.mock import ANY, AsyncMock, Mock

import pytest

from app.admin.routes.users_audit import reset_user_password, toggle_user
from app.admin.services import users_audit_service as users_audit_service_module
from app.admin.services.users_audit_service import AdminUsersAuditService
from app.domains.user.models import UserStatus


def _build_request() -> Mock:
    request = Mock()
    request.client = Mock(host="127.0.0.1")
    request.headers = {"user-agent": "pytest"}
    return request


@pytest.mark.asyncio
async def test_toggle_user_delegates_to_service_action():
    admin_user = Mock(id=1, username="admin")
    service = Mock()
    service.toggle_user = AsyncMock(
        return_value={"success": True, "status": UserStatus.INACTIVE}
    )

    response = await toggle_user(
        user_id=2,
        request=_build_request(),
        user=admin_user,
        service=service,
    )

    assert response.status_code == 200
    service.toggle_user.assert_awaited_once_with(
        request=ANY,
        user=admin_user,
        target_user_id=2,
    )


@pytest.mark.asyncio
async def test_reset_password_delegates_to_service_action():
    admin_user = Mock(id=1, username="admin")
    service = Mock()
    service.reset_user_password_action = AsyncMock(
        return_value={
            "success": True,
            "new_password": "new-password",
            "message": "Password reset successful. New password: new-password",
        }
    )

    response = await reset_user_password(
        user_id=2,
        request=_build_request(),
        user=admin_user,
        service=service,
    )

    assert response.status_code == 200
    service.reset_user_password_action.assert_awaited_once_with(
        request=ANY,
        user=admin_user,
        target_user_id=2,
    )


@pytest.mark.asyncio
async def test_toggle_user_service_logs_and_returns_status(monkeypatch: pytest.MonkeyPatch):
    service = AdminUsersAuditService(db=AsyncMock())
    target_user = Mock(username="target", status=UserStatus.INACTIVE)
    service.toggle_user_status = AsyncMock(return_value=target_user)
    audit_mock = AsyncMock()
    monkeypatch.setattr(users_audit_service_module, "log_admin_action", audit_mock)

    payload = await service.toggle_user(
        request=_build_request(),
        user=SimpleNamespace(id=1, username="admin"),
        target_user_id=2,
    )

    service.toggle_user_status.assert_awaited_once_with(
        target_user_id=2,
        acting_user_id=1,
    )
    audit_mock.assert_awaited_once()
    assert payload == {"success": True, "status": UserStatus.INACTIVE}


@pytest.mark.asyncio
async def test_reset_password_service_logs_and_returns_payload(monkeypatch: pytest.MonkeyPatch):
    service = AdminUsersAuditService(db=AsyncMock())
    target_user = Mock(username="target")
    service.reset_user_password = AsyncMock(return_value=(target_user, "new-password"))
    audit_mock = AsyncMock()
    monkeypatch.setattr(users_audit_service_module, "log_admin_action", audit_mock)

    payload = await service.reset_user_password_action(
        request=_build_request(),
        user=SimpleNamespace(id=1, username="admin"),
        target_user_id=2,
    )

    service.reset_user_password.assert_awaited_once_with(target_user_id=2)
    audit_mock.assert_awaited_once()
    assert payload == {
        "success": True,
        "new_password": "new-password",
        "message": "Password reset successful. New password: new-password",
    }
