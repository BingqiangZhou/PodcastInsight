"""Admin router aggregator."""

from fastapi import APIRouter

from app.admin.routes.apikeys import router as apikeys_router
from app.admin.routes.dashboard import router as dashboard_router
from app.admin.routes.settings import router as settings_router
from app.admin.routes.subscriptions import router as subscriptions_router


router = APIRouter()
router.include_router(dashboard_router)
router.include_router(apikeys_router)
router.include_router(subscriptions_router)
router.include_router(settings_router)
