// Thin HTTP client to AXIO7 API. No data caching, no auth state.
// AXIO7_API_BASE_URL defaults to https://axio7.com (prod). Override with
// http://localhost:3000 during dev.
//
// AXIO7_API_TOKEN is optional — only required for endpoints that gate by user
// (none of the read-only tools here require it today, but kept for future
// per-user routes like watchlists or audit log).

const BASE_URL = (process.env.AXIO7_API_BASE_URL || 'https://axio7.com').replace(/\/$/, '');
const TOKEN = process.env.AXIO7_API_TOKEN || '';
const TIMEOUT_MS = Number(process.env.AXIO7_API_TIMEOUT_MS || 25_000);
const USER_AGENT = process.env.AXIO7_API_USER_AGENT || 'axio7-market-mcp/0.1.0';

export type HttpMethod = 'GET' | 'POST' | 'DELETE';

export type FetchResult<T> =
  | { ok: true; status: number; data: T }
  | { ok: false; status: number; error: string };

export async function axio7Fetch<T>(
  method: HttpMethod,
  path: string,
  options: {
    query?: Record<string, string | number | undefined>;
    body?: unknown;
  } = {}
): Promise<FetchResult<T>> {
  const url = new URL(path.startsWith('/') ? path : `/${path}`, BASE_URL);
  for (const [k, v] of Object.entries(options.query || {})) {
    if (v !== undefined && v !== null && v !== '') {
      url.searchParams.set(k, String(v));
    }
  }

  const headers: Record<string, string> = {
    Accept: 'application/json',
    'User-Agent': USER_AGENT,
  };
  if (TOKEN) headers['Authorization'] = `Bearer ${TOKEN}`;
  if (options.body !== undefined) headers['Content-Type'] = 'application/json';

  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const res = await fetch(url.toString(), {
      method,
      headers,
      body: options.body !== undefined ? JSON.stringify(options.body) : undefined,
      signal: controller.signal,
    });
    const text = await res.text();
    let parsed: unknown = text;
    try {
      parsed = text ? JSON.parse(text) : null;
    } catch {
      // leave as text
    }
    if (!res.ok) {
      const message =
        typeof parsed === 'object' && parsed !== null && 'error' in parsed
          ? String((parsed as { error: unknown }).error)
          : text || `HTTP ${res.status}`;
      return { ok: false, status: res.status, error: message };
    }
    return { ok: true, status: res.status, data: parsed as T };
  } catch (err) {
    return {
      ok: false,
      status: 0,
      error: err instanceof Error ? err.message : 'unknown fetch error',
    };
  } finally {
    clearTimeout(t);
  }
}

export function getBaseUrl(): string {
  return BASE_URL;
}
