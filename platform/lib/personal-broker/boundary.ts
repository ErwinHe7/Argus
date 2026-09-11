import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';

export const SESSION_COOKIE = 'leo_personal_broker';
const SESSION_SECONDS = 8 * 60 * 60;
const ID = /^[A-Za-z0-9_-]{16,64}$/;
export type PersonalConfig = { enabled: boolean; origin: string; secret: string };

export function getPersonalConfig(): PersonalConfig {
  return { enabled: process.env.NODE_ENV === 'development' && process.env.LEO_PERSONAL_TRADING_ENABLED === 'true',
    origin: process.env.LEO_PERSONAL_WEB_ORIGIN ?? '', secret: process.env.LEO_PERSONAL_GATEWAY_TOKEN ?? '' };
}

/** This feature is exclusively for the dedicated loopback development launcher. */
export function authorizeLocalRequest(headers: Headers, method: string, config: PersonalConfig): boolean {
  if (!config.enabled || config.secret.length < 32) return false;
  let origin: URL;
  try { origin = new URL(config.origin); } catch { return false; }
  if (origin.protocol !== 'http:' || origin.hostname !== '127.0.0.1' || origin.origin !== config.origin ||
      origin.username || origin.password || headers.get('host') !== origin.host ||
      headers.has('forwarded')) return false;
  // Next adds this header even for a direct loopback request.
  const forwardedHost = headers.get('x-forwarded-host');
  if (forwardedHost && forwardedHost !== origin.host) return false;
  const forwardedFor = headers.get('x-forwarded-for');
  if (forwardedFor && forwardedFor !== '127.0.0.1' && forwardedFor !== '::1') return false;
  if (headers.get('sec-fetch-site') !== 'same-origin') return false;
  const requestOrigin = headers.get('origin');
  if (requestOrigin && requestOrigin !== config.origin) return false;
  return method === 'GET' || requestOrigin === config.origin;
}

function signature(value: string, secret: string) { return createHmac('sha256', secret).update(`leo-personal-v1:${value}`).digest('hex'); }
export function issueSession(secret: string, now = Date.now()): string {
  const value = `${randomBytes(32).toString('hex')}.${Math.floor(now / 1000) + SESSION_SECONDS}`;
  return `${value}.${signature(value, secret)}`;
}
export function verifySession(cookie: string | undefined, secret: string, now = Date.now()): string | null {
  if (!cookie || secret.length < 32 || !/^[a-f0-9]{64}\.\d{10}\.[a-f0-9]{64}$/.test(cookie)) return null;
  const [id, expiry, actual] = cookie.split('.');
  const remaining = Number(expiry) - Math.floor(now / 1000);
  if (remaining <= 0 || remaining > SESSION_SECONDS) return null;
  const expected = signature(`${id}.${expiry}`, secret);
  // One local Windows-owner workspace. Cookie renewal must not orphan the
  // owner's durable journal after a browser or gateway restart.
  return timingSafeEqual(Buffer.from(actual), Buffer.from(expected))
    ? createHmac('sha256', secret).update('leo-personal-owner-v1').digest('hex') : null;
}

export function allowedPath(method: string, segments: string[]): string | null {
  const path = segments.join('/');
  if (method === 'GET' && ['status', 'accounts', 'snapshot'].includes(path)) return `/${path}`;
  if (method === 'POST' && ['connect', 'disconnect', 'unlock', 'previews', 'confirm', 'session'].includes(path)) return `/${path}`;
  if (method === 'GET' && segments.length === 2 && segments[0] === 'commands' && ID.test(segments[1])) return `/${path}`;
  if (method === 'GET' && segments.length === 3 && segments[0] === 'previews' && ID.test(segments[1]) && segments[2] === 'command') return `/${path}`;
  if (method === 'POST' && segments.length === 3 && segments[0] === 'previews' && ID.test(segments[1]) && segments[2] === 'discard') return `/${path}`;
  return null;
}

/** Select exact fields. No quantities, notionals, or brokerage math are computed in TypeScript. */
export function validatePersonalBody(path: string, value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const body = value as Record<string, unknown>;
  const keys = Object.keys(body).sort().join(',');
  if (['/session', '/disconnect'].includes(path) || /^\/previews\/[A-Za-z0-9_-]{16,64}\/discard$/.test(path)) return keys === '' ? {} : null;
  if (path === '/connect' && keys === 'account_id,mode' && typeof body.account_id === 'string' && /^[1-9]\d{0,19}$/.test(body.account_id) && ['SIMULATE', 'REAL'].includes(String(body.mode))) return body;
  if (path === '/unlock' && keys === 'password' && typeof body.password === 'string' && body.password.length > 0 && body.password.length <= 128 && !/[\u0000-\u001f]/.test(body.password)) return body;
  if (path === '/confirm' && keys === 'confirmed,preview_id' && body.confirmed === true && typeof body.preview_id === 'string' && ID.test(body.preview_id)) return body;
  if (path === '/previews' && keys === 'limit_price,quantity,side,symbol' && typeof body.symbol === 'string' && /^[A-Z][A-Z0-9]*(?:\.[A-Z0-9]+)?$/.test(body.symbol) && body.symbol.length <= 14 &&
      ['BUY', 'SELL'].includes(String(body.side)) && typeof body.quantity === 'string' && /^[1-9]\d{0,7}$/.test(body.quantity) &&
      typeof body.limit_price === 'string' && /^(?:0|[1-9]\d{0,7})(?:\.\d{1,2})?$/.test(body.limit_price) && !/^0(?:\.0{1,2})?$/.test(body.limit_price)) return body;
  return null;
}
