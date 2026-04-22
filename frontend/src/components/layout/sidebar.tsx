'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  LayoutDashboard,
  Podcast,
  FileText,
  Settings,
  Radio,
  ChevronLeft,
  ChevronRight,
  Sun,
  Moon,
  Menu,
  X,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { useSidebar } from './sidebar-context';
import { useTheme } from './theme-provider';
import { useState } from 'react';

const navItems = [
  {
    label: '仪表盘',
    href: '/',
    icon: LayoutDashboard,
  },
  {
    label: '播客',
    href: '/podcasts',
    icon: Podcast,
  },
  {
    label: '剧集',
    href: '/episodes',
    icon: FileText,
  },
  {
    label: '设置',
    href: '/settings',
    icon: Settings,
  },
];

function SidebarContent({ onNavClick }: { onNavClick?: () => void }) {
  const pathname = usePathname();
  const { collapsed, toggle } = useSidebar();
  const { theme, toggle: toggleTheme } = useTheme();

  return (
    <div className="flex h-full flex-col">
      {/* Logo */}
      <div className="flex h-14 items-center justify-between border-b border-sidebar-border px-3">
        <Link href="/" className="flex items-center gap-2.5 overflow-hidden">
          <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-md bg-sidebar-primary">
            <Radio className="h-4 w-4 text-sidebar-primary-foreground" />
          </div>
          {!collapsed && (
            <span className="font-display text-base font-bold tracking-tight text-sidebar-foreground whitespace-nowrap">
              PodcastInsight
            </span>
          )}
        </Link>
        <button
          onClick={toggle}
          className="hidden lg:flex h-7 w-7 shrink-0 items-center justify-center rounded-md text-sidebar-foreground/50 hover:bg-sidebar-accent hover:text-sidebar-foreground transition-colors"
          aria-label={collapsed ? '展开侧边栏' : '收起侧边栏'}
        >
          {collapsed ? (
            <ChevronRight className="h-3.5 w-3.5" />
          ) : (
            <ChevronLeft className="h-3.5 w-3.5" />
          )}
        </button>
      </div>

      {/* Navigation */}
      <nav className="flex-1 space-y-0.5 px-2 py-3">
        {navItems.map((item) => {
          const isActive =
            item.href === '/'
              ? pathname === '/'
              : pathname.startsWith(item.href);

          return (
            <Link
              key={item.href}
              href={item.href}
              onClick={onNavClick}
              title={collapsed ? item.label : undefined}
              className={cn(
                'group flex items-center rounded-lg text-sm font-medium transition-all duration-200',
                collapsed
                  ? 'justify-center px-0 py-2.5'
                  : 'gap-3 px-3 py-2.5',
                isActive
                  ? 'bg-sidebar-primary/15 text-sidebar-primary'
                  : 'text-sidebar-foreground/60 hover:bg-sidebar-accent hover:text-sidebar-foreground'
              )}
            >
              <item.icon
                className={cn(
                  'h-[18px] w-[18px] shrink-0 transition-colors',
                  isActive
                    ? 'text-sidebar-primary'
                    : 'text-sidebar-foreground/50 group-hover:text-sidebar-foreground/80'
                )}
              />
              {!collapsed && <span>{item.label}</span>}
              {!collapsed && isActive && (
                <div className="ml-auto h-1.5 w-1.5 rounded-full bg-sidebar-primary" />
              )}
            </Link>
          );
        })}
      </nav>

      {/* Footer */}
      <div className="border-t border-sidebar-border px-2 py-3 space-y-1">
        <button
          onClick={toggleTheme}
          className={cn(
            'flex items-center rounded-lg text-sm font-medium transition-all duration-200 w-full',
            'text-sidebar-foreground/50 hover:bg-sidebar-accent hover:text-sidebar-foreground',
            collapsed
              ? 'justify-center px-0 py-2.5'
              : 'gap-3 px-3 py-2.5'
          )}
          aria-label={theme === 'dark' ? '切换亮色模式' : '切换暗色模式'}
        >
          {theme === 'dark' ? (
            <Sun className="h-[18px] w-[18px] shrink-0" />
          ) : (
            <Moon className="h-[18px] w-[18px] shrink-0" />
          )}
          {!collapsed && (
            <span>{theme === 'dark' ? '亮色模式' : '暗色模式'}</span>
          )}
        </button>
        {!collapsed && (
          <div className="px-3 pt-1">
            <p className="text-[11px] text-sidebar-foreground/30">
              PodcastInsight v1.0
            </p>
          </div>
        )}
      </div>
    </div>
  );
}

export function Sidebar() {
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <>
      {/* Mobile hamburger */}
      <button
        onClick={() => setMobileOpen(true)}
        className="lg:hidden fixed top-0 left-0 z-40 flex h-14 w-14 items-center justify-center bg-sidebar-background text-sidebar-foreground border-b border-sidebar-border"
        aria-label="打开菜单"
      >
        <Menu className="h-5 w-5" />
      </button>

      {/* Mobile overlay */}
      {mobileOpen && (
        <div
          className="lg:hidden fixed inset-0 z-50 bg-black/50 backdrop-blur-sm"
          onClick={() => setMobileOpen(false)}
        />
      )}

      {/* Mobile drawer */}
      <aside
        className={cn(
          'lg:hidden fixed inset-y-0 left-0 z-50 w-64 bg-sidebar-background transition-transform duration-300 ease-out border-r border-sidebar-border',
          mobileOpen ? 'translate-x-0' : '-translate-x-full'
        )}
      >
        <SidebarContent onNavClick={() => setMobileOpen(false)} />
        <button
          onClick={() => setMobileOpen(false)}
          className="absolute top-4 right-3 flex h-7 w-7 items-center justify-center rounded-md text-sidebar-foreground/50 hover:bg-sidebar-accent"
          aria-label="关闭菜单"
        >
          <X className="h-4 w-4" />
        </button>
      </aside>

      {/* Desktop sidebar */}
      <DesktopSidebar />
    </>
  );
}

function DesktopSidebar() {
  const { collapsed } = useSidebar();

  return (
    <aside
      className={cn(
        'hidden lg:flex h-screen flex-col border-r border-sidebar-border bg-sidebar-background transition-[width] duration-200',
        collapsed ? 'w-16' : 'w-56'
      )}
    >
      <SidebarContent />
    </aside>
  );
}
