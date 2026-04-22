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
} from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { ProviderForm } from '@/components/provider-form';
import {
  useProviders,
  useCreateProvider,
  useUpdateProvider,
  useDeleteProvider,
  useTestProvider,
} from '@/lib/api';
import type { AIProvider, CreateProviderRequest, UpdateProviderRequest } from '@/types';
import { toast } from 'sonner';

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
          <h1 className="text-2xl font-bold">设置</h1>
          <p className="text-sm text-muted-foreground">
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
        <div className="flex items-center justify-center py-20">
          <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
        </div>
      ) : providers?.items.length ? (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {providers.items.map((provider) => (
            <Card key={provider.id}>
              <CardHeader className="pb-3">
                <div className="flex items-center justify-between">
                  <CardTitle className="flex items-center gap-2 text-base">
                    <Plug className="h-4 w-4" />
                    {provider.provider_name}
                    {provider.is_default && (
                      <Badge variant="secondary" className="text-xs">
                        默认
                      </Badge>
                    )}
                  </CardTitle>
                </div>
              </CardHeader>
              <CardContent className="space-y-3">
                <div>
                  <p className="text-xs text-muted-foreground">Base URL</p>
                  <p className="truncate text-sm">{provider.base_url}</p>
                </div>

                <div>
                  <p className="text-xs text-muted-foreground">API Key</p>
                  <p className="text-sm">••••••••••••••••</p>
                </div>

                {/* Models */}
                {provider.models && provider.models.length > 0 && (
                  <div>
                    <p className="text-xs text-muted-foreground">模型</p>
                    <div className="mt-1 flex flex-wrap gap-1.5">
                      {provider.models.map((model) => (
                        <Badge key={model.id} variant="outline" className="text-xs">
                          {model.model_name}
                          {model.is_default && ' (默认)'}
                        </Badge>
                      ))}
                    </div>
                  </div>
                )}

                {/* Test result */}
                {testMut.data && testMut.variables === provider.id && (
                  <div
                    className={`flex items-center gap-1.5 text-xs ${
                      testMut.data.success
                        ? 'text-green-600 dark:text-green-400'
                        : 'text-red-600 dark:text-red-400'
                    }`}
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
                <div className="flex gap-2 pt-1">
                  <Button
                    variant="outline"
                    size="sm"
                    className="flex-1"
                    onClick={() => handleTest(provider.id)}
                    disabled={testMut.isPending && testMut.variables === provider.id}
                  >
                    {testMut.isPending && testMut.variables === provider.id ? (
                      <Loader2 className="mr-1 h-3.5 w-3.5 animate-spin" />
                    ) : (
                      <Plug className="mr-1 h-3.5 w-3.5" />
                    )}
                    测试连接
                  </Button>
                  <Button
                    variant="outline"
                    size="icon"
                    className="h-8 w-8"
                    onClick={() => handleEdit(provider)}
                  >
                    <Pencil className="h-3.5 w-3.5" />
                  </Button>
                  <Button
                    variant="outline"
                    size="icon"
                    className="h-8 w-8 text-destructive hover:bg-destructive/10"
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
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-16">
            <Plug className="mb-3 h-10 w-10 text-muted-foreground" />
            <p className="text-sm text-muted-foreground">
              暂未配置 AI 提供商
            </p>
            <Button className="mt-4" size="sm" onClick={handleCreate}>
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
