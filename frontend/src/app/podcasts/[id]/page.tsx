'use client';

import { use } from 'react';
import Image from 'next/image';
import Link from 'next/link';
import { ArrowLeft, RefreshCw, Star, StarOff, ExternalLink } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { EpisodeCard } from '@/components/episode-card';
import {
  usePodcast,
  useEpisodes,
  useTrackPodcast,
  useUntrackPodcast,
} from '@/lib/api';
import { formatDate } from '@/lib/utils';
import { toast } from 'sonner';

export default function PodcastDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const { data: podcast, isLoading } = usePodcast(id);
  const { data: episodes } = useEpisodes({ podcast_id: id, page_size: 50 });
  const trackMut = useTrackPodcast();
  const untrackMut = useUntrackPodcast();

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-20">
        <RefreshCw className="h-6 w-6 animate-spin text-muted-foreground" />
      </div>
    );
  }

  if (!podcast) {
    return (
      <div className="py-20 text-center">
        <p className="text-muted-foreground">播客未找到</p>
      </div>
    );
  }

  const handleTrackToggle = () => {
    const mut = podcast.is_tracked ? untrackMut : trackMut;
    mut.mutate(id, {
      onSuccess: () => {
        toast.success(podcast.is_tracked ? '已取消追踪' : '已开始追踪');
      },
      onError: (err) => {
        toast.error(`操作失败: ${err.message}`);
      },
    });
  };

  return (
    <div className="space-y-6">
      {/* Back */}
      <Link
        href="/podcasts"
        className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft className="h-4 w-4" />
        返回播客列表
      </Link>

      {/* Podcast Info Card */}
      <Card>
        <CardContent className="p-6">
          <div className="flex flex-col gap-6 sm:flex-row sm:items-start">
            {/* Logo */}
            <div className="relative h-24 w-24 flex-shrink-0 overflow-hidden rounded-xl bg-muted">
              {podcast.logo_url ? (
                <Image
                  src={podcast.logo_url}
                  alt={podcast.name}
                  fill
                  className="object-cover"
                  sizes="96px"
                />
              ) : (
                <div className="flex h-full w-full items-center justify-center text-3xl font-bold text-muted-foreground">
                  {podcast.name.charAt(0)}
                </div>
              )}
            </div>

            {/* Info */}
            <div className="min-w-0 flex-1">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <h1 className="text-xl font-bold">{podcast.name}</h1>
                  {podcast.author && (
                    <p className="mt-1 text-sm text-muted-foreground">
                      {podcast.author}
                    </p>
                  )}
                </div>
                <div className="flex gap-2">
                  <Button
                    variant={podcast.is_tracked ? 'secondary' : 'default'}
                    size="sm"
                    onClick={handleTrackToggle}
                    disabled={trackMut.isPending || untrackMut.isPending}
                  >
                    {podcast.is_tracked ? (
                      <>
                        <StarOff className="mr-1.5 h-3.5 w-3.5" />
                        取消追踪
                      </>
                    ) : (
                      <>
                        <Star className="mr-1.5 h-3.5 w-3.5" />
                        追踪
                      </>
                    )}
                  </Button>
                  {podcast.rss_feed_url && (
                    <Button variant="outline" size="icon" asChild>
                      <a
                        href={podcast.rss_feed_url}
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <ExternalLink className="h-4 w-4" />
                      </a>
                    </Button>
                  )}
                </div>
              </div>

              <div className="mt-3 flex flex-wrap items-center gap-2">
                <Badge variant="secondary">排名 #{podcast.rank}</Badge>
                {podcast.category && (
                  <Badge variant="outline">{podcast.category}</Badge>
                )}
                {podcast.track_count != null && (
                  <span className="text-xs text-muted-foreground">
                    订阅数: {podcast.track_count.toLocaleString()}
                  </span>
                )}
                {podcast.avg_duration != null && (
                  <span className="text-xs text-muted-foreground">
                    平均时长: {Math.round(podcast.avg_duration / 60)} 分钟
                  </span>
                )}
                {podcast.last_synced_at && (
                  <span className="text-xs text-muted-foreground">
                    最后同步: {formatDate(podcast.last_synced_at)}
                  </span>
                )}
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Episode List */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">
            剧集列表
            {episodes && (
              <span className="ml-2 text-sm font-normal text-muted-foreground">
                ({episodes.total} 集)
              </span>
            )}
          </CardTitle>
        </CardHeader>
        <CardContent>
          {episodes?.items.length ? (
            <div className="space-y-2">
              {episodes.items.map((ep) => (
                <EpisodeCard key={ep.id} episode={ep} />
              ))}
            </div>
          ) : (
            <p className="py-10 text-center text-sm text-muted-foreground">
              暂无剧集数据，请先追踪播客并同步
            </p>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
