import { NextResponse } from 'next/server';
import { getBrokerAdapter, getPaperTradeLog } from '@/lib/market-intelligence/broker';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET() {
  const broker = getBrokerAdapter();
  const [account, positions] = await Promise.all([broker.getAccount(), broker.getPositions()]);
  const trades = broker.mode === 'paper' ? getPaperTradeLog().slice(-50).reverse() : [];

  return NextResponse.json(
    {
      broker: { name: broker.name, mode: broker.mode },
      account,
      positions,
      trades,
      disclaimer:
        'AXIO7 does not execute live orders. Paper account state is in-process and resets on deploy unless persisted to Redis.',
    },
    { headers: { 'Cache-Control': 'no-store' } }
  );
}
