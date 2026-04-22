import Link from 'next/link';

export default function NotFound() {
  return (
    <div className="flex min-h-[60vh] flex-col items-center justify-center gap-4">
      <h2 className="text-2xl font-bold">页面未找到</h2>
      <p className="text-muted-foreground">你访问的页面不存在</p>
      <Link
        href="/"
        className="text-primary underline underline-offset-4 hover:text-primary/80"
      >
        返回首页
      </Link>
    </div>
  );
}
