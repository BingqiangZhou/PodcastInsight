'use client';

import { Suspense, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { RefreshCw, SlidersHorizontal, Inbox } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { EpisodeCard } from '@/components/episode-card';
import { EpisodeRowSkeleton } from '@/components/skeletons';
import { useEpisodes, useSyncEpisodes } from '@/lib/api';
import { toast } from 'sonner';
import type { TranscriptStatus, SummaryStatus } from '@/types';

const STATUS_OPTIONS = ['全部', 'pending', 'processing', 'completed', 'failed'] as const;

const STATUS_LABELS: Record<string, string> = {
  全部: '全部',
  pending: '等待中',
  processing: '处理中',
  completed: '已完成',
  failed: '失败',
};

function EpisodesContent() {
  const searchParams = useSearchParams();
  const initialTranscriptStatus = searchParams.get('transcript_status') || '';
  const initialSummaryStatus = searchParams.get('summary_status') || '';

  const [page, setPage] = useState(1);
  const [transcriptStatus, setTranscriptStatus] = useState(initialTranscriptStatus);
  const [summaryStatus, setSummaryStatus] = useState(initialSummaryStatus);
  const perPage = 20;

  const { data, isLoading } = useEpisodes({
    page,
    page_size: perPage,
    transcript_status: (transcriptStatus && transcriptStatus !== '全部')
      ? (transcriptStatus as TranscriptStatus)
      : undefined,
    summary_status: (summaryStatus && summaryStatus !== '全部')
      ? (summaryStatus as SummaryStatus)
      : undefined,
  });

  const syncMut = useSyncEpisodes();

  const handleFilterChange = (setter: (val: string) => void, val: string) => {
    setter(val === '全部' ? '' : val);
    setPage(1);
  };

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">剧集列表</h1>
          <p className="mt-1 text-sm text-muted-foreground">浏览所有剧集</p>
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={() =>
            syncMut.mutate(undefined, {
              onSuccess: () => toast.success('剧集同步已触发'),
              onError: (err) => toast.error(`同步失败: ${err.message}`),
            })
          }
          disabled={syncMut.isPending}
        >
          <RefreshCw
            className={`mr-1.5 h-3.5 w-3.5 ${syncMut.isPending ? 'animate-spin' : ''}`}
          />
          同步剧集
        </Button>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap items-center gap-3 rounded-xl border bg-card p-3">
        <SlidersHorizontal className="h-4 w-4 text-muted-foreground" />
        <Select
          value={transcriptStatus || '全部'}
          onValueChange={(v) => handleFilterChange(setTranscriptStatus, v)}
        >
          <SelectTrigger className="w-[130px] h-9">
            <SelectValue placeholder="转录状态" />
          </SelectTrigger>
          <SelectContent>
            {STATUS_OPTIONS.map((s) => (
              <SelectItem key={s} value={s}>
                {STATUS_LABELS[s]}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Select
          value={summaryStatus || '全部'}
          onValueChange={(v) => handleFilterChange(setSummaryStatus, v)}
        >
          <SelectTrigger className="w-[130px] h-9">
            <SelectValue placeholder="总结状态" />
          </SelectTrigger>
          <SelectContent>
            {STATUS_OPTIONS.map((s) => (
              <SelectItem key={s} value={s}>
                {STATUS_LABELS[s]}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <span className="ml-auto text-sm tabular-nums text-muted-foreground">
          {data?.total ?? 0} 集
        </span>
      </div>

      {/* Episode List */}
      {isLoading ? (
        <div className="space-y-2">
          {Array.from({ length: 8 }).map((_, i) => (
            <EpisodeRowSkeleton key={i} />
          ))}
        </div>
      ) : data?.items.length ? (
        <div className="space-y-2">
          {data.items.map((ep) => (
            <EpisodeCard key={ep.id} episode={ep} showPodcastName />
          ))}
        </div>
      ) : (
        <div className="flex flex-col items-center justify-center py-20">
          <Inbox className="h-12 w-12 text-muted-foreground/30" />
          <p className="mt-4 text-sm text-muted-foreground">未找到剧集</p>
          {(transcriptStatus || summaryStatus) && (
            <Button
              variant="outline"
              size="sm"
              className="mt-3"
              onClick={() => { setTranscriptStatus(''); setSummaryStatus(''); setPage(1); }}
            >
              清除筛选条件
            </Button>
          )}
        </div>
      )}

      {/* Pagination */}
      {data && data.total_pages > 1 && (
        <div className="flex items-center justify-center gap-3">
          <Button
            variant="outline"
            size="sm"
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            disabled={page <= 1}
          >
            上一页
          </Button>
          <span className="min-w-[80px] text-center text-sm tabular-nums text-muted-foreground">
            {page} / {data.total_pages}
          </span>
          <Button
            variant="outline"
            size="sm"
            onClick={() => setPage((p) => Math.min(data.total_pages, p + 1))}
            disabled={page >= data.total_pages}
          >
            下一页
          </Button>
        </div>
      )}
    </div>
  );
}

export default function EpisodesPage() {
  return (
    <Suspense
      fallback={
        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <div>
              <div className="h-7 w-28 animate-pulse rounded bg-primary/10" />
              <div className="mt-1 h-4 w-36 animate-pulse rounded bg-primary/10" />
            </div>
            <div className="h-9 w-24 animate-pulse rounded-md bg-primary/10" />
          </div>
          <div className="space-y-2">
            {Array.from({ length: 8 }).map((_, i) => (
              <EpisodeRowSkeleton key={i} />
            ))}
          </div>
        </div>
      }
    >
      <EpisodesContent />
    </Suspense>
  );
}
