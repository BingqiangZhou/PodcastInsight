import { Card, CardContent } from '@/components/ui/card';
import { StatusBadge } from '@/components/status-badge';
import { Calendar, Clock, FileText, Sparkles } from 'lucide-react';
import { formatDate, formatDuration } from '@/lib/utils';
import type { TranscriptStatus, SummaryStatus } from '@/types';

interface EpisodeInfoCardProps {
  publishedAt: string | null;
  duration: number | null;
  transcriptStatus: TranscriptStatus | null;
  summaryStatus: SummaryStatus | null;
}

export function EpisodeInfoCard({
  publishedAt,
  duration,
  transcriptStatus,
  summaryStatus,
}: EpisodeInfoCardProps) {
  return (
    <Card>
      <CardContent className="p-4">
        <div className="grid grid-cols-2 gap-4">
          {/* Published Date */}
          <div className="space-y-1">
            <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
              <Calendar className="h-3.5 w-3.5" />
              <span>发布日期</span>
            </div>
            <p className="text-sm font-medium">
              {publishedAt ? formatDate(publishedAt) : '—'}
            </p>
          </div>

          {/* Duration */}
          <div className="space-y-1">
            <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
              <Clock className="h-3.5 w-3.5" />
              <span>时长</span>
            </div>
            <p className="text-sm font-medium">
              {duration != null ? formatDuration(duration) : '—'}
            </p>
          </div>

          {/* Transcript Status */}
          <div className="space-y-1">
            <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
              <FileText className="h-3.5 w-3.5" />
              <span>转录状态</span>
            </div>
            <StatusBadge status={transcriptStatus} type="transcript" />
          </div>

          {/* Summary Status */}
          <div className="space-y-1">
            <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
              <Sparkles className="h-3.5 w-3.5" />
              <span>AI 总结</span>
            </div>
            <StatusBadge status={summaryStatus} type="summary" />
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
