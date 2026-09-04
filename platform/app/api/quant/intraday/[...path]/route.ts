import { NextRequest, NextResponse } from 'next/server';
import { getCurrentUser, isAdmin } from '@/lib/auth';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const maxDuration = 300;

const BACKEND = (process.env.INTRADAY_QUANT_API_URL || 'http://127.0.0.1:8001').replace(/\/$/, '');

const GET_ALLOWLIST = new Set([
  'overview',
  'runs',
  'system/status',
  'data/plan',
  'data/coverage',
  'data/capabilities',
  'live/status',
  'live/capabilities',
  'live/bars',
  'predictor/forecast',
  'predictor/owner-preview',
  'predictor/shadow',
  'predictor/settlements',
  'predictor/model',
  'predictor/walk-forward',
  'predictor/calibration',
  'research/opportunities',
  'memory/summary',
  'events/atlas',
  'analogs/current',
  'state/current',
  'research/factory',
  'audit/predictions',
  'context/fusion',
  'allocation/betting',
  'risk/portfolio-analytics',
]);

const POST_ALLOWLIST = new Set(['runs']);
const RUN_PATH = /^runs\/[A-Za-z0-9-]{1,80}$/;
const MAX_CONTROL_BODY_BYTES = 65_536;

function allowedPath(method: 'GET' | 'POST', suffix: string) {
  if (method === 'GET') return GET_ALLOWLIST.has(suffix) || RUN_PATH.test(suffix);
  return POST_ALLOWLIST.has(suffix);
}

function isSameOrigin(request: NextRequest) {
  const origin = request.headers.get('origin');
  if (!origin) return false;
  try {
    return new URL(origin).origin === new URL(request.url).origin;
  } catch {
    return false;
  }
}

function isExplicitQuantAdmin(email: string | null | undefined) {
  if (!email) return false;
  const allowlist = (process.env.QUANT_ADMIN_EMAILS || '')
    .split(',')
    .map((value) => value.trim().toLowerCase())
    .filter(Boolean);
  return allowlist.includes(email.toLowerCase());
}

async function readLimitedBody(request: NextRequest, maximumBytes: number) {
  const declaredLength = request.headers.get('content-length');
  if (declaredLength) {
    const parsedLength = Number(declaredLength);
    if (!Number.isSafeInteger(parsedLength) || parsedLength < 0 || parsedLength > maximumBytes) {
      throw new RangeError('BODY_TOO_LARGE');
    }
  }
  if (!request.body) return '';
  const reader = request.body.getReader();
  const decoder = new TextDecoder();
  let totalBytes = 0;
  let body = '';
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    totalBytes += value.byteLength;
    if (totalBytes > maximumBytes) {
      await reader.cancel();
      throw new RangeError('BODY_TOO_LARGE');
    }
    body += decoder.decode(value, { stream: true });
  }
  return body + decoder.decode();
}

async function proxy(
  request: NextRequest,
  context: { params: { path: string[] } },
  method: 'GET' | 'POST'
) {
  const rawSuffix = context.params.path.join('/');
  if (!allowedPath(method, rawSuffix)) {
    return NextResponse.json(
      { error: 'Quant control-plane route is not exposed by this gateway.' },
      { status: 404, headers: { 'Cache-Control': 'no-store' } }
    );
  }
  const suffix = context.params.path.map(encodeURIComponent).join('/');
  const inbound = new URL(request.url);
  const target = `${BACKEND}/api/v1/${suffix}${inbound.search}`;
  const headers: Record<string, string> = { Accept: 'application/json' };
  const researchToken = process.env.INTRADAY_QUANT_TOKEN;
  const user = await getCurrentUser().catch(() => null);
  const localLicensedForecastRead =
    process.env.NODE_ENV !== 'production' &&
    process.env.AXIO_ENABLE_LOCAL_UNCALIBRATED_LIVE_RESEARCH === '1' &&
    method === 'GET' &&
    rawSuffix === 'predictor/forecast' &&
    user?.authenticated === true;
  const administratorAccess =
    user !== null && isAdmin(user) && isExplicitQuantAdmin(user.email);
  if (
    !user
    || (!administratorAccess && !localLicensedForecastRead)
    || (method === 'POST' && !isSameOrigin(request))
  ) {
    return NextResponse.json(
      { error: 'Authenticated administrator access is required.' },
      { status: 403, headers: { 'Cache-Control': 'no-store' } }
    );
  }
  if (!researchToken || researchToken.length < 32) {
    return NextResponse.json(
      { error: 'Quant control-plane access is disabled until a 32+ character token is configured.' },
      { status: 503, headers: { 'Cache-Control': 'no-store' } }
    );
  }
  headers['X-Research-Token'] = researchToken;
  let body: string | undefined;
  if (method === 'POST') {
    const contentType = request.headers.get('content-type')?.toLowerCase() || '';
    if (!contentType.startsWith('application/json')) {
      return NextResponse.json(
        { error: 'Quant control requests must use application/json.' },
        { status: 415, headers: { 'Cache-Control': 'no-store' } }
      );
    }
    headers['Content-Type'] = 'application/json';
    try {
      body = await readLimitedBody(request, MAX_CONTROL_BODY_BYTES);
    } catch (error) {
      if (!(error instanceof RangeError) || error.message !== 'BODY_TOO_LARGE') throw error;
      return NextResponse.json(
        { error: 'Quant request body exceeds 64 KiB.' },
        { status: 413, headers: { 'Cache-Control': 'no-store' } }
      );
    }
  }
  try {
    const response = await fetch(target, {
      method,
      headers,
      body,
      cache: 'no-store',
      signal: AbortSignal.timeout(method === 'POST' ? 30_000 : 10_000),
    });
    const text = await response.text();
    return new NextResponse(text, {
      status: response.status,
      headers: {
        'Content-Type': response.headers.get('Content-Type') || 'application/json; charset=utf-8',
        'Cache-Control': 'no-store',
      },
    });
  } catch (error) {
    return NextResponse.json(
      {
        error: 'Intraday research backend is unavailable.',
        detail: error instanceof Error ? error.message : String(error),
        expectedBackend: BACKEND,
      },
      { status: 503, headers: { 'Cache-Control': 'no-store' } }
    );
  }
}

export function GET(request: NextRequest, context: { params: { path: string[] } }) {
  return proxy(request, context, 'GET');
}

export function POST(request: NextRequest, context: { params: { path: string[] } }) {
  return proxy(request, context, 'POST');
}
