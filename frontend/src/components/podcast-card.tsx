'use client';

import Link from 'next/link';
import Image from 'next/image';
import { Star, StarOff } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import type { Podcast } from '@/types';

interface PodcastCardProps {
  podcast: Podcast;
  onTrackToggle?: (id: string, isTracked: boolean) => void;
  isToggling?: boolean;
}

export function PodcastCard({
  podcast,
  onTrackToggle,
  isToggling,
}: PodcastCardProps) {
  return (
    <Link href={`/podcasts/${podcast.id}`} className="group block">
      <Card className="overflow-hidden transition-all duration-200 hover:border-primary/20 hover:shadow-md">
        <CardContent className="p-4">
          <div className="flex items-start gap-3">
            {/* Logo */}
            <div className="relative h-14 w-14 flex-shrink-0 overflow-hidden rounded-xl bg-muted">
              {podcast.logo_url ? (
                <Image
                  src={podcast.logo_url}
                  alt={podcast.name}
                  fill
                  className="object-cover transition-transform duration-300 group-hover:scale-110"
                  sizes="56px"
                />
              ) : (
                <div className="flex h-full w-full items-center justify-center text-lg font-bold text-muted-foreground">
                  {podcast.name.charAt(0)}
                </div>
              )}
            </div>

            {/* Info */}
            <div className="min-w-0 flex-1">
              <h3 className="truncate text-sm font-semibold leading-tight group-hover:text-primary transition-colors">
                {podcast.name}
              </h3>
              {podcast.author && (
                <p className="mt-0.5 truncate text-xs text-muted-foreground">
                  {podcast.author}
                </p>
              )}
              <div className="mt-1.5 flex items-center gap-1.5">
                <span
                  className={cn(
                    'inline-flex items-center rounded-md px-1.5 py-0.5 text-[11px] font-semibold tabular-nums',
                    podcast.rank <= 10
                      ? 'bg-primary/10 text-primary'
                      : 'bg-muted text-muted-foreground'
                  )}
                >
                  #{podcast.rank}
                </span>
                {podcast.category && (
                  <span className="text-[11px] text-muted-foreground">
                    {podcast.category}
                  </span>
                )}
                {podcast.is_tracked && (
                  <Star className="h-3 w-3 fill-primary text-primary" />
                )}
              </div>
            </div>
          </div>
        </CardContent>

        {/* Track button */}
        <div className="border-t px-4 py-2.5">
          <Button
            variant={podcast.is_tracked ? 'secondary' : 'outline'}
            size="sm"
            className="w-full h-8"
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              onTrackToggle?.(podcast.id, podcast.is_tracked);
            }}
            disabled={isToggling}
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
        </div>
      </Card>
    </Link>
  );
}
