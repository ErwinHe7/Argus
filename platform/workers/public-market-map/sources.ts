import { z } from 'zod';
import { parquetMetadata, parquetReadObjects } from 'hyparquet';
import type { PublicMarketMapReceipt } from '../../lib/market-map/types';
import { hfPublicationAt, hfRefreshDeadline, US_CALENDAR_END, US_CALENDAR_SOURCE, US_CALENDAR_START, US_CALENDAR_VERIFIED_AT, usSessions, type UsSession } from './us-calendar';

export const SYMBOLS = ['AAPL', 'SPY'] as const;
export const HORIZONS = { '5d': 5, '10d': 10, '20d': 20, '60d': 60 } as const;
export const SNAPSHOT_KEY = 'snapshots:us:v1';
const HISTORY_SESSIONS = 126;
const ALLOWED_ORIGIN = 'https://api.hfdatalibrary.com';
export const sourceDocumentSchema = z.object({
  url: z.string().url(), retrieved_at: z.string().datetime(), sha256: z.string().regex(/^[a-f0-9]{64}$/),
  expires_at: z.string().datetime(), encoding: z.literal('base64-parquet'), record_count: z.number().int().min(1).max(15000), payload: z.string(),
}).strict();
export type SourceDocument = z.infer<typeof sourceDocumentSchema>;
export type PublicSourceReader = (url: string, cacheSeconds: number) => Promise<SourceDocument>;
type DailyBar = { observed_at: string; open: number; high: number; low: number; close: number; volume: number; session: 'regular' };

export class PublicSourceError extends Error {
  constructor(readonly code: string) { super(code); }
}
function requireCondition(condition: unknown, code: string): asserts condition {
  if (!condition) throw new PublicSourceError(code);
}
export async function digest(value: string | Uint8Array): Promise<string> {
  const bytes = await crypto.subtle.digest('SHA-256', typeof value === 'string' ? new TextEncoder().encode(value) : new Uint8Array(value));
  return [...new Uint8Array(bytes)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}
async function readBoundedBytes(response: Response, maximumBytes: number): Promise<Uint8Array<ArrayBuffer>> {
  requireCondition(response.body, 'source_empty_body');
  const reader = response.body.getReader(), chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const chunk = await reader.read();
      if (chunk.done) break;
      total += chunk.value.byteLength;
      if (total > maximumBytes) { await reader.cancel(); throw new PublicSourceError('source_body_too_large'); }
      chunks.push(chunk.value);
    }
  } finally { reader.releaseLock(); }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  return bytes;
}
export async function readBoundedJson(response: Response, maximumBytes = 128 * 1024): Promise<unknown> {
  const body = await readBoundedBytes(response, maximumBytes);
  try { return JSON.parse(new TextDecoder('utf-8', { fatal: true, ignoreBOM: false }).decode(body)); } catch { throw new PublicSourceError('source_json_invalid'); }
}
export const sourceUrl = (symbol: typeof SYMBOLS[number]) => `${ALLOWED_ORIGIN}/v1/download-token/${symbol}?timeframe=daily&format=parquet&version=clean`;

async function safeFetch(url: URL, headers?: Record<string, string>): Promise<Response> {
  requireCondition(url.origin === ALLOWED_ORIGIN && !url.username && !url.password && !url.hash, 'source_origin_rejected');
  let response: Response;
  try { response = await fetch(url.href, { headers, redirect: 'manual', signal: AbortSignal.timeout(25000) }); }
  catch {
    // Fetch messages and response bodies may contain bearer credentials.
    console.error(JSON.stringify({ event: 'public_source_fetch_error', origin: url.origin, path: url.pathname }));
    throw new PublicSourceError('hf_request_failed');
  }
  requireCondition(response.status < 300 || response.status >= 400, 'hf_redirect_rejected');
  requireCondition(response.ok, `hf_http_${response.status}`);
  return response;
}
export async function fetchSourceDocument(url: string, cacheSeconds: number, apiKey?: string): Promise<SourceDocument> {
  requireCondition(typeof apiKey === 'string' && apiKey.trim().length > 0, 'hf_api_key_missing');
  requireCondition(SYMBOLS.some((symbol) => sourceUrl(symbol) === url), 'source_url_rejected');
  const response = await safeFetch(new URL(url), { Accept: 'application/json', 'X-API-Key': apiKey });
  const token = z.object({ url: z.string().url(), expires_at: z.string().datetime({ offset: true }), version: z.literal('clean'), timeframe: z.literal('daily'), format: z.literal('parquet') }).passthrough().safeParse(await readBoundedJson(response));
  requireCondition(token.success && Date.parse(token.data.expires_at) > Date.now(), 'hf_download_token_invalid');
  const signed = new URL(token.data.url), symbol = new URL(url).pathname.split('/').at(-1)!;
  requireCondition(signed.origin === ALLOWED_ORIGIN && signed.pathname === `/v1/download/${symbol}` && !!signed.searchParams.get('token'), 'hf_download_url_rejected');
  const bytes = await readBoundedBytes(await safeFetch(signed), 8 * 1024 * 1024);
  let record_count: number;
  try { record_count = Number(parquetMetadata(bytes.buffer).num_rows); } catch { throw new PublicSourceError('hf_parquet_invalid'); }
  requireCondition(Number.isSafeInteger(record_count) && record_count > 0 && record_count <= 15000, 'hf_parquet_row_limit');
  let binary = '';
  for (let index = 0; index < bytes.length; index += 8192) binary += String.fromCharCode(...bytes.subarray(index, index + 8192));
  const payload = btoa(binary);
  const retrieved = new Date();
  // Persist stable endpoint + original binary bytes; never the signed token URL.
  return { url, retrieved_at: retrieved.toISOString(), sha256: await digest(bytes), expires_at: new Date(retrieved.getTime() + cacheSeconds * 1000).toISOString(), encoding: 'base64-parquet', record_count, payload };
}

function dailyDate(raw: unknown): string {
  const value = raw instanceof Date ? raw.toISOString().replace(/Z$/, '') : String(raw);
  const iso = /^(\d{4}-\d{2}-\d{2})(?:[ T]00:00:00(?:\.0+)?)?$/.exec(value);
  const american = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(value);
  const date = iso?.[1] ?? (american ? `${american[3]}-${american[1]}-${american[2]}` : '');
  requireCondition(date && Number.isFinite(Date.parse(`${date}T00:00:00Z`)) && new Date(`${date}T00:00:00Z`).toISOString().slice(0, 10) === date, 'hf_daily_date_invalid');
  return date;
}
function numeric(raw: unknown): number {
  const value = String(raw);
  requireCondition(/^[+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$/.test(value), 'hf_numeric_field_invalid');
  const number = Number(value); requireCondition(Number.isFinite(number), 'hf_numeric_field_invalid'); return number;
}
export async function parseDailyBars(document: SourceDocument, now: Date, sessions: UsSession[]): Promise<DailyBar[]> {
  let rows: Record<string, unknown>[];
  try {
    const bytes = Uint8Array.from(atob(document.payload), (char) => char.charCodeAt(0));
    requireCondition(await digest(bytes) === document.sha256, 'hf_parquet_hash_mismatch');
    rows = await parquetReadObjects({ file: bytes.buffer });
  } catch (error) { if (error instanceof PublicSourceError) throw error; throw new PublicSourceError('hf_parquet_invalid'); }
  requireCondition(rows.length === document.record_count && rows.length > 0 && rows.length <= 15000, 'hf_parquet_row_limit');
  return parseDailyRows(rows, now, sessions);
}

/** Pure deserialization/field mapping; no indicators or OHLC aggregation. */
export function parseDailyRows(rows: Record<string, unknown>[], now: Date, sessions: UsSession[]): DailyBar[] {
  const header = Object.keys(rows[0] ?? {}).map((value) => value.toLowerCase());
  requireCondition(new Set(header).size === header.length && (header.includes('datetime') || header.includes('date')) && ['open', 'high', 'low', 'close', 'volume', 'source'].every((key) => header.includes(key)), 'hf_daily_fields_changed');
  const schedule = new Map(sessions.map((session) => [session.date, session]));
  const bars: DailyBar[] = [], seen = new Set<string>();
  for (const original of rows) {
    const row = Object.fromEntries(Object.entries(original).map(([key, value]) => [key.toLowerCase(), value]));
    const date = dailyDate(row.datetime ?? row.date);
    if (date < US_CALENDAR_START) continue;
    const session = schedule.get(date);
    requireCondition(session, 'hf_non_exchange_session');
    requireCondition(!seen.has(date), 'hf_duplicate_sessions'); seen.add(date);
    if (Date.parse(session.close) > now.getTime() || hfPublicationAt(date) > now.getTime()) continue;
    requireCondition(row.source === 'iex', 'hf_iex_source_unverified');
    const get = (key: string) => numeric(row[key]);
    const bar: DailyBar = { observed_at: session.close, open: get('open'), high: get('high'), low: get('low'), close: get('close'), volume: get('volume'), session: 'regular' };
    requireCondition(bar.volume > 0 && Number.isSafeInteger(bar.volume) && bar.low > 0 && bar.low <= bar.open && bar.open <= bar.high && bar.low <= bar.close && bar.close <= bar.high, 'hf_ohlcv_geometry_invalid');
    bars.push(bar);
  }
  return bars.sort((a, b) => Date.parse(a.observed_at) - Date.parse(b.observed_at));
}

export async function preparePublicInputs(read: PublicSourceReader, now = new Date()) {
  const end = new Date(now.getTime() + 120 * 86400000).toISOString().slice(0, 10);
  requireCondition(end <= US_CALENDAR_END, 'us_calendar_out_of_range');
  const sessions = usSessions(US_CALENDAR_START, end);
  const due = sessions.filter((session) => hfPublicationAt(session.date) <= now.getTime());
  requireCondition(due.length >= HISTORY_SESSIONS, 'us_history_calendar_incomplete');
  const documents = await Promise.all(SYMBOLS.map((symbol) => read(sourceUrl(symbol), 900)));
  const histories = await Promise.all(documents.map(async (document) => (await parseDailyBars(document, now, sessions)).slice(-HISTORY_SESSIONS)));
  const cutoff = histories[0].at(-1)?.observed_at;
  requireCondition(cutoff && histories.every((bars) => bars.length === HISTORY_SESSIONS && bars.every((bar, index) => bar.observed_at === histories[0][index].observed_at)), 'hf_history_or_benchmark_incomplete');
  const cutoffIndex = sessions.findIndex((session) => session.close === cutoff);
  const expected = sessions.slice(cutoffIndex - HISTORY_SESSIONS + 1, cutoffIndex + 1);
  requireCondition(expected.length === HISTORY_SESSIONS && expected.every((session, index) => session.close === histories[0][index].observed_at), 'hf_history_sessions_missing');
  // Redownloading old data cannot move its deadline. The prior session may
  // survive the morning publication window, but not the next refresh deadline.
  const next = sessions[cutoffIndex + 1];
  requireCondition(next, 'us_future_calendar_incomplete');
  const expires = Math.min(hfRefreshDeadline(next.date), Date.parse(cutoff) + 604800000);
  requireCondition(expires > now.getTime(), 'hf_latest_session_missing');
  const future = sessions.slice(cutoffIndex + 1);
  requireCondition(future.length >= 60, 'us_future_calendar_incomplete');
  const generated_at = new Date(Math.max(now.getTime(), ...documents.map((document) => Date.parse(document.retrieved_at)))).toISOString();
  const sources = SYMBOLS.map((symbol, index) => ({ id: `hf-iex-${symbol.toLowerCase()}`, provider: 'HF Data Library / IEX Exchange HIST', dataset: `Clean daily ${symbol}; USD OHLC; adjustment unverified; IEX-only share volume, not SIP; XNYS regular session`, observed_at: cutoff, available_at: documents[index].retrieved_at, retrieved_at: documents[index].retrieved_at, delay_minutes: Math.ceil((Date.parse(documents[index].retrieved_at) - Date.parse(cutoff)) / 60000) }));
  const receipts: PublicMarketMapReceipt[] = documents.map((document) => ({ url: document.url, retrieved_at: document.retrieved_at, sha256: document.sha256, record_count: document.record_count }));
  receipts.push({ url: US_CALENDAR_SOURCE, retrieved_at: US_CALENDAR_VERIFIED_AT, sha256: await digest(JSON.stringify(sessions)), record_count: sessions.length });
  const inputs = SYMBOLS.flatMap((symbol, index) => Object.entries(HORIZONS).map(([horizon, count]) => {
    const benchmark = SYMBOLS[1 - index];
    return {
      mode: 'public_market', calendar: 'exchange', price_adjustment: 'source_adjusted_unverified',
      asset: { asset_id: index === 0 ? 'aa910000-0000-4000-8000-000000000001' : '59100000-0000-4000-8000-000000000001', symbol, name: index === 0 ? 'Apple Inc.' : 'SPDR S&P 500 ETF Trust', asset_type: index === 0 ? 'equity' : 'etf', exchange: index === 0 ? 'NASDAQ' : 'NYSE Arca', currency: 'USD', market_timezone: 'America/New_York' },
      horizon, bars: histories[index], sources, ohlcv_source_id: `hf-iex-${symbol.toLowerCase()}`,
      benchmark: { source_id: `hf-iex-${benchmark.toLowerCase()}`, benchmark_symbol: benchmark, name: benchmark === 'SPY' ? 'S&P 500 ETF comparison (IEX observations)' : 'Apple comparison (IEX observations)', series: histories[1 - index].map((bar) => ({ observed_at: bar.observed_at, value: bar.close })) },
      rights: { access: 'public_market_data', terms_url: 'https://www.iex.io/legal/hist-data-terms', usage_note: 'Elkassabgi, A. (2026). HF Data Library. https://doi.org/10.5281/zenodo.19501605; compilation CC BY 4.0. Data provided for free by IEX. By accessing or using IEX Historical Data, you agree to the IEX Historical Data Terms of Use. IEX-only observations are not the consolidated tape or NBBO. The website declares adjusted prices, but the incremental source code implements limited split handling and dividend adjustments are not verified. Corporate-action completeness is not established. Trade-break messages are not consumed upstream. No options IV or trade-volume profile. Current data vintage, not point-in-time backtest history.' },
      generated_at, expected_sessions: HISTORY_SESSIONS, max_age_seconds: Math.floor((expires - Date.parse(cutoff)) / 1000),
      projected_sessions: future.slice(0, count).map((session) => session.close), seed: `HF:IEX:${symbol}:${cutoff}:historical-bootstrap-v1`,
    };
  }));
  return { inputs, receipts, documents, generated_at, expires_at: new Date(expires).toISOString() };
}
