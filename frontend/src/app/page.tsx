'use client';

import {
  Podcast,
  FileText,
  AudioLines,
  Sparkles,
  RefreshCw,
  ArrowRight,
  TrendingUp,
} from 'lucide-react';
import Link from 'next/link';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { PodcastCard } from '@/components/podcast-card';
import { StatusBadge } from '@/components/status-badge';
import { DashboardSkeleton } from '@/components/skeletons';
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
import { cn } from '@/lib/utils';

export default function DashboardPage() {
  const { data: stats, isLoading: statsLoading } = useDashboardStats();
  const { data: rankings, isLoading: rankingsLoading } = useRankings(1, 6);
  const { data: recentEpisodes, isLoading: episodesLoading } = useEpisodes({ page_size: 5, page: 1 });
  const syncRankings = useSyncRankings();
  const syncEpisodes = useSyncEpisodes();
  const trackMut = useTrackPodcast();
  const untrackMut = useUntrackPodcast();

  const isLoading = statsLoading && rankingsLoading && episodesLoading;

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

  if (isLoading) return <DashboardSkeleton />;

  const statCards = [
    {
      title: '总播客数',
      value: stats?.total_podcasts ?? 0,
      icon: Podcast,
      href: '/podcasts',
      accent: 'bg-chart-1/10 text-chart-1',
    },
    {
      title: '已追踪',
      value: stats?.tracked_podcasts ?? 0,
      icon: AudioLines,
      href: '/podcasts?is_tracked=true',
      accent: 'bg-chart-2/10 text-chart-2',
    },
    {
      title: '总集数',
      value: stats?.total_episodes ?? 0,
      icon: FileText,
      href: '/episodes',
      accent: 'bg-chart-3/10 text-chart-3',
    },
    {
      title: '已转录',
      value: stats?.transcribed_episodes ?? 0,
      icon: Sparkles,
      href: '/episodes?transcript_status=completed',
      accent: 'bg-chart-4/10 text-chart-4',
    },
  ];

  return (
    <div className="space-y-8">
      {/* Page Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">仪表盘</h1>
          <p className="mt-1 text-sm text-muted-foreground">
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
              className={cn('mr-1.5 h-3.5 w-3.5', syncRankings.isPending && 'animate-spin')}
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
              className={cn('mr-1.5 h-3.5 w-3.5', syncEpisodes.isPending && 'animate-spin')}
            />
            同步剧集
          </Button>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        {statCards.map((stat, i) => (
          <Link key={stat.title} href={stat.href}>
            <Card className="animate-fade-in-up border-0 shadow-sm transition-all duration-200 hover:shadow-md hover:bg-muted/30 cursor-pointer">
              <CardContent className="p-5">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-xs font-medium text-muted-foreground uppercase tracking-wide">
                      {stat.title}
                    </p>
                    <p className="mt-2 text-3xl font-bold tabular-nums tracking-tight">
                      {statsLoading ? '--' : stat.value.toLocaleString()}
                    </p>
                  </div>
                  <div className={cn('flex h-10 w-10 items-center justify-center rounded-xl', stat.accent)}>
                    <stat.icon className="h-5 w-5" />
                  </div>
                </div>
              </CardContent>
            </Card>
          </Link>
        ))}
      </div>

      {/* Two-column layout */}
      <div className="grid gap-6 lg:grid-cols-2">
        {/* Top Rankings */}
        <Card className="animate-fade-in-up stagger-5 border-0 shadow-sm">
          <CardHeader className="flex flex-row items-center justify-between pb-3">
            <CardTitle className="flex items-center gap-2 text-base">
              <TrendingUp className="h-4 w-4 text-primary" />
              热门播客排行
            </CardTitle>
            <Link href="/podcasts">
              <Button variant="ghost" size="sm" className="text-xs">
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
                    isToggling={trackMut.isPending || untrackMut.isPending}
                  />
                ))}
              </div>
            ) : (
              <div className="flex flex-col items-center justify-center py-12">
                <Podcast className="h-10 w-10 text-muted-foreground/40" />
                <p className="mt-3 text-sm text-muted-foreground">暂无排行数据</p>
                <Button
                  variant="outline"
                  size="sm"
                  className="mt-3"
                  onClick={() =>
                    syncRankings.mutate(undefined, {
                      onSuccess: () => toast.success('排名同步已触发'),
                    })
                  }
                  disabled={syncRankings.isPending}
                >
                  同步排名
                </Button>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Recent Episodes */}
        <Card className="animate-fade-in-up stagger-6 border-0 shadow-sm">
          <CardHeader className="flex flex-row items-center justify-between pb-3">
            <CardTitle className="flex items-center gap-2 text-base">
              <FileText className="h-4 w-4 text-primary" />
              最新剧集
            </CardTitle>
            <Link href="/episodes">
              <Button variant="ghost" size="sm" className="text-xs">
                查看全部
                <ArrowRight className="ml-1 h-3.5 w-3.5" />
              </Button>
            </Link>
          </CardHeader>
          <CardContent>
            {recentEpisodes?.items.length ? (
              <div className="divide-y">
                {recentEpisodes.items.map((ep) => (
                  <Link
                    key={ep.id}
                    href={`/episodes/${ep.id}`}
                    className="group flex items-center gap-3 py-3 first:pt-0 last:pb-0 transition-colors hover:bg-muted/30 -mx-2 px-2 rounded-lg"
                  >
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-medium group-hover:text-primary transition-colors">
                        {ep.title}
                      </p>
                      <div className="mt-1 flex items-center gap-2 text-xs text-muted-foreground">
                        {ep.published_at && <span>{formatDate(ep.published_at)}</span>}
                        {ep.duration != null && (
                          <span>{formatDuration(ep.duration)}</span>
                        )}
                      </div>
                    </div>
                    <div className="flex gap-1.5 shrink-0">
                      <StatusBadge status={ep.transcript_status} type="transcript" />
                      <StatusBadge status={ep.summary_status} type="summary" />
                    </div>
                  </Link>
                ))}
              </div>
            ) : (
              <div className="flex flex-col items-center justify-center py-12">
                <FileText className="h-10 w-10 text-muted-foreground/40" />
                <p className="mt-3 text-sm text-muted-foreground">暂无剧集数据</p>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
