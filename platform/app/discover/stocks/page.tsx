import type { Metadata } from 'next';
import { InvestingWorkspace } from '@/components/investing/InvestingHeader';
import { StockDiscovery } from '@/components/investing/StockDiscovery';
import { getStockDiscovery } from '@/lib/investing/discovery-server';

export const dynamic = 'force-dynamic';
export const metadata: Metadata = { title: 'Stocks · Leo', description: 'Search U.S. exchange-listed securities and inspect available market research.' };
export default async function StockDiscoveryPage() {
  const initial = await getStockDiscovery({ limit: 40, offset: 0 });
  return <InvestingWorkspace active="stocks"><StockDiscovery initial={initial} /></InvestingWorkspace>;
}
