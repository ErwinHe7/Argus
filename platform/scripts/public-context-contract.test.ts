// @ts-nocheck
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import {
  buildPublicContextCatalog,
  fetchSecPublicContext,
  licenseBlockedResponse,
  normalizeSecAcceptanceTimestamp,
  PUBLIC_CONTEXT_SCHEMA,
} from '../lib/public-context.ts';
import {
  fetchPublicMacroContext,
  PUBLIC_MACRO_SERIES,
} from '../lib/public-macro.ts';

const read = (path) =>
  readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

test('public context catalog exposes only licensed or fail-closed sources', () => {
  const previousSec = process.env.SEC_USER_AGENT;
  delete process.env.SEC_USER_AGENT;
  try {
    const catalog = buildPublicContextCatalog('https://axio7.com/');
    assert.equal(catalog.schema_version, PUBLIC_CONTEXT_SCHEMA);
    assert.equal(
      catalog.sources.find((source) => source.id === 'sec_edgar')?.state,
      'configuration_required'
    );
    assert.equal(
      catalog.sources.find((source) => source.id === 'fred_alfred')?.state,
      'disabled_pending_written_permission'
    );    for (const id of [
      'bls_public_api',
      'us_treasury_yield_curve',
      'ny_fed_markets_api',
    ]) {
      assert.equal(
        catalog.sources.find((source) => source.id === id)?.state,
        'ready'
      );
    }
    assert.equal(
      catalog.sources.find((source) => source.id === 'bea_api')?.state,
      'free_key_required_not_connected'
    );
    assert.match(catalog.api.macro, /CPI_US_ALL_SA/);
    assert.doesNotMatch(catalog.api.macro, /CPIAUCSL|DGS10|T10Y2Y/);
    for (const id of [
      'occ_daily_open_interest',
      'issuer_rss',
      'benzinga_news',
    ]) {
      assert.match(
        String(catalog.sources.find((source) => source.id === id)?.state),
        /^disabled_/
      );
    }
    const serialized = JSON.stringify(catalog);
    assert.doesNotMatch(serialized, /api_key=/i);
    assert.doesNotMatch(serialized, /\/api\/v1\/live\/bars/i);
    assert.doesNotMatch(serialized, /\b(?:bbo|trades)\b/i);
  } finally {
    restoreEnv('SEC_USER_AGENT', previousSec);
  }
});

test('SEC timestamps fail closed unless timezone-qualified', () => {
  assert.equal(
    normalizeSecAcceptanceTimestamp('2026-07-27T13:08:16.000Z'),
    '2026-07-27T13:08:16.000Z'
  );
  assert.equal(
    normalizeSecAcceptanceTimestamp('2026-07-27T09:08:16-04:00'),
    '2026-07-27T13:08:16.000Z'
  );
  assert.equal(normalizeSecAcceptanceTimestamp('20260727130816'), null);
  assert.equal(normalizeSecAcceptanceTimestamp('2026-07-27'), null);
});

test('SEC public context serializes exact availability and rejects imprecise rows', async () => {
  const previousFetch = globalThis.fetch;
  const previousAgent = process.env.SEC_USER_AGENT;
  const previousSymbols = process.env.AXIO7_PUBLIC_CONTEXT_SYMBOLS;
  process.env.SEC_USER_AGENT = 'AXIO7 public context ops@axio7.com';
  process.env.AXIO7_PUBLIC_CONTEXT_SYMBOLS = 'NVDA';

  globalThis.fetch = async (input) => {
    const url = String(input);
    if (url.endsWith('/files/company_tickers.json')) {
      return jsonResponse({
        0: { cik_str: 1045810, ticker: 'NVDA', title: 'NVIDIA CORP' },
      });
    }
    if (url.includes('/submissions/CIK0001045810.json')) {
      return jsonResponse({
        filings: {
          recent: {
            accessionNumber: [
              '0001045810-26-000001',
              '0001045810-26-000002',
            ],
            acceptanceDateTime: [
              '2026-07-25T16:00:00.000Z',
              '20260725170000',
            ],
            filingDate: ['2026-07-25', '2026-07-25'],
            reportDate: ['2026-07-25', '2026-07-25'],
            form: ['8-K', '10-Q'],
            primaryDocument: ['nvda-8k.htm', 'nvda-10q.htm'],
            primaryDocDescription: ['Current report', 'Quarterly report'],
          },
        },
      });
    }
    if (url.includes('/api/xbrl/companyfacts/CIK0001045810.json')) {
      return jsonResponse({
        facts: {
          'us-gaap': {
            RevenueFromContractWithCustomerExcludingAssessedTax: {
              label: 'Revenue',
              units: {
                USD: [
                  {
                    accn: '0001045810-26-000001',
                    start: '2026-04-01',
                    end: '2026-06-30',
                    filed: '2026-07-25',
                    form: '8-K',
                    fp: 'Q2',
                    fy: 2026,
                    val: 123,
                  },
                  {
                    accn: '0001045810-26-000001',
                    start: '2026-01-01',
                    end: '2026-06-30',
                    filed: '2026-07-25',
                    form: '8-K',
                    fp: 'Q2',
                    fy: 2026,
                    val: 999,
                  },
                ],
              },
            },
            Revenues: {
              label: 'Fallback revenue',
              units: {
                USD: [
                  {
                    accn: '0001045810-26-000001',
                    start: '2026-04-01',
                    end: '2026-06-30',
                    filed: '2026-07-25',
                    form: '8-K',
                    fp: 'Q2',
                    fy: 2026,
                    val: 456,
                  },
                ],
              },
            },
          },
        },
      });
    }
    throw new Error(`unexpected test URL: ${url}`);
  };

  try {
    const report = await fetchSecPublicContext('nvda', 10);
    assert.equal(report.schema_version, PUBLIC_CONTEXT_SCHEMA);
    assert.equal(report.observation_cutoff, '2026-07-25T16:00:00.000Z');
    assert.equal(report.coverage.filings_returned, 1);
    assert.equal(
      report.coverage.filings_rejected_without_exact_availability,
      1
    );
    assert.equal(report.coverage.xbrl_facts_returned, 1);
    const xbrlFacts = report.items.filter((item) => item.kind === 'xbrl_fact');
    assert.equal(xbrlFacts[0].tag, 'RevenueFromContractWithCustomerExcludingAssessedTax');
    assert.equal(xbrlFacts[0].tag_priority, 0);
    assert.equal(xbrlFacts[0].period_kind, 'quarterly');
    assert.equal(xbrlFacts[0].value, 123);
    assert.equal(report.freshness.status, 'latest_official_filing');
    assert.equal(report.model_version, null);
    assert.equal(report.feature_version, null);
    assert.ok(
      report.items.every(
        (item) =>
          item.availability_precision === 'exact_timestamp' &&
          item.archive_verified === false &&
          item.model_eligible === false
      )
    );
    const serialized = JSON.stringify(report);
    assert.doesNotMatch(serialized, /api_key|token|DATABENTO/i);
  } finally {
    globalThis.fetch = previousFetch;
    restoreEnv('SEC_USER_AGENT', previousAgent);
    restoreEnv('AXIO7_PUBLIC_CONTEXT_SYMBOLS', previousSymbols);
  }
});

test('direct official macro context is allowlisted, grounded, and never model-eligible', async () => {
  const previousFetch = globalThis.fetch;
  globalThis.__axio7PublicMacroCache = new Map();
  const calls = [];

  globalThis.fetch = async (input, init = {}) => {
    const url = String(input);
    calls.push({ url, init });
    if (url.includes('api.bls.gov')) {
      assert.equal(init.method, 'POST');
      const body = JSON.parse(String(init.body));
      assert.deepEqual(body.seriesid, [
        'CUSR0000SA0',
        'LNS14000000',
        'CES0000000001',
      ]);
      assert.equal(body.registrationkey, undefined);
      return responseWithType(
        JSON.stringify({
          status: 'REQUEST_SUCCEEDED',
          Results: {
            series: [
              blsSeries('CUSR0000SA0', '318.2'),
              blsSeries('LNS14000000', '4.1'),
              blsSeries('CES0000000001', '159500'),
            ],
          },
        }),
        'application/json'
      );
    }
    if (url.includes('home.treasury.gov')) {
      return responseWithType(
        '<feed><entry><content><m:properties>' +
          '<d:NEW_DATE>2026-07-24T00:00:00</d:NEW_DATE>' +
          '<d:BC_2YEAR>4.20</d:BC_2YEAR>' +
          '<d:BC_10YEAR>4.55</d:BC_10YEAR>' +
          '</m:properties></content></entry></feed>',
        'application/atom+xml'
      );
    }
    if (url.includes('markets.newyorkfed.org')) {
      return responseWithType(
        JSON.stringify({
          refRates: [
            {
              type: 'EFFR',
              effectiveDate: '2026-07-24',
              percentRate: '4.33',
              revisionIndicator: '',
            },
          ],
        }),
        'application/json'
      );
    }
    throw new Error(`unexpected macro test URL: ${url}`);
  };

  try {
    const report = await fetchPublicMacroContext([...PUBLIC_MACRO_SERIES]);
    assert.deepEqual(report.coverage.requested_series, [...PUBLIC_MACRO_SERIES]);
    assert.deepEqual(report.coverage.missing_series, []);
    assert.equal(report.coverage.complete, true);
    assert.equal(report.coverage.source_count, 3);
    assert.equal(report.items.length, PUBLIC_MACRO_SERIES.length);
    assert.equal(report.model_eligible, false);
    assert.equal(report.archive_verified, false);
    assert.equal(report.point_in_time, false);
    assert.equal(report.model_version, null);
    assert.equal(report.feature_version, null);
    assert.ok(
      report.items.every(
        (item) =>
          item.model_eligible === false &&
          item.archive_verified === false &&
          item.availability_precision === 'axio7_retrieval_time'
      )
    );
    const spread = report.items.find(
      (item) => item.series === 'UST_10Y2Y_SPREAD'
    );
    assert.equal(spread.value, 0.35);
    assert.equal(spread.derived, true);
    assert.equal(spread.derived_from.length, 2);
    assert.equal(calls.length, 3);
    const serializedReport = JSON.stringify(report);
    assert.match(serializedReport, /BLS\.gov cannot vouch/);
    assert.match(serializedReport, /AXIO7 is not affiliated with the New York Fed/);
    assert.doesNotMatch(
      JSON.stringify({ report, calls }),
      /registrationkey|api_key|DATABENTO_API_KEY/i
    );
  } finally {
    globalThis.fetch = previousFetch;
    delete globalThis.__axio7PublicMacroCache;
  }
});
test('OCC and news endpoints serialize a license blocker, never synthetic data', () => {
  for (const resource of ['occ-open-interest', 'news']) {
    const report = licenseBlockedResponse(resource);
    assert.equal(report.error.code, 'SOURCE_LICENSE_REQUIRED');
    assert.equal(report.observation_cutoff, null);
    assert.deepEqual(report.items, []);
  }
  const occ = JSON.stringify(licenseBlockedResponse('occ-open-interest'));
  assert.match(occ, /market-wide/i);
  assert.match(occ, /not symbol or contract OI/i);
  assert.doesNotMatch(occ, /strike|dealer sign|gamma_eligible/i);
});

test('context route is active, GET-only, strict, bounded, and isolated from private market data', () => {
  const middleware = read('middleware.ts');
  const apiProtection = read('lib/api-protection.ts');
  const route = read('app/api/context/v1/[resource]/route.ts');
  const implementation = read('lib/public-context.ts');
  const officialSync = read('scripts/sync-official-context.mjs');

  assert.match(middleware, /['"]\/api\/context\/v1['"]/);
  assert.match(apiProtection, /PUBLIC_MARKET_READ_PATHS[^;]*\/api\/context\/v1/);
  assert.match(route, /export async function GET/);
  assert.doesNotMatch(route, /export async function (?:POST|PUT|PATCH|DELETE)/);
  assert.match(route, /\.strict\(\)/);
  assert.match(route, /\.max\(20\)/);
  assert.match(route, /checkRateLimit/);
  assert.match(route, /Cache-Control/);
  assert.doesNotMatch(route, /\/api\/v1\/live\/bars|DATABENTO_API_KEY/);
  assert.doesNotMatch(
    implementation,
    /\/api\/v1\/live\/bars|input_path|manifest_path/
  );  assert.doesNotMatch(implementation, /api\.stlouisfed\.org/);
  assert.match(officialSync, /csvOption\('--sources', \['sec'\]\)/);
  assert.match(officialSync, /source !== 'sec'/);
  assert.doesNotMatch(
    officialSync,
    /api\\.stlouisfed\\.org|FRED_API_KEY|fredSeries|syncFred/
  );

});

function blsSeries(seriesID, value) {
  return {
    seriesID,
    data: [
      {
        year: '2026',
        period: 'M06',
        value,
        footnotes: [{}],
      },      {
        year: '2026',
        period: 'M07',
        value: '-',
        footnotes: [{ text: 'Data not available' }],
      },
    ],
  };
}

function responseWithType(body, contentType) {
  return new Response(body, {
    status: 200,
    headers: { 'Content-Type': contentType },
  });
}
function jsonResponse(value) {
  return new Response(JSON.stringify(value), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

function restoreEnv(name, value) {
  if (value === undefined) delete process.env[name];
  else process.env[name] = value;
}
