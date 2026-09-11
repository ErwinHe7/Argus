import assert from 'node:assert/strict';
import { test } from 'node:test';
import { attachResearchCoverage, currentResearchCoverage, parseDiscoveryQuery, type ResearchCoverage } from '../lib/investing/discovery';
import type { MarketUniverseEntry } from '../lib/market-universe/types';

const now = new Date('2026-09-05T16:00:00Z');
const coverage: ResearchCoverage = { symbol: 'AAPL', observation_cutoff: '2026-09-04T20:00:00Z', expires_at: '2026-09-08T20:00:00Z', source: 'test source', href: '/discover/market-map?symbol=AAPL' };
const entry = (symbol: string): MarketUniverseEntry => ({ symbol, name: symbol, exchange: 'NASDAQ', exchange_code: 'Q', directory: 'nasdaq_listed', security_kind: 'non_etf', nasdaq_symbol: symbol, cqs_symbol: null, financial_status: 'N' });

test('public directory query bounds pagination and rejects execution or upstream parameters', () => {
  assert.deepEqual(parseDiscoveryQuery(new URLSearchParams('q=Apple&exchange=NASDAQ&kind=non_etf&coverage=ready&offset=40')), { query: 'Apple', exchange: 'NASDAQ', kind: 'non_etf', coverage: 'ready', offset: 40, limit: 40 });
  for (const query of ['q=AAPL&q=NVDA', 'url=https://example.com', 'order=buy', 'limit=100000', 'offset=-1', 'offset=01', 'offset=30001', 'exchange=SP500', 'coverage=buy', 'kind=stock', 'q=%0AAAPL', `q=${'x'.repeat(81)}`]) {
    assert.equal(parseDiscoveryQuery(new URLSearchParams(query)), null, query);
  }
});

test('a listed security never inherits another symbol’s available analysis', () => {
  const result = attachResearchCoverage([entry('AAPL'), entry('NVDA'), entry('aapl')], [coverage], now);
  assert.equal(result[0].research?.symbol, 'AAPL');
  assert.equal(result[1].research, null);
  assert.equal(result[2].research, null);
});

test('expired, future-dated, invalid and misdirected research cannot be marked available', () => {
  const invalid = [
    { ...coverage, expires_at: now.toISOString() },
    { ...coverage, observation_cutoff: '2026-09-06T00:00:00Z' },
    { ...coverage, expires_at: 'invalid' },
    { ...coverage, observation_cutoff: 'invalid' },
    { ...coverage, href: '/discover/market-map?symbol=NVDA' },
    { ...coverage, href: 'https://example.com' },
  ];
  assert.deepEqual(currentResearchCoverage(invalid, now), []);
  assert.equal(attachResearchCoverage([entry('AAPL')], invalid, now)[0].research, null);
});

test('missing coverage preserves listing identity without a model result', () => {
  assert.deepEqual(attachResearchCoverage([entry('BRK.B')], [], now), [{ ...entry('BRK.B'), research: null }]);
});
