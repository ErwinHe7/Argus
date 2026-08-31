import { NextRequest, NextResponse } from 'next/server';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';
import { requirePaidResearchAccess } from '@/lib/research-access';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const ROUTE = '/api/quant/reason';

/**
 * An explainer may describe a verified Rust result; it may not manufacture or
 * rescue a rank that the quantitative service has not published.
 */
export async function POST(req: NextRequest) {
  const access = await requirePaidResearchAccess();
  if (!access.allowed) return access.response;

  const rate = checkRateLimit(rateLimitKey(req, ROUTE), 4, 60_000);
  if (!rate.allowed) {
    return NextResponse.json({ error: 'Rate limit.' }, { status: 429 });
  }

  return NextResponse.json(
    {
      schema_version: 'axio.factor-shadow-explainer-status.v1',
      status: 'NO_VERIFIED_FACTOR_RANK_TO_EXPLAIN',
      explainer_invoked: false,
      rank_published: false,
      execution_enabled: false,
      message:
        'The Rust factor-shadow candidate has not been promoted, so no LLM explanation was generated.',
    },
    {
      status: 503,
      headers: { 'Cache-Control': 'no-store' },
    }
  );
}
