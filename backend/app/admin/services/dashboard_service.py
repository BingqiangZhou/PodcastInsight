"""Admin dashboard service."""

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domains.ai.models import AIModelConfig
from app.domains.subscription.models import Subscription
from app.domains.user.models import User


async def get_dashboard_context(db: AsyncSession) -> dict[str, int]:
    """Build dashboard statistics payloads."""
    apikey_count = int(
        (await db.execute(select(func.count()).select_from(AIModelConfig))).scalar()
        or 0,
    )
    subscription_count = int(
        (await db.execute(select(func.count()).select_from(Subscription))).scalar()
        or 0,
    )
    user_count = int(
        (await db.execute(select(func.count()).select_from(User))).scalar() or 0,
    )
    return {
        "apikey_count": apikey_count,
        "subscription_count": subscription_count,
        "user_count": user_count,
    }
