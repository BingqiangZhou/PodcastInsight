'use client';

import { use, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { Loader2, FileText, Sparkles } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { StatusBadge } from '@/components/status-badge';
import { EpisodeInfoCard } from '@/components/episode-info-card';
import { ExpandableDescription } from '@/components/expandable-description';
import { TranscriptViewer } from '@/components/transcript-viewer';
import { SummaryCard } from '@/components/summary-card';
import {
  useTranscribeEpisode,
  useSummarizeEpisode,
} from '@/lib/api';
import { toast } from 'sonner';
import type { Episode, TranscriptStatus, SummaryStatus } from '@/types';

interface EpisodeTabsProps {
  episodeId: string;
  episode: Episode;
}

type TabValue = 'overview' | 'transcript' | 'summary';

function TabContent({ episodeId, episode, activeTab }: {
  episodeId: string;
  episode: Episode;
  activeTab: TabValue;
}) {
  const transcribeMut = useTranscribeEpisode();
  const summarizeMut = useSummarizeEpisode();

  const canTranscribe =
    episode.transcript_status === null ||
    episode.transcript_status === 'failed';
  const canSummarize =
    episode.summary_status === null ||
    episode.summary_status === 'failed';
  const isTranscribing = episode.transcript_status === 'processing';
  const isSummarizing = episode.summary_status === 'processing';

  const handleTranscribe = () => {
    transcribeMut.mutate(episodeId, {
      onSuccess: () => toast.success('转录完成'),
      onError: (err) => toast.error(`转录失败: ${err.message}`),
    });
  };

  const handleSummarize = () => {
    summarizeMut.mutate(episodeId, {
      onSuccess: () => toast.success('总结任务已提交'),
      onError: (err) => toast.error(`总结失败: ${err.message}`),
    });
  };

  if (activeTab === 'overview') {
    return (
      <div className="space-y-6">
        <EpisodeInfoCard
          publishedAt={episode.published_at}
          duration={episode.duration}
          transcriptStatus={episode.transcript_status}
          summaryStatus={episode.summary_status}
        />

        <div className="flex flex-wrap gap-2">
          <Button
            size="sm"
            className="gap-1.5"
            onClick={handleTranscribe}
            disabled={!canTranscribe || transcribeMut.isPending}
          >
            {isTranscribing || transcribeMut.isPending ? (
              <Loader2 className="h-3.5 w-3.5 animate-spin" />
            ) : (
              <FileText className="h-3.5 w-3.5" />
            )}
            {isTranscribing
              ? '转录中...'
              : episode.transcript_status === 'completed'
                ? '重新转录'
                : '开始转录'}
          </Button>
          <Button
            variant="outline"
            size="sm"
            className="gap-1.5"
            onClick={handleSummarize}
            disabled={!canSummarize || summarizeMut.isPending}
          >
            {isSummarizing || summarizeMut.isPending ? (
              <Loader2 className="h-3.5 w-3.5 animate-spin" />
            ) : (
              <Sparkles className="h-3.5 w-3.5" />
            )}
            {isSummarizing
              ? '总结中...'
              : episode.summary_status === 'completed'
                ? '重新总结'
                : '开始总结'}
          </Button>
        </div>

        {episode.description && (
          <>
            <div className="border-t border-border" />
            <ExpandableDescription content={episode.description} />
          </>
        )}
      </div>
    );
  }

  if (activeTab === 'transcript') {
    return (
      <TranscriptViewer episodeId={episodeId} isActive={true} />
    );
  }

  if (activeTab === 'summary') {
    return (
      <SummaryCard episodeId={episodeId} isActive={true} />
    );
  }

  return null;
}

function TabTrigger({
  value,
  activeTab,
  onClick,
  children,
  status,
}: {
  value: TabValue;
  activeTab: TabValue;
  onClick: () => void;
  children: React.ReactNode;
  status?: 'completed' | 'processing' | null;
}) {
  const isActive = activeTab === value;

  return (
    <button
      onClick={onClick}
      className={`relative flex items-center gap-2 pb-3 text-sm font-medium transition-colors ${
        isActive
          ? 'border-b-2 border-primary text-primary'
          : 'text-muted-foreground hover:text-foreground'
      }`}
    >
      {children}
      {status === 'completed' && (
        <span className="h-1.5 w-1.5 rounded-full bg-green-500" />
      )}
      {status === 'processing' && (
        <Loader2 className="h-3 w-3 animate-spin text-muted-foreground" />
      )}
    </button>
  );
}

function EpisodeTabsInner({ episodeId, episode }: EpisodeTabsProps) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const currentTab = (searchParams.get('tab') as TabValue) || 'overview';

  const setTab = (tab: TabValue) => {
    router.push(`?tab=${tab}`, { scroll: false });
  };

  const transcriptStatus = episode.transcript_status;
  const summaryStatus = episode.summary_status;

  const getTabStatus = (type: 'transcript' | 'summary'): 'completed' | 'processing' | null => {
    const status = type === 'transcript' ? transcriptStatus : summaryStatus;
    if (status === 'completed') return 'completed';
    if (status === 'processing') return 'processing';
    return null;
  };

  return (
    <div className="space-y-6">
      <div className="flex gap-6 border-b border-border">
        <TabTrigger
          value="overview"
          activeTab={currentTab}
          onClick={() => setTab('overview')}
        >
          概述
        </TabTrigger>
        <TabTrigger
          value="transcript"
          activeTab={currentTab}
          onClick={() => setTab('transcript')}
          status={getTabStatus('transcript')}
        >
          转录文本
        </TabTrigger>
        <TabTrigger
          value="summary"
          activeTab={currentTab}
          onClick={() => setTab('summary')}
          status={getTabStatus('summary')}
        >
          AI 总结
        </TabTrigger>
      </div>

      <Suspense fallback={<div className="py-8 text-center text-muted-foreground">加载中...</div>}>
        <TabContent episodeId={episodeId} episode={episode} activeTab={currentTab} />
      </Suspense>
    </div>
  );
}

export function EpisodeTabs(props: EpisodeTabsProps) {
  return (
    <Suspense fallback={null}>
      <EpisodeTabsInner {...props} />
    </Suspense>
  );
}
