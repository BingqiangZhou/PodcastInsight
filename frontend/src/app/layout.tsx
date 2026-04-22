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
  title: 'PodcastInsight - 播客洞察平台',
  description: '播客排名监控、转录与AI洞察平台',
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
