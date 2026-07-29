import fs from 'node:fs/promises';
import path from 'node:path';

const SYMBOLS = [
  { name: 'SOXX', yahoo: 'SOXX', start: '2001-01-01', adjusted: true },
  { name: 'SOXL', yahoo: 'SOXL', start: '2010-03-11', adjusted: true },
  { name: 'KOSPI', yahoo: '^KS11', start: '1996-01-01', adjusted: false },
];

const OUT_DIR = path.resolve('reports');
const CASES_CSV = path.join(OUT_DIR, 'bollinger-break-cases.csv');
const SUMMARY_CSV = path.join(OUT_DIR, 'bollinger-break-summary.csv');
const SUMMARY_MD = path.join(OUT_DIR, 'bollinger-break-summary.md');

const HEADERS = {
  accept: 'application/json',
  'user-agent': 'Mozilla/5.0 (compatible; AXIO7-bollinger-backtest/1.0)',
};

function fmtDate(d) {
  return new Date(d * 1000).toISOString().slice(0, 10);
}

function pct(v) {
  return Number.isFinite(v) ? v * 100 : null;
}

function round(v, n = 4) {
  if (v === null || v === undefined || Number.isNaN(v)) return '';
  return Number(v).toFixed(n);
}

function csvEscape(v) {
  if (v === null || v === undefined) return '';
  const s = String(v);
  return /[",\n]/.test(s) ? `"${s.replaceAll('"', '""')}"` : s;
}

function toCsv(rows, columns) {
  return [
    columns.join(','),
    ...rows.map((row) => columns.map((c) => csvEscape(row[c])).join(',')),
  ].join('\n');
}

function mean(xs) {
  const valid = xs.filter((x) => Number.isFinite(x));
  if (!valid.length) return null;
  return valid.reduce((s, x) => s + x, 0) / valid.length;
}

function median(xs) {
  const valid = xs.filter((x) => Number.isFinite(x)).sort((a, b) => a - b);
  if (!valid.length) return null;
  const mid = Math.floor(valid.length / 2);
  return valid.length % 2 ? valid[mid] : (valid[mid - 1] + valid[mid]) / 2;
}

function quantile(xs, q) {
  const valid = xs.filter((x) => Number.isFinite(x)).sort((a, b) => a - b);
  if (!valid.length) return null;
  const pos = (valid.length - 1) * q;
  const lo = Math.floor(pos);
  const hi = Math.ceil(pos);
  if (lo === hi) return valid[lo];
  return valid[lo] + (valid[hi] - valid[lo]) * (pos - lo);
}

function stdevPopulation(xs) {
  const m = mean(xs);
  if (m === null) return null;
  return Math.sqrt(xs.reduce((s, x) => s + (x - m) ** 2, 0) / xs.length);
}

function sma(values, endExclusive, lookback) {
  if (endExclusive < lookback) return null;
  return mean(values.slice(endExclusive - lookback, endExclusive));
}

function computeBands(rows) {
  for (let i = 0; i < rows.length; i += 1) {
    if (i < 19) {
      rows[i].ma20 = null;
      rows[i].lower = null;
      rows[i].upper = null;
      rows[i].sma200 = null;
      continue;
    }
    const window = rows.slice(i - 19, i + 1).map((r) => r.close);
    const ma20 = mean(window);
    const sd = stdevPopulation(window);
    rows[i].ma20 = ma20;
    rows[i].lower = ma20 - 2 * sd;
    rows[i].upper = ma20 + 2 * sd;
    rows[i].sma200 = sma(rows.map((r) => r.close), i + 1, 200);
  }
}

async function fetchYahooDaily(symbol, startDate, adjusted) {
  const period1 = Math.floor(new Date(`${startDate}T00:00:00Z`).getTime() / 1000);
  const period2 = Math.floor(Date.now() / 1000) + 86_400;
  const url =
    `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}` +
    `?period1=${period1}&period2=${period2}&interval=1d&includePrePost=false&events=div%2Csplits`;
  const res = await fetch(url, { headers: HEADERS });
  if (!res.ok) throw new Error(`Yahoo chart ${symbol} HTTP ${res.status}`);
  const json = await res.json();
  const root = json?.chart?.result?.[0];
  if (!root) throw new Error(json?.chart?.error?.description || `No Yahoo data for ${symbol}`);

  const quote = root.indicators?.quote?.[0] || {};
  const adj = root.indicators?.adjclose?.[0]?.adjclose || [];
  const timestamps = root.timestamp || [];
  const rows = [];
  for (let i = 0; i < timestamps.length; i += 1) {
    const rawClose = quote.close?.[i];
    const close = adjusted && Number.isFinite(adj[i]) ? adj[i] : rawClose;
    if (!Number.isFinite(close)) continue;
    rows.push({
      date: fmtDate(timestamps[i]),
      open: quote.open?.[i] ?? null,
      high: quote.high?.[i] ?? null,
      low: quote.low?.[i] ?? null,
      close,
      volume: quote.volume?.[i] ?? null,
    });
  }
  computeBands(rows);
  return {
    rows,
    asOf:
      typeof root.meta?.regularMarketTime === 'number'
        ? new Date(root.meta.regularMarketTime * 1000).toISOString()
        : null,
    currentPrice:
      typeof root.meta?.regularMarketPrice === 'number'
        ? root.meta.regularMarketPrice
        : rows.at(-1)?.close ?? null,
  };
}

function futureReturn(rows, idx, days) {
  const target = rows[idx + days];
  if (!target) return null;
  return target.close / rows[idx].close - 1;
}

function minReturn(rows, idx, days) {
  const future = rows.slice(idx + 1, idx + days + 1);
  if (!future.length) return null;
  return Math.min(...future.map((r) => r.close)) / rows[idx].close - 1;
}

function maxReturn(rows, idx, days) {
  const future = rows.slice(idx + 1, idx + days + 1);
  if (!future.length) return null;
  return Math.max(...future.map((r) => r.close)) / rows[idx].close - 1;
}

function firstHit(rows, idx, maxDays, predicate) {
  for (let j = idx + 1; j <= Math.min(rows.length - 1, idx + maxDays); j += 1) {
    if (predicate(rows[j])) {
      return { date: rows[j].date, days: j - idx, ret: rows[j].close / rows[idx].close - 1 };
    }
  }
  return { date: '', days: null, ret: null };
}

function countConsecutiveBelow(rows, idx) {
  let n = 0;
  for (let j = idx; j < rows.length; j += 1) {
    if (rows[j].lower !== null && rows[j].close < rows[j].lower) n += 1;
    else break;
  }
  return n;
}

function backtest(symbol, rows, startDate) {
  const filtered = rows.filter((r) => r.date >= startDate);
  const offset = rows.length - filtered.length;
  const cases = [];
  for (let i = Math.max(offset, 19); i < rows.length; i += 1) {
    const r = rows[i];
    const prev = rows[i - 1];
    const below = r.lower !== null && r.close < r.lower;
    const prevBelow = prev?.lower !== null && prev.close < prev.lower;
    if (!below || prevBelow) continue;

    const reenter = firstHit(rows, i, 60, (x) => x.lower !== null && x.close >= x.lower);
    const midline = firstHit(rows, i, 60, (x) => x.ma20 !== null && x.close >= x.ma20);
    const up10 = maxReturn(rows, i, 10);
    const down10 = minReturn(rows, i, 10);
    cases.push({
      symbol,
      break_date: r.date,
      close: r.close,
      ma20: r.ma20,
      lower_band: r.lower,
      distance_below_lower_pct: pct(r.close / r.lower - 1),
      trend_regime: r.sma200 === null ? 'no_sma200' : r.close >= r.sma200 ? 'above_sma200' : 'below_sma200',
      consecutive_below_days: countConsecutiveBelow(rows, i),
      ret_1d_pct: pct(futureReturn(rows, i, 1)),
      ret_3d_pct: pct(futureReturn(rows, i, 3)),
      ret_5d_pct: pct(futureReturn(rows, i, 5)),
      ret_10d_pct: pct(futureReturn(rows, i, 10)),
      ret_20d_pct: pct(futureReturn(rows, i, 20)),
      ret_60d_pct: pct(futureReturn(rows, i, 60)),
      max_up_next_10d_pct: pct(up10),
      max_drawdown_next_10d_pct: pct(down10),
      reenter_band_within_60d: reenter.days !== null,
      reenter_band_date: reenter.date,
      days_to_reenter_band: reenter.days,
      return_to_reenter_band_pct: pct(reenter.ret),
      midline_within_60d: midline.days !== null,
      midline_date: midline.date,
      days_to_midline: midline.days,
      return_to_midline_pct: pct(midline.ret),
    });
  }
  return cases;
}

function summarize(cases) {
  const symbols = [...new Set(cases.map((c) => c.symbol))];
  return symbols.map((symbol) => {
    const rows = cases.filter((c) => c.symbol === symbol);
    const reenter = rows.filter((r) => r.reenter_band_within_60d);
    const midline = rows.filter((r) => r.midline_within_60d);
    return {
      symbol,
      cases: rows.length,
      first_case: rows[0]?.break_date || '',
      last_case: rows.at(-1)?.break_date || '',
      reenter_band_60d_rate_pct: pct(reenter.length / rows.length),
      median_days_to_reenter_band: median(reenter.map((r) => r.days_to_reenter_band)),
      midline_60d_rate_pct: pct(midline.length / rows.length),
      median_days_to_midline: median(midline.map((r) => r.days_to_midline)),
      positive_5d_rate_pct: pct(rows.filter((r) => r.ret_5d_pct > 0).length / rows.length),
      positive_10d_rate_pct: pct(rows.filter((r) => r.ret_10d_pct > 0).length / rows.length),
      positive_20d_rate_pct: pct(rows.filter((r) => r.ret_20d_pct > 0).length / rows.length),
      positive_60d_rate_pct: pct(rows.filter((r) => r.ret_60d_pct > 0).length / rows.length),
      median_ret_5d_pct: median(rows.map((r) => r.ret_5d_pct)),
      median_ret_10d_pct: median(rows.map((r) => r.ret_10d_pct)),
      median_ret_20d_pct: median(rows.map((r) => r.ret_20d_pct)),
      median_ret_60d_pct: median(rows.map((r) => r.ret_60d_pct)),
      worst_ret_20d_pct: Math.min(...rows.map((r) => r.ret_20d_pct).filter(Number.isFinite)),
      worst_drawdown_next_10d_pct: Math.min(
        ...rows.map((r) => r.max_drawdown_next_10d_pct).filter(Number.isFinite)
      ),
      q25_ret_20d_pct: quantile(rows.map((r) => r.ret_20d_pct), 0.25),
      q75_ret_20d_pct: quantile(rows.map((r) => r.ret_20d_pct), 0.75),
    };
  });
}

function formatTable(rows, columns) {
  const header = `| ${columns.join(' | ')} |`;
  const sep = `| ${columns.map(() => '---').join(' | ')} |`;
  const body = rows.map((r) => `| ${columns.map((c) => r[c]).join(' | ')} |`);
  return [header, sep, ...body].join('\n');
}

async function main() {
  await fs.mkdir(OUT_DIR, { recursive: true });
  const allCases = [];
  const meta = [];
  for (const symbol of SYMBOLS) {
    console.error(`Fetching ${symbol.name} (${symbol.yahoo})...`);
    const data = await fetchYahooDaily(symbol.yahoo, symbol.start, symbol.adjusted);
    const cases = backtest(symbol.name, data.rows, symbol.start);
    allCases.push(...cases);
    meta.push({
      symbol: symbol.name,
      yahoo: symbol.yahoo,
      bars: data.rows.length,
      first_date: data.rows[0]?.date || '',
      last_date: data.rows.at(-1)?.date || '',
      as_of: data.asOf || '',
      current_price: data.currentPrice ?? '',
      cases: cases.length,
    });
  }

  const summary = summarize(allCases);
  const caseColumns = [
    'symbol',
    'break_date',
    'close',
    'ma20',
    'lower_band',
    'distance_below_lower_pct',
    'trend_regime',
    'consecutive_below_days',
    'ret_1d_pct',
    'ret_3d_pct',
    'ret_5d_pct',
    'ret_10d_pct',
    'ret_20d_pct',
    'ret_60d_pct',
    'max_up_next_10d_pct',
    'max_drawdown_next_10d_pct',
    'reenter_band_within_60d',
    'reenter_band_date',
    'days_to_reenter_band',
    'return_to_reenter_band_pct',
    'midline_within_60d',
    'midline_date',
    'days_to_midline',
    'return_to_midline_pct',
  ];
  const summaryColumns = [
    'symbol',
    'cases',
    'first_case',
    'last_case',
    'reenter_band_60d_rate_pct',
    'median_days_to_reenter_band',
    'midline_60d_rate_pct',
    'median_days_to_midline',
    'positive_5d_rate_pct',
    'positive_10d_rate_pct',
    'positive_20d_rate_pct',
    'positive_60d_rate_pct',
    'median_ret_5d_pct',
    'median_ret_10d_pct',
    'median_ret_20d_pct',
    'median_ret_60d_pct',
    'worst_ret_20d_pct',
    'worst_drawdown_next_10d_pct',
    'q25_ret_20d_pct',
    'q75_ret_20d_pct',
  ];

  const roundedCases = allCases.map((r) => Object.fromEntries(
    Object.entries(r).map(([k, v]) => [k, typeof v === 'number' ? round(v) : v])
  ));
  const roundedSummary = summary.map((r) => Object.fromEntries(
    Object.entries(r).map(([k, v]) => [k, typeof v === 'number' ? round(v) : v])
  ));

  await fs.writeFile(CASES_CSV, `${toCsv(roundedCases, caseColumns)}\n`);
  await fs.writeFile(SUMMARY_CSV, `${toCsv(roundedSummary, summaryColumns)}\n`);

  const mdRows = roundedSummary.map((r) => ({
    symbol: r.symbol,
    cases: r.cases,
    reenter_60d: `${r.reenter_band_60d_rate_pct}%`,
    med_reenter_days: r.median_days_to_reenter_band,
    midline_60d: `${r.midline_60d_rate_pct}%`,
    pos_20d: `${r.positive_20d_rate_pct}%`,
    med_20d: `${r.median_ret_20d_pct}%`,
    worst_20d: `${r.worst_ret_20d_pct}%`,
    worst_10d_dd: `${r.worst_drawdown_next_10d_pct}%`,
  }));
  const md = [
    '# Bollinger Lower-Band Break Backtest',
    '',
    `Generated: ${new Date().toISOString()}`,
    '',
    'Rule: adjusted daily close < 20-day Bollinger lower band (MA20 - 2 * population stdev). Consecutive below-band closes count as one event, using the first break date.',
    '',
    '## Data Pull',
    '',
    formatTable(meta, ['symbol', 'yahoo', 'bars', 'first_date', 'last_date', 'as_of', 'current_price', 'cases']),
    '',
    '## Summary',
    '',
    formatTable(mdRows, [
      'symbol',
      'cases',
      'reenter_60d',
      'med_reenter_days',
      'midline_60d',
      'pos_20d',
      'med_20d',
      'worst_20d',
      'worst_10d_dd',
    ]),
    '',
    `Full case list: ${CASES_CSV}`,
    `Full summary CSV: ${SUMMARY_CSV}`,
    '',
  ].join('\n');
  await fs.writeFile(SUMMARY_MD, md);

  console.log(JSON.stringify({ meta, summary: roundedSummary, files: { CASES_CSV, SUMMARY_CSV, SUMMARY_MD } }, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
