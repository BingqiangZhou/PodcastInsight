'use client';

import {
  Podcast,
  FileText,
  AudioLines,
  Sparkles,
  RefreshCw,
  ArrowRight,
  TrendingUp,
  CheckCircle,
  Clock,
  BarChart3,
  AlertTriangle,
  Loader2,
  Hourglass,
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
  useProductionStats,
} from '@/lib/api';
import { formatDate, formatDuration } from '@/lib/utils';
import { toast } from 'sonner';
import { cn } from '@/lib/utils';

export default function DashboardPage() {
  const { data: stats, isLoading: statsLoading } = useDashboardStats();
  const { data: rankings, isLoading: rankingsLoading } = useRankings(1, 6);
  const { data: recentEpisodes, isLoading: episodesLoading } = useEpisodes({ page_size: 5, page: 1 });
  const { data: productionStats } = useProductionStats();
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

      {/* Pipeline Flow View */}
      {productionStats?.pipeline && (() => {
        const p = productionStats.pipeline;
        const totalFailed = p.transcription_failed + p.summary_failed;
        return (
          <div className="space-y-4">
            {/* Failed Tasks Alert */}
            {totalFailed > 0 && (
              <Link href="/episodes?transcript_status=failed">
                <Card className="border-0 shadow-sm bg-red-50 dark:bg-red-950/30 border-l-4 border-l-red-500 cursor-pointer hover:shadow-md transition-all">
                  <CardContent className="p-4">
                    <div className="flex items-center gap-3">
                      <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-red-500/10">
                        <AlertTriangle className="h-5 w-5 text-red-600 dark:text-red-400" />
                      </div>
                      <div>
                        <p className="text-sm font-semibold text-red-700 dark:text-red-300">
                          {totalFailed} 个任务需要关注
                        </p>
                        <p className="text-xs text-red-600/70 dark:text-red-400/70">
                          {p.transcription_failed > 0 && `${p.transcription_failed} 个转录失败`}
                          {p.transcription_failed > 0 && p.summary_failed > 0 && '，'}
                          {p.summary_failed > 0 && `${p.summary_failed} 个总结失败`}
                          {' — 点击查看详情'}
                        </p>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              </Link>
            )}

            {/* Pipeline Flow */}
            <h2 className="flex items-center gap-2 text-base font-semibold">
              <BarChart3 className="h-4 w-4 text-primary" />
              生产流水线
            </h2>
            <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
              {[
                { label: '待转录', value: p.transcription_pending, icon: Hourglass, accent: 'bg-yellow-500/10 text-yellow-600 dark:text-yellow-400' },
                { label: '转录中', value: p.transcription_processing, icon: Loader2, accent: 'bg-blue-500/10 text-blue-600 dark:text-blue-400' },
                { label: '待总结', value: p.summary_pending, icon: Hourglass, accent: 'bg-orange-500/10 text-orange-600 dark:text-orange-400' },
                { label: '总结中', value: p.summary_processing, icon: Loader2, accent: 'bg-indigo-500/10 text-indigo-600 dark:text-indigo-400' },
              ].map((stage) => (
                <Card key={stage.label} className="border-0 shadow-sm">
                  <CardContent className="p-4">
                    <div className="flex items-center justify-between">
                      <div>
                        <p className="text-xs font-medium text-muted-foreground">{stage.label}</p>
                        <p className="mt-1 text-2xl font-bold tabular-nums">{stage.value}</p>
                      </div>
                      <div className={cn('flex h-8 w-8 items-center justify-center rounded-lg', stage.accent)}>
                        <stage.icon className={cn('h-4 w-4', stage.label.includes('中') && 'animate-spin')} />
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          </div>
        );
      })()}

      {/* Production Stats */}
      <div className="space-y-4">
        <h2 className="flex items-center gap-2 text-base font-semibold">
          <BarChart3 className="h-4 w-4 text-primary" />
          生产统计
        </h2>

        {/* Stat Cards */}
        {(() => {
          const formatSeconds = (sec: number | null | undefined): string => {
            if (sec == null) return '--';
            if (sec < 60) return `${Math.round(sec)}s`;
            const m = Math.floor(sec / 60);
            const s = Math.round(sec % 60);
            return s > 0 ? `${m}m ${s}s` : `${m}m`;
          };

          const formatRate = (rate: number | null | undefined): string => {
            if (rate == null) return '--';
            return `${(rate * 100).toFixed(1)}%`;
          };

          const productionCards = [
            {
              title: '转录成功率',
              value: formatRate(productionStats?.transcription_success_rate),
              icon: CheckCircle,
              accent: 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400',
            },
            {
              title: '摘要成功率',
              value: formatRate(productionStats?.summary_success_rate),
              icon: CheckCircle,
              accent: 'bg-blue-500/10 text-blue-600 dark:text-blue-400',
            },
            {
              title: '平均转录耗时',
              value: formatSeconds(productionStats?.avg_transcription_duration_sec),
              icon: Clock,
              accent: 'bg-amber-500/10 text-amber-600 dark:text-amber-400',
            },
            {
              title: '平均摘要耗时',
              value: formatSeconds(productionStats?.avg_summary_duration_sec),
              icon: Clock,
              accent: 'bg-purple-500/10 text-purple-600 dark:text-purple-400',
            },
          ];

          return (
            <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
              {productionCards.map((card) => (
                <Card key={card.title} className="border-0 shadow-sm">
                  <CardContent className="p-5">
                    <div className="flex items-center justify-between">
                      <div>
                        <p className="text-xs font-medium text-muted-foreground uppercase tracking-wide">
                          {card.title}
                        </p>
                        <p className="mt-2 text-3xl font-bold tabular-nums tracking-tight">
                          {card.value}
                        </p>
                      </div>
                      <div className={cn('flex h-10 w-10 items-center justify-center rounded-xl', card.accent)}>
                        <card.icon className="h-5 w-5" />
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          );
        })()}

        {/* 7-Day Trend Chart */}
        {(() => {
          const trend = productionStats?.last_7_days ?? [];
          const maxCount = Math.max(
            ...trend.map((d) => Math.max(d.transcribed, d.summarized)),
            1,
          );

          const formatDateLabel = (dateStr: string): string => {
            const d = new Date(dateStr);
            return `${d.getMonth() + 1}/${d.getDate()}`;
          };

          return (
            <Card className="border-0 shadow-sm">
              <CardHeader className="pb-3">
                <CardTitle className="flex items-center gap-2 text-base">
                  <TrendingUp className="h-4 w-4 text-primary" />
                  近 7 天处理趋势
                </CardTitle>
              </CardHeader>
              <CardContent>
                {trend.length > 0 ? (
                  <div className="space-y-3">
                    {/* Legend */}
                    <div className="flex items-center gap-4 text-xs text-muted-foreground">
                      <span className="flex items-center gap-1.5">
                        <span className="inline-block h-2.5 w-2.5 rounded-sm bg-chart-1" />
                        转录
                      </span>
                      <span className="flex items-center gap-1.5">
                        <span className="inline-block h-2.5 w-2.5 rounded-sm bg-chart-2" />
                        摘要
                      </span>
                    </div>
                    {/* Bars */}
                    <div className="flex items-end gap-2 h-40">
                      {trend.map((day) => {
                        const transcribedH = (day.transcribed / maxCount) * 100;
                        const summarizedH = (day.summarized / maxCount) * 100;
                        return (
                          <div key={day.date} className="flex-1 flex flex-col items-center gap-1">
                            <div className="flex items-end gap-0.5 w-full h-32">
                              <div className="flex-1 flex flex-col justify-end">
                                <div
                                  className="w-full rounded-t-sm bg-chart-1/80 transition-all duration-300"
                                  style={{ height: `${Math.max(transcribedH, 2)}%` }}
                                  title={`转录: ${day.transcribed}`}
                                />
                              </div>
                              <div className="flex-1 flex flex-col justify-end">
                                <div
                                  className="w-full rounded-t-sm bg-chart-2/80 transition-all duration-300"
                                  style={{ height: `${Math.max(summarizedH, 2)}%` }}
                                  title={`摘要: ${day.summarized}`}
                                />
                              </div>
                            </div>
                            <span className="text-[10px] text-muted-foreground tabular-nums">
                              {formatDateLabel(day.date)}
                            </span>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                ) : (
                  <div className="flex flex-col items-center justify-center py-12">
                    <BarChart3 className="h-10 w-10 text-muted-foreground/40" />
                    <p className="mt-3 text-sm text-muted-foreground">暂无趋势数据</p>
                  </div>
                )}
              </CardContent>
            </Card>
          );
        })()}
      </div>
    </div>
  );
}
