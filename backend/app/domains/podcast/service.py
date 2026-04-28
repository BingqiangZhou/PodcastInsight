import logging
from datetime import datetime, timedelta, timezone
from math import ceil
from uuid import UUID

import aiohttp
import feedparser
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.domains.podcast.models import Episode, ProcessingStatus
from app.domains.podcast.repository import (
    EpisodeRepository,
    PodcastRankingHistoryRepository,
    PodcastRepository,
)
from app.domains.podcast.schemas import (
    EpisodeDetail,
    EpisodeListResponse,
    EpisodeResponse,
    PaginatedResponse,
    PodcastDetail,
    PodcastListResponse,
    PodcastResponse,
    PodcastTrackResponse,
    SyncResponse,
)

logger = logging.getLogger(__name__)
settings = get_settings()


class PodcastService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = PodcastRepository(session)
        self.history_repo = PodcastRankingHistoryRepository(session)

    async def list_podcasts(
        self,
        page: int = 1,
        page_size: int = 20,
        category: str | None = None,
        is_tracked: bool | None = None,
        search: str | None = None,
    ) -> PodcastListResponse:
        skip = (page - 1) * page_size
        podcasts = await self.repo.get_filtered(
            skip=skip,
            limit=page_size,
            category=category,
            is_tracked=is_tracked,
            search=search,
        )
        total = await self.repo.get_filtered_count(
            category=category,
            is_tracked=is_tracked,
            search=search,
        )
        return PodcastListResponse(
            items=[PodcastResponse.model_validate(p) for p in podcasts],
            total=total,
            page=page,
            page_size=page_size,
            total_pages=ceil(total / page_size) if total > 0 else 0,
        )

    async def get_podcast(self, podcast_id: UUID) -> PodcastDetail | None:
        podcast = await self.repo.get(podcast_id)
        if podcast is None:
            return None
        episode_repo = EpisodeRepository(self.session)
        episode_count = await episode_repo.count_by_podcast(podcast_id)
        detail = PodcastDetail.model_validate(podcast)
        detail.episode_count = episode_count
        return detail

    async def get_rankings(self, page: int = 1, page_size: int = 50) -> PodcastListResponse:
        skip = (page - 1) * page_size
        podcasts = await self.repo.get_rankings(skip=skip, limit=page_size)
        total = await self.repo.count()
        return PodcastListResponse(
            items=[PodcastResponse.model_validate(p) for p in podcasts],
            total=total,
            page=page,
            page_size=page_size,
            total_pages=ceil(total / page_size) if total > 0 else 0,
        )

    async def track_podcast(self, podcast_id: UUID) -> PodcastTrackResponse | None:
        podcast = await self.repo.update(podcast_id, {"is_tracked": True})
        if podcast is None:
            return None
        return PodcastTrackResponse.model_validate(podcast)

    async def untrack_podcast(self, podcast_id: UUID) -> PodcastTrackResponse | None:
        podcast = await self.repo.update(podcast_id, {"is_tracked": False})
        if podcast is None:
            return None
        return PodcastTrackResponse.model_validate(podcast)

    async def get_production_stats(self) -> dict:
        """Compute content production statistics."""
        from app.domains.transcription.models import Transcript
        from app.domains.summary.models import Summary

        now = datetime.now(timezone.utc)
        seven_days_ago = now - timedelta(days=7)

        # Total counts
        total_episodes = await self.session.scalar(
            select(func.count()).select_from(Episode)
        )

        transcribed = await self.session.scalar(
            select(func.count()).select_from(Episode).where(
                Episode.transcript_status == ProcessingStatus.COMPLETED
            )
        )
        summarized = await self.session.scalar(
            select(func.count()).select_from(Episode).where(
                Episode.summary_status == ProcessingStatus.COMPLETED
            )
        )

        # Success rates
        trans_completed = await self.session.scalar(
            select(func.count()).select_from(Transcript).where(
                Transcript.status == ProcessingStatus.COMPLETED
            )
        )
        trans_failed = await self.session.scalar(
            select(func.count()).select_from(Transcript).where(
                Transcript.status == ProcessingStatus.FAILED
            )
        )
        sum_completed = await self.session.scalar(
            select(func.count()).select_from(Summary).where(
                Summary.status == ProcessingStatus.COMPLETED
            )
        )
        sum_failed = await self.session.scalar(
            select(func.count()).select_from(Summary).where(
                Summary.status == ProcessingStatus.FAILED
            )
        )

        trans_total = (trans_completed or 0) + (trans_failed or 0)
        sum_total = (sum_completed or 0) + (sum_failed or 0)

        # Average processing duration
        avg_trans_duration = await self.session.scalar(
            select(func.avg(Transcript.processing_duration_sec)).where(
                Transcript.processing_duration_sec != None,  # noqa: E711
                Transcript.status == ProcessingStatus.COMPLETED,
            )
        )
        avg_sum_duration = await self.session.scalar(
            select(func.avg(Summary.processing_duration_sec)).where(
                Summary.processing_duration_sec != None,  # noqa: E711
                Summary.status == ProcessingStatus.COMPLETED,
            )
        )

        # 7-day trend
        trend = []
        for i in range(7):
            day = (now - timedelta(days=6 - i)).date()
            next_day = day + timedelta(days=1)
            day_start = datetime(day.year, day.month, day.day, tzinfo=timezone.utc)
            day_end = datetime(next_day.year, next_day.month, next_day.day, tzinfo=timezone.utc)

            trans_count = await self.session.scalar(
                select(func.count()).select_from(Transcript).where(
                    Transcript.status == ProcessingStatus.COMPLETED,
                    Transcript.updated_at >= day_start,
                    Transcript.updated_at < day_end,
                )
            )
            sum_count = await self.session.scalar(
                select(func.count()).select_from(Summary).where(
                    Summary.status == ProcessingStatus.COMPLETED,
                    Summary.updated_at >= day_start,
                    Summary.updated_at < day_end,
                )
            )
            trend.append({
                "date": day.isoformat(),
                "transcribed": trans_count or 0,
                "summarized": sum_count or 0,
            })

        # Pipeline stage counts for the production flow view
        trans_pending = await self.session.scalar(
            select(func.count()).select_from(Episode).where(
                Episode.transcript_status == ProcessingStatus.PENDING
            )
        )
        trans_processing = await self.session.scalar(
            select(func.count()).select_from(Episode).where(
                Episode.transcript_status == ProcessingStatus.PROCESSING
            )
        )
        sum_pending = await self.session.scalar(
            select(func.count()).select_from(Episode).where(
                Episode.summary_status == ProcessingStatus.PENDING
            )
        )
        sum_processing = await self.session.scalar(
            select(func.count()).select_from(Episode).where(
                Episode.summary_status == ProcessingStatus.PROCESSING
            )
        )

        return {
            "total_episodes": total_episodes or 0,
            "transcribed": transcribed or 0,
            "summarized": summarized or 0,
            "transcription_success_rate": round(trans_completed / trans_total, 3) if trans_total > 0 else None,
            "summary_success_rate": round(sum_completed / sum_total, 3) if sum_total > 0 else None,
            "avg_transcription_duration_sec": round(avg_trans_duration, 1) if avg_trans_duration else None,
            "avg_summary_duration_sec": round(avg_sum_duration, 1) if avg_sum_duration else None,
            "last_7_days": trend,
            "pipeline": {
                "transcription_pending": trans_pending or 0,
                "transcription_processing": trans_processing or 0,
                "transcription_completed": transcribed or 0,
                "transcription_failed": trans_failed or 0,
                "summary_pending": sum_pending or 0,
                "summary_processing": sum_processing or 0,
                "summary_completed": summarized or 0,
                "summary_failed": sum_failed or 0,
            },
        }

    async def sync_rankings(self) -> dict:
        """Fetch podcasts from xyzrank.com API and update database."""
        fetched_count = 0
        updated_count = 0
        created_count = 0
        synced_podcast_ids: list = []

        async with aiohttp.ClientSession() as http_session:
            for offset in range(0, 1000, 50):
                url = f"{settings.XYZRANK_API_URL}?offset={offset}&limit=50"
                try:
                    async with http_session.get(url, timeout=aiohttp.ClientTimeout(total=30)) as resp:
                        if resp.status != 200:
                            logger.warning(f"xyzrank API returned status {resp.status} at offset {offset}")
                            continue
                        data = await resp.json()
                except Exception as e:
                    logger.error(f"Error fetching xyzrank API at offset {offset}: {e}")
                    continue

                # API returns {"items": [...], "total": N}
                items = data.get("items", []) if isinstance(data, dict) else data
                if not items:
                    break

                for item in items:
                    xyzrank_id = str(item.get("id", ""))
                    if not xyzrank_id:
                        continue

                    # Extract RSS feed URL from links array
                    rss_feed_url = None
                    for link in item.get("links", []):
                        if link.get("name") == "rss":
                            rss_feed_url = link.get("url")
                            break

                    existing = await self.repo.get_by_xyzrank_id(xyzrank_id)
                    podcast_data = {
                        "name": item.get("name", ""),
                        "rank": item.get("rank", 0),
                        "logo_url": item.get("logoURL") or item.get("logo_url"),
                        "category": item.get("primaryGenreName") or item.get("category"),
                        "author": item.get("authorsText") or item.get("author"),
                        "rss_feed_url": rss_feed_url or item.get("rss_feed_url") or item.get("feed_url"),
                        "track_count": item.get("trackCount") or item.get("track_count"),
                        "avg_duration": item.get("avgDuration") or item.get("avg_duration"),
                        "avg_play_count": item.get("avgPlayCount") or item.get("avg_play_count"),
                        "last_synced_at": datetime.now(timezone.utc),
                    }

                    if existing:
                        await self.repo.update(existing.id, podcast_data)
                        synced_podcast_ids.append(existing.id)
                        updated_count += 1
                    else:
                        podcast_data["xyzrank_id"] = xyzrank_id
                        new_podcast = await self.repo.create(podcast_data)
                        synced_podcast_ids.append(new_podcast.id)
                        created_count += 1

                    fetched_count += 1

        # Record ranking history only for podcasts fetched in this sync
        for podcast_id in synced_podcast_ids:
            podcast = await self.repo.get(podcast_id)
            if podcast:
                await self.history_repo.create(
                    {
                        "podcast_id": podcast.id,
                        "rank": podcast.rank,
                        "avg_play_count": podcast.avg_play_count,
                    }
                )

        await self.session.flush()
        logger.info(
            f"Ranking sync complete: fetched={fetched_count}, created={created_count}, updated={updated_count}"
        )
        return {
            "fetched": fetched_count,
            "created": created_count,
            "updated": updated_count,
        }


class EpisodeService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = EpisodeRepository(session)

    async def list_episodes(
        self,
        page: int = 1,
        page_size: int = 20,
        podcast_id: UUID | None = None,
        transcript_status: ProcessingStatus | None = None,
        summary_status: ProcessingStatus | None = None,
    ) -> EpisodeListResponse:
        skip = (page - 1) * page_size
        episodes = await self.repo.get_filtered(
            skip=skip,
            limit=page_size,
            podcast_id=podcast_id,
            transcript_status=transcript_status,
            summary_status=summary_status,
        )
        total = await self.repo.get_filtered_count(
            podcast_id=podcast_id,
            transcript_status=transcript_status,
            summary_status=summary_status,
        )
        return EpisodeListResponse(
            items=[EpisodeResponse.model_validate(e) for e in episodes],
            total=total,
            page=page,
            page_size=page_size,
            total_pages=ceil(total / page_size) if total > 0 else 0,
        )

    async def get_episode(self, episode_id: UUID) -> EpisodeDetail | None:
        episode = await self.repo.get_with_relations(episode_id)
        if episode is None:
            return None
        detail = EpisodeDetail.model_validate(episode)
        if episode.podcast:
            detail.podcast_name = episode.podcast.name
            detail.podcast_logo_url = episode.podcast.logo_url
        return detail

    async def sync_episodes(self, podcast_id: UUID | None = None) -> dict:
        """Parse RSS feeds for tracked podcasts and create new episodes."""
        podcast_repo = PodcastRepository(self.session)
        if podcast_id:
            podcast = await podcast_repo.get(podcast_id)
            tracked_podcasts = [podcast] if podcast else []
        else:
            tracked_podcasts = await podcast_repo.get_tracked(limit=1000)

        total_created = 0
        total_updated = 0
        new_episode_ids: list[str] = []

        for podcast in tracked_podcasts:
            if not podcast.rss_feed_url:
                logger.warning(f"Podcast {podcast.name} has no RSS feed URL, skipping")
                continue

            try:
                async with aiohttp.ClientSession() as http_session:
                    async with http_session.get(
                        podcast.rss_feed_url, timeout=aiohttp.ClientTimeout(total=30)
                    ) as resp:
                        if resp.status != 200:
                            logger.warning(
                                f"RSS feed for {podcast.name} returned status {resp.status}"
                            )
                            continue
                        content = await resp.text()

                feed = feedparser.parse(content)

                for entry in feed.entries:
                    audio_url = None
                    duration = None

                    # Try to find audio enclosure
                    for link in getattr(entry, "links", []):
                        if link.get("type", "").startswith("audio/"):
                            audio_url = link.get("href")
                            duration = int(link.get("length", 0)) // 1000  # approximate seconds
                            break

                    if not audio_url:
                        # Fallback to enclosure
                        enclosures = getattr(entry, "enclosures", [])
                        if enclosures:
                            audio_url = enclosures[0].get("href") or enclosures[0].get("url")
                            try:
                                duration = int(enclosures[0].get("length", 0)) // 1000
                            except (ValueError, TypeError):
                                duration = None

                    if not audio_url:
                        continue

                    # Check if episode already exists
                    existing = await self.repo.get_by_audio_url(audio_url)
                    if existing:
                        total_updated += 1
                        continue

                    # Parse published date
                    published_at = None
                    if hasattr(entry, "published_parsed") and entry.published_parsed:
                        from time import mktime

                        published_at = datetime.fromtimestamp(mktime(entry.published_parsed), tz=timezone.utc)
                    elif hasattr(entry, "updated_parsed") and entry.updated_parsed:
                        from time import mktime

                        published_at = datetime.fromtimestamp(mktime(entry.updated_parsed), tz=timezone.utc)

                    # Parse duration from itunes duration tag
                    itunes_duration = getattr(entry, "itunes_duration", None)
                    if itunes_duration:
                        try:
                            parts = itunes_duration.split(":")
                            if len(parts) == 3:
                                duration = int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2])
                            elif len(parts) == 2:
                                duration = int(parts[0]) * 60 + int(parts[1])
                            else:
                                duration = int(itunes_duration)
                        except (ValueError, TypeError):
                            duration = duration

                    episode = await self.repo.create(
                        {
                            "podcast_id": podcast.id,
                            "title": entry.get("title", "Untitled"),
                            "description": entry.get("summary") or entry.get("description"),
                            "audio_url": audio_url,
                            "duration": duration,
                            "published_at": published_at,
                        }
                    )
                    total_created += 1
                    new_episode_ids.append(str(episode.id))

            except Exception as e:
                logger.error(f"Error syncing episodes for podcast {podcast.name}: {e}")
                continue

        await self.session.flush()
        logger.info(f"Episode sync complete: created={total_created}, updated={total_updated}")
        return {
            "created": total_created,
            "updated": total_updated,
            "new_episode_ids": new_episode_ids,
        }
