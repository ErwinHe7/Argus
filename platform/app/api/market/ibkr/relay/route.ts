import crypto from 'node:crypto';
import { NextRequest, NextResponse } from 'next/server';
import { getCurrentUser, isAdmin } from '@/lib/auth';
import { checkRateLimit, rateLimitKey } from '@/lib/market-intelligence/rate-limit';
import { readIbkrQuoteRelayReceipt } from '@/lib/quant/research-client';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 15;

const BACKEND = (process.env.INTRADAY_QUANT_API_URL || 'http://127.0.0.1:8001').replace(/\/$/, '');
const MAX_BODY_BYTES = 65_536;
const ROUTE = '/api/market/ibkr/relay';

function constantTimeMatch(expected: string, provided: string) {
  const expectedHash = crypto.createHash('sha256').update(expected).digest();
  const providedHash = crypto.createHash('sha256').update(provided).digest();
  return crypto.timingSafeEqual(expectedHash, providedHash);
}

function bearerToken(request: NextRequest) {
  const authorization = request.headers.get('authorization') || '';
  return authorization.startsWith('Bearer ') ? authorization.slice(7) : '';
}

async function readLimitedBody(request: NextRequest) {
  const declaredLength = request.headers.get('content-length');
  if (declaredLength) {
    const parsed = Number(declaredLength);
    if (!Number.isSafeInteger(parsed) || parsed < 0 || parsed > MAX_BODY_BYTES) {
      throw new RangeError('BODY_TOO_LARGE');
    }
  }
  if (!request.body) return '';
  const reader = request.body.getReader();
  const decoder = new TextDecoder();
  let total = 0;
  let body = '';
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > MAX_BODY_BYTES) {
      await reader.cancel();
      throw new RangeError('BODY_TOO_LARGE');
    }
    body += decoder.decode(value, { stream: true });
  }
  return body + decoder.decode();
}

export async function GET(request: NextRequest) {
  const user = await getCurrentUser();
  if (!isAdmin(user)) {
    return NextResponse.json(
      { error: user.authenticated ? 'forbidden' : 'authentication_required' },
      { status: user.authenticated ? 403 : 401, headers: { 'Cache-Control': 'no-store' } }
    );
  }
  const rate = checkRateLimit(rateLimitKey(request, ROUTE), 40, 60_000);
  if (!rate.allowed) {
    return NextResponse.json(
      { error: 'Rate limit.' },
      {
        status: 429,
        headers: {
          'Cache-Control': 'no-store',
          'Retry-After': String(rate.resetSeconds),
        },
      }
    );
  }
  try {
    const receipt = await readIbkrQuoteRelayReceipt();
    return NextResponse.json(receipt, {
      headers: {
        'Cache-Control': 'no-store',
        'X-RateLimit-Remaining': String(rate.remaining),
      },
    });
  } catch {
    return NextResponse.json(
      { error: 'Rust IBKR quote receipt is unavailable.' },
      { status: 503, headers: { 'Cache-Control': 'no-store' } }
    );
  }
}

export async function POST(request: NextRequest) {
  const relayToken = process.env.IBKR_QUOTE_RELAY_TOKEN || '';
  const researchToken = process.env.INTRADAY_QUANT_TOKEN || '';
  if (relayToken.length < 32 || researchToken.length < 32) {
    return NextResponse.json(
      { error: 'IBKR quote relay is disabled.' },
      { status: 503, headers: { 'Cache-Control': 'no-store' } }
    );
  }
  const provided = bearerToken(request);
  if (!provided || !constantTimeMatch(relayToken, provided)) {
    return NextResponse.json(
      { error: 'Invalid IBKR quote relay token.' },
      { status: 401, headers: { 'Cache-Control': 'no-store' } }
    );
  }
  const contentType = request.headers.get('content-type')?.toLowerCase() || '';
  if (!contentType.startsWith('application/json')) {
    return NextResponse.json(
      { error: 'IBKR quote batches must use application/json.' },
      { status: 415, headers: { 'Cache-Control': 'no-store' } }
    );
  }
  let body: string;
  try {
    body = await readLimitedBody(request);
  } catch (error) {
    if (!(error instanceof RangeError) || error.message !== 'BODY_TOO_LARGE') throw error;
    return NextResponse.json(
      { error: 'IBKR quote batch exceeds 64 KiB.' },
      { status: 413, headers: { 'Cache-Control': 'no-store' } }
    );
  }
  try {
    const response = await fetch(`${BACKEND}/api/v1/live/ibkr/quotes`, {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        'X-Research-Token': researchToken,
      },
      body,
      cache: 'no-store',
      signal: AbortSignal.timeout(10_000),
    });
    return new NextResponse(await response.text(), {
      status: response.status,
      headers: {
        'Content-Type': response.headers.get('content-type') || 'application/json; charset=utf-8',
        'Cache-Control': 'no-store',
      },
    });
  } catch (error) {
    return NextResponse.json(
      {
        error: 'Rust IBKR quote ingress is unavailable.',
        detail: error instanceof Error ? error.message : String(error),
      },
      { status: 503, headers: { 'Cache-Control': 'no-store' } }
    );
  }
}
