import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parquetMetadata, parquetReadObjects } from 'hyparquet';
import { digest, fetchSourceDocument, parseDailyBars, parseDailyRows, preparePublicInputs, sourceUrl, type SourceDocument } from '../workers/public-market-map/sources';
import { hfPublicationAt, hfRefreshDeadline, usSessions } from '../workers/public-market-map/us-calendar';
import { validateUsBundle } from '../workers/public-market-map/bundle';
import { computePublicSnapshot } from '../workers/public-market-map/wasm';
import { isPublicUsMarketAsset } from '../lib/market-map/public-catalog';

// Deliberately synthetic parser fixture. It is never written to snapshot
// artifacts/KV and is not a substitute for the still-required HF credentials.
const fixture = Buffer.from(JSON.parse(readFileSync(new URL('./fixtures/hf-daily-snappy-test.json', import.meta.url), 'utf8')).payload, 'base64');
const bytes = () => new Uint8Array(fixture).buffer;
const clock = new Date('2026-09-04T14:00:00.000Z');
const sessions = usSessions('2026-01-01', '2026-12-31');
async function document(url = sourceUrl('AAPL')): Promise<SourceDocument> {
  return { url, retrieved_at: '2026-09-04T13:55:00.000Z', expires_at: '2026-09-04T14:10:00.000Z', sha256: await digest(fixture), encoding: 'base64-parquet', record_count: 131, payload: fixture.toString('base64') };
}

test('published XNYS calendar preserves DST, holidays, early closes and its bounded validity', () => {
  assert.equal(usSessions('2026-03-06', '2026-03-06')[0].close, '2026-03-06T21:00:00.000Z');
  assert.equal(usSessions('2026-03-09', '2026-03-09')[0].close, '2026-03-09T20:00:00.000Z');
  assert.equal(usSessions('2026-11-27', '2026-11-27')[0].close, '2026-11-27T18:00:00.000Z');
  assert.equal(usSessions('2026-12-24', '2026-12-24')[0].close, '2026-12-24T18:00:00.000Z');
  assert.equal(usSessions('2026-09-07', '2026-09-07').length, 0);
  assert.equal(usSessions('2028-01-03', '2028-01-03').length, 1);
  assert.throws(() => usSessions('2029-01-01', '2029-02-01'), /us_calendar_out_of_range/);
  assert.equal(new Date(hfPublicationAt('2026-09-03')).toISOString(), '2026-09-04T08:00:00.000Z');
  assert.equal(new Date(hfRefreshDeadline('2026-09-03')).toISOString(), '2026-09-04T14:30:00.000Z');
});

test('real Snappy decoding preserves daily timestamps and INT64 volume; unfinished sessions are excluded', async () => {
  const metadata = parquetMetadata(bytes());
  assert.ok(metadata.row_groups.every((group) => group.columns.every((column) => column.meta_data?.codec === 'SNAPPY')));
  const decoded = await parquetReadObjects({ file: bytes() });
  assert.ok(decoded[0].datetime instanceof Date);
  assert.equal(typeof decoded[0].Volume, 'bigint');
  const bars = await parseDailyBars(await document(), clock, sessions);
  assert.equal(bars.length, 130);
  assert.equal(bars.at(-1)?.observed_at, '2026-09-03T20:00:00.000Z');
  assert.equal(bars[0].volume, 100000);
  assert.ok(bars.every((bar) => bar.session === 'regular'));
  const corrupt = await document(); corrupt.sha256 = '0'.repeat(64);
  await assert.rejects(parseDailyBars(corrupt, clock, sessions), /hf_parquet_hash_mismatch/);
});

test('duplicate dates, wrong source, impossible OHLC and intraday timestamps are rejected', () => {
  const row = { datetime: '2026-09-03', Open: 10, High: 12, Low: 9, Close: 11, Volume: 100, source: 'iex' };
  assert.throws(() => parseDailyRows([row, row], clock, sessions), /hf_duplicate_sessions/);
  assert.throws(() => parseDailyRows([{ ...row, source: 'pitrading' }], clock, sessions), /hf_iex_source_unverified/);
  assert.throws(() => parseDailyRows([{ ...row, High: 8 }], clock, sessions), /hf_ohlcv_geometry_invalid/);
  assert.throws(() => parseDailyRows([{ ...row, datetime: '2026-09-03 09:30:00' }], clock, sessions), /hf_daily_date_invalid/);
});

test('two-step HF transport persists neither API key nor signed token and rejects redirects', async () => {
  const originalFetch = globalThis.fetch;
  const calls: { url: string; options?: RequestInit }[] = [];
  const secret = 'test-only-secret', token = 'test-only-signed-token';
  globalThis.fetch = (async (url: string | URL | Request, options?: RequestInit) => {
    calls.push({ url: String(url), options });
    return calls.length === 1 ? Response.json({ url: `https://api.hfdatalibrary.com/v1/download/AAPL?token=${token}`, expires_at: new Date(Date.now() + 600000).toISOString(), version: 'clean', timeframe: 'daily', format: 'parquet' }) : new Response(bytes());
  }) as typeof fetch;
  try {
    const result = await fetchSourceDocument(sourceUrl('AAPL'), 900, secret);
    assert.equal(new Headers(calls[0].options?.headers).get('X-API-Key'), secret);
    assert.equal(calls[1].options?.headers, undefined);
    assert.equal(calls[0].options?.redirect, 'manual');
    assert.equal(result.sha256, await digest(fixture));
    assert.ok(!JSON.stringify(result).includes(secret) && !JSON.stringify(result).includes(token));
    globalThis.fetch = (async () => new Response('', { status: 302, headers: { Location: 'https://other.example/' } })) as typeof fetch;
    await assert.rejects(fetchSourceDocument(sourceUrl('AAPL'), 900, secret), /hf_redirect_rejected/);
    await assert.rejects(fetchSourceDocument(sourceUrl('AAPL'), 900), /hf_api_key_missing/);
  } finally { globalThis.fetch = originalFetch; }
});

test('HF-shaped test inputs pass the actual Rust WASM and US gate; old markets and incomplete bundles fail closed', async () => {
  const prepared = await preparePublicInputs(async (url) => document(url), clock);
  const wasm = await WebAssembly.compile(readFileSync(new URL('../workers/public-market-map/market-map.wasm', import.meta.url)));
  const snapshots = prepared.inputs.map((input) => computePublicSnapshot(wasm, input, clock));
  const bundle = { mode: 'public_market', generated_at: prepared.generated_at, expires_at: prepared.expires_at, snapshots, receipts: prepared.receipts };
  const validated = validateUsBundle(bundle, new Date('2026-09-04T14:01:00.000Z'));
  assert.ok(validated);
  assert.equal(validated.snapshots.length, 8);
  assert.ok(validated.snapshots.every((snapshot) => snapshot.panels.implied_volatility === null && !snapshot.provenance.coverage.corporate_actions_adjusted && snapshot.price_adjustment === 'source_adjusted_unverified'));
  assert.equal(validateUsBundle({ ...bundle, snapshots: snapshots.slice(0, 7) }, clock), null);
  assert.equal(validateUsBundle(bundle, new Date(bundle.expires_at)), null);
  const wrongMarket = structuredClone(bundle); wrongMarket.snapshots[0].asset.currency = 'TWD';
  assert.equal(validateUsBundle(wrongMarket, clock), null);
  const wrongSource = structuredClone(bundle); wrongSource.snapshots[0].provenance.sources[0].provider = 'Taiwan Stock Exchange';
  assert.equal(validateUsBundle(wrongSource, clock), null);
  const leaked = structuredClone(bundle); leaked.receipts[0].url += '&token=never-allowed';
  assert.equal(validateUsBundle(leaked, clock), null);
  await assert.rejects(preparePublicInputs(async (url) => document(url), new Date('2026-09-09T14:31:00.000Z')), /hf_latest_session_missing/);
});

test('asset metadata cannot relabel a Taiwan observation as a US asset', () => {
  assert.ok(isPublicUsMarketAsset({ symbol: 'AAPL', currency: 'USD', market_timezone: 'America/New_York', asset_type: 'equity', exchange: 'NASDAQ' }));
  assert.ok(isPublicUsMarketAsset({ symbol: 'SPY', currency: 'USD', market_timezone: 'America/New_York', asset_type: 'etf', exchange: 'NYSE Arca' }));
  assert.equal(isPublicUsMarketAsset({ symbol: 'AAPL', currency: 'TWD', market_timezone: 'Asia/Taipei', asset_type: 'equity', exchange: 'TWSE' }), false);
  assert.equal(isPublicUsMarketAsset({ symbol: 'SPY', currency: 'USD', market_timezone: 'America/New_York', asset_type: 'equity', exchange: 'NASDAQ' }), false);
});
