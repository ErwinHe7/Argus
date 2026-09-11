import { createHash } from 'node:crypto';
import { DIRECTORY_MAX_AGE_DAYS, DIRECTORY_URLS, validateMarketUniverseCatalog } from './catalog';
import type { MarketUniverseCatalog, MarketUniverseEntry, MarketUniverseSource } from './types';

type DirectoryId = MarketUniverseSource['id'];
const HEADERS: Record<DirectoryId, string> = {
  nasdaq_listed: 'Symbol|Security Name|Market Category|Test Issue|Financial Status|Round Lot Size|ETF|NextShares',
  other_listed: 'ACT Symbol|Security Name|Exchange|CQS Symbol|ETF|Round Lot Size|Test Issue|NASDAQ Symbol',
};
// M is NYSE Texas in Nasdaq's Equity Trade Journal field definitions (June 2025).
const EXCHANGES: Record<string, string> = { A: 'NYSE American', N: 'NYSE', P: 'NYSE Arca', Z: 'Cboe BZX', V: 'IEX', M: 'NYSE Texas' };
const fail = (code: string): never => { throw new Error(code); };
const check = (condition: unknown, code: string): void => { if (!condition) fail(code); };

export function parseNasdaqDirectory(id: DirectoryId, input: string, retrievedAt: string): { entries: MarketUniverseEntry[]; source: MarketUniverseSource } {
  check(Object.hasOwn(DIRECTORY_URLS, id) && Number.isFinite(Date.parse(retrievedAt)), 'directory_input_invalid');
  check(Buffer.byteLength(input, 'utf8') <= 5_000_000, 'directory_response_too_large');
  const lines = input.replace(/^\uFEFF/, '').trimEnd().split(/\r?\n/);
  check(lines[0] === HEADERS[id] && lines.length > 2, 'directory_header_invalid');
  const footer = /^File Creation Time: (\d{8}\d{2}:?\d{2})\|+$/.exec(lines.at(-1)!);
  check(footer, 'directory_footer_missing');
  const stamp = footer![1];
  const date = `${stamp.slice(4, 8)}-${stamp.slice(0, 2)}-${stamp.slice(2, 4)}`;
  const dateMs = Date.parse(`${date}T00:00:00Z`);
  check(Number.isFinite(dateMs) && new Date(dateMs).toISOString().slice(0, 10) === date &&
    Number(stamp.slice(8, 10)) < 24 && Number(stamp.slice(-2)) < 60 && dateMs <= Date.parse(retrievedAt), 'directory_source_time_invalid');
  check(dateMs + DIRECTORY_MAX_AGE_DAYS * 86400000 > Date.parse(retrievedAt), 'directory_stale');
  let excluded = 0;
  const entries: MarketUniverseEntry[] = [], seen = new Set<string>();
  for (const line of lines.slice(1, -1)) {
    const values = line.split('|');
    check(values.length === 8, 'directory_row_invalid');
    const [symbol, name] = values;
    check(symbol && name.trim() && !seen.has(symbol), 'directory_symbol_invalid');
    seen.add(symbol);
    const isNasdaq = id === 'nasdaq_listed';
    const testIssue = values[isNasdaq ? 3 : 6], etf = values[isNasdaq ? 6 : 4];
    check(['Y', 'N'].includes(testIssue) && ['Y', 'N'].includes(etf) && /^\d+$/.test(values[5]) && Number(values[5]) > 0, 'directory_flag_invalid');
    if (isNasdaq) check(['Q', 'G', 'S'].includes(values[2]) && /^[NDEQGHJK]$/.test(values[4]) && ['Y', 'N'].includes(values[7]), 'directory_nasdaq_fields_invalid');
    else check(Object.hasOwn(EXCHANGES, values[2]), 'directory_exchange_unknown');
    if (testIssue === 'Y') { excluded++; continue; }
    entries.push({ symbol, name: name.trim(), exchange: isNasdaq ? 'NASDAQ' : EXCHANGES[values[2]],
      exchange_code: isNasdaq ? 'Q' : values[2], directory: id, security_kind: etf === 'Y' ? 'etf' : 'non_etf',
      nasdaq_symbol: isNasdaq ? symbol : values[7], cqs_symbol: isNasdaq ? null : values[3], financial_status: isNasdaq ? values[4] : null });
  }
  check(entries.length > 0 && entries.length <= 30000, 'directory_rows_invalid');
  return { entries, source: { id, url: DIRECTORY_URLS[id], retrieved_at: retrievedAt,
    sha256: createHash('sha256').update(input).digest('hex'), source_creation_time: stamp,
    source_creation_date: date, rows: lines.length - 2, excluded_test_issues: excluded } };
}

export function buildMarketUniverseCatalog(nasdaqText: string, otherText: string, retrievedAt: string, now = new Date(retrievedAt)): MarketUniverseCatalog {
  const parsed = [parseNasdaqDirectory('nasdaq_listed', nasdaqText, retrievedAt), parseNasdaqDirectory('other_listed', otherText, retrievedAt)];
  const sources = parsed.map((result) => result.source);
  const catalog: MarketUniverseCatalog = {
    schema_version: 'market-universe.v1', scope: 'us_exchange_listed_securities', generated_at: now.toISOString(),
    expires_at: new Date(Math.min(...sources.map((source) => Date.parse(`${source.source_creation_date}T00:00:00Z`))) + DIRECTORY_MAX_AGE_DAYS * 86400000).toISOString(),
    sources, entries: parsed.flatMap((result) => result.entries).sort((a, b) => a.symbol.localeCompare(b.symbol, 'en')),
    index_membership: 'not_supplied', limitations: [
      'Exchange-listed securities from Nasdaq Trader; OTC securities and delisted securities are outside this directory.',
      'Non-ETF entries include common shares, preferred shares, warrants, units and other securities; the source does not provide a reliable common-stock classification.',
      'Index membership, including S&P 500 and Nasdaq-100 membership, is not supplied or inferred.',
      'Listing identity does not establish broker tradability, current quotes, historical data coverage, model coverage or a trade recommendation.',
      'Native ACT, CQS and Nasdaq symbols are retained; broker contract identifiers must be resolved separately.',
      'This is a current directory snapshot, not point-in-time membership for backtests. Source footer time has no stated UTC offset; freshness uses a conservative seven-day source-date limit.',
    ],
  };
  return validateMarketUniverseCatalog(catalog, now) ?? fail('directory_catalog_invalid');
}

/** Two fixed public metadata URLs; no credentials, redirects or arbitrary hosts. */
export async function fetchNasdaqDirectory(id: DirectoryId, fetchImplementation: typeof fetch = fetch): Promise<string> {
  check(Object.hasOwn(DIRECTORY_URLS, id), 'directory_source_invalid');
  let response: Response;
  try { response = await fetchImplementation(DIRECTORY_URLS[id], { redirect: 'error', signal: AbortSignal.timeout(25000), headers: { Accept: 'text/plain' } }); }
  catch { return fail('directory_request_failed'); }
  check(response.ok && response.body, 'directory_http_failed');
  const reader = response.body!.getReader(), chunks: Uint8Array[] = [];
  let length = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.byteLength;
      if (length > 5_000_000) { await reader.cancel(); return fail('directory_response_too_large'); }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  try { return new TextDecoder('utf-8', { fatal: true }).decode(Buffer.concat(chunks)); }
  catch { return fail('directory_encoding_invalid'); }
}
