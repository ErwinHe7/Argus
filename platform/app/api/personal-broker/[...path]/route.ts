import { NextRequest, NextResponse } from 'next/server';
import { allowedPath, authorizeLocalRequest, getPersonalConfig, issueSession, SESSION_COOKIE, validatePersonalBody, verifySession } from '@/lib/personal-broker/boundary';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
const safeHeaders = { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff', 'Cross-Origin-Resource-Policy': 'same-origin' };
const reply = (status: number, body: unknown) => NextResponse.json(body, { status, headers: safeHeaders });

async function boundedBody(request: NextRequest) {
  if (!/^application\/json(?:;\s*charset=utf-8)?$/i.test(request.headers.get('content-type') ?? '') ||
      Number(request.headers.get('content-length') ?? 0) > 4096 || !request.body) throw new Error('invalid_body');
  const reader = request.body.getReader();
  let bytes = 0; const chunks: Uint8Array[] = [];
  try { for (;;) { const { done, value } = await reader.read(); if (done) break;
    bytes += value.byteLength; if (bytes > 4096) { await reader.cancel(); throw new Error('body_too_large'); } chunks.push(value);
  } } finally { reader.releaseLock(); }
  return JSON.parse(Buffer.concat(chunks).toString('utf8')) as unknown;
}

async function handle(request: NextRequest, context: { params: { path: string[] } }) {
  const config = getPersonalConfig();
  if (!config.enabled) return reply(404, { error: 'personal_mode_disabled', message: 'Use the local personal trading launcher.' });
  if (!authorizeLocalRequest(request.headers, request.method, config)) return reply(403, { error: 'local_access_required', message: 'Open this workspace directly at its local address.' });
  const path = allowedPath(request.method, context.params.path);
  if (!path || request.nextUrl.search) return reply(400, { error: 'invalid_request', message: 'Unsupported broker request.' });
  let body: Record<string, unknown> | null = null;
  if (request.method === 'POST') {
    try { body = validatePersonalBody(path, await boundedBody(request)); } catch { /* Never log a body, password, or upstream error. */ }
    if (!body) return reply(400, { error: 'invalid_request', message: 'Check the request fields and try again.' });
  }
  const existingCookie = request.cookies.get(SESSION_COOKIE)?.value;
  let session = verifySession(existingCookie, config.secret);
  if (path === '/session') {
    const response = reply(200, { ready: true });
    if (!session) response.cookies.set(SESSION_COOKIE, issueSession(config.secret), { httpOnly: true, sameSite: 'strict', path: '/api/personal-broker', maxAge: 28800 });
    return response;
  }
  if (!session) return reply(401, { error: 'session_required', message: 'Refresh the page to start a local session.' });
  try {
    const upstream = await fetch(`http://127.0.0.1:8766${path}`, {
      method: request.method, cache: 'no-store', redirect: 'error', signal: AbortSignal.timeout(25_000),
      headers: { 'Authorization': `Bearer ${config.secret}`, 'X-Leo-Session': session, 'Content-Type': 'application/json' },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    if (!upstream.body) throw new Error('no_body');
    const reader = upstream.body.getReader(); const chunks: Uint8Array[] = []; let size = 0;
    try { for (;;) { const {done,value} = await reader.read(); if (done) break; size += value.byteLength;
      if (size > 1_000_000) { await reader.cancel(); throw new Error('oversized_response'); } chunks.push(value);
    } } finally { reader.releaseLock(); }
    const result = JSON.parse(Buffer.concat(chunks).toString('utf8')) as unknown;
    if (!result || typeof result !== 'object' || Array.isArray(result)) throw new Error('invalid_response');
    return reply(upstream.status, result);
  } catch {
    return reply(503, { error: 'gateway_unavailable', message: path === '/confirm'
      ? 'The submission result is unavailable. Use Check order status; do not create another order.'
      : 'The local moomoo bridge is unavailable. Start the personal trading launcher, then try again.' });
  }
}
export { handle as GET, handle as POST };
