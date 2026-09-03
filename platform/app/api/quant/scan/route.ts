import { NextRequest, NextResponse } from 'next/server';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';
import {
  QuantBackendUnavailableError,
  readFactorShadowStatus,
} from '@/lib/quant/research-client';
import { requirePaidResearchAccess } from '@/lib/research-access';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 60;

const ROUTE = '/api/quant/scan';

/**
 * The former endpoint calculated an ad-hoc Yahoo-backed factor rank in
 * TypeScript. Production quantitative inference belongs to the Rust service,
 * and missing/unentitled/PIT-incomplete data may not be silently skipped.
 *
 * Keep this paid route present, but fail closed until the separately validated
 * Rust factor-shadow artifact and licensed PIT universe are promoted.
 */
export async function GET(req: NextRequest) {
  const access = await requirePaidResearchAccess();
  if (!access.allowed) return access.response;

  const rate = checkRateLimit(rateLimitKey(req, ROUTE), 6, 60_000);
  if (!rate.allowed) {
    return NextResponse.json({ error: 'Rate limit.' }, { status: 429 });
  }

  try {
    const factorShadow = await readFactorShadowStatus();
    return NextResponse.json(
      {
        error: 'Quant factor scan unavailable.',
        code: factorShadow.candidate.status,
        factor_shadow: factorShadow,
      },
      {
        status: 503,
        headers: { 'Cache-Control': 'no-store' },
      }
    );
  } catch (error) {
    const code =
      error instanceof QuantBackendUnavailableError
        ? error.code
        : 'RUST_FACTOR_SHADOW_UNAVAILABLE';
    console.error('[/api/quant/scan]', code);
    return NextResponse.json(
      { error: 'Quant factor scan unavailable.', code },
      {
        status: 503,
        headers: { 'Cache-Control': 'no-store' },
      }
    );
  }
}
