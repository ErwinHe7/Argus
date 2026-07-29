// SEC EDGAR Form 4 (insider transactions) reader.
// 100% public, official SEC data. No paid tier needed.

const SEC_USER_AGENT =
  process.env.SEC_USER_AGENT ||
  process.env.MARKET_SEC_USER_AGENT ||
  'AXIO7 Market Intelligence contact@axio7.com';

// Known CIKs for the watchlist. SEC requires this lookup.
const KNOWN_CIKS: Record<string, string> = {
  AAPL: '0000320193',
  AMD: '0000002488',
  AMZN: '0001018724',
  AVGO: '0001730168',
  COIN: '0001679788',
  GOOGL: '0001652044',
  META: '0001326801',
  MSFT: '0000789019',
  NFLX: '0001065280',
  NVDA: '0001045810',
  PLTR: '0001321655',
  SMCI: '0001375365',
  TSLA: '0001318605',
  MRVL: '0001835632',
  MU: '0000723125',
  INTC: '0000050863',
  QCOM: '0000804328',
  ARM: '0001973239',
  CRM: '0001108524',
  ORCL: '0001341439',
  PANW: '0001327567',
  CRWD: '0001535527',
  DDOG: '0001561550',
  NET: '0001477333',
  SNOW: '0001640147',
  NOW: '0001373715',
  CEG: '0001868275',
  VST: '0001692819',
  ANET: '0001596532',
  COHR: '0000021510',
  LITE: '0001633978',
};

export type InsiderFiling = {
  ticker: string;
  cik: string;
  form: '4' | '4/A';
  accession: string;
  filedAt: string;
  reportDate: string | null;
  url: string;
  primaryDocDescription: string;
};

export type InsiderSummary = {
  ticker: string;
  cik: string;
  totalFilings90d: number;
  totalFilingsAllRecent: number;
  latest: InsiderFiling | null;
  filings: InsiderFiling[];
  reliability: 'ok' | 'unavailable';
  errorMessage?: string;
};

export type InsiderReport = {
  generatedAt: string;
  tickers: string[];
  summaries: InsiderSummary[];
  topRecent: InsiderFiling[];
  reliability: 'ok' | 'partial' | 'unavailable';
  disclaimer: string;
};

type SecSubmission = {
  filings?: {
    recent?: {
      accessionNumber?: string[];
      filingDate?: string[];
      reportDate?: string[];
      form?: string[];
      primaryDocument?: string[];
      primaryDocDescription?: string[];
    };
  };
};

const DEFAULT_TICKERS = [
  'NVDA', 'AMD', 'AVGO', 'TSLA', 'MSFT', 'META', 'GOOGL', 'AMZN', 'AAPL',
  'PLTR', 'SMCI', 'COIN', 'CRWD', 'PANW', 'SNOW', 'NOW', 'CEG', 'VST',
];

export async function buildInsiderReport(input: string[] = DEFAULT_TICKERS): Promise<InsiderReport> {
  const tickers = Array.from(
    new Set(input.map((t) => t.toUpperCase()).filter((t) => KNOWN_CIKS[t]))
  ).slice(0, 25);
  const generatedAt = new Date().toISOString();
  const ninetyDaysAgo = Date.now() - 90 * 24 * 60 * 60 * 1000;

  const results = await Promise.all(
    tickers.map(async (ticker) => {
      try {
        const filings = await fetchForm4(ticker);
        const recent90d = filings.filter((f) => new Date(f.filedAt).getTime() >= ninetyDaysAgo);
        return {
          ticker,
          cik: KNOWN_CIKS[ticker],
          totalFilings90d: recent90d.length,
          totalFilingsAllRecent: filings.length,
          latest: filings[0] || null,
          filings: filings.slice(0, 8),
          reliability: 'ok' as const,
        };
      } catch (err) {
        return {
          ticker,
          cik: KNOWN_CIKS[ticker],
          totalFilings90d: 0,
          totalFilingsAllRecent: 0,
          latest: null,
          filings: [],
          reliability: 'unavailable' as const,
          errorMessage: err instanceof Error ? err.message : 'sec edgar fetch failed',
        };
      }
    })
  );

  const okCount = results.filter((r) => r.reliability === 'ok').length;
  const reliability =
    okCount === results.length ? 'ok' : okCount > 0 ? 'partial' : 'unavailable';

  const topRecent = results
    .flatMap((r) => r.filings)
    .sort((a, b) => new Date(b.filedAt).getTime() - new Date(a.filedAt).getTime())
    .slice(0, 15);

  return {
    generatedAt,
    tickers,
    summaries: results,
    topRecent,
    reliability,
    disclaimer:
      'Form 4 数据直接读自 SEC EDGAR 公开端点，仅展示是否有最新内部人交易申报。提单数 ≠ 净买卖方向，仅作为关注信号。',
  };
}

async function fetchForm4(ticker: string): Promise<InsiderFiling[]> {
  const cik = KNOWN_CIKS[ticker];
  if (!cik) throw new Error(`No CIK mapping for ${ticker}`);
  const url = `https://data.sec.gov/submissions/CIK${cik}.json`;
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), 8000);
  try {
    const res = await fetch(url, {
      cache: 'no-store',
      signal: controller.signal,
      headers: {
        'User-Agent': SEC_USER_AGENT,
        Accept: 'application/json',
      },
    });
    if (!res.ok) throw new Error(`SEC ${res.status}`);
    const data = (await res.json()) as SecSubmission;
    const recent = data.filings?.recent;
    if (!recent?.accessionNumber?.length) return [];

    const out: InsiderFiling[] = [];
    for (let i = 0; i < recent.accessionNumber.length; i += 1) {
      const form = recent.form?.[i];
      if (form !== '4' && form !== '4/A') continue;
      const accession = recent.accessionNumber[i];
      const archiveAccession = accession.replace(/-/g, '');
      const primaryDoc = recent.primaryDocument?.[i] || '';
      const filingUrl = primaryDoc
        ? `https://www.sec.gov/Archives/edgar/data/${Number(cik)}/${archiveAccession}/${primaryDoc}`
        : `https://www.sec.gov/Archives/edgar/data/${Number(cik)}/${archiveAccession}/`;
      out.push({
        ticker,
        cik,
        form: form as '4' | '4/A',
        accession,
        filedAt: recent.filingDate?.[i] || '',
        reportDate: recent.reportDate?.[i] || null,
        url: filingUrl,
        primaryDocDescription: recent.primaryDocDescription?.[i] || 'Form 4',
      });
      if (out.length >= 40) break;
    }
    return out;
  } finally {
    clearTimeout(t);
  }
}
