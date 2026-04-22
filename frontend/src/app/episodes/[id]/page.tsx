'use client';

import { use, Suspense } from 'react';
import Link from 'next/link';
import { ArrowLeft, RefreshCw } from 'lucide-react';
import { EpisodeTabs } from '@/components/episode-tabs';
import { AudioPlayer } from '@/components/audio-player';
import { StatusBadge } from '@/components/status-badge';
import { useEpisode } from '@/lib/api';
import { formatDate, formatDuration } from '@/lib/utils';

function EpisodeDetailContent({ id }: { id: string }) {
  const { data: episode, isLoading } = useEpisode(id);

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-20">
        <RefreshCw className="h-5 w-5 animate-spin text-muted-foreground" />
      </div>
    );
  }

  if (!episode) {
    return (
      <div className="py-20 text-center">
        <p className="text-muted-foreground">剧集未找到</p>
      </div>
    );
  }

  return (
    <div className={`space-y-8 ${episode.audio_url ? 'pb-44' : ''}`}>
      {/* Back link */}
      {episode.podcast && (
        <Link
          href={`/podcasts/${episode.podcast_id}`}
          className="group inline-flex items-center gap-1.5 text-sm text-muted-foreground transition-colors hover:text-primary"
        >
          <ArrowLeft className="h-3.5 w-3.5 transition-transform group-hover:-translate-x-0.5" />
          <span>{episode.podcast.name}</span>
        </Link>
      )}

      {/* Episode Header */}
      <div className="animate-fade-in-up space-y-4">
        <h1 className="font-display text-2xl font-semibold leading-snug tracking-tight sm:text-3xl">
          {episode.title}
        </h1>

        {/* Meta row */}
        <div className="flex flex-wrap items-center gap-x-4 gap-y-2 text-sm text-muted-foreground">
          {episode.published_at && (
            <span className="flex items-center gap-1.5">
              {formatDate(episode.published_at)}
            </span>
          )}
          {episode.duration != null && (
            <span className="flex items-center gap-1.5">
              {formatDuration(episode.duration)}
            </span>
          )}
          <StatusBadge status={episode.transcript_status} type="transcript" />
          <StatusBadge status={episode.summary_status} type="summary" />
        </div>
      </div>

      {/* Tabs */}
      <EpisodeTabs episodeId={id} episode={episode} />
    </div>
  );
}

export default function EpisodeDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const episode = useEpisode(id).data;

  return (
    <>
      <Suspense fallback={<div className="py-20 text-center text-muted-foreground">加载中...</div>}>
        <EpisodeDetailContent id={id} />
      </Suspense>

      {/* Audio Player - always mounted for seekTo functionality */}
      {episode?.audio_url && (
        <AudioPlayer
          audioUrl={episode.audio_url}
          title={episode.title}
          podcastName={episode.podcast?.name}
          coverUrl={episode.podcast?.logo_url ?? undefined}
        />
      )}
    </>
  );
}
