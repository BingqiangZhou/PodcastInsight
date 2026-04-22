'use client';

import { useState, useCallback } from 'react';
import { RefreshCw, SlidersHorizontal } from 'lucide-react';
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
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [category, setCategory] = useState('');
  const perPage = 12;

  const { data, isLoading } = usePodcasts({
    page,
    page_size: perPage,
    search: search || undefined,
    category: category && category !== '全部' ? category : undefined,
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
          <h1 className="text-2xl font-bold">播客列表</h1>
          <p className="text-sm text-muted-foreground">
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
      <div className="flex flex-wrap items-center gap-3">
        <SearchBar
          placeholder="搜索播客..."
          onSearch={(val) => {
            setSearch(val);
            setPage(1);
          }}
        />
        <div className="flex items-center gap-2">
          <SlidersHorizontal className="h-4 w-4 text-muted-foreground" />
          <Select value={category || '全部'} onValueChange={handleCategoryChange}>
            <SelectTrigger className="w-[140px]">
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
        <span className="text-sm text-muted-foreground">
          共 {data?.total ?? 0} 个播客
        </span>
      </div>

      {/* Podcast Grid */}
      {isLoading ? (
        <div className="flex items-center justify-center py-20">
          <RefreshCw className="h-6 w-6 animate-spin text-muted-foreground" />
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
        <div className="py-20 text-center">
          <p className="text-muted-foreground">未找到播客</p>
        </div>
      )}

      {/* Pagination */}
      {data && data.total_pages > 1 && (
        <div className="flex items-center justify-center gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            disabled={page <= 1}
          >
            上一页
          </Button>
          <span className="text-sm text-muted-foreground">
            第 {page} / {data.total_pages} 页
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
