'use client';

import { useState } from 'react';
import {
  Plus,
  Pencil,
  Trash2,
  Plug,
  Loader2,
  CheckCircle2,
  XCircle,
  BrainCircuit,
} from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { ProviderForm } from '@/components/provider-form';
import { ProviderCardSkeleton } from '@/components/skeletons';
import {
  useProviders,
  useCreateProvider,
  useUpdateProvider,
  useDeleteProvider,
  useTestProvider,
} from '@/lib/api';
import type { AIProvider, CreateProviderRequest, UpdateProviderRequest } from '@/types';
import { toast } from 'sonner';
import { cn } from '@/lib/utils';

export default function SettingsPage() {
  const { data: providers, isLoading } = useProviders();
  const createMut = useCreateProvider();
  const updateMut = useUpdateProvider();
  const deleteMut = useDeleteProvider();
  const testMut = useTestProvider();

  const [formOpen, setFormOpen] = useState(false);
  const [editingProvider, setEditingProvider] = useState<AIProvider | null>(null);

  const handleCreate = () => {
    setEditingProvider(null);
    setFormOpen(true);
  };

  const handleEdit = (provider: AIProvider) => {
    setEditingProvider(provider);
    setFormOpen(true);
  };

  const handleDelete = (id: string) => {
    if (!confirm('确定要删除此提供商吗？')) return;
    deleteMut.mutate(id, {
      onSuccess: () => toast.success('已删除提供商'),
      onError: (err) => toast.error(`删除失败: ${err.message}`),
    });
  };

  const handleFormSubmit = (
    data: CreateProviderRequest | UpdateProviderRequest
  ) => {
    if (editingProvider) {
      updateMut.mutate(
        { id: editingProvider.id, data: data as UpdateProviderRequest },
        {
          onSuccess: () => {
            toast.success('提供商已更新');
            setFormOpen(false);
          },
          onError: (err) => toast.error(`更新失败: ${err.message}`),
        }
      );
    } else {
      createMut.mutate(data as CreateProviderRequest, {
        onSuccess: () => {
          toast.success('提供商已添加');
          setFormOpen(false);
        },
        onError: (err) => toast.error(`添加失败: ${err.message}`),
      });
    }
  };

  const handleTest = (id: string) => {
    testMut.mutate(id, {
      onSuccess: (result) => {
        if (result.success) {
          toast.success(`连接成功: ${result.message}`);
        } else {
          toast.error(`连接失败: ${result.message}`);
        }
      },
      onError: (err) => toast.error(`测试失败: ${err.message}`),
    });
  };

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">设置</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            管理 AI 提供商和模型配置
          </p>
        </div>
        <Button size="sm" onClick={handleCreate}>
          <Plus className="mr-1.5 h-3.5 w-3.5" />
          添加提供商
        </Button>
      </div>

      {/* Provider List */}
      {isLoading ? (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <ProviderCardSkeleton key={i} />
          ))}
        </div>
      ) : providers?.items.length ? (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {providers.items.map((provider) => (
            <Card
              key={provider.id}
              className="overflow-hidden transition-all duration-200 hover:shadow-md hover:border-primary/20"
            >
              <CardContent className="p-5 space-y-4">
                {/* Header */}
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2.5">
                    <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary/10">
                      <BrainCircuit className="h-4 w-4 text-primary" />
                    </div>
                    <div>
                      <h3 className="text-sm font-semibold">{provider.name}</h3>
                    </div>
                  </div>
                  {provider.is_active && (
                    <Badge variant="secondary" className="text-[11px]">
                      活跃
                    </Badge>
                  )}
                </div>

                {/* Details */}
                <div className="space-y-2 text-sm">
                  <div>
                    <p className="text-[11px] font-medium text-muted-foreground uppercase tracking-wide">
                      Base URL
                    </p>
                    <p className="mt-0.5 truncate text-xs text-foreground/80 font-mono">
                      {provider.base_url}
                    </p>
                  </div>
                  <div>
                    <p className="text-[11px] font-medium text-muted-foreground uppercase tracking-wide">
                      API Key
                    </p>
                    <p className="mt-0.5 text-xs text-foreground/60 font-mono">
                      sk-{'*'.repeat(20)}
                    </p>
                  </div>
                </div>

                {/* Models */}
                {provider.models && provider.models.length > 0 && (
                  <div className="flex flex-wrap gap-1.5">
                    {provider.models.map((model) => (
                      <Badge
                        key={model.id}
                        variant={model.is_default ? 'default' : 'outline'}
                        className="text-[11px]"
                      >
                        {model.model_name}
                      </Badge>
                    ))}
                  </div>
                )}

                {/* Test result */}
                {testMut.data && testMut.variables === provider.id && (
                  <div
                    className={cn(
                      'flex items-center gap-1.5 rounded-lg px-3 py-2 text-xs',
                      testMut.data.success
                        ? 'bg-green-500/10 text-green-700 dark:text-green-400'
                        : 'bg-red-500/10 text-red-700 dark:text-red-400'
                    )}
                  >
                    {testMut.data.success ? (
                      <CheckCircle2 className="h-3.5 w-3.5" />
                    ) : (
                      <XCircle className="h-3.5 w-3.5" />
                    )}
                    {testMut.data.message}
                  </div>
                )}

                {/* Actions */}
                <div className="flex gap-2 pt-1 border-t">
                  <Button
                    variant="outline"
                    size="sm"
                    className="flex-1 h-8"
                    onClick={() => handleTest(provider.id)}
                    disabled={testMut.isPending && testMut.variables === provider.id}
                  >
                    {testMut.isPending && testMut.variables === provider.id ? (
                      <Loader2 className="mr-1.5 h-3.5 w-3.5 animate-spin" />
                    ) : (
                      <Plug className="mr-1.5 h-3.5 w-3.5" />
                    )}
                    测试连接
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    className="h-8 w-8 p-0"
                    onClick={() => handleEdit(provider)}
                  >
                    <Pencil className="h-3.5 w-3.5" />
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    className="h-8 w-8 p-0 text-destructive hover:bg-destructive/10 hover:text-destructive"
                    onClick={() => handleDelete(provider.id)}
                  >
                    <Trash2 className="h-3.5 w-3.5" />
                  </Button>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      ) : (
        <Card className="border-dashed">
          <CardContent className="flex flex-col items-center justify-center py-20">
            <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-muted">
              <BrainCircuit className="h-7 w-7 text-muted-foreground" />
            </div>
            <h3 className="mt-4 text-sm font-medium">暂未配置 AI 提供商</h3>
            <p className="mt-1 text-xs text-muted-foreground text-center max-w-[260px]">
              添加 AI 提供商以启用转录和智能总结功能
            </p>
            <Button className="mt-5" size="sm" onClick={handleCreate}>
              <Plus className="mr-1.5 h-3.5 w-3.5" />
              添加提供商
            </Button>
          </CardContent>
        </Card>
      )}

      {/* Provider Form Dialog */}
      <ProviderForm
        open={formOpen}
        onOpenChange={setFormOpen}
        provider={editingProvider}
        onSubmit={handleFormSubmit}
        isSubmitting={createMut.isPending || updateMut.isPending}
      />
    </div>
  );
}
