'use client';

import { Lightbulb, Sparkles } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import type { Summary } from '@/types';

interface SummaryCardProps {
  summary: Summary;
}

export function SummaryCard({ summary }: SummaryCardProps) {
  return (
    <Card className="animate-fade-in-up">
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between">
          <CardTitle className="flex items-center gap-2 text-base">
            <Sparkles className="h-4 w-4 text-chart-1" />
            AI 总结
          </CardTitle>
          <div className="flex items-center gap-2 text-xs text-muted-foreground">
            {summary.provider && <span>提供商: {summary.provider}</span>}
            {summary.model_used && <span>模型: {summary.model_used}</span>}
          </div>
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* Main content */}
        <div className="rounded-md bg-muted/50 p-4">
          <p className="whitespace-pre-wrap text-sm leading-relaxed">
            {summary.content}
          </p>
        </div>

        {/* Key topics */}
        {summary.key_topics && summary.key_topics.length > 0 && (
          <div>
            <h4 className="mb-2 flex items-center gap-1.5 text-sm font-medium">
              <Lightbulb className="h-4 w-4 text-chart-4" />
              关键主题
            </h4>
            <div className="flex flex-wrap gap-2">
              {summary.key_topics.map((topic, i) => (
                <Badge key={i} variant="secondary">
                  {topic}
                </Badge>
              ))}
            </div>
          </div>
        )}

        {/* Highlights */}
        {summary.highlights && summary.highlights.length > 0 && (
          <div>
            <h4 className="mb-2 text-sm font-medium">要点</h4>
            <ul className="space-y-1.5">
              {summary.highlights.map((highlight, i) => (
                <li key={i} className="flex items-start gap-2 text-sm">
                  <span className="mt-1.5 h-1.5 w-1.5 flex-shrink-0 rounded-full bg-chart-2" />
                  {highlight}
                </li>
              ))}
            </ul>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
