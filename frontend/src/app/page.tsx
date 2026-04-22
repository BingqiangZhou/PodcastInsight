'use client';

import {
  Podcast,
  FileText,
  AudioLines,
  Sparkles,
  RefreshCw,
  ArrowRight,
} from 'lucide-react';
import Link from 'next/link';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { PodcastCard } from '@/components/podcast-card';
import { StatusBadge } from '@/components/status-badge';
import {
  useDashboardStats,
  useRankings,
  useEpisodes,
  useSyncRankings,
  useSyncEpisodes,
  useTrackPodcast,
  useUntrackPodcast,
} from '@/lib/api';
import { formatDate, formatDuration } from '@/lib/utils';
import { toast } from 'sonner';

export default function DashboardPage() {
  const { data: stats, isLoading: statsLoading } = useDashboardStats();
  const { data: rankings } = useRankings(1, 6);
  const { data: recentEpisodes } = useEpisodes({ page_size: 5, page: 1 });
  const syncRankings = useSyncRankings();
  const syncEpisodes = useSyncEpisodes();
  const trackMut = useTrackPodcast();
  const untrackMut = useUntrackPodcast();

  const handleTrackToggle = (id: string, isTracked: boolean) => {
    const mut = isTracked ? untrackMut : trackMut;
    mut.mutate(id, {
      onSuccess: () => {
        toast.success(isTracked ? '已取消追踪' : '已开始追踪');
      },
      onError: (err) => {
        toast.error(`操作失败: ${err.message}`);
      },
    });
  };

  const statCards = [
    {
      title: '总播客数',
      value: stats?.total_podcasts ?? 0,
      icon: Podcast,
      color: 'text-chart-1',
    },
    {
      title: '已追踪',
      value: stats?.tracked_podcasts ?? 0,
      icon: AudioLines,
      color: 'text-chart-2',
    },
    {
      title: '总集数',
      value: stats?.total_episodes ?? 0,
      icon: FileText,
      color: 'text-chart-3',
    },
    {
      title: '已转录',
      value: stats?.transcribed_episodes ?? 0,
      icon: Sparkles,
      color: 'text-chart-4',
    },
  ];

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">仪表盘</h1>
          <p className="text-sm text-muted-foreground">
            播客知识中心概览
          </p>
        </div>
        <div className="flex gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() =>
              syncRankings.mutate(undefined, {
                onSuccess: () => toast.success('排名同步已触发'),
                onError: (err) => toast.error(`同步失败: ${err.message}`),
              })
            }
            disabled={syncRankings.isPending}
          >
            <RefreshCw
              className={`mr-1.5 h-3.5 w-3.5 ${syncRankings.isPending ? 'animate-spin' : ''}`}
            />
            同步排名
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={() =>
              syncEpisodes.mutate(undefined, {
                onSuccess: () => toast.success('剧集同步已触发'),
                onError: (err) => toast.error(`同步失败: ${err.message}`),
              })
            }
            disabled={syncEpisodes.isPending}
          >
            <RefreshCw
              className={`mr-1.5 h-3.5 w-3.5 ${syncEpisodes.isPending ? 'animate-spin' : ''}`}
            />
            同步剧集
          </Button>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        {statCards.map((stat, i) => (
          <Card key={stat.title} className={`animate-fade-in-up stagger-${i + 1}`}>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-xs text-muted-foreground">{stat.title}</p>
                  <p className="mt-1 text-2xl font-bold tabular-nums">
                    {statsLoading ? (
                      <span className="text-muted-foreground">--</span>
                    ) : (
                      stat.value.toLocaleString()
                    )}
                  </p>
                </div>
                <stat.icon className={`h-8 w-8 ${stat.color} opacity-80`} />
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Two-column layout */}
      <div className="grid gap-6 lg:grid-cols-2">
        {/* Top Rankings */}
        <Card className="animate-fade-in-up stagger-5">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-base">热门播客排行</CardTitle>
            <Link href="/podcasts">
              <Button variant="ghost" size="sm">
                查看全部
                <ArrowRight className="ml-1 h-3.5 w-3.5" />
              </Button>
            </Link>
          </CardHeader>
          <CardContent>
            {rankings?.items.length ? (
              <div className="grid gap-3 sm:grid-cols-2">
                {rankings.items.map((podcast) => (
                  <PodcastCard
                    key={podcast.id}
                    podcast={podcast}
                    onTrackToggle={handleTrackToggle}
                    isToggling={
                      trackMut.isPending || untrackMut.isPending
                    }
                  />
                ))}
              </div>
            ) : (
              <p className="py-8 text-center text-sm text-muted-foreground">
                暂无排行数据
              </p>
            )}
          </CardContent>
        </Card>

        {/* Recent Episodes */}
        <Card className="animate-fade-in-up stagger-6">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-base">最新剧集</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              {recentEpisodes?.items.length ? (
                recentEpisodes.items.map((ep) => (
                  <Link
                    key={ep.id}
                    href={`/episodes/${ep.id}`}
                    className="flex items-center gap-3 rounded-md p-2 transition-colors hover:bg-muted/50"
                  >
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-medium">
                        {ep.title}
                      </p>
                      <div className="flex items-center gap-2 text-xs text-muted-foreground">
                        {ep.published_at && <span>{formatDate(ep.published_at)}</span>}
                        {ep.duration != null && (
                          <span>{formatDuration(ep.duration)}</span>
                        )}
                      </div>
                    </div>
                    <div className="flex gap-1.5">
                      <StatusBadge
                        status={ep.transcript_status}
                        type="transcript"
                      />
                      <StatusBadge
                        status={ep.summary_status}
                        type="summary"
                      />
                    </div>
                  </Link>
                ))
              ) : (
                <p className="py-8 text-center text-sm text-muted-foreground">
                  暂无剧集数据
                </p>
              )}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
