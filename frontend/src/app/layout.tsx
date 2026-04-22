import type { Metadata } from 'next';
import { Newsreader, Outfit } from 'next/font/google';
import './globals.css';
import { Providers } from '@/components/providers';

const newsreader = Newsreader({
  subsets: ['latin'],
  variable: '--font-display',
  display: 'swap',
});

const outfit = Outfit({
  subsets: ['latin'],
  variable: '--font-body',
  display: 'swap',
});

export const metadata: Metadata = {
  title: 'PodDigest - 播客知识中心',
  description: '播客排名监控、转录与AI总结平台',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="zh-CN" suppressHydrationWarning>
      <body className={`${newsreader.variable} ${outfit.variable} font-body`}>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
