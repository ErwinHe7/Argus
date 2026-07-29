#!/usr/bin/env node

/**
 * Alphabet earnings event study.
 *
 * Data provenance:
 * - SEC submissions JSON: official 8-K acceptance timestamps, Item 2.02 only.
 * - Yahoo Finance chart endpoint: split/dividend-adjusted daily prices. This is
 *   an exploratory public-data source, not a licensed point-in-time feed.
 *
 * The script intentionally does not infer earnings surprise, CapEx surprise,
 * or guidance surprise because no historical point-in-time consensus dataset
 * is available in this workspace.
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(SCRIPT_DIR, '..');
const REPORT_DIR = path.join(ROOT, 'reports');

const arg = (name, fallback) => {
  const index = process.argv.indexOf(name);
  return index >= 0 && process.argv[index + 1] ? process.argv[index + 1] : fallback;
};

const AS_OF = arg('--as-of', new Date().toISOString().slice(0, 10));
const START = arg('--start', '2004-01-01');
// A forecasting replay needs two explicit information boundaries. The event
// date removes the still-unknown release from the historical sample, while the
// market-data boundary prevents a run later that day from ingesting the close.
const FORECAST_EVENT_DATE = arg('--forecast-event-date', null);
const MARKET_DATA_THROUGH = arg('--market-data-through', AS_OF);
const BOOTSTRAP_SAMPLES = Number(arg('--bootstrap-samples', '5000'));
const SEC_USER_AGENT =
  process.env.SEC_USER_AGENT || 'Axio7 earnings research contact research@example.com';

if (
  !/^\d{4}-\d{2}-\d{2}$/.test(AS_OF) ||
  !/^\d{4}-\d{2}-\d{2}$/.test(START) ||
  !/^\d{4}-\d{2}-\d{2}$/.test(MARKET_DATA_THROUGH) ||
  (FORECAST_EVENT_DATE && !/^\d{4}-\d{2}-\d{2}$/.test(FORECAST_EVENT_DATE))
) {
  throw new Error(
    '--as-of, --start, --market-data-through and --forecast-event-date must use YYYY-MM-DD',
  );
}

const CIKS = [
  { cik: '0001288776', issuer: 'Google Inc.' },
  { cik: '0001652044', issuer: 'Alphabet Inc.' },
];

const SYMBOLS = {
  GOOGL: 'GOOGL',
  SPY: 'SPY',
  QQQ: 'QQQ',
  SOXX: 'SOXX',
  MU: 'MU',
  SNDK: 'SNDK',
  WDC: 'WDC',
  STX: 'STX',
  VIX: '^VIX',
  TNX: '^TNX',
  TLT: 'TLT',
  HYG: 'HYG',
  GLD: 'GLD',
  USO: 'USO',
  UUP: 'UUP',
};

const EVENT_ASSETS = ['GOOGL', 'SPY', 'QQQ', 'SOXX', 'MU', 'SNDK', 'WDC', 'STX'];
const HORIZONS = [1, 5, 20];
const AI_INFRASTRUCTURE_ERA_START = '2023-07-25';

// SEC Item 2.02 is broader than a quarterly earnings release. These exclusions
// were verified against the primary filing text, and are retained in the report
// so the event universe is auditable instead of silently cadence-filtered.
const AUDITED_EXCLUSIONS = new Map([
  [
    '0001193125-06-043641',
    'Google Analyst Day furnished historical non-GAAP tables; not a quarterly earnings release.',
  ],
  [
    '0001652044-23-000034',
    'Alphabet disclosure blog previewed reporting changes before the April 25 earnings release.',
  ],
  [
    '0001288776-15-000044',
    'Duplicate transition filing for the same October 22, 2015 release; Alphabet CIK filing retained.',
  ],
]);

const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

async function fetchJson(url, headers = {}, attempts = 4) {
  let lastError;
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      const response = await fetch(url, { headers });
      if (response.ok) return await response.json();
      const error = new Error(`HTTP ${response.status} for ${new URL(url).hostname}`);
      error.status = response.status;
      if (![429, 500, 502, 503, 504].includes(response.status)) throw error;
      lastError = error;
    } catch (error) {
      lastError = error;
    }
    await sleep(500 * 2 ** attempt);
  }
  throw lastError;
}

function rowsFromColumns(columns, issuer, cik) {
  const count = columns?.form?.length || 0;
  const rows = [];
  for (let index = 0; index < count; index += 1) {
    const accession = columns.accessionNumber?.[index] || '';
    const primaryDocument = columns.primaryDocument?.[index] || '';
    rows.push({
      issuer,
      cik,
      accession,
      filingDate: columns.filingDate?.[index] || '',
      reportDate: columns.reportDate?.[index] || '',
      acceptance: columns.acceptanceDateTime?.[index] || '',
      form: columns.form?.[index] || '',
      items: columns.items?.[index] || '',
      primaryDocument,
      filingUrl:
        accession && primaryDocument
          ? `https://www.sec.gov/Archives/edgar/data/${Number(cik)}/${accession.replaceAll('-', '')}/${primaryDocument}`
          : null,
    });
  }
  return rows;
}

async function loadSecEarningsEvents() {
  const all = [];
  const secHeaders = { 'User-Agent': SEC_USER_AGENT, Accept: 'application/json' };
  for (const { cik, issuer } of CIKS) {
    const base = `https://data.sec.gov/submissions/CIK${cik}.json`;
    const submissions = await fetchJson(base, secHeaders);
    all.push(...rowsFromColumns(submissions.filings.recent, issuer, cik));
    for (const older of submissions.filings.files || []) {
      const history = await fetchJson(
        `https://data.sec.gov/submissions/${older.name}`,
        secHeaders,
      );
      all.push(...rowsFromColumns(history, issuer, cik));
      await sleep(120);
    }
  }
  const cutoff = new Date(`${AS_OF}T23:59:59.999Z`).getTime();
  const deduplicated = new Map();
  for (const row of all) {
    if (row.form !== '8-K' || !/(^|,)\s*2\.02\s*(,|$)/.test(row.items)) continue;
    const accepted = Date.parse(row.acceptance);
    if (!Number.isFinite(accepted) || accepted > cutoff) continue;
    deduplicated.set(row.accession, row);
  }
  const item202 = [...deduplicated.values()].sort(
    (left, right) => Date.parse(left.acceptance) - Date.parse(right.acceptance),
  );
  const exclusions = item202
    .filter((row) => AUDITED_EXCLUSIONS.has(row.accession))
    .map((row) => ({ ...row, reason: AUDITED_EXCLUSIONS.get(row.accession) }));
  const forecastBoundaryExclusions = FORECAST_EVENT_DATE
    ? item202.filter((row) => acceptanceNewYork(row.acceptance).date >= FORECAST_EVENT_DATE)
    : [];
  return {
    item202,
    exclusions,
    forecastBoundaryExclusions,
    events: item202.filter(
      (row) =>
        !AUDITED_EXCLUSIONS.has(row.accession) &&
        (!FORECAST_EVENT_DATE || acceptanceNewYork(row.acceptance).date < FORECAST_EVENT_DATE),
    ),
  };
}

function unixSeconds(dateString) {
  return Math.floor(Date.parse(`${dateString}T00:00:00Z`) / 1000);
}

function dateInNewYork(timestampSeconds) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/New_York',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date(timestampSeconds * 1000));
  const value = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${value.year}-${value.month}-${value.day}`;
}

async function loadYahooSeries(ticker) {
  const period1 = unixSeconds(START);
  const period2 = unixSeconds(MARKET_DATA_THROUGH) + 3 * 86_400;
  const url = new URL(
    `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(ticker)}`,
  );
  url.searchParams.set('period1', String(period1));
  url.searchParams.set('period2', String(period2));
  url.searchParams.set('interval', '1d');
  url.searchParams.set('events', 'div,splits');
  const payload = await fetchJson(url.toString(), { 'User-Agent': 'Mozilla/5.0 Axio7Research/1.0' });
  if (payload.chart?.error) throw new Error(`${ticker}: ${payload.chart.error.description}`);
  const result = payload.chart?.result?.[0];
  if (!result) throw new Error(`${ticker}: empty chart result`);
  const quote = result.indicators?.quote?.[0] || {};
  const adjusted = result.indicators?.adjclose?.[0]?.adjclose || [];
  const rows = [];
  for (let index = 0; index < (result.timestamp || []).length; index += 1) {
    const rawClose = quote.close?.[index];
    const adjustedClose = adjusted[index];
    const rawOpen = quote.open?.[index];
    if (![rawClose, adjustedClose, rawOpen].every(Number.isFinite) || rawClose <= 0) continue;
    const adjustmentFactor = adjustedClose / rawClose;
    const date = dateInNewYork(result.timestamp[index]);
    if (date > MARKET_DATA_THROUGH) continue;
    rows.push({
      date,
      open: rawOpen * adjustmentFactor,
      high: Number.isFinite(quote.high?.[index]) ? quote.high[index] * adjustmentFactor : null,
      low: Number.isFinite(quote.low?.[index]) ? quote.low[index] * adjustmentFactor : null,
      close: adjustedClose,
      volume: Number.isFinite(quote.volume?.[index]) ? quote.volume[index] : null,
    });
  }
  rows.sort((left, right) => left.date.localeCompare(right.date));
  return {
    ticker,
    currency: result.meta?.currency || null,
    exchange: result.meta?.exchangeName || null,
    rows,
    byDate: new Map(rows.map((row, index) => [row.date, { ...row, index }])),
  };
}

function acceptanceNewYork(acceptance) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/New_York',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(new Date(acceptance));
  const value = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return {
    date: `${value.year}-${value.month}-${value.day}`,
    hour: Number(value.hour),
    minute: Number(value.minute),
    second: Number(value.second),
  };
}

function firstTradingDateOnOrAfter(series, date, strictAfter = false) {
  return series.rows.find((row) => (strictAfter ? row.date > date : row.date >= date))?.date || null;
}

function lastTradingDateBefore(series, date) {
  for (let index = series.rows.length - 1; index >= 0; index -= 1) {
    if (series.rows[index].date < date) return series.rows[index].date;
  }
  return null;
}

function attachReactionSessions(events, calendar) {
  return events.map((event) => {
    const local = acceptanceNewYork(event.acceptance);
    const afterClose = local.hour >= 16;
    const reactionDate = firstTradingDateOnOrAfter(calendar, local.date, afterClose);
    return { ...event, acceptanceEtDate: local.date, afterClose, reactionDate };
  });
}

const safeReturn = (end, start) =>
  Number.isFinite(end) && Number.isFinite(start) && start !== 0 ? end / start - 1 : null;

function eventWindow(series, reactionDate) {
  const reaction = series.byDate.get(reactionDate);
  if (!reaction || reaction.index < 1) return null;
  const previous = series.rows[reaction.index - 1];
  const result = {
    previousDate: previous.date,
    gap: safeReturn(reaction.open, previous.close),
    intraday: safeReturn(reaction.close, reaction.open),
    pre5: reaction.index >= 6 ? safeReturn(previous.close, series.rows[reaction.index - 6].close) : null,
  };
  for (const horizon of HORIZONS) {
    const ending = series.rows[reaction.index + horizon - 1];
    result[`ret${horizon}`] = ending ? safeReturn(ending.close, previous.close) : null;
    result[`endDate${horizon}`] = ending?.date || null;
  }
  return result;
}

function mean(values) {
  const clean = values.filter(Number.isFinite);
  return clean.length ? clean.reduce((sum, value) => sum + value, 0) / clean.length : null;
}

function median(values) {
  const clean = values.filter(Number.isFinite).sort((left, right) => left - right);
  if (!clean.length) return null;
  const middle = Math.floor(clean.length / 2);
  return clean.length % 2 ? clean[middle] : (clean[middle - 1] + clean[middle]) / 2;
}

function standardDeviation(values) {
  const clean = values.filter(Number.isFinite);
  if (clean.length < 2) return null;
  const average = mean(clean);
  return Math.sqrt(
    clean.reduce((sum, value) => sum + (value - average) ** 2, 0) / (clean.length - 1),
  );
}

function seededRandom(seed = 0x9e3779b9) {
  let state = seed >>> 0;
  return () => {
    state += 0x6d2b79f5;
    let value = state;
    value = Math.imul(value ^ (value >>> 15), value | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4_294_967_296;
  };
}

function bootstrapMeanInterval(values, seed) {
  const clean = values.filter(Number.isFinite);
  if (clean.length < 2) return [null, null];
  const random = seededRandom(seed);
  const samples = [];
  for (let iteration = 0; iteration < BOOTSTRAP_SAMPLES; iteration += 1) {
    let total = 0;
    for (let index = 0; index < clean.length; index += 1) {
      total += clean[Math.floor(random() * clean.length)];
    }
    samples.push(total / clean.length);
  }
  samples.sort((left, right) => left - right);
  return [
    samples[Math.floor(0.025 * (samples.length - 1))],
    samples[Math.floor(0.975 * (samples.length - 1))],
  ];
}

function summarize(values, seed) {
  const clean = values.filter(Number.isFinite);
  const [ciLow, ciHigh] = bootstrapMeanInterval(clean, seed);
  return {
    n: clean.length,
    mean: mean(clean),
    median: median(clean),
    positiveRate: clean.length ? clean.filter((value) => value > 0).length / clean.length : null,
    standardDeviation: standardDeviation(clean),
    bootstrap95: [ciLow, ciHigh],
  };
}

function weightedQuantile(observations, quantile) {
  const clean = observations
    .filter((row) => Number.isFinite(row.value) && Number.isFinite(row.weight) && row.weight > 0)
    .sort((left, right) => left.value - right.value);
  const total = clean.reduce((sum, row) => sum + row.weight, 0);
  if (!clean.length || total <= 0) return null;
  let cumulative = 0;
  for (const row of clean) {
    cumulative += row.weight / total;
    if (cumulative >= quantile) return row.value;
  }
  return clean.at(-1).value;
}

function ols(xValues, yValues) {
  const pairs = xValues
    .map((x, index) => [x, yValues[index]])
    .filter(([x, y]) => Number.isFinite(x) && Number.isFinite(y));
  if (pairs.length < 3) return { n: pairs.length, alpha: null, beta: null, correlation: null, r2: null };
  const xs = pairs.map(([x]) => x);
  const ys = pairs.map(([, y]) => y);
  const xMean = mean(xs);
  const yMean = mean(ys);
  const covariance = pairs.reduce((sum, [x, y]) => sum + (x - xMean) * (y - yMean), 0);
  const xVariance = xs.reduce((sum, x) => sum + (x - xMean) ** 2, 0);
  const yVariance = ys.reduce((sum, y) => sum + (y - yMean) ** 2, 0);
  const beta = xVariance > 0 ? covariance / xVariance : null;
  const alpha = Number.isFinite(beta) ? yMean - beta * xMean : null;
  const correlation = xVariance > 0 && yVariance > 0 ? covariance / Math.sqrt(xVariance * yVariance) : null;
  return {
    n: pairs.length,
    alpha,
    beta,
    correlation,
    r2: Number.isFinite(correlation) ? correlation ** 2 : null,
  };
}

function previousIndexOnOrBefore(series, date) {
  const exact = series.byDate.get(date);
  if (exact) return exact.index;
  for (let index = series.rows.length - 1; index >= 0; index -= 1) {
    if (series.rows[index].date <= date) return index;
  }
  return -1;
}

function trailingReturn(series, date, sessions = 20) {
  const index = previousIndexOnOrBefore(series, date);
  if (index < sessions) return null;
  return safeReturn(series.rows[index].close, series.rows[index - sessions].close);
}

function trailingVolatility(series, date, sessions = 20) {
  const index = previousIndexOnOrBefore(series, date);
  if (index < sessions) return null;
  const returns = [];
  for (let cursor = index - sessions + 1; cursor <= index; cursor += 1) {
    returns.push(Math.log(series.rows[cursor].close / series.rows[cursor - 1].close));
  }
  const daily = standardDeviation(returns);
  return Number.isFinite(daily) ? daily * Math.sqrt(252) : null;
}

function level(series, date, divisor = 1) {
  const index = previousIndexOnOrBefore(series, date);
  return index >= 0 ? series.rows[index].close / divisor : null;
}

function macroFeatures(seriesByKey, date) {
  return {
    googl20: trailingReturn(seriesByKey.GOOGL, date),
    qqq20: trailingReturn(seriesByKey.QQQ, date),
    soxx20: trailingReturn(seriesByKey.SOXX, date),
    mu20: trailingReturn(seriesByKey.MU, date),
    tlt20: trailingReturn(seriesByKey.TLT, date),
    hyg20: trailingReturn(seriesByKey.HYG, date),
    gld20: trailingReturn(seriesByKey.GLD, date),
    uso20: trailingReturn(seriesByKey.USO, date),
    uup20: trailingReturn(seriesByKey.UUP, date),
    vix: level(seriesByKey.VIX, date),
    tenYearYield: level(seriesByKey.TNX, date),
    soxxVol20: trailingVolatility(seriesByKey.SOXX, date),
  };
}

function robustScales(rows, keys) {
  return Object.fromEntries(
    keys.map((key) => {
      const values = rows.map((row) => row.features[key]).filter(Number.isFinite);
      const center = median(values);
      const mad = median(values.map((value) => Math.abs(value - center)));
      const scale = Number.isFinite(mad) && mad > 1e-12 ? 1.4826 * mad : standardDeviation(values);
      return [key, { center, scale }];
    }),
  );
}

function analogDistance(features, current, scales, keys) {
  const contributions = [];
  for (const key of keys) {
    const left = features[key];
    const right = current[key];
    const scale = scales[key]?.scale;
    if (![left, right, scale].every(Number.isFinite) || scale <= 0) continue;
    contributions.push(((left - right) / scale) ** 2);
  }
  return {
    dimensions: contributions.length,
    // Cross-regime ranking is only comparable when every declared macro/market
    // dimension exists. Earlier events remain in unconditional statistics but
    // are not allowed to look artificially close because oil/USD/credit is blank.
    distance: contributions.length === keys.length ? Math.sqrt(mean(contributions)) : null,
  };
}

function predictionDiagnostics(records) {
  const clean = records.filter(
    (row) =>
      Number.isFinite(row.actual) &&
      Number.isFinite(row.predictedMean) &&
      Number.isFinite(row.predictedProbability) &&
      Number.isFinite(row.baselineMean) &&
      Number.isFinite(row.baselineProbability),
  );
  const average = (selector) =>
    clean.length
      ? clean.reduce((sum, row) => sum + selector(row), 0) / clean.length
      : null;
  return {
    n: clean.length,
    analogBrier: average(
      (row) => (row.predictedProbability - (row.actual > 0 ? 1 : 0)) ** 2,
    ),
    baselineBrier: average(
      (row) => (row.baselineProbability - (row.actual > 0 ? 1 : 0)) ** 2,
    ),
    analogDirectionAccuracy: average(
      (row) => ((row.predictedProbability >= 0.5) === (row.actual > 0) ? 1 : 0),
    ),
    baselineDirectionAccuracy: average(
      (row) => ((row.baselineProbability >= 0.5) === (row.actual > 0) ? 1 : 0),
    ),
    analogMeanAbsoluteError: average((row) => Math.abs(row.predictedMean - row.actual)),
    baselineMeanAbsoluteError: average((row) => Math.abs(row.baselineMean - row.actual)),
    firstForecastDate: clean[0]?.acceptanceEtDate || null,
    lastForecastDate: clean.at(-1)?.acceptanceEtDate || null,
  };
}

function csvEscape(value) {
  if (value === null || value === undefined) return '';
  const text = typeof value === 'number' ? String(value) : String(value);
  return /[",\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

function percentage(value, digits = 2) {
  return Number.isFinite(value) ? `${(value * 100).toFixed(digits)}%` : 'NA';
}

function number(value, digits = 2) {
  return Number.isFinite(value) ? value.toFixed(digits) : 'NA';
}

function buildEventCsv(events) {
  const headers = [
    'acceptance_utc',
    'acceptance_et_date',
    'reaction_date',
    'issuer',
    'accession',
    'sec_filing_url',
    ...EVENT_ASSETS.flatMap((asset) => [
      `${asset}_gap`,
      `${asset}_1d`,
      `${asset}_5d`,
      `${asset}_20d`,
      `${asset}_excess_qqq_1d`,
      `${asset}_excess_qqq_5d`,
      `${asset}_excess_qqq_20d`,
    ]),
  ];
  const lines = [headers.join(',')];
  for (const event of events) {
    const row = [
      event.acceptance,
      event.acceptanceEtDate,
      event.reactionDate,
      event.issuer,
      event.accession,
      event.filingUrl,
    ];
    for (const asset of EVENT_ASSETS) {
      const window = event.windows[asset];
      row.push(
        window?.gap,
        window?.ret1,
        window?.ret5,
        window?.ret20,
        event.excess[asset]?.ret1,
        event.excess[asset]?.ret5,
        event.excess[asset]?.ret20,
      );
    }
    lines.push(row.map(csvEscape).join(','));
  }
  return `${lines.join('\n')}\n`;
}

function summaryTable(summary, metric = 'ret1') {
  const lines = [
    '| Asset | N | Mean | Median | Positive | Bootstrap mean 95% CI |',
    '|---|---:|---:|---:|---:|---:|',
  ];
  for (const asset of EVENT_ASSETS) {
    const value = summary[asset][metric];
    lines.push(
      `| ${asset} | ${value.n} | ${percentage(value.mean)} | ${percentage(value.median)} | ${percentage(value.positiveRate, 1)} | ${percentage(value.bootstrap95[0])} to ${percentage(value.bootstrap95[1])} |`,
    );
  }
  return lines.join('\n');
}

function buildMarkdown(report) {
  const lines = [];
  lines.push('# Alphabet earnings event study');
  lines.push('');
  lines.push(
    `Run as-of: **${report.asOf}**. Market data frozen through: **${report.marketDataThrough}**. Forecast event excluded on/after: **${report.forecastEventDate || 'not set'}**. Historical completed events: **${report.completedEventCount}**.`,
  );
  lines.push('');
  lines.push('## What this run measures');
  lines.push('');
  lines.push(
    'An event is an official SEC 8-K containing Item 2.02, after three primary-document-audited exclusions (two non-quarterly updates and one duplicate transition filing). When the SEC acceptance time is at or after 16:00 New York time, the reaction session is the next trading day. Returns use adjusted closes from the close before the reaction session through 1, 5, or 20 trading sessions. Gap return uses the adjusted reaction-session open. Excess return is the asset return minus QQQ over the same window (QQQ itself is measured against SPY).',
  );
  lines.push('');
  lines.push('Audited exclusions:');
  lines.push('');
  for (const exclusion of report.secExclusions) {
    lines.push(
      `- ${exclusion.acceptance.slice(0, 10)} / [${exclusion.accession}](${exclusion.filingUrl}): ${exclusion.reason}`,
    );
  }
  lines.push('');
  lines.push('## Data coverage');
  lines.push('');
  lines.push('| Series | First | Last | Daily rows | Role |');
  lines.push('|---|---|---|---:|---|');
  for (const item of report.coverage) {
    lines.push(`| ${item.key} | ${item.first || 'NA'} | ${item.last || 'NA'} | ${item.rows} | ${item.role} |`);
  }
  lines.push('');
  lines.push('## First tradable reaction: adjusted opening gap');
  lines.push('');
  lines.push(summaryTable(report.gapSummary, 'gap'));
  lines.push('');
  lines.push('## Unconditional reaction: raw 1-day close-to-close');
  lines.push('');
  lines.push(summaryTable(report.summary, 'ret1'));
  lines.push('');
  lines.push('## Unconditional reaction: raw 5-session cumulative');
  lines.push('');
  lines.push(summaryTable(report.summary, 'ret5'));
  lines.push('');
  lines.push('## Excess reaction versus QQQ (QQQ versus SPY): 1 day');
  lines.push('');
  lines.push(summaryTable(report.excessSummary, 'ret1'));
  lines.push('');
  lines.push('## AI-infrastructure comparable slice (2023 Q2 onward)');
  lines.push('');
  lines.push(
    `This is a small **n=${report.subperiods.aiInfrastructureEra.eventCount}** sensitivity slice beginning with the July 25, 2023 Q2 release, when Alphabet's Cloud and AI-infrastructure CapEx became a materially more direct semiconductor-demand signal. It is descriptive and has much wider uncertainty than the full history.`,
  );
  lines.push('');
  lines.push('| Asset | N | Mean 1d | Positive 1d | Mean 5d |');
  lines.push('|---|---:|---:|---:|---:|');
  for (const asset of EVENT_ASSETS) {
    const item = report.subperiods.aiInfrastructureEra.assets[asset];
    lines.push(
      `| ${asset} | ${item.ret1.n} | ${percentage(item.ret1.mean)} | ${percentage(item.ret1.positiveRate, 1)} | ${percentage(item.ret5.mean)} |`,
    );
  }
  lines.push('');
  lines.push('## Current pre-event market state');
  lines.push('');
  lines.push(`Latest completed session: **${report.currentSnapshot.date}**.`);
  lines.push('');
  lines.push('| Series | Adjusted close | 20-session move |');
  lines.push('|---|---:|---:|');
  for (const asset of ['GOOGL', 'QQQ', 'SOXX', 'MU', 'SNDK']) {
    lines.push(
      `| ${asset} | ${number(report.currentSnapshot.prices[asset], 2)} | ${percentage(report.currentSnapshot.displayReturns20[asset])} |`,
    );
  }
  lines.push('');
  lines.push('| Macro proxy | Current value | 20-session move |');
  lines.push('|---|---:|---:|');
  lines.push(`| VIX | ${number(report.currentSnapshot.features.vix, 2)} | NA |`);
  lines.push(`| 10-year yield | ${number(report.currentSnapshot.features.tenYearYield, 3)}% | NA |`);
  lines.push(`| SOXX realized volatility | ${percentage(report.currentSnapshot.features.soxxVol20, 1)} annualized | NA |`);
  lines.push(`| Oil / USO | ${number(report.currentSnapshot.prices.USO, 2)} | ${percentage(report.currentSnapshot.features.uso20)} |`);
  lines.push(`| Gold / GLD | ${number(report.currentSnapshot.prices.GLD, 2)} | ${percentage(report.currentSnapshot.features.gld20)} |`);
  lines.push(`| USD / UUP | ${number(report.currentSnapshot.prices.UUP, 2)} | ${percentage(report.currentSnapshot.features.uup20)} |`);
  lines.push(`| Duration / TLT | ${number(report.currentSnapshot.prices.TLT, 2)} | ${percentage(report.currentSnapshot.features.tlt20)} |`);
  lines.push(`| High yield / HYG | ${number(report.currentSnapshot.prices.HYG, 2)} | ${percentage(report.currentSnapshot.features.hyg20)} |`);
  lines.push('');
  lines.push('## Transmission from Alphabet move');
  lines.push('');
  lines.push('| Asset | N | Slope to GOOGL 1d | Correlation | R^2 | Mean if GOOGL up | Mean if GOOGL down |');
  lines.push('|---|---:|---:|---:|---:|---:|---:|');
  for (const asset of EVENT_ASSETS.filter((value) => value !== 'GOOGL')) {
    const item = report.transmission[asset];
    lines.push(
      `| ${asset} | ${item.regression.n} | ${number(item.regression.beta, 3)} | ${number(item.regression.correlation, 3)} | ${number(item.regression.r2, 3)} | ${percentage(item.googleUp.mean)} (n=${item.googleUp.n}) | ${percentage(item.googleDown.mean)} (n=${item.googleDown.n}) |`,
    );
  }
  lines.push('');
  lines.push(`## Pre-event macro/market analogs to ${report.currentSnapshot.date}`);
  lines.push('');
  lines.push(
    `The distance uses the close immediately before each historical release date, matching the current snapshot one session before the July 22 release. Inputs are 20-session moves in GOOGL, QQQ, SOXX, MU, TLT, HYG, GLD, USO and UUP; VIX and 10-year yield levels; and SOXX 20-session realized volatility. Each feature is robustly scaled by the historical event median/MAD. Top-k=${report.analogs.k}; kernel effective sample size=${number(report.analogs.ess, 2)}.`,
  );
  lines.push('');
  lines.push('| Rank | Filing acceptance (ET date) | Reaction | Distance | Dims | GOOGL 1d | SOXX 1d | MU 1d | QQQ 1d |');
  lines.push('|---:|---|---|---:|---:|---:|---:|---:|---:|');
  report.analogs.top.forEach((item, index) => {
    lines.push(
      `| ${index + 1} | ${item.acceptanceEtDate} | ${item.reactionDate} | ${number(item.distance, 3)} | ${item.dimensions} | ${percentage(item.returns.GOOGL)} | ${percentage(item.returns.SOXX)} | ${percentage(item.returns.MU)} | ${percentage(item.returns.QQQ)} |`,
    );
  });
  lines.push('');
  lines.push('### Kernel-weighted analog forecast (historical distribution, not a guarantee)');
  lines.push('');
  lines.push('| Asset | Horizon | Weighted mean | Positive probability | P10 | Median | P90 | Analog N |');
  lines.push('|---|---:|---:|---:|---:|---:|---:|---:|');
  for (const item of report.analogs.forecast) {
    lines.push(
      `| ${item.asset} | ${item.horizon}d | ${percentage(item.weightedMean)} | ${percentage(item.positiveProbability, 1)} | ${percentage(item.p10)} | ${percentage(item.p50)} | ${percentage(item.p90)} | ${item.n} |`,
    );
  }
  lines.push('');
  lines.push('## Expanding-window analog validation');
  lines.push('');
  lines.push('Each historical forecast below was produced with earlier, fully matured events only. Robust scales and neighbors were re-fit at every step. Lower Brier score is better; positive Brier skill means the analog beat the expanding unconditional baseline.');
  lines.push('');
  lines.push('| Asset | Horizon | OOS N | Analog Brier | Baseline Brier | Brier skill | Analog direction | Baseline direction |');
  lines.push('|---|---:|---:|---:|---:|---:|---:|---:|');
  for (const asset of EVENT_ASSETS) {
    for (const horizon of [1, 5]) {
      const item = report.walkForwardValidation[asset][`ret${horizon}`];
      const skill =
        Number.isFinite(item.baselineBrier) && Number.isFinite(item.analogBrier)
          ? item.baselineBrier - item.analogBrier
          : null;
      lines.push(
        `| ${asset} | ${horizon}d | ${item.n} | ${number(item.analogBrier, 4)} | ${number(item.baselineBrier, 4)} | ${number(skill, 4)} | ${percentage(item.analogDirectionAccuracy, 1)} | ${percentage(item.baselineDirectionAccuracy, 1)} |`,
      );
    }
  }
  lines.push('');
  lines.push('## All completed Alphabet/Google earnings events');
  lines.push('');
  lines.push('| SEC acceptance (ET date) | Reaction session | GOOGL 1d | QQQ 1d | SOXX 1d | MU 1d | SNDK 1d | WDC 1d | STX 1d |');
  lines.push('|---|---|---:|---:|---:|---:|---:|---:|---:|');
  for (const event of report.events) {
    lines.push(
      `| [${event.acceptanceEtDate}](${event.filingUrl}) | ${event.reactionDate} | ${percentage(event.windows.GOOGL?.ret1)} | ${percentage(event.windows.QQQ?.ret1)} | ${percentage(event.windows.SOXX?.ret1)} | ${percentage(event.windows.MU?.ret1)} | ${percentage(event.windows.SNDK?.ret1)} | ${percentage(event.windows.WDC?.ret1)} | ${percentage(event.windows.STX?.ret1)} |`,
    );
  }
  lines.push('');
  lines.push('## Interpretation limits');
  lines.push('');
  lines.push('- This is an exploratory event study, not an execution backtest and not investment advice. It does not include bid/ask, slippage, options implied volatility or tradability at the post-release price.');
  lines.push('- Yahoo adjusted daily bars are convenient public historical context, not the workspace\'s licensed point-in-time feed. The local Massive account rejected a 2005 probe (HTTP 403) and its existing minute data starts in July 2024, so it cannot validate this 20-year daily study.');
  lines.push('- SEC Item 2.02 identifies release timing, but there is no licensed historical consensus, CapEx guidance surprise, Cloud revenue surprise, or transcript sentiment history. Therefore this run measures total announcement association, not causal impact of CapEx alone.');
  lines.push('- SNDK in the downloaded series begins with the 2025 standalone listing. It must not be spliced to the pre-2016 SanDisk security. WDC and STX are shown as imperfect storage proxies, not replacements for SNDK.');
  lines.push('- Direct SNDK analog output is suppressed when fewer than five comparable observations survive the similarity filter; a one-event 100% hit rate is not evidence.');
  lines.push('- Overlapping 5- and 20-session windows, changing index constituents, ETF methodology, post-2014 share-class history, and repeated macro regimes make observations dependent. Bootstrap intervals resample earnings events and should be treated as descriptive uncertainty.');
  lines.push('- The analog ranking is point-in-time on market prices, rates and proxies, but it does not encode wars/news as categorical labels; their effects enter only insofar as VIX, rates, oil, gold, USD, credit and price/volatility proxies reflected them.');
  lines.push('');
  lines.push('## Source endpoints');
  lines.push('');
  lines.push('- [SEC Alphabet submissions](https://data.sec.gov/submissions/CIK0001652044.json) and [SEC Google Inc. submissions](https://data.sec.gov/submissions/CIK0001288776.json), plus their official history files.');
  lines.push('- Yahoo chart: `https://query1.finance.yahoo.com/v8/finance/chart/{ticker}`.');
  lines.push('');
  return `${lines.join('\n')}\n`;
}

async function main() {
  await fs.mkdir(REPORT_DIR, { recursive: true });
  const sec = await loadSecEarningsEvents();
  const events = sec.events;
  const seriesByKey = {};
  for (const [key, ticker] of Object.entries(SYMBOLS)) {
    seriesByKey[key] = await loadYahooSeries(ticker);
    await sleep(100);
  }
  const calendar = seriesByKey.QQQ;
  const withSessions = attachReactionSessions(events, calendar);
  const completed = [];
  for (const event of withSessions) {
    if (!event.reactionDate) continue;
    const windows = Object.fromEntries(
      EVENT_ASSETS.map((asset) => [asset, eventWindow(seriesByKey[asset], event.reactionDate)]),
    );
    if (!Number.isFinite(windows.GOOGL?.ret1) || !Number.isFinite(windows.QQQ?.ret1)) continue;
    const excess = {};
    for (const asset of EVENT_ASSETS) {
      const benchmark = asset === 'QQQ' ? windows.SPY : windows.QQQ;
      excess[asset] = Object.fromEntries(
        HORIZONS.map((horizon) => {
          const value = windows[asset]?.[`ret${horizon}`];
          const benchmarkValue = benchmark?.[`ret${horizon}`];
          return [`ret${horizon}`, Number.isFinite(value) && Number.isFinite(benchmarkValue) ? value - benchmarkValue : null];
        }),
      );
    }
    completed.push({ ...event, windows, excess });
  }

  const summary = {};
  const excessSummary = {};
  const gapSummary = {};
  for (const [assetIndex, asset] of EVENT_ASSETS.entries()) {
    summary[asset] = {};
    excessSummary[asset] = {};
    gapSummary[asset] = {
      gap: summarize(
        completed.map((event) => event.windows[asset]?.gap),
        500 + assetIndex,
      ),
    };
    for (const [horizonIndex, horizon] of HORIZONS.entries()) {
      summary[asset][`ret${horizon}`] = summarize(
        completed.map((event) => event.windows[asset]?.[`ret${horizon}`]),
        1000 + assetIndex * 100 + horizonIndex,
      );
      excessSummary[asset][`ret${horizon}`] = summarize(
        completed.map((event) => event.excess[asset]?.[`ret${horizon}`]),
        5000 + assetIndex * 100 + horizonIndex,
      );
    }
  }

  const googleMoves = completed.map((event) => event.windows.GOOGL?.ret1);
  const transmission = {};
  for (const asset of EVENT_ASSETS.filter((value) => value !== 'GOOGL')) {
    const assetMoves = completed.map((event) => event.windows[asset]?.ret1);
    transmission[asset] = {
      regression: ols(googleMoves, assetMoves),
      googleUp: summarize(
        completed
          .filter((event) => event.windows.GOOGL?.ret1 > 0)
          .map((event) => event.windows[asset]?.ret1),
        8000 + EVENT_ASSETS.indexOf(asset),
      ),
      googleDown: summarize(
        completed
          .filter((event) => event.windows.GOOGL?.ret1 < 0)
          .map((event) => event.windows[asset]?.ret1),
        9000 + EVENT_ASSETS.indexOf(asset),
      ),
    };
  }

  const aiEraEvents = completed.filter(
    (event) => event.acceptanceEtDate >= AI_INFRASTRUCTURE_ERA_START,
  );
  const aiEraAssets = {};
  for (const [assetIndex, asset] of EVENT_ASSETS.entries()) {
    aiEraAssets[asset] = {
      ret1: summarize(
        aiEraEvents.map((event) => event.windows[asset]?.ret1),
        11_000 + assetIndex,
      ),
      ret5: summarize(
        aiEraEvents.map((event) => event.windows[asset]?.ret5),
        12_000 + assetIndex,
      ),
    };
  }

  const currentDate = calendar.rows.filter((row) => row.date <= MARKET_DATA_THROUGH).at(-1)?.date;
  const currentFeatures = macroFeatures(seriesByKey, currentDate);
  const eventFeatureRows = completed
    .map((event) => {
      // The current run only has the July 21 close before the July 22 release.
      // Freeze every historical comparison at the same relative information
      // boundary instead of mixing in announcement-day price action.
      const priorDate = lastTradingDateBefore(calendar, event.acceptanceEtDate);
      return priorDate ? { event, priorDate, features: macroFeatures(seriesByKey, priorDate) } : null;
    })
    .filter(Boolean);
  const featureKeys = Object.keys(currentFeatures);
  const completeFeatureRows = eventFeatureRows.filter((row) =>
    featureKeys.every((key) => Number.isFinite(row.features[key])),
  );

  // Expanding-window validation: every forecast is built only from earlier
  // earnings events whose five-session outcome had already matured. Scaling,
  // neighbor selection and the unconditional comparison are re-fit at each
  // step, so the diagnostics do not reuse future regime information.
  const validationRecords = Object.fromEntries(
    EVENT_ASSETS.map((asset) => [
      asset,
      Object.fromEntries([1, 5].map((horizon) => [`ret${horizon}`, []])),
    ]),
  );
  for (let queryIndex = 0; queryIndex < completeFeatureRows.length; queryIndex += 1) {
    const query = completeFeatureRows[queryIndex];
    const trainingRows = completeFeatureRows
      .slice(0, queryIndex)
      .filter(
        (row) =>
          row.event.windows.GOOGL?.endDate5 &&
          row.event.windows.GOOGL.endDate5 < query.priorDate,
      );
    if (trainingRows.length < 20) continue;
    const trainingScales = robustScales(trainingRows, featureKeys);
    const candidates = trainingRows
      .map((row) => ({
        ...row,
        ...analogDistance(row.features, query.features, trainingScales, featureKeys),
      }))
      .filter((row) => Number.isFinite(row.distance))
      .sort((left, right) => left.distance - right.distance);
    const localK = Math.min(12, candidates.length);
    const neighbors = candidates.slice(0, localK);
    if (neighbors.length < 5) continue;
    const localBandwidth = median(neighbors.map((row) => row.distance)) || 1;
    const localRawWeights = neighbors.map((row) =>
      Math.exp(-0.5 * (row.distance / localBandwidth) ** 2),
    );
    const localWeightTotal = localRawWeights.reduce((sum, value) => sum + value, 0);
    if (!(localWeightTotal > 0)) continue;
    const localWeights = localRawWeights.map((value) => value / localWeightTotal);

    for (const asset of EVENT_ASSETS) {
      for (const horizon of [1, 5]) {
        const field = `ret${horizon}`;
        const actual = query.event.windows[asset]?.[field];
        const neighborObservations = neighbors
          .map((row, index) => ({
            value: row.event.windows[asset]?.[field],
            weight: localWeights[index],
          }))
          .filter((row) => Number.isFinite(row.value));
        const baselineValues = trainingRows
          .map((row) => row.event.windows[asset]?.[field])
          .filter(Number.isFinite);
        const survivingWeight = neighborObservations.reduce(
          (sum, row) => sum + row.weight,
          0,
        );
        if (
          !Number.isFinite(actual) ||
          neighborObservations.length < 5 ||
          baselineValues.length < 20 ||
          !(survivingWeight > 0)
        ) {
          continue;
        }
        validationRecords[asset][field].push({
          acceptanceEtDate: query.event.acceptanceEtDate,
          actual,
          predictedMean:
            neighborObservations.reduce(
              (sum, row) => sum + row.value * row.weight,
              0,
            ) / survivingWeight,
          predictedProbability:
            neighborObservations.reduce(
              (sum, row) => sum + (row.value > 0 ? row.weight : 0),
              0,
            ) / survivingWeight,
          baselineMean: mean(baselineValues),
          baselineProbability:
            (baselineValues.filter((value) => value > 0).length + 0.5) /
            (baselineValues.length + 1),
        });
      }
    }
  }
  const walkForwardValidation = Object.fromEntries(
    EVENT_ASSETS.map((asset) => [
      asset,
      Object.fromEntries(
        [1, 5].map((horizon) => [
          `ret${horizon}`,
          predictionDiagnostics(validationRecords[asset][`ret${horizon}`]),
        ]),
      ),
    ]),
  );

  const scales = robustScales(completeFeatureRows, featureKeys);
  const ranked = completeFeatureRows
    .map((row) => ({ ...row, ...analogDistance(row.features, currentFeatures, scales, featureKeys) }))
    .filter((row) => Number.isFinite(row.distance))
    .sort((left, right) => left.distance - right.distance);
  const k = Math.min(12, ranked.length);
  const topRows = ranked.slice(0, k);
  const bandwidth = median(topRows.map((row) => row.distance)) || 1;
  const rawWeights = topRows.map((row) => Math.exp(-0.5 * (row.distance / bandwidth) ** 2));
  const weightTotal = rawWeights.reduce((sum, value) => sum + value, 0);
  const weights = rawWeights.map((value) => value / weightTotal);
  const ess = 1 / weights.reduce((sum, value) => sum + value ** 2, 0);
  const analogForecast = [];
  for (const asset of ['GOOGL', 'QQQ', 'SPY', 'SOXX', 'MU', 'SNDK', 'WDC', 'STX']) {
    for (const horizon of [1, 5]) {
      const observations = topRows
        .map((row, index) => ({ value: row.event.windows[asset]?.[`ret${horizon}`], weight: weights[index] }))
        .filter((row) => Number.isFinite(row.value));
      const localWeight = observations.reduce((sum, row) => sum + row.weight, 0);
      const forecastEligible = observations.length >= 5 && localWeight > 0;
      analogForecast.push({
        asset,
        horizon,
        n: observations.length,
        status: forecastEligible ? 'DESCRIPTIVE_ANALOG' : 'INSUFFICIENT_DIRECT_HISTORY',
        weightedMean: forecastEligible
          ? observations.reduce((sum, row) => sum + row.value * row.weight, 0) / localWeight
          : null,
        positiveProbability: forecastEligible
          ? observations.reduce((sum, row) => sum + (row.value > 0 ? row.weight : 0), 0) / localWeight
          : null,
        p10: forecastEligible ? weightedQuantile(observations, 0.1) : null,
        p50: forecastEligible ? weightedQuantile(observations, 0.5) : null,
        p90: forecastEligible ? weightedQuantile(observations, 0.9) : null,
      });
    }
  }

  const coverageRoles = {
    GOOGL: 'issuer event return',
    SPY: 'broad-market benchmark',
    QQQ: 'growth benchmark',
    SOXX: 'semiconductor ETF',
    MU: 'memory semiconductor',
    SNDK: 'current standalone SanDisk only',
    WDC: 'storage proxy',
    STX: 'storage proxy',
    VIX: 'risk regime feature',
    TNX: '10-year yield proxy',
    TLT: 'duration feature',
    HYG: 'credit-risk feature',
    GLD: 'gold feature',
    USO: 'oil feature',
    UUP: 'USD feature',
  };
  const coverage = Object.entries(seriesByKey).map(([key, series]) => ({
    key,
    ticker: series.ticker,
    first: series.rows[0]?.date || null,
    last: series.rows.at(-1)?.date || null,
    rows: series.rows.length,
    role: coverageRoles[key],
  }));

  const report = {
    schemaVersion: 'alphabet-earnings-event-study-v1',
    generatedAt: new Date().toISOString(),
    asOf: AS_OF,
    forecastEventDate: FORECAST_EVENT_DATE,
    marketDataThrough: MARKET_DATA_THROUGH,
    start: START,
    secEventDefinition: '8-K Item 2.02, reaction session assigned from official SEC acceptance timestamp',
    priceDefinition: 'Yahoo adjusted daily OHLC; close before reaction through 1/5/20 sessions',
    bootstrapSamples: BOOTSTRAP_SAMPLES,
    secItem202Count: sec.item202.length,
    secEventCount: events.length,
    secExclusions: sec.exclusions,
    forecastBoundaryExclusions: sec.forecastBoundaryExclusions,
    completedEventCount: completed.length,
    coverage,
    summary,
    gapSummary,
    excessSummary,
    subperiods: {
      aiInfrastructureEra: {
        start: AI_INFRASTRUCTURE_ERA_START,
        eventCount: aiEraEvents.length,
        assets: aiEraAssets,
      },
    },
    transmission,
    currentSnapshot: {
      date: currentDate,
      features: currentFeatures,
      prices: Object.fromEntries(
        Object.keys(SYMBOLS).map((key) => [key, level(seriesByKey[key], currentDate)]),
      ),
      displayReturns20: Object.fromEntries(
        Object.keys(SYMBOLS).map((key) => [key, trailingReturn(seriesByKey[key], currentDate)]),
      ),
    },
    analogs: {
      featureKeys,
      k,
      bandwidth,
      ess,
      top: topRows.map((row) => ({
        acceptanceEtDate: row.event.acceptanceEtDate,
        reactionDate: row.event.reactionDate,
        distance: row.distance,
        dimensions: row.dimensions,
        priorDate: row.priorDate,
        weight: weights[topRows.indexOf(row)],
        features: row.features,
        returns: Object.fromEntries(
          ['GOOGL', 'QQQ', 'SPY', 'SOXX', 'MU', 'SNDK', 'WDC', 'STX'].map((asset) => [
            asset,
            row.event.windows[asset]?.ret1 ?? null,
          ]),
        ),
      })),
      forecast: analogForecast,
    },
    walkForwardValidation,
    regimeFeatureRows: completeFeatureRows.map((row) => ({
      acceptanceEtDate: row.event.acceptanceEtDate,
      reactionDate: row.event.reactionDate,
      priorDate: row.priorDate,
      features: row.features,
      returns: Object.fromEntries(
        EVENT_ASSETS.map((asset) => [
          asset,
          {
            ret1: row.event.windows[asset]?.ret1 ?? null,
            ret5: row.event.windows[asset]?.ret5 ?? null,
          },
        ]),
      ),
    })),
    events: completed,
    limitations: [
      'No historical point-in-time earnings/CapEx/Cloud consensus or surprise fields.',
      'No options/NBBO or transaction-cost execution simulation.',
      'Yahoo public daily series is exploratory and not licensed point-in-time evidence.',
      'SNDK current listing is not continuous with pre-2016 SanDisk; WDC/STX are imperfect proxies.',
      'Macro/geopolitical effects are represented only through observed market proxies.',
    ],
  };

  const base = `alphabet-earnings-event-study-${AS_OF}`;
  const jsonPath = path.join(REPORT_DIR, `${base}.json`);
  const csvPath = path.join(REPORT_DIR, `${base}-events.csv`);
  const markdownPath = path.join(REPORT_DIR, `${base}.md`);
  await fs.writeFile(jsonPath, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
  await fs.writeFile(csvPath, buildEventCsv(completed), 'utf8');
  await fs.writeFile(markdownPath, buildMarkdown(report), 'utf8');
  console.log(
    JSON.stringify(
      {
        asOf: AS_OF,
        forecastEventDate: FORECAST_EVENT_DATE,
        marketDataThrough: MARKET_DATA_THROUGH,
        secEvents: events.length,
        completedEvents: completed.length,
        currentSnapshotDate: currentDate,
        analogEss: ess,
        outputs: { markdownPath, jsonPath, csvPath },
      },
      null,
      2,
    ),
  );
}

await main();
