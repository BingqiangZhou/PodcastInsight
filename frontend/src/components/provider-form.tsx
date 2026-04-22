'use client';

import { useState, useEffect } from 'react';
import { Loader2 } from 'lucide-react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import type { AIProvider, CreateProviderRequest, UpdateProviderRequest } from '@/types';

interface ProviderFormProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  provider?: AIProvider | null;
  onSubmit: (data: CreateProviderRequest | UpdateProviderRequest) => void;
  isSubmitting?: boolean;
}

const PROVIDER_TYPES = [
  { value: 'openai', label: 'OpenAI' },
  { value: 'deepseek', label: 'DeepSeek' },
  { value: 'openrouter', label: 'OpenRouter' },
  { value: 'custom', label: '自定义 (OpenAI 兼容)' },
];

const DEFAULT_URLS: Record<string, string> = {
  openai: 'https://api.openai.com/v1',
  deepseek: 'https://api.deepseek.com/v1',
  openrouter: 'https://openrouter.ai/api/v1',
  custom: '',
};

export function ProviderForm({
  open,
  onOpenChange,
  provider,
  onSubmit,
  isSubmitting,
}: ProviderFormProps) {
  const isEditing = !!provider;

  const [providerType, setProviderType] = useState(
    provider?.provider_type ?? ''
  );
  const [name, setName] = useState(provider?.name ?? '');
  const [baseUrl, setBaseUrl] = useState(provider?.base_url ?? '');
  const [apiKey, setApiKey] = useState('');
  const [isActive, setIsActive] = useState(provider?.is_active ?? true);

  // Reset form when dialog opens or provider changes
  useEffect(() => {
    if (open) {
      setProviderType(provider?.provider_type ?? '');
      setName(provider?.name ?? '');
      setBaseUrl(provider?.base_url ?? '');
      setApiKey('');
      setIsActive(provider?.is_active ?? true);
    }
  }, [open, provider]);

  const handleProviderTypeChange = (value: string) => {
    setProviderType(value);
    if (!isEditing) {
      setName(value);
      setBaseUrl(DEFAULT_URLS[value] ?? '');
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (isEditing) {
      const data: UpdateProviderRequest = {};
      if (name) data.name = name;
      if (providerType) data.provider_type = providerType;
      if (baseUrl) data.base_url = baseUrl;
      if (apiKey) data.api_key = apiKey;
      data.is_active = isActive;
      onSubmit(data);
    } else {
      onSubmit({
        name: name || providerType,
        provider_type: providerType,
        base_url: baseUrl,
        api_key: apiKey,
        is_active: isActive,
      });
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[425px]">
        <DialogHeader>
          <DialogTitle>
            {isEditing ? '编辑 AI 提供商' : '添加 AI 提供商'}
          </DialogTitle>
          <DialogDescription>
            {isEditing
              ? '修改 AI 提供商的配置信息'
              : '配置新的 AI 提供商以用于转录和总结'}
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Provider type */}
          <div className="space-y-2">
            <label className="text-sm font-medium">提供商类型</label>
            <Select
              value={providerType}
              onValueChange={handleProviderTypeChange}
            >
              <SelectTrigger>
                <SelectValue placeholder="选择提供商类型" />
              </SelectTrigger>
              <SelectContent>
                {PROVIDER_TYPES.map((type) => (
                  <SelectItem key={type.value} value={type.value}>
                    {type.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {/* Name */}
          <div className="space-y-2">
            <label className="text-sm font-medium">名称</label>
            <Input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="例如: My OpenAI"
              required
            />
          </div>

          {/* Base URL */}
          <div className="space-y-2">
            <label className="text-sm font-medium">Base URL</label>
            <Input
              value={baseUrl}
              onChange={(e) => setBaseUrl(e.target.value)}
              placeholder="https://api.openai.com/v1"
              required
            />
          </div>

          {/* API Key */}
          <div className="space-y-2">
            <label className="text-sm font-medium">
              API Key{' '}
              {isEditing && (
                <span className="text-muted-foreground">(留空则不修改)</span>
              )}
            </label>
            <Input
              type="password"
              value={apiKey}
              onChange={(e) => setApiKey(e.target.value)}
              placeholder="sk-..."
              required={!isEditing}
            />
          </div>

          {/* Active toggle */}
          <div className="flex items-center gap-2">
            <input
              type="checkbox"
              id="is_active"
              checked={isActive}
              onChange={(e) => setIsActive(e.target.checked)}
              className="h-4 w-4 rounded border-input"
            />
            <label htmlFor="is_active" className="text-sm">
              启用此提供商
            </label>
          </div>

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
            >
              取消
            </Button>
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting && (
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              )}
              {isEditing ? '保存' : '添加'}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
