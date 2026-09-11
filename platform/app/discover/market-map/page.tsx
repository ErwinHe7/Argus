import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { MarketMap } from '@/components/market-map/MarketMap';
import { getPublicMarketMapSnapshots, getPublicMarketMapStatus } from '@/lib/market-map/public-server';
import { DEFAULT_PUBLIC_MARKET_SYMBOL, isPublicMarketSymbol } from '@/lib/market-map/public-catalog';

export const dynamic = 'force-dynamic';
export const metadata: Metadata = {
  title: 'Market Map · Leo',
  description: 'Explore U.S. stock and ETF daily prices, calculated indicators and evidence-linked market explanations.',
};

export default async function MarketMapEntryPage({ searchParams }: { searchParams: { symbol?: string } }) {
  const symbol = searchParams.symbol ?? DEFAULT_PUBLIC_MARKET_SYMBOL;
  if (!isPublicMarketSymbol(symbol)) notFound();
  const [snapshots, status] = await Promise.all([getPublicMarketMapSnapshots(symbol).catch(() => []), getPublicMarketMapStatus()]);
  if (!snapshots.length) notFound();
  return <MarketMap key={symbol} snapshots={snapshots} publicData publicSymbols={status.symbols ?? [symbol]} />;
}
