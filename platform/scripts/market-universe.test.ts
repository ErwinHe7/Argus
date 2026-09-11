import test from 'node:test';
import assert from 'node:assert/strict';
import { buildMarketUniverseCatalog, fetchNasdaqDirectory, parseNasdaqDirectory } from '../lib/market-universe/ingest';
import { isMarketUniverseFresh, searchMarketUniverse, validateMarketUniverseCatalog } from '../lib/market-universe/catalog';

const NOW = '2026-09-05T12:00:00.000Z';
// Small explicit parser fixtures, never a fallback runtime universe or quote source.
const NASDAQ = [
  'Symbol|Security Name|Market Category|Test Issue|Financial Status|Round Lot Size|ETF|NextShares',
  'AAPL|Apple Inc. - Common Stock|Q|N|N|100|N|N',
  'PREFP|Example Depositary Preferred Shares|G|N|D|100|N|N',
  'QQQ|Example Nasdaq Index ETF|G|N|N|100|Y|N',
  'ZTEST|Explicit Test Issue|Q|Y|N|100|N|N',
  'File Creation Time: 0904202621:31|||||||',
].join('\r\n');
const OTHER = [
  'ACT Symbol|Security Name|Exchange|CQS Symbol|ETF|Round Lot Size|Test Issue|NASDAQ Symbol',
  'BRK.B|Berkshire Hathaway Inc. Class B Common Stock|N|BRK.B|N|100|N|BRK/B',
  'NMCO.V|Example Rights when issued|N|NMCOrw|N|100|N|NMCO^#',
  'SPY|SPDR S&P 500 ETF Trust|P|SPY|Y|100|N|SPY',
  'MTEST|NYSE Texas Test|M|MTEST|N|100|Y|MTEST',
  'File Creation Time: 0904202621:31||||||',
].join('\n');
const fixture = () => buildMarketUniverseCatalog(NASDAQ, OTHER, NOW);

test('complete source receipts exclude test issues and preserve native symbol aliases', () => {
  const catalog = fixture();
  assert.equal(catalog.entries.length, 6);
  assert.deepEqual(catalog.sources.map((source) => [source.rows, source.excluded_test_issues]), [[4, 1], [4, 1]]);
  assert.equal(catalog.sources[0].source_creation_time, '0904202621:31');
  assert.equal(catalog.entries.find((entry) => entry.symbol === 'BRK.B')?.nasdaq_symbol, 'BRK/B');
  assert.equal(catalog.entries.find((entry) => entry.symbol === 'NMCO.V')?.nasdaq_symbol, 'NMCO^#');
  assert.equal(catalog.entries.find((entry) => entry.symbol === 'PREFP')?.security_kind, 'non_etf');
  assert.equal(catalog.index_membership, 'not_supplied');
});

test('search matches native aliases and issuer names with distinct Nasdaq and ETF filters', () => {
  const catalog = fixture();
  const now = new Date(NOW);
  assert.deepEqual(searchMarketUniverse(catalog, { query: 'brk/b' }, now).entries.map((entry) => entry.symbol), ['BRK.B']);
  assert.deepEqual(searchMarketUniverse(catalog, { query: 'apple' }, now).entries.map((entry) => entry.symbol), ['AAPL']);
  assert.deepEqual(searchMarketUniverse(catalog, { exchange: 'NASDAQ', kind: 'etf' }, now).entries.map((entry) => entry.symbol), ['QQQ']);
  assert.deepEqual(searchMarketUniverse(catalog, { exchange: 'other', kind: 'non_etf', limit: 1, offset: 1 }, now).entries.map((entry) => entry.symbol), ['NMCO.V']);
  assert.equal(searchMarketUniverse(catalog, { exchange: 'other', kind: 'non_etf', limit: 1 }, now).total, 2);
});

test('a fresh download cannot extend stale source dates or accept future source dates', () => {
  assert.throws(() => buildMarketUniverseCatalog(NASDAQ, OTHER, '2026-09-11T00:00:00.000Z'), /directory_stale/);
  assert.throws(() => buildMarketUniverseCatalog(NASDAQ.replace('09042026', '09062026'), OTHER, NOW), /directory_source_time_invalid/);
  assert.throws(() => buildMarketUniverseCatalog(NASDAQ.replace('09042026', '02302026'), OTHER, NOW), /directory_source_time_invalid/);
  const catalog = fixture();
  assert.equal(isMarketUniverseFresh(catalog, new Date(catalog.expires_at)), false);
  assert.throws(() => searchMarketUniverse(catalog, {}, new Date(catalog.expires_at)), /directory_stale/);
});

test('truncation, duplicate source symbols, unknown exchanges and changed flags fail closed', () => {
  assert.throws(() => parseNasdaqDirectory('nasdaq_listed', NASDAQ.split('\r\n').slice(0, -1).join('\n'), NOW), /directory_footer_missing/);
  assert.throws(() => buildMarketUniverseCatalog(NASDAQ.replace('PREFP|', 'AAPL|'), OTHER, NOW), /directory_symbol_invalid/);
  assert.throws(() => buildMarketUniverseCatalog(NASDAQ, OTHER.replace('|N|BRK.B|', '|X|BRK.B|'), NOW), /directory_exchange_unknown/);
  assert.throws(() => buildMarketUniverseCatalog(NASDAQ.replace('|100|Y|N', '|100|U|N'), OTHER, NOW), /directory_flag_invalid/);
});

test('catalog validation rejects incomplete rows, future receipts and unsupported expiry extension', () => {
  const missing = fixture(); missing.entries.pop();
  assert.equal(validateMarketUniverseCatalog(missing, new Date(NOW)), null);
  const future = fixture(); future.sources[0].retrieved_at = '2026-09-06T00:00:00.000Z';
  assert.equal(validateMarketUniverseCatalog(future, new Date(NOW)), null);
  const prolonged = fixture(); prolonged.expires_at = '2026-09-12T00:00:00.000Z';
  assert.equal(validateMarketUniverseCatalog(prolonged, new Date(NOW)), null);
  const duplicate = fixture(); duplicate.entries[0].symbol = duplicate.entries[1].symbol;
  assert.equal(validateMarketUniverseCatalog(duplicate, new Date(NOW)), null);
});

test('search input is bounded and never treats literal punctuation as a regular expression', () => {
  const catalog = fixture(), now = new Date(NOW);
  assert.throws(() => searchMarketUniverse(catalog, { limit: 101 }, now), /directory_query_invalid/);
  assert.throws(() => searchMarketUniverse(catalog, { offset: -1 }, now), /directory_query_invalid/);
  assert.throws(() => searchMarketUniverse(catalog, { query: 'x'.repeat(101) }, now), /directory_query_invalid/);
  assert.equal(searchMarketUniverse(catalog, { query: '.*' }, now).total, 0);
});

test('directory fetching has fixed URLs, rejects HTTP failures and bounds streamed bytes', async () => {
  const seen: unknown[] = [];
  const reader = (async (url: unknown, options: unknown) => { seen.push({ url, options }); return new Response(NASDAQ); }) as typeof fetch;
  assert.equal(await fetchNasdaqDirectory('nasdaq_listed', reader), NASDAQ);
  assert.equal((seen[0] as { url: string }).url, 'https://www.nasdaqtrader.com/dynamic/SymDir/nasdaqlisted.txt');
  assert.equal((seen[0] as { options: RequestInit }).options.redirect, 'error');
  await assert.rejects(() => fetchNasdaqDirectory('nasdaq_listed', (async () => new Response('blocked', { status: 403 })) as typeof fetch), /directory_http_failed/);
  await assert.rejects(() => fetchNasdaqDirectory('nasdaq_listed', (async () => new Response(new Uint8Array(5_000_001))) as typeof fetch), /directory_response_too_large/);
});
