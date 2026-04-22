'use client';

import Link from 'next/link';
import { Clock, Calendar } from 'lucide-react';
import { StatusBadge } from '@/components/status-badge';
import { cn, formatDate, formatDuration } from '@/lib/utils';
import type { Episode } from '@/types';

interface EpisodeCardProps {
  episode: Episode;
  showPodcastName?: boolean;
}

export function EpisodeCard({ episode, showPodcastName = false }: EpisodeCardProps) {
  return (
    <Link href={`/episodes/${episode.id}`}>
      <div
        className={cn(
          'flex items-center gap-4 rounded-lg border p-4 transition-colors hover:bg-muted/50',
        )}
      >
        {/* Episode info */}
        <div className="min-w-0 flex-1">
          <h4 className="truncate text-sm font-medium group-hover:text-primary">
            {episode.title}
          </h4>
          <div className="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-muted-foreground">
            {showPodcastName && episode.podcast?.name && (
              <span className="font-medium">{episode.podcast.name}</span>
            )}
            {episode.published_at && (
              <span className="flex items-center gap-1">
                <Calendar className="h-3 w-3" />
                {formatDate(episode.published_at)}
              </span>
            )}
            {episode.duration != null && (
              <span className="flex items-center gap-1">
                <Clock className="h-3 w-3" />
                {formatDuration(episode.duration)}
              </span>
            )}
          </div>
        </div>

        {/* Status badges */}
        <div className="flex flex-shrink-0 items-center gap-2">
          <StatusBadge status={episode.transcript_status} type="transcript" />
          <StatusBadge status={episode.summary_status} type="summary" />
        </div>
      </div>
    </Link>
  );
}
