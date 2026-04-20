"""Admin route snapshot checks."""

from app.main import app


def _route_paths() -> set[str]:
    return {route.path for route in app.routes}


def test_admin_routes_snapshot() -> None:
    paths = _route_paths()

    expected_paths = {
        "/api/v1/admin/",
        "/api/v1/admin/login",
        "/api/v1/admin/logout",
        "/api/v1/admin/apikeys",
        "/api/v1/admin/apikeys/test",
        "/api/v1/admin/apikeys/create",
        "/api/v1/admin/apikeys/{key_id}/toggle",
        "/api/v1/admin/apikeys/{key_id}/edit",
        "/api/v1/admin/apikeys/{key_id}/delete",
        "/api/v1/admin/api/apikeys/export/json",
        "/api/v1/admin/api/apikeys/import/json",
        "/api/v1/admin/subscriptions",
        "/api/v1/admin/subscriptions/update-frequency",
        "/api/v1/admin/subscriptions/{sub_id}/edit",
        "/api/v1/admin/subscriptions/test-url",
        "/api/v1/admin/subscriptions/test-all",
        "/api/v1/admin/subscriptions/{sub_id}/delete",
        "/api/v1/admin/subscriptions/{sub_id}/refresh",
        "/api/v1/admin/subscriptions/batch/refresh",
        "/api/v1/admin/subscriptions/batch/toggle",
        "/api/v1/admin/subscriptions/batch/delete",
        "/api/v1/admin/api/subscriptions/export/opml",
        "/api/v1/admin/api/subscriptions/import/opml",
        "/api/v1/admin/settings",
        "/api/v1/admin/settings/api/audio",
        "/api/v1/admin/settings/frequency",
        "/api/v1/admin/settings/api/storage/info",
        "/api/v1/admin/settings/api/storage/cleanup/config",
        "/api/v1/admin/settings/api/storage/cleanup/execute",
    }

    assert expected_paths.issubset(paths)
