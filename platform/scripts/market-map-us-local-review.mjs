#!/usr/bin/env node
/**
 * Personal local evaluation only. Never writes production artifacts or KV.
 * Build + serve: node --import tsx scripts/market-map-us-local-review.mjs --serve
 * Serve a still-fresh saved build: add --serve-only instead of --serve.
 * Next dev: PUBLIC_MARKET_MAP_DEV_ORIGIN=http://127.0.0.1:8790
 */
import { createHash } from 'node:crypto';
import { createServer } from 'node:http';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import calendarModule from '../workers/public-market-map/us-calendar.ts';
import wasmModule from '../workers/public-market-map/wasm.ts';
import validatorModule from '../lib/market-map/validate.ts';

const { usSessions } = calendarModule;
const { computePublicSnapshot } = wasmModule;
const { validatePublicMarketMapBundle } = validatorModule;
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const directory = join(root, '.quant-runtime/us-local-review');
const output = join(directory, 'bundle.json');
const SYMBOL = 'AAPL';
const BENCHMARK = 'VTI';
const HORIZONS = { '5d': 5, '10d': 10, '20d': 20, '60d': 60 };
const SESSION_COUNT = 130;
const DAY = 86_400_000;
const TERMS = 'https://eodhd.com/financial-apis/terms-conditions';
const USAGE = 'EODHD demo / personal local evaluation only. Display and redistribution outside this local evaluation are not authorized. OHLC is unadjusted; volume is split-adjusted by the provider. VTI is the named comparison ETF, not SPY or a sector-flow measure. No options IV or trade-level volume profile is provided.';
const requireValue = (condition, code) => { if (!condition) throw new Error(code); };
const sha256 = (text) => createHash('sha256').update(text).digest('hex');
const marketDate = (date) => new Intl.DateTimeFormat('en-CA', { timeZone: 'America/New_York', year: 'numeric', month: '2-digit', day: '2-digit' }).format(date);
const args = process.argv.slice(2);
const portOption = args.find((value) => value.startsWith('--port='));
const port = Number(portOption?.slice(7) ?? '8790');
requireValue(Number.isInteger(port) && port >= 1024 && port <= 65535, 'invalid_loopback_port');
requireValue(args.every((value) => ['--serve', '--serve-only', '--help'].includes(value) || value === portOption), 'unknown_argument');

async function fetchDaily(symbol, from, to) {
  const url = `https://eodhd.com/api/eod/${symbol}.US?api_token=demo&fmt=json&from=${from}&to=${to}&period=d&order=a`;
  const response = await fetch(url, { headers: { Accept: 'application/json' }, redirect: 'error', signal: AbortSignal.timeout(25_000) });
  requireValue(response.ok && response.body, `eodhd_${symbol}_http_${response.status}`);
  const reader = response.body.getReader();
  const chunks = [];
  let length = 0;
  try {
    for (;;) {
      const { value, done } = await reader.read();
      if (done) break;
      length += value.byteLength;
      if (length > 1_000_000) { await reader.cancel(); throw new Error('eodhd_response_too_large'); }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  const text = new TextDecoder('utf-8', { fatal: true }).decode(Buffer.concat(chunks));
  const rows = JSON.parse(text);
  requireValue(Array.isArray(rows) && rows.length >= SESSION_COUNT, `eodhd_${symbol}_history_incomplete`);
  const retrieved_at = new Date().toISOString();
  const document = { provider: 'EODHD demo', usage: USAGE, url, retrieved_at, sha256: sha256(text), rows };
  await writeFile(join(directory, `${symbol}-source.json`), JSON.stringify(document, null, 2));
  return document;
}

async function build() {
  await mkdir(directory, { recursive: true });
  const started = new Date();
  const from = marketDate(new Date(started.getTime() - 240 * DAY));
  const to = marketDate(started);
  const calendar = usSessions(from, marketDate(new Date(started.getTime() + 120 * DAY)));
  const sessionByDate = new Map(calendar.map((session) => [session.date, session]));
  // The documented demo permits AAPL and VTI. SPY returned 403 and is not substituted.
  const documents = await Promise.all([SYMBOL, BENCHMARK].map((symbol) => fetchDaily(symbol, from, to)));
  const generated_at = new Date().toISOString();
  const now = Date.parse(generated_at);
  const histories = documents.map((document) => {
    let previous = '';
    const bars = [];
    for (const row of document.rows) {
      requireValue(row && /^\d{4}-\d{2}-\d{2}$/.test(row.date) && row.date > previous, 'eodhd_unordered_or_invalid_dates');
      previous = row.date;
      const session = sessionByDate.get(row.date);
      requireValue(session, 'eodhd_non_trading_date');
      if (Date.parse(session.close) > now) continue;
      requireValue([row.open, row.high, row.low, row.close].every((value) => typeof value === 'number' && Number.isFinite(value) && value > 0), 'eodhd_invalid_price');
      requireValue(typeof row.volume === 'number' && Number.isFinite(row.volume) && row.volume >= 0 &&
        row.low <= row.open && row.open <= row.high && row.low <= row.close && row.close <= row.high, 'eodhd_invalid_ohlcv');
      bars.push({ observed_at: session.close, open: row.open, high: row.high, low: row.low, close: row.close, volume: row.volume, session: 'exchange_daily' });
    }
    requireValue(bars.length >= SESSION_COUNT, 'eodhd_completed_history_incomplete');
    return bars.slice(-SESSION_COUNT);
  });
  const bars = histories[0];
  const cutoff = bars.at(-1).observed_at;
  const latestRequired = calendar.filter((session) => Date.parse(session.close) + 15 * 60_000 <= now).at(-1);
  requireValue(latestRequired && cutoff === latestRequired.close, 'eodhd_latest_completed_session_missing');
  const expected = calendar.filter((session) => session.close >= bars[0].observed_at && Date.parse(session.close) <= Date.parse(cutoff));
  requireValue(expected.length === SESSION_COUNT && expected.every((session, index) => bars[index].observed_at === session.close), 'eodhd_market_session_gap');
  requireValue(histories[1].length === SESSION_COUNT && histories[1].every((bar, index) => bar.observed_at === bars[index].observed_at), 'eodhd_benchmark_session_mismatch');
  const future = calendar.filter((session) => Date.parse(session.close) > Date.parse(cutoff));
  requireValue(future.length >= 60, 'us_projection_calendar_incomplete');
  const expires = Math.min(Date.parse(future[0].close) + 2 * 60 * 60_000, Date.parse(cutoff) + 7 * DAY);
  requireValue(expires > now, 'local_snapshot_expired');
  const sources = documents.map((document, index) => ({
    id: `eodhd-${index === 0 ? SYMBOL : BENCHMARK}`.toLowerCase(), provider: 'EODHD demo',
    dataset: `${index === 0 ? SYMBOL : BENCHMARK}.US daily OHLCV / personal local evaluation / unadjusted USD OHLC; split-adjusted volume`,
    observed_at: cutoff, available_at: document.retrieved_at, retrieved_at: document.retrieved_at, delay_minutes: 15,
  }));
  const inputs = Object.entries(HORIZONS).map(([horizon, count]) => ({
    mode: 'public_market', calendar: 'exchange', price_adjustment: 'unadjusted',
    asset: { asset_id: 'aab10000-0000-4000-8000-000000000001', symbol: SYMBOL, name: 'Apple Inc.', asset_type: 'equity', exchange: 'NASDAQ', currency: 'USD', market_timezone: 'America/New_York' },
    horizon, bars, sources, ohlcv_source_id: 'eodhd-aapl',
    benchmark: { source_id: 'eodhd-vti', benchmark_symbol: BENCHMARK, name: 'Vanguard Total Stock Market ETF comparison', series: histories[1].map((bar) => ({ observed_at: bar.observed_at, value: bar.close })) },
    rights: { access: 'public_market_data', terms_url: TERMS, usage_note: USAGE },
    generated_at, expected_sessions: SESSION_COUNT, max_age_seconds: Math.floor((expires - Date.parse(cutoff)) / 1000),
    projected_sessions: future.slice(0, count).map((session) => session.close), seed: `EODHD:${SYMBOL}:${cutoff}:personal-local-bootstrap-v1`,
  }));
  await writeFile(join(directory, 'inputs.json'), JSON.stringify(inputs, null, 2));
  const wasm = await WebAssembly.compile(await readFile(join(root, 'workers/public-market-map/market-map.wasm')));
  const snapshots = inputs.map((input) => computePublicSnapshot(wasm, input));
  const bundle = { mode: 'public_market', generated_at, expires_at: new Date(expires).toISOString(), snapshots,
    receipts: documents.map(({ url, retrieved_at, sha256, rows }) => ({ url, retrieved_at, sha256, record_count: rows.length })) };
  requireValue(validatePublicMarketMapBundle(bundle), 'local_bundle_validation_failed');
  await writeFile(output, JSON.stringify(bundle));
  await writeFile(join(directory, 'README.txt'), `${USAGE}\n\nSnapshot protocol mode public_market selects the existing optional-data schema; it does not grant public display rights.\nFiles in this directory must not be copied to public artifacts or KV.\n\nRun: node --import tsx scripts/market-map-us-local-review.mjs --serve\nNext dev environment: PUBLIC_MARKET_MAP_DEV_ORIGIN=http://127.0.0.1:${port}\n`);
  console.log(JSON.stringify({ status: 'LOCAL_READY', symbols: [SYMBOL], benchmark: BENCHMARK, bars: SESSION_COUNT, horizons: Object.keys(HORIZONS), cutoff, last_close: snapshots[0].last_price, expires_at: bundle.expires_at, output, usage: 'EODHD demo / personal local evaluation only' }));
  return bundle;
}

function serve(bundle) {
  const loopbackHosts = new Set([`127.0.0.1:${port}`, `localhost:${port}`]);
  const respond = (response, status, payload) => { response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' }); response.end(JSON.stringify(payload)); };
  const server = createServer((request, response) => {
    if (!loopbackHosts.has(request.headers.host)) return respond(response, 403, { error: 'loopback_host_required' });
    if (request.headers.origin) {
      let origin;
      try { origin = new URL(request.headers.origin); } catch { return respond(response, 403, { error: 'loopback_origin_required' }); }
      if (origin.protocol !== 'http:' || !['localhost', '127.0.0.1', '[::1]'].includes(origin.hostname)) return respond(response, 403, { error: 'loopback_origin_required' });
    }
    if (request.method !== 'GET') return respond(response, 405, { error: 'method_not_allowed' });
    const url = new URL(request.url, `http://127.0.0.1:${port}`);
    if (!['/snapshots', '/status'].includes(url.pathname)) return respond(response, 404, { error: 'not_found' });
    const valid = validatePublicMarketMapBundle(bundle);
    if (url.pathname === '/status') return respond(response, 200, { available: Boolean(valid), mode: 'public_market', market: 'US', symbols: valid ? [SYMBOL] : [], expires_at: bundle.expires_at, scope: 'personal_local_evaluation', provider: 'EODHD demo' });
    if (!valid) return respond(response, 503, { error: 'local_market_data_expired' });
    if ([...url.searchParams.keys()].some((key) => !['symbol', 'horizon'].includes(key)) || ['symbol', 'horizon'].some((key) => url.searchParams.getAll(key).length > 1)) return respond(response, 400, { error: 'invalid_query' });
    const symbol = url.searchParams.get('symbol') ?? SYMBOL;
    const horizon = url.searchParams.get('horizon');
    if (symbol !== SYMBOL || (horizon && !Object.hasOwn(HORIZONS, horizon))) return respond(response, 400, { error: 'unsupported_symbol_or_horizon' });
    respond(response, 200, { ...bundle, snapshots: valid.snapshots.filter((snapshot) => !horizon || snapshot.horizon === horizon) });
  });
  server.listen(port, '127.0.0.1', () => console.log(JSON.stringify({ status: 'LOCAL_SERVING', origin: `http://127.0.0.1:${port}`, symbols: [SYMBOL], scope: 'personal_local_evaluation' })));
  server.on('error', (error) => { console.error(JSON.stringify({ status: 'LOCAL_BLOCKED', code: error.code ?? 'loopback_server_failed' })); process.exitCode = 1; });
  process.once('SIGINT', () => server.close());
  process.once('SIGTERM', () => server.close());
}

try {
  if (args.includes('--help')) console.log('node --import tsx scripts/market-map-us-local-review.mjs [--serve | --serve-only] [--port=8790]\nOnly AAPL is served; VTI supplies the observed benchmark. Personal local evaluation only.');
  else {
    const bundle = args.includes('--serve-only') ? JSON.parse(await readFile(output, 'utf8')) : await build();
    requireValue(validatePublicMarketMapBundle(bundle), 'saved_local_bundle_missing_or_expired');
    if (args.includes('--serve') || args.includes('--serve-only')) serve(bundle);
  }
} catch (error) {
  console.error(JSON.stringify({ status: 'LOCAL_BLOCKED', code: error instanceof Error ? error.message : 'local_evaluation_failed' }));
  process.exitCode = 1;
}
