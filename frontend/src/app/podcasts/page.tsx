'use client';

import { Suspense, useState, useCallback } from 'react';
import { useSearchParams } from 'next/navigation';
import { RefreshCw, SlidersHorizontal, Search } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { SearchBar } from '@/components/search-bar';
import { PodcastCard } from '@/components/podcast-card';
import { PodcastCardSkeleton } from '@/components/skeletons';
import {
  usePodcasts,
  useTrackPodcast,
  useUntrackPodcast,
  useSyncRankings,
} from '@/lib/api';
import { toast } from 'sonner';

const CATEGORIES = [
  '全部',
  '科技',
  '商业',
  '教育',
  '娱乐',
  '社会',
  '音乐',
  '新闻',
  '健康',
  '体育',
  '其他',
];

export default function PodcastsPage() {
  return (
    <Suspense
      fallback={<PodcastsPageSkeleton />}
    >
      <PodcastsContent />
    </Suspense>
  );
}

function PodcastsPageSkeleton() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <div className="h-7 w-28 animate-pulse rounded bg-primary/10" />
          <div className="mt-1 h-4 w-44 animate-pulse rounded bg-primary/10" />
        </div>
        <div className="h-9 w-24 animate-pulse rounded-md bg-primary/10" />
      </div>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        {Array.from({ length: 12 }).map((_, i) => (
          <PodcastCardSkeleton key={i} />
        ))}
      </div>
    </div>
  );
}

function PodcastsContent() {
  const searchParams = useSearchParams();
  const initialTracked = searchParams.get('is_tracked');

  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [category, setCategory] = useState('');
  const perPage = 12;

  const { data, isLoading } = usePodcasts({
    page,
    page_size: perPage,
    search: search || undefined,
    category: category && category !== '全部' ? category : undefined,
    is_tracked: initialTracked === 'true' ? true : undefined,
  });

  const trackMut = useTrackPodcast();
  const untrackMut = useUntrackPodcast();
  const syncMut = useSyncRankings();

  const handleTrackToggle = useCallback(
    (id: string, isTracked: boolean) => {
      const mut = isTracked ? untrackMut : trackMut;
      mut.mutate(id, {
        onSuccess: () => {
          toast.success(isTracked ? '已取消追踪' : '已开始追踪');
        },
        onError: (err) => {
          toast.error(`操作失败: ${err.message}`);
        },
      });
    },
    [trackMut, untrackMut]
  );

  const handleCategoryChange = (val: string) => {
    setCategory(val);
    setPage(1);
  };

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">播客列表</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            浏览和追踪你感兴趣的播客
          </p>
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={() =>
            syncMut.mutate(undefined, {
              onSuccess: () => toast.success('排名同步已触发'),
              onError: (err) => toast.error(`同步失败: ${err.message}`),
            })
          }
          disabled={syncMut.isPending}
        >
          <RefreshCw
            className={`mr-1.5 h-3.5 w-3.5 ${syncMut.isPending ? 'animate-spin' : ''}`}
          />
          同步排名
        </Button>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap items-center gap-3 rounded-xl border bg-card p-3">
        <SearchBar
          placeholder="搜索播客..."
          onSearch={(val) => {
            setSearch(val);
            setPage(1);
          }}
        />
        <div className="h-6 w-px bg-border hidden sm:block" />
        <div className="flex items-center gap-2">
          <SlidersHorizontal className="h-4 w-4 text-muted-foreground" />
          <Select value={category || '全部'} onValueChange={handleCategoryChange}>
            <SelectTrigger className="w-[130px] h-9">
              <SelectValue placeholder="分类筛选" />
            </SelectTrigger>
            <SelectContent>
              {CATEGORIES.map((cat) => (
                <SelectItem key={cat} value={cat}>
                  {cat}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <span className="ml-auto text-sm tabular-nums text-muted-foreground">
          {data?.total ?? 0} 个播客
        </span>
      </div>

      {/* Podcast Grid */}
      {isLoading ? (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {Array.from({ length: 8 }).map((_, i) => (
            <PodcastCardSkeleton key={i} />
          ))}
        </div>
      ) : data?.items.length ? (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {data.items.map((podcast, i) => (
            <div key={podcast.id} className={`animate-fade-in-up stagger-${Math.min(i % 8 + 1, 8)}`}>
              <PodcastCard
                podcast={podcast}
                onTrackToggle={handleTrackToggle}
                isToggling={trackMut.isPending || untrackMut.isPending}
              />
            </div>
          ))}
        </div>
      ) : (
        <div className="flex flex-col items-center justify-center py-20">
          <Search className="h-12 w-12 text-muted-foreground/30" />
          <p className="mt-4 text-sm text-muted-foreground">未找到匹配的播客</p>
          {(search || category) && (
            <Button
              variant="outline"
              size="sm"
              className="mt-3"
              onClick={() => { setSearch(''); setCategory(''); setPage(1); }}
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
