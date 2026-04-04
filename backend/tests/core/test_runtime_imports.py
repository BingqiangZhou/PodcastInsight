"""Import/runtime smoke tests for lazy startup boundaries."""

from app.admin.router import router as admin_router
from app.core.celery_app import create_celery_app
from app.domains.podcast.tasks.runtime import worker_session
from app.main import app, create_application


def test_app_import_and_factory_smoke() -> None:
    assert app is not None
    created = create_application()
    assert created.title


def test_admin_router_import_smoke() -> None:
    paths = {route.path for route in admin_router.routes}
    assert "/subscriptions" in paths  # admin subscription routes


def test_celery_app_lazy_creation_smoke() -> None:
    celery_app = create_celery_app()
    assert celery_app.conf.task_routes
    assert celery_app.conf.beat_schedule


def test_worker_runtime_exports_session_factory() -> None:
    assert callable(worker_session)
