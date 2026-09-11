import 'server-only';

import { getCloudflareContext } from '@opennextjs/cloudflare';
import { validatePublicMarketMapSnapshot } from './validate';
import type { PublicMarketMapSnapshot } from './types';
import { DEFAULT_PUBLIC_MARKET_SYMBOL, isPublicMarketSymbol, isPublicUsMarketAsset } from './public-catalog';

const MAX_RESPONSE_BYTES = 4_000_000;

async function fetchPublicFeed(path: string): Promise<Response> {
  if (process.env.NODE_ENV === 'development') {
    const origin = process.env.PUBLIC_MARKET_MAP_DEV_ORIGIN || 'https://leo-market-map.axio7.workers.dev';
    return fetch(`${origin}${path}`, { cache: 'no-store', signal: AbortSignal.timeout(15_000) });
  }
  const { env } = getCloudflareContext();
  return env.PUBLIC_MARKET_MAP.fetch(`https://public-market-map.internal${path}`, { signal: AbortSignal.timeout(15_000) });
}

export async function getPublicMarketMapStatus(): Promise<{ available: boolean; expires_at?: string; symbols?: string[] }> {
  try {
    const response = await fetchPublicFeed('/status');
    if (!response.ok) return { available: false };
    const status = await response.json() as Record<string, unknown>;
    if (status.available !== true || status.mode !== 'public_market' || status.market !== 'US' ||
        !Array.isArray(status.symbols) || !status.symbols.includes(DEFAULT_PUBLIC_MARKET_SYMBOL) ||
        typeof status.expires_at !== 'string' || !(Date.parse(status.expires_at) > Date.now())) return { available: false };
    return { available: true, expires_at: status.expires_at, symbols: status.symbols.filter((symbol): symbol is string => typeof symbol === 'string' && isPublicMarketSymbol(symbol)) };
  } catch { return { available: false }; }
}

/** Public U.S. observations use their own feed; member-vendor gates stay separate. */
export async function getPublicMarketMapSnapshots(symbol = DEFAULT_PUBLIC_MARKET_SYMBOL): Promise<PublicMarketMapSnapshot[]> {
  if (!isPublicMarketSymbol(symbol)) return [];
  const path = `/snapshots?symbol=${symbol}`;
  const response = await fetchPublicFeed(path);
  if (!response.ok || !response.body) return [];
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let length = 0;
  try {
    for (;;) {
      const { value, done } = await reader.read();
      if (done) break;
      length += value.byteLength;
      if (length > MAX_RESPONSE_BYTES) { await reader.cancel(); return []; }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  let payload: unknown;
  try { payload = JSON.parse(new TextDecoder().decode(bytes)); } catch { return []; }
  if (!payload || typeof payload !== 'object' || !('mode' in payload) || payload.mode !== 'public_market' ||
      !('snapshots' in payload) || !Array.isArray(payload.snapshots) || payload.snapshots.length !== 4) return [];
  const snapshots = payload.snapshots.map((raw: unknown) => validatePublicMarketMapSnapshot(raw));
  if (snapshots.some((snapshot) => !snapshot || snapshot.asset.symbol !== symbol || !isPublicUsMarketAsset(snapshot.asset))) return [];
  const valid = snapshots.filter((snapshot): snapshot is PublicMarketMapSnapshot => snapshot !== null);
  if (new Set(valid.map((snapshot) => snapshot.horizon)).size !== 4 ||
      new Set(valid.map((snapshot) => snapshot.provenance.observation_cutoff)).size !== 1) return [];
  return valid;
}
