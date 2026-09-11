import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { MarketMap } from '@/components/market-map/MarketMap';
import { getMarketMapSnapshot } from '@/lib/market-map/server';
import type { MarketMapHorizon } from '@/lib/market-map/types';

export const dynamic = 'force-dynamic';
export const metadata: Metadata = { title: 'Market Map · Leo', robots: { index: false, follow: false } };

export default async function MarketMapPage({ params }: { params: { symbol: string } }) {
  const symbol = params.symbol.toUpperCase();
  if (!/^[A-Z][A-Z0-9.\-]{0,14}$/.test(symbol)) notFound();
  const horizons: MarketMapHorizon[] = ['5d', '10d', '20d', '60d'];
  const results = await Promise.all(horizons.map((horizon) => getMarketMapSnapshot(symbol, horizon)));
  const snapshots = results.filter((snapshot): snapshot is NonNullable<typeof snapshot> => snapshot !== null);
  if (!snapshots.length) notFound();
  return <MarketMap snapshots={snapshots} />;
}
