#!/usr/bin/env node
/** Fetch inputs, delegate normalization and quant work, then publish a gated bundle.
 * Usage: node --env-file=.env.local scripts/market-map-refresh.mjs --config PRIVATE.json
 *        node scripts/market-map-refresh.mjs --check
 * Vendor responses and subprocess stderr are never written to the console.
 */
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const artifactDirectory = join(root, 'lib/market-map/artifacts');
const workDirectory = join(root, '.quant-runtime/market-map');
const pythonHelper = join(root, 'intraday_quant/src/intraday_quant/market_map.py');
const horizons = { '5d': 5, '10d': 10, '20d': 20, '60d': 60 };
const requiredSources = ['ohlcv', 'corporate-actions', 'options-iv', 'sector'];
const asJson = (value) => JSON.stringify(value, null, 2) + '\n';
const sha256 = (value) => createHash('sha256').update(value).digest('hex');

export class MarketMapDataError extends Error {
  constructor(code) { super(code); this.code = code; }
}
const fail = (code) => { throw new MarketMapDataError(code); };
const readJson = async (path) => JSON.parse((await readFile(path, 'utf8')).replace(/^\uFEFF/, ''));

export function safeVendorUrl(pathOrUrl) {
  const url = new URL(pathOrUrl, 'https://api.massive.com');
  if (url.protocol !== 'https:' || url.hostname !== 'api.massive.com' ||
      url.port || url.username || url.password || url.hash) fail('provider_url_rejected');
  // Pagination sometimes repeats a provider credential in the URL. Never retain it.
  url.searchParams.delete('apiKey');
  url.searchParams.delete('api_key');
  return url;
}

export async function fetchMassivePages(path, key, fetchImplementation = fetch) {
  const rows = [];
  const visited = new Set();
  let next = path;
  let adjusted = true;
  for (let page = 0; next && page < 32; page++) {
    const url = safeVendorUrl(next);
    if (visited.has(url.href)) fail('provider_pagination_loop');
    visited.add(url.href);
    let response;
    try {
      response = await fetchImplementation(url, {
        headers: { Authorization: `Bearer ${key}`, Accept: 'application/json' },
        signal: AbortSignal.timeout(30000), redirect: 'error',
      });
    } catch { fail('provider_request_failed'); }
    if (!response.ok) fail([401, 403].includes(response.status) ? 'provider_not_entitled' : `provider_http_${response.status}`);
    const body = await response.json().catch(() => fail('provider_response_invalid'));
    if (body.status && !['OK', 'DELAYED'].includes(body.status)) fail('provider_response_invalid');
    const explicitEmpty = body.results === undefined && (body.resultsCount === 0 || body.count === 0);
    if (!Array.isArray(body.results) && !explicitEmpty) fail('provider_response_invalid');
    rows.push(...(body.results ?? []));
    if (rows.length > 400000) fail('provider_response_oversized');
    if ('adjusted' in body && body.adjusted !== true) adjusted = false;
    next = body.next_url ?? null;
  }
  if (next) fail('provider_pagination_incomplete');
  return { rows, adjusted };
}

export function validateIvSessions(iv, sessions) {
  const date = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/New_York', year: 'numeric', month: '2-digit', day: '2-digit' });
  if (!Array.isArray(iv.series) || iv.series.length < 6) fail('same_tenor_atm_iv_history_invalid');
  const recent = iv.series.slice(-6);
  const expected = sessions.slice(-6);
  if (recent.some((point, index) => !Number.isFinite(Date.parse(point.observed_at)) ||
    Date.parse(point.observed_at) > Date.parse(expected[index].close) ||
    date.format(new Date(point.observed_at)) !== expected[index].date)) fail('same_tenor_atm_iv_history_stale');
}

export function selectResearchSessions(calendar, now, historySessions = 126, delayMinutes = 60) {
  if (calendar.schema_version !== 'market-map-calendar.v1' || !calendar.source || !Array.isArray(calendar.sessions)) fail('exchange_calendar_invalid');
  if (!Number.isInteger(historySessions) || historySessions < 60 || historySessions > 252 ||
      !Number.isInteger(delayMinutes) || delayMinutes < 15 || delayMinutes > 240) fail('research_window_invalid');
  const sessions = calendar.sessions;
  if (sessions.some((session, index) =>
    !/^\d{4}-\d{2}-\d{2}$/.test(session.date) ||
    !(Date.parse(session.open) < Date.parse(session.close)) ||
    (index > 0 && Date.parse(session.open) <= Date.parse(sessions[index - 1].close)))) fail('exchange_calendar_invalid');
  const complete = sessions.filter((session) => Date.parse(session.close) + delayMinutes * 60000 <= now.getTime());
  const history = complete.slice(-historySessions);
  if (history.length !== historySessions) fail('exchange_calendar_history_incomplete');
  const future = sessions.filter((session) => Date.parse(session.close) > Date.parse(history.at(-1).close));
  if (future.length < 60) fail('exchange_calendar_projection_incomplete');
  const expiresAt = new Date(Date.parse(future[0].close) + delayMinutes * 60000).toISOString();
  if (Date.parse(expiresAt) <= now.getTime()) fail('exchange_calendar_stale');
  return { history, future, expiresAt };
}

function run(command, args, code) {
  const result = spawnSync(command, args, { cwd: root, encoding: 'utf8', windowsHide: true, maxBuffer: 8 * 1024 * 1024 });
  if (result.error || result.status !== 0) fail(code);
  return result.stdout;
}

async function atomicJson(path, value) {
  await mkdir(dirname(path), { recursive: true });
  const temporary = `${path}.${process.pid}.tmp`;
  await writeFile(temporary, asJson(value), 'utf8');
  await rename(temporary, path);
}

async function verifiedRights(config, cutoff) {
  if (!Array.isArray(config.rights) || !config.rights.length) fail('display_rights_missing');
  const validations = [];
  for (const receipt of config.rights) {
    if (!receipt.data_root || !/^[a-f0-9]{64}$/.test(receipt.receipt_sha256) ||
        !Array.isArray(receipt.source_ids) || !receipt.source_ids.length) fail('display_rights_configuration_invalid');
    const dataRoot = resolve(root, receipt.data_root);
    const result = JSON.parse(run(config.quantctl_binary ?? 'quantctl', [
      'data', 'validate-market-data-rights', '--data-root', dataRoot,
      '--provider', receipt.provider, '--product', receipt.product,
      '--receipt-sha256', receipt.receipt_sha256,
    ], 'display_rights_validation_failed'));
    if (result.status !== 'READY') fail('display_rights_validation_failed');
    const privateReceipt = await readJson(join(dataRoot, 'rights/market_data_rights_receipt.json'));
    const expiresAt = new Date(Math.min(Date.parse(privateReceipt.valid_until), Date.parse(privateReceipt.review_due_at), Date.parse(cutoff))).toISOString();
    validations.push({ status: result.status, provider: receipt.provider.toLowerCase(), product: receipt.product, source_ids: receipt.source_ids, receipt_sha256: receipt.receipt_sha256, expires_at: expiresAt });
  }
  const covered = new Set(validations.flatMap((receipt) => receipt.source_ids));
  if (requiredSources.some((source) => !covered.has(source))) fail('display_rights_coverage_incomplete');
  return validations;
}

async function loadCalendar(config, now) {
  if (config.calendar_path) return readJson(resolve(root, config.calendar_path));
  const start = new Date(now.getTime() - 500 * 86400000).toISOString().slice(0, 10);
  const end = new Date(now.getTime() + 150 * 86400000).toISOString().slice(0, 10);
  const path = join(workDirectory, 'calendar.json');
  run(config.python_binary ?? 'python', [pythonHelper, '--calendar', start, end, '--output', path], 'exchange_calendar_runtime_missing');
  return readJson(path);
}

async function fetchRegularBars(symbol, sessions, key, config) {
  const from = sessions[0].date;
  const to = sessions.at(-1).date;
  const path = `/v2/aggs/ticker/${encodeURIComponent(symbol)}/range/1/minute/${from}/${to}?adjusted=true&sort=asc&limit=50000`;
  const fetched = await fetchMassivePages(path, key);
  const inputPath = join(workDirectory, `${symbol}-minutes.json`);
  const outputPath = join(workDirectory, `${symbol}-daily.json`);
  await atomicJson(inputPath, { adjusted: fetched.adjusted, sessions, minutes: fetched.rows });
  run(config.python_binary ?? 'python', [pythonHelper, '--input', inputPath, '--output', outputPath], 'regular_session_coverage_invalid');
  return readJson(outputPath);
}

async function refresh(config) {
  const key = process.env.MASSIVE_API_KEY;
  if (!key) fail('MASSIVE_API_KEY_missing');
  if (!config.asset || !/^[A-Z][A-Z0-9.-]{0,15}$/.test(config.asset.symbol) ||
      !config.sector || !/^[A-Z][A-Z0-9.-]{0,15}$/.test(config.sector.benchmark_symbol)) fail('asset_configuration_missing');
  if (!config.iv_history_path) fail('same_tenor_atm_iv_history_missing');
  await mkdir(workDirectory, { recursive: true });
  const now = new Date();
  const calendar = await loadCalendar(config, now);
  const selected = selectResearchSessions(calendar, now, config.history_sessions ?? 126, config.delay_minutes ?? 60);
  const rights = await verifiedRights(config, selected.expiresAt);
  const iv = await readJson(resolve(root, config.iv_history_path));
  if (iv.symbol !== config.asset.symbol || iv.tenor_days !== 30 || iv.moneyness !== 'atm' ||
      iv.methodology !== 'constant_tenor_atm' || !iv.source || iv.source.id !== 'options-iv' ||
      !Array.isArray(iv.series) || iv.series.length < 6) fail('same_tenor_atm_iv_history_invalid');
  const cutoff = selected.history.at(-1).close;
  validateIvSessions(iv, selected.history);
  const symbol = config.asset.symbol;
  const benchmark = config.sector.benchmark_symbol;
  const assetBars = fetchRegularBars(symbol, selected.history, key, config);
  const [bars, sectorBars, splits, dividends] = await Promise.all([
    assetBars,
    benchmark === symbol ? assetBars : fetchRegularBars(benchmark, selected.history, key, config),
    fetchMassivePages(`/v3/reference/splits?ticker=${symbol}&execution_date.gte=${selected.history[0].date}&execution_date.lte=${selected.history.at(-1).date}&limit=1000`, key),
    fetchMassivePages(`/v3/reference/dividends?ticker=${symbol}&ex_dividend_date.gte=${selected.history[0].date}&ex_dividend_date.lte=${selected.history.at(-1).date}&limit=1000`, key),
  ]);
  await atomicJson(join(workDirectory, `${symbol}-corporate-actions.json`), { splits: splits.rows, dividends: dividends.rows });
  const generated = new Date().toISOString();
  const source = (id, dataset) => ({ id, provider: 'Massive', dataset, observed_at: cutoff, available_at: generated, retrieved_at: generated, delay_minutes: config.delay_minutes ?? 60 });
  const input = {
    asset: config.asset, bars,
    sources: [source('ohlcv', 'split-adjusted minute aggregates / XNYS regular sessions'), source('corporate-actions', 'splits and cash dividend reference / price returns, no dividend reinvestment'), iv.source, source('sector', 'benchmark split-adjusted minute aggregates / XNYS regular sessions')],
    ohlcv_source_id: 'ohlcv', corporate_actions_source_id: 'corporate-actions',
    options_iv: { tenor_days: 30, series: iv.series, source_id: 'options-iv' },
    sector: { ...config.sector, series: sectorBars.map((bar) => ({ observed_at: bar.observed_at, value: bar.close })), source_id: 'sector' },
    corporate_actions_adjusted: true, display_authorized: true, generated_at: generated,
    max_age_seconds: Math.floor((Date.parse(selected.expiresAt) - Date.parse(cutoff)) / 1000),
    expected_sessions: selected.history.length,
  };
  if (config.trades_path) {
    const trades = await readJson(resolve(root, config.trades_path));
    if (trades.symbol !== symbol || trades.source?.id !== 'trades' || !Array.isArray(trades.trades)) fail('trade_archive_invalid');
    if (!rights.some((receipt) => receipt.source_ids.includes('trades'))) fail('trade_display_rights_missing');
    input.trades = trades.trades;
    input.trades_source_id = 'trades';
    input.sources.push(trades.source);
  }
  if (input.sources.some((source) => !rights.some((receipt) =>
    receipt.provider === source.provider.toLowerCase() && receipt.source_ids.includes(source.id)))) {
    fail('display_rights_provider_mismatch');
  }
  const snapshots = {};
  for (const [horizon, count] of Object.entries(horizons)) {
    const inputPath = join(workDirectory, `${symbol}-${horizon}-input.json`);
    const outputPath = join(workDirectory, `${symbol}-${horizon}.json`);
    await atomicJson(inputPath, { ...input, horizon, projected_sessions: selected.future.slice(0, count).map((session) => session.close) });
    run(config.market_map_binary ?? 'market-map', ['--input', inputPath, '--output', outputPath], 'rust_market_map_validation_failed');
    snapshots[`${symbol}:${horizon}`] = await readJson(outputPath);
  }
  // Validate the exact same contract used by the website before bundling.
  const pending = join(workDirectory, 'pending-snapshots.json');
  await atomicJson(pending, snapshots);
  run(process.execPath, [join(root, 'node_modules/tsx/dist/cli.mjs'), join(root, 'scripts/market-map-validate.ts'), pending], 'website_snapshot_validation_failed');
  const artifacts = Object.entries(snapshots).map(([key, value]) => ({ key, sha256: sha256(JSON.stringify(value)), source_ids: value.provenance.sources.map((item) => item.id) }));
  const expiresAt = new Date(Math.min(Date.parse(selected.expiresAt), ...rights.map((receipt) => Date.parse(receipt.expires_at)))).toISOString();
  // Publish manifest last. A partial update cannot validate against old hashes.
  await atomicJson(join(artifactDirectory, 'snapshots.json'), snapshots);
  await atomicJson(join(artifactDirectory, 'publication.json'), { schema_version: 'market-map-publication.v1', generated_at: generated, expires_at: expiresAt, rights_validation: rights, artifacts });
  return { status: 'READY', symbol, horizons: Object.keys(horizons), observation_cutoff: cutoff, expires_at: expiresAt, calendar: calendar.source, gaps: config.trades_path ? [] : ['optional_observed_trade_volume_profile_missing'] };
}

export async function main(args = process.argv.slice(2)) {
  await mkdir(artifactDirectory, { recursive: true });
  const checkedAt = new Date().toISOString();
  let result;
  try {
    if (args.includes('--check')) {
      result = { status: 'BLOCKED', checked_at: checkedAt, credential_configured: Boolean(process.env.MASSIVE_API_KEY), gaps: [
        ...(!process.env.MASSIVE_API_KEY ? ['MASSIVE_API_KEY_missing'] : []),
        'private_refresh_configuration_required', 'same_tenor_atm_iv_history_required', 'display_rights_receipts_required',
      ] };
    } else {
      const index = args.indexOf('--config');
      if (index < 0 || !args[index + 1]) fail('private_refresh_configuration_required');
      result = { checked_at: checkedAt, ...await refresh(await readJson(resolve(root, args[index + 1]))) };
    }
  } catch (error) {
    result = { status: 'BLOCKED', checked_at: checkedAt, gaps: [error instanceof MarketMapDataError ? error.code : 'market_map_input_or_runtime_unavailable'] };
  }
  await atomicJson(join(artifactDirectory, 'status.json'), result);
  console.log(asJson(result).trim());
  if (result.status !== 'READY') process.exitCode = 2;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
