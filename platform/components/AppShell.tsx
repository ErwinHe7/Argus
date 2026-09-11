'use client';

import { usePathname } from 'next/navigation';
import { ErrorBoundary } from './ErrorBoundary';

export function AppShell({
  bg,
  nav,
  footer,
  children,
}: {
  bg: React.ReactNode;
  nav: React.ReactNode;
  footer: React.ReactNode;
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const isResearchHome =
    pathname === '/' || pathname === '/original' || pathname === '/original/' || pathname === '/research' || pathname === '/research/iv' || pathname === '/acceptance/research' || pathname.startsWith('/discover/market-map') || pathname === '/discover/stocks' || pathname === '/brokers';
  const isIntradayQuant = pathname === '/quant/intraday';

  if (isResearchHome) {
    return (
      <ErrorBoundary>{children}</ErrorBoundary>
    );
  }

  if (isIntradayQuant) {
    return (
      <>
        {nav}
        <main className="min-h-screen pt-[72px] max-[760px]:pt-16" data-site-theme="quant-dark">
          <ErrorBoundary>{children}</ErrorBoundary>
        </main>
      </>
    );
  }

  return (
    <>
      {bg}
      {nav}
      <main className="mx-auto max-w-5xl px-4 pb-24 pt-24">
        <ErrorBoundary>{children}</ErrorBoundary>
      </main>
      {footer}
    </>
  );
}
