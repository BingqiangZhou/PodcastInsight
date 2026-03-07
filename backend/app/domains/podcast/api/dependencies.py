"""Podcast API dependency compatibility shims backed by centralized providers."""

from app.core.providers import (
    get_conversation_service,
    get_daily_report_service,
    get_summary_service,
    get_summary_workflow_service,
    get_transcription_service,
    get_transcription_workflow_service,
)
from app.core.providers import (
    get_podcast_episode_service as get_episode_service,
)
from app.core.providers import (
    get_podcast_playback_service as get_playback_service,
)
from app.core.providers import (
    get_podcast_queue_service as get_queue_service,
)
from app.core.providers import (
    get_podcast_schedule_service as get_schedule_service,
)
from app.core.providers import (
    get_podcast_search_service as get_search_service,
)
from app.core.providers import (
    get_podcast_stats_service as get_stats_service,
)
from app.core.providers import (
    get_podcast_subscription_service as get_subscription_service,
)
from app.core.providers import (
    get_token_user_id as get_current_user_id,
)
from app.core.providers import (
    get_transcription_scheduler as get_scheduler,
)


__all__ = [
    "get_conversation_service",
    "get_current_user_id",
    "get_daily_report_service",
    "get_episode_service",
    "get_playback_service",
    "get_queue_service",
    "get_schedule_service",
    "get_scheduler",
    "get_search_service",
    "get_stats_service",
    "get_subscription_service",
    "get_summary_service",
    "get_summary_workflow_service",
    "get_transcription_service",
    "get_transcription_workflow_service",
]
