import module from './market-map.wasm';
import { validateUsBundle } from './bundle';
import type { PublicMarketMapBundle } from '../../lib/market-map/types';
import { computePublicSnapshot } from './wasm';
import { SYMBOLS, HORIZONS, SNAPSHOT_KEY, digest, fetchSourceDocument, preparePublicInputs, PublicSourceError, sourceDocumentSchema } from './sources';

const headers = { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'public, max-age=60' };
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...headers, ...(status !== 200 ? { 'Cache-Control': 'no-store' } : {}) } });
type PublicMarketMapBindings = PublicMarketMapEnv & { HF_DATA_API_KEY?: string };

async function refresh(env: PublicMarketMapBindings): Promise<void> {
  if (!env.HF_DATA_API_KEY?.trim()) throw new PublicSourceError('hf_api_key_missing');
  const prepared = await preparePublicInputs(async (url, ttl) => {
    const key = `source:hf:us:v1:${await digest(url)}`;
    const parsed = sourceDocumentSchema.safeParse(await env.PUBLIC_MAP_STORE.get(key, 'json'));
    if (parsed.success && Date.parse(parsed.data.expires_at) > Date.now()) return parsed.data;
    const document = await fetchSourceDocument(url, ttl, env.HF_DATA_API_KEY);
    await env.PUBLIC_MAP_STORE.put(key, JSON.stringify(document), { expirationTtl: Math.max(60, ttl) });
    await env.PUBLIC_MAP_STORE.put(`raw:hf:us:v1:${document.sha256}`, JSON.stringify(document), { expirationTtl: 120 * 86400 });
    return document;
  });
  const snapshots = prepared.inputs.map((input) => computePublicSnapshot(module, input));
  const bundle: PublicMarketMapBundle = { mode: 'public_market', generated_at: prepared.generated_at, expires_at: prepared.expires_at, snapshots, receipts: prepared.receipts };
  if (!validateUsBundle(bundle)) throw new PublicSourceError('public_bundle_contract_invalid');
  // Only a complete successful bundle replaces the previously validated snapshot.
  await env.PUBLIC_MAP_STORE.put(SNAPSHOT_KEY, JSON.stringify(bundle));
  console.log(JSON.stringify({ event: 'market_map_refreshed', snapshots: snapshots.length, observation_cutoff: snapshots[0].provenance.observation_cutoff, expires_at: bundle.expires_at }));
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method !== 'GET') return json({ error: 'method_not_allowed' }, 405);
    if (url.pathname === '/status') {
      if (url.search) return json({ error: 'invalid_query' }, 400);
      const bundle = env.HF_DATA_API_KEY?.trim() ? validateUsBundle(await env.PUBLIC_MAP_STORE.get(SNAPSHOT_KEY, 'json')) : null;
      return json({ available: !!bundle, mode: 'public_market', market: 'US', symbols: SYMBOLS, ...(bundle ? { expires_at: bundle.expires_at } : {}) });
    }
    if (url.pathname !== '/snapshots') return json({ error: 'not_found' }, 404);
    const symbol = url.searchParams.get('symbol'), horizon = url.searchParams.get('horizon');
    if ([...url.searchParams.keys()].some((key) => !['symbol', 'horizon'].includes(key)) ||
        url.searchParams.getAll('symbol').length > 1 || url.searchParams.getAll('horizon').length > 1 ||
        (symbol !== null && !SYMBOLS.some((value) => value === symbol)) || (horizon !== null && !Object.hasOwn(HORIZONS, horizon))) return json({ error: 'invalid_query' }, 400);
    const bundle = env.HF_DATA_API_KEY?.trim() ? validateUsBundle(await env.PUBLIC_MAP_STORE.get(SNAPSHOT_KEY, 'json')) : null;
    if (!bundle) return json({ error: 'public_market_snapshot_unavailable' }, 503);
    return json({ ...bundle, snapshots: bundle.snapshots.filter((snapshot) => (!symbol || snapshot.asset.symbol === symbol) && (!horizon || snapshot.horizon === horizon)) });
  },
  async scheduled(_controller, env, ctx) {
    ctx.waitUntil(refresh(env).catch((error) => {
      console.error(JSON.stringify({ event: 'market_map_refresh_failed', code: error instanceof PublicSourceError ? error.code : 'public_market_refresh_failed' }));
      throw error;
    }));
  },
} satisfies ExportedHandler<PublicMarketMapBindings>;
