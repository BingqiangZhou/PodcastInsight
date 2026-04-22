'use client';

import { useState, useMemo, useCallback } from 'react';
import { Search } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import type { Transcript, TranscriptSegment } from '@/types';

interface TranscriptViewerProps {
  transcript: Transcript;
}

function formatTimestamp(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  if (h > 0) {
    return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  }
  return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
}

export function TranscriptViewer({ transcript }: TranscriptViewerProps) {
  const [searchTerm, setSearchTerm] = useState('');
  const hasSegments = transcript.segments && transcript.segments.length > 0;

  const filteredSegments = useMemo(() => {
    if (!hasSegments) return null;
    if (!searchTerm.trim()) return transcript.segments!;

    const lowerSearch = searchTerm.toLowerCase();
    return transcript.segments!.filter((seg) =>
      seg.text.toLowerCase().includes(lowerSearch)
    );
  }, [transcript.segments, searchTerm, hasSegments]);

  const highlightedContent = useMemo(() => {
    if (hasSegments) return null;
    if (!searchTerm.trim()) return transcript.content;

    const escaped = searchTerm.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const regex = new RegExp(`(${escaped})`, 'gi');
    const parts = transcript.content.split(regex);

    return parts.map((part, i) =>
      regex.test(part) ? (
        <mark key={i} className="rounded bg-yellow-200 px-0.5 dark:bg-yellow-800">
          {part}
        </mark>
      ) : (
        part
      )
    );
  }, [transcript.content, searchTerm, hasSegments]);

  const highlightText = useCallback(
    (text: string) => {
      if (!searchTerm.trim()) return text;
      const escaped = searchTerm.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const regex = new RegExp(`(${escaped})`, 'gi');
      const parts = text.split(regex);
      return parts.map((part, i) =>
        regex.test(part) ? (
          <mark key={i} className="rounded bg-yellow-200 px-0.5 dark:bg-yellow-800">
            {part}
          </mark>
        ) : (
          part
        )
      );
    },
    [searchTerm]
  );

  return (
    <Card className="animate-fade-in-up">
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-3">
        <CardTitle className="text-base">转录文本</CardTitle>
        <div className="flex items-center gap-2 text-xs text-muted-foreground">
          {transcript.language && <span>语言: {transcript.language}</span>}
          {transcript.word_count && <span>字数: {transcript.word_count.toLocaleString()}</span>}
          {transcript.model_used && <span>模型: {transcript.model_used}</span>}
        </div>
      </CardHeader>
      <CardContent>
        <div className="relative mb-3">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            type="text"
            placeholder="搜索转录内容..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-9"
          />
        </div>
        <div className="max-h-[500px] overflow-y-auto rounded-md bg-muted/50 p-4">
          {hasSegments ? (
            <div className="space-y-2 text-sm leading-relaxed">
              {filteredSegments?.map((seg, i) => (
                <div key={i} className="flex gap-3">
                  <span className="shrink-0 font-mono text-xs text-muted-foreground pt-0.5 select-none">
                    [{formatTimestamp(seg.start)}]
                  </span>
                  <span className="whitespace-pre-wrap">{highlightText(seg.text)}</span>
                </div>
              ))}
            </div>
          ) : (
            <pre className="whitespace-pre-wrap text-sm leading-relaxed">
              {highlightedContent}
            </pre>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
