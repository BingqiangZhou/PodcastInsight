'use client';

import { use } from 'react';
import Link from 'next/link';
import {
  ArrowLeft,
  RefreshCw,
  FileText,
  Sparkles,
  Loader2,
} from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { StatusBadge } from '@/components/status-badge';
import { TranscriptViewer } from '@/components/transcript-viewer';
import { SummaryCard } from '@/components/summary-card';
import {
  useEpisode,
  useTranscript,
  useSummary,
  useTranscribeEpisode,
  useSummarizeEpisode,
} from '@/lib/api';
import { formatDate, formatDuration } from '@/lib/utils';
import { toast } from 'sonner';

export default function EpisodeDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const { data: episode, isLoading } = useEpisode(id);
  const { data: transcript } = useTranscript(id, {
    retry: false,
    enabled: episode?.transcript_status === 'completed',
  });
  const { data: summary } = useSummary(id, {
    retry: false,
    enabled: episode?.summary_status === 'completed',
  });

  const transcribeMut = useTranscribeEpisode();
  const summarizeMut = useSummarizeEpisode();

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-20">
        <RefreshCw className="h-6 w-6 animate-spin text-muted-foreground" />
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

  const handleTranscribe = () => {
    transcribeMut.mutate(id, {
      onSuccess: () => toast.success('转录完成'),
      onError: (err) => toast.error(`转录失败: ${err.message}`),
    });
  };

  const handleSummarize = () => {
    summarizeMut.mutate(id, {
      onSuccess: () => toast.success('总结任务已提交'),
      onError: (err) => toast.error(`总结失败: ${err.message}`),
    });
  };

  const canTranscribe =
    episode.transcript_status === null ||
    episode.transcript_status === 'failed';
  const canSummarize =
    episode.summary_status === null ||
    episode.summary_status === 'failed';
  const isTranscribing = episode.transcript_status === 'processing';
  const isSummarizing = episode.summary_status === 'processing';

  return (
    <div className="space-y-6">
      {/* Back */}
      {episode.podcast && (
        <Link
          href={`/podcasts/${episode.podcast_id}`}
          className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
        >
          <ArrowLeft className="h-4 w-4" />
          返回 {episode.podcast.name}
        </Link>
      )}

      {/* Episode Info */}
      <Card className="animate-fade-in-up">
        <CardContent className="p-6">
          <h1 className="text-xl font-bold">{episode.title}</h1>
          {episode.description && (
            <p className="mt-2 text-sm text-muted-foreground line-clamp-3">
              {episode.description}
            </p>
          )}
          <div className="mt-3 flex flex-wrap items-center gap-3 text-sm text-muted-foreground">
            {episode.published_at && (
              <span>{formatDate(episode.published_at)}</span>
            )}
            {episode.duration != null && (
              <span>{formatDuration(episode.duration)}</span>
            )}
            <StatusBadge status={episode.transcript_status} type="transcript" />
            <StatusBadge status={episode.summary_status} type="summary" />
          </div>

          {/* Audio Player */}
          {episode.audio_url && (
            <div className="mt-4">
              <audio controls className="w-full" preload="metadata">
                <source src={episode.audio_url} />
                您的浏览器不支持音频播放
              </audio>
            </div>
          )}

          {/* Action Buttons */}
          <div className="mt-4 flex flex-wrap gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={handleTranscribe}
              disabled={!canTranscribe || transcribeMut.isPending}
            >
              {isTranscribing || transcribeMut.isPending ? (
                <Loader2 className="mr-1.5 h-3.5 w-3.5 animate-spin" />
              ) : (
                <FileText className="mr-1.5 h-3.5 w-3.5" />
              )}
              {isTranscribing
                ? '转录中...'
                : episode.transcript_status === 'completed'
                  ? '已转录'
                  : '开始转录'}
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={handleSummarize}
              disabled={!canSummarize || summarizeMut.isPending}
            >
              {isSummarizing || summarizeMut.isPending ? (
                <Loader2 className="mr-1.5 h-3.5 w-3.5 animate-spin" />
              ) : (
                <Sparkles className="mr-1.5 h-3.5 w-3.5" />
              )}
              {isSummarizing
                ? '总结中...'
                : episode.summary_status === 'completed'
                  ? '已总结'
                  : '开始总结'}
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Transcript */}
      {transcript && <TranscriptViewer transcript={transcript} />}
      {isTranscribing && !transcript && (
        <Card className="animate-fade-in">
          <CardContent className="flex items-center justify-center gap-2 py-10 text-muted-foreground">
            <Loader2 className="h-4 w-4 animate-spin" />
            正在转录中，请稍候...
          </CardContent>
        </Card>
      )}

      {/* Summary */}
      {summary && <SummaryCard summary={summary} />}
      {isSummarizing && !summary && (
        <Card className="animate-fade-in">
          <CardContent className="flex items-center justify-center gap-2 py-10 text-muted-foreground">
            <Loader2 className="h-4 w-4 animate-spin" />
            正在生成总结，请稍候...
          </CardContent>
        </Card>
      )}
    </div>
  );
}
