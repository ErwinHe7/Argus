// SEC 13F institutional holdings reader.
// Pulls the latest public 13F-HR information table for selected institutions
// and looks for the requested ticker by CUSIP / issuer keywords.

const SEC_USER_AGENT =
  process.env.SEC_USER_AGENT ||
  process.env.MARKET_SEC_USER_AGENT ||
  'AXIO7 Market Intelligence contact@axio7.com';

const SEC_TIMEOUT_MS = 12_000;

type Institution = {
  id: string;
  name: string;
  cik: string;
};

const TRACKED_INSTITUTIONS: Institution[] = [
  { id: 'goldman-sachs', name: 'Goldman Sachs', cik: '0000886982' },
  { id: 'jpmorgan', name: 'JPMorgan Chase', cik: '0000019617' },
  { id: 'jane-street', name: 'Jane Street Group', cik: '0001595888' },
  { id: 'citadel', name: 'Citadel Advisors', cik: '0001423053' },
  { id: 'susquehanna', name: 'Susquehanna International', cik: '0001446194' },
  { id: 'renaissance', name: 'Renaissance Technologies', cik: '0001037389' },
];

type TickerLookup = {
  cusips: string[];
  issuerKeywords: string[];
};

const TICKER_LOOKUP: Record<string, TickerLookup> = {
  AAPL: { cusips: ['037833100'], issuerKeywords: ['APPLE'] },
  AMD: { cusips: ['007903107'], issuerKeywords: ['ADVANCED MICRO DEVICES', 'AMD'] },
  AMZN: { cusips: ['023135106'], issuerKeywords: ['AMAZON'] },
  ARM: { cusips: ['042068205'], issuerKeywords: ['ARM HOLDINGS'] },
  ASML: { cusips: ['N07059210', '00207Y102'], issuerKeywords: ['ASML'] },
  AVGO: { cusips: ['11135F101'], issuerKeywords: ['BROADCOM'] },
  COIN: { cusips: ['19260Q107'], issuerKeywords: ['COINBASE'] },
  GOOGL: { cusips: ['02079K305'], issuerKeywords: ['ALPHABET'] },
  GOOG: { cusips: ['02079K107'], issuerKeywords: ['ALPHABET'] },
  META: { cusips: ['30303M102'], issuerKeywords: ['META PLATFORMS'] },
  MSFT: { cusips: ['594918104'], issuerKeywords: ['MICROSOFT'] },
  MSTR: { cusips: ['594972408'], issuerKeywords: ['MICROSTRATEGY'] },
  MU: { cusips: ['595112103'], issuerKeywords: ['MICRON'] },
  NVDA: { cusips: ['67066G104'], issuerKeywords: ['NVIDIA'] },
  ORCL: { cusips: ['68389X105'], issuerKeywords: ['ORACLE'] },
  PLTR: { cusips: ['69608A108'], issuerKeywords: ['PALANTIR'] },
  RKLB: { cusips: ['773122106'], issuerKeywords: ['ROCKET LAB'] },
  SMCI: { cusips: ['86800U104'], issuerKeywords: ['SUPER MICRO'] },
  TSLA: { cusips: ['88160R101'], issuerKeywords: ['TESLA'] },
  TSM: { cusips: ['874039100'], issuerKeywords: ['TAIWAN SEMICONDUCTOR'] },
};

export type InstitutionalHoldingDetail = {
  issuer: string;
  titleOfClass: string;
  cusip: string;
  instrument: 'stock' | 'call' | 'put' | 'other';
  sharesOrPrincipal: number;
  reportedValueUsd: number;
};

export type InstitutionalHoldingDelta = {
  priorFilingDate: string | null;
  priorReportDate: string | null;
  priorAccession: string | null;
  priorStockShares: number;
  priorReportedValueUsd: number;
  shareDelta: number;
  shareDeltaPct: number | null;
  valueDelta: number;
  action: 'new_position' | 'added' | 'reduced' | 'exited' | 'unchanged' | 'unavailable';
};

export type InstitutionalHoldingRow = {
  institutionId: string;
  institutionName: string;
  cik: string;
  status: 'reported' | 'not_reported' | 'unavailable';
  filingDate: string | null;
  reportDate: string | null;
  accession: string | null;
  filingUrl: string | null;
  stockShares: number;
  callEquivalentShares: number;
  putEquivalentShares: number;
  reportedValueUsd: number;
  details: InstitutionalHoldingDetail[];
  delta: InstitutionalHoldingDelta | null;
  errorMessage?: string;
};

export type InstitutionalHoldingsReport = {
  ticker: string;
  generatedAt: string;
  source: 'sec_13f';
  lookup: TickerLookup | null;
  rows: InstitutionalHoldingRow[];
  reliability: 'ok' | 'partial' | 'unavailable';
  disclaimer: string;
};

type SecSubmission = {
  name?: string;
  filings?: {
    recent?: {
      accessionNumber?: string[];
      filingDate?: string[];
      reportDate?: string[];
      form?: string[];
      primaryDocument?: string[];
    };
  };
};

type SecDirectory = {
  directory?: {
    item?: Array<{ name?: string; type?: string; size?: string }>;
  };
};

export async function buildInstitutionalHoldingsReport(rawTicker: string): Promise<InstitutionalHoldingsReport> {
  const ticker = rawTicker.replace(/^\$/, '').toUpperCase();
  const lookup = TICKER_LOOKUP[ticker] || null;

  if (!lookup) {
    return {
      ticker,
      generatedAt: new Date().toISOString(),
      source: 'sec_13f',
      lookup,
      rows: [],
      reliability: 'unavailable',
      disclaimer:
        'No CUSIP mapping for this ticker yet. Add the ticker CUSIP before SEC 13F matching can be reliable.',
    };
  }

  const rows = await Promise.all(
    TRACKED_INSTITUTIONS.map((institution) => fetchInstitutionHolding(institution, ticker, lookup))
  );
  const okCount = rows.filter((row) => row.status === 'reported' || row.status === 'not_reported').length;
  const reliability = okCount === rows.length ? 'ok' : okCount > 0 ? 'partial' : 'unavailable';

  return {
    ticker,
    generatedAt: new Date().toISOString(),
    source: 'sec_13f',
    lookup,
    rows: rows.sort((a, b) => b.reportedValueUsd - a.reportedValueUsd),
    reliability,
    disclaimer:
      'SEC 13F is the latest public institutional filing, not a live position feed. Reports are quarterly and can be delayed up to 45 days; use it as evidence of large-holder exposure, not real-time order flow.',
  };
}

async function fetchInstitutionHolding(
  institution: Institution,
  ticker: string,
  lookup: TickerLookup
): Promise<InstitutionalHoldingRow> {
  try {
    const filings = await recent13Fs(institution, 2);
    if (filings.length === 0) {
      return emptyRow(institution, 'unavailable', 'No recent 13F-HR filing found.');
    }
    const filing = filings[0];

    const infoTableUrl = await findInfoTableUrl(institution.cik, filing.accession);
    if (!infoTableUrl) {
      return emptyRow(institution, 'unavailable', 'No 13F information table XML found.', filing);
    }

    const xml = await secText(infoTableUrl);
    const details = extractTickerHoldings(xml, lookup);

    // Pull prior-quarter snapshot (best effort) for whale-watcher delta.
    let priorSnapshot: { stockShares: number; reportedValueUsd: number; filing: Latest13F } | null = null;
    if (filings.length > 1) {
      const prior = filings[1];
      try {
        const priorXmlUrl = await findInfoTableUrl(institution.cik, prior.accession);
        if (priorXmlUrl) {
          const priorXml = await secText(priorXmlUrl);
          const priorDetails = extractTickerHoldings(priorXml, lookup);
          const priorStock = priorDetails
            .filter((d) => d.instrument === 'stock')
            .reduce((sum, d) => sum + d.sharesOrPrincipal, 0);
          const priorValue = priorDetails.reduce((sum, d) => sum + d.reportedValueUsd, 0);
          priorSnapshot = { stockShares: priorStock, reportedValueUsd: priorValue, filing: prior };
        }
      } catch {
        // Prior-quarter fetch failures are non-fatal — current-quarter data still flows.
      }
    }

    if (details.length === 0) {
      // Not in latest 13F — but if it WAS in the prior quarter, that's an "exit" signal.
      const delta = priorSnapshot && priorSnapshot.stockShares > 0
        ? {
            priorFilingDate: priorSnapshot.filing.filingDate,
            priorReportDate: priorSnapshot.filing.reportDate,
            priorAccession: priorSnapshot.filing.accession,
            priorStockShares: priorSnapshot.stockShares,
            priorReportedValueUsd: priorSnapshot.reportedValueUsd,
            shareDelta: -priorSnapshot.stockShares,
            shareDeltaPct: -1,
            valueDelta: -priorSnapshot.reportedValueUsd,
            action: 'exited' as const,
          }
        : null;
      return {
        ...emptyRow(institution, 'not_reported', undefined, filing),
        filingUrl: filing.filingUrl,
        delta,
      };
    }

    const stockShares = details
      .filter((detail) => detail.instrument === 'stock')
      .reduce((sum, detail) => sum + detail.sharesOrPrincipal, 0);
    const callEquivalentShares = details
      .filter((detail) => detail.instrument === 'call')
      .reduce((sum, detail) => sum + detail.sharesOrPrincipal, 0);
    const putEquivalentShares = details
      .filter((detail) => detail.instrument === 'put')
      .reduce((sum, detail) => sum + detail.sharesOrPrincipal, 0);
    const reportedValueUsd = details.reduce((sum, detail) => sum + detail.reportedValueUsd, 0);

    const delta: InstitutionalHoldingDelta | null = priorSnapshot
      ? buildDelta(priorSnapshot, stockShares, reportedValueUsd)
      : { // first time we have data — treat as new position if prior fetch failed-but-existed
          priorFilingDate: null,
          priorReportDate: null,
          priorAccession: null,
          priorStockShares: 0,
          priorReportedValueUsd: 0,
          shareDelta: stockShares,
          shareDeltaPct: null,
          valueDelta: reportedValueUsd,
          action: 'unavailable',
        };

    return {
      institutionId: institution.id,
      institutionName: institution.name,
      cik: institution.cik,
      status: 'reported',
      filingDate: filing.filingDate,
      reportDate: filing.reportDate,
      accession: filing.accession,
      filingUrl: filing.filingUrl,
      stockShares,
      callEquivalentShares,
      putEquivalentShares,
      reportedValueUsd,
      details,
      delta,
    };
  } catch (err) {
    return emptyRow(institution, 'unavailable', err instanceof Error ? err.message : 'SEC fetch failed.');
  }
}

function buildDelta(
  prior: { stockShares: number; reportedValueUsd: number; filing: Latest13F },
  currentShares: number,
  currentValue: number
): InstitutionalHoldingDelta {
  const shareDelta = currentShares - prior.stockShares;
  const shareDeltaPct = prior.stockShares > 0 ? shareDelta / prior.stockShares : null;
  const valueDelta = currentValue - prior.reportedValueUsd;
  let action: InstitutionalHoldingDelta['action'];
  if (prior.stockShares <= 0 && currentShares > 0) action = 'new_position';
  else if (currentShares <= 0 && prior.stockShares > 0) action = 'exited';
  else if (Math.abs(shareDelta) < Math.max(1, prior.stockShares * 0.005)) action = 'unchanged';
  else if (shareDelta > 0) action = 'added';
  else action = 'reduced';
  return {
    priorFilingDate: prior.filing.filingDate,
    priorReportDate: prior.filing.reportDate,
    priorAccession: prior.filing.accession,
    priorStockShares: prior.stockShares,
    priorReportedValueUsd: prior.reportedValueUsd,
    shareDelta,
    shareDeltaPct,
    valueDelta,
    action,
  };
}

type Latest13F = {
  accession: string;
  filingDate: string;
  reportDate: string | null;
  filingUrl: string;
};

async function latest13F(institution: Institution): Promise<Latest13F | null> {
  const list = await recent13Fs(institution, 1);
  return list[0] || null;
}

async function recent13Fs(institution: Institution, limit: number): Promise<Latest13F[]> {
  const data = await secJson<SecSubmission>(`https://data.sec.gov/submissions/CIK${institution.cik}.json`);
  const recent = data.filings?.recent;
  if (!recent?.form?.length || !recent.accessionNumber?.length) return [];

  const out: Latest13F[] = [];
  const cikNoZeros = institution.cik.replace(/^0+/, '');
  for (let i = 0; i < recent.form.length && out.length < limit; i += 1) {
    const form = recent.form[i];
    if (form !== '13F-HR' && form !== '13F-HR/A') continue;
    const accession = recent.accessionNumber[i];
    if (!accession) continue;
    const archiveAccession = accession.replace(/-/g, '');
    out.push({
      accession,
      filingDate: recent.filingDate?.[i] || '',
      reportDate: recent.reportDate?.[i] || null,
      filingUrl: `https://www.sec.gov/Archives/edgar/data/${cikNoZeros}/${archiveAccession}/`,
    });
  }
  return out;
}

async function findInfoTableUrl(cik: string, accession: string): Promise<string | null> {
  const cikNoZeros = cik.replace(/^0+/, '');
  const archiveAccession = accession.replace(/-/g, '');
  const baseUrl = `https://www.sec.gov/Archives/edgar/data/${cikNoZeros}/${archiveAccession}`;
  const directory = await secJson<SecDirectory>(`${baseUrl}/index.json`);
  const files = directory.directory?.item?.map((item) => item.name || '').filter(Boolean) || [];
  const xmlFiles = files.filter((name) => /\.xml$/i.test(name) && !/primary/i.test(name));
  const preferred =
    xmlFiles.find((name) => /info|table/i.test(name)) ||
    xmlFiles.find((name) => /13f/i.test(name)) ||
    xmlFiles[0];
  return preferred ? `${baseUrl}/${preferred}` : null;
}

function extractTickerHoldings(xml: string, lookup: TickerLookup): InstitutionalHoldingDetail[] {
  const cusips = new Set(lookup.cusips.map((cusip) => normalize(cusip)));
  const issuerKeywords = lookup.issuerKeywords.map((keyword) => normalize(keyword));
  const details: InstitutionalHoldingDetail[] = [];
  const tableRe = /<(?:\w+:)?infoTable\b[^>]*>([\s\S]*?)<\/(?:\w+:)?infoTable>/gi;

  for (const match of xml.matchAll(tableRe)) {
    const block = match[1];
    const issuer = textTag(block, 'nameOfIssuer');
    const titleOfClass = textTag(block, 'titleOfClass');
    const cusip = textTag(block, 'cusip');
    const normalizedCusip = normalize(cusip);
    const normalizedIssuer = normalize(issuer);
    const matchesCusip = cusips.has(normalizedCusip);
    const matchesIssuer =
      issuerKeywords.length > 0 && issuerKeywords.some((keyword) => normalizedIssuer.includes(keyword));

    if (!matchesCusip && !matchesIssuer) continue;

    const putCall = normalize(textTag(block, 'putCall'));
    const instrument =
      putCall === 'CALL' ? 'call' : putCall === 'PUT' ? 'put' : titleOfClass.toUpperCase().includes('CALL') ? 'call' : 'stock';
    const sharesOrPrincipal = numberTag(block, 'sshPrnamt');
    const reportedValueUsd = numberTag(block, 'value');

    details.push({
      issuer,
      titleOfClass,
      cusip,
      instrument,
      sharesOrPrincipal,
      reportedValueUsd,
    });
  }

  return details;
}

function textTag(block: string, tag: string): string {
  const re = new RegExp(`<(?:\\w+:)?${tag}\\b[^>]*>([\\s\\S]*?)<\\/(?:\\w+:)?${tag}>`, 'i');
  const value = block.match(re)?.[1] || '';
  return decodeXml(value.trim());
}

function numberTag(block: string, tag: string): number {
  const raw = textTag(block, tag).replace(/,/g, '');
  const value = Number(raw);
  return Number.isFinite(value) ? value : 0;
}

function decodeXml(value: string): string {
  return value
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

function normalize(value: string): string {
  return value.replace(/[^A-Z0-9]/gi, '').toUpperCase();
}

function emptyRow(
  institution: Institution,
  status: InstitutionalHoldingRow['status'],
  errorMessage?: string,
  filing?: Latest13F
): InstitutionalHoldingRow {
  return {
    institutionId: institution.id,
    institutionName: institution.name,
    cik: institution.cik,
    status,
    filingDate: filing?.filingDate || null,
    reportDate: filing?.reportDate || null,
    accession: filing?.accession || null,
    filingUrl: filing?.filingUrl || null,
    stockShares: 0,
    callEquivalentShares: 0,
    putEquivalentShares: 0,
    reportedValueUsd: 0,
    details: [],
    delta: null,
    errorMessage,
  };
}

async function secJson<T>(url: string): Promise<T> {
  const text = await secText(url, 'application/json');
  return JSON.parse(text) as T;
}

async function secText(url: string, accept = 'application/xml,text/xml,text/plain,*/*'): Promise<string> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), SEC_TIMEOUT_MS);
  try {
    const res = await fetch(url, {
      cache: 'no-store',
      signal: controller.signal,
      headers: {
        Accept: accept,
        'User-Agent': SEC_USER_AGENT,
      },
    });
    if (!res.ok) throw new Error(`SEC ${res.status} ${res.statusText}`);
    return await res.text();
  } finally {
    clearTimeout(timeout);
  }
}
