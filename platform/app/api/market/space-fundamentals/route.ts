import { NextResponse } from 'next/server';
import { spaceFundamentals, spaceFundamentalSources } from '@/lib/market-intelligence/space-fundamentals';

export const dynamic = 'force-dynamic';

export function GET() {
  return NextResponse.json({
    generatedAt: new Date().toISOString(),
    universe: ['RKLB', 'ASTS', 'PL', 'SPCX'],
    note:
      'Snapshot research data. Public-company market ratios are pulled from StockAnalysis on 2026-06-04; operating metrics are sourced from company releases and SEC filings.',
    companies: spaceFundamentals,
    sources: spaceFundamentalSources,
  });
}
