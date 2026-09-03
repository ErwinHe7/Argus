import { createHash } from 'node:crypto';

export const PUBLIC_CONTEXT_SCHEMA = 'axio.public-context.v1';

const SEC_TICKER_URL = 'https://www.sec.gov/files/company_tickers.json';
const SEC_API_DOCS =
  'https://www.sec.gov/search-filings/edgar-application-programming-interfaces';
const SEC_USAGE_TERMS =
  'https://www.sec.gov/about/webmaster-frequently-asked-questions';
const FRED_API_DOCS =
  'https://fred.stlouisfed.org/docs/api/fred/series_observations.html';
const FRED_API_KEY_URL = 'https://fredaccount.stlouisfed.org/apikeys';
const FRED_TERMS = 'https://fred.stlouisfed.org/legal/terms/';
const BLS_API_DOCS = 'https://www.bls.gov/developers/';
const BLS_API_TERMS = 'https://www.bls.gov/developers/termsOfService.htm';
const BLS_COPYRIGHT = 'https://www.bls.gov/opub/copyright-information.htm';
const BLS_KEY_URL = 'https://data.bls.gov/registrationEngine/';
const TREASURY_API_DOCS =
  'https://home.treasury.gov/treasury-daily-interest-rate-xml-feed';
const NY_FED_API_DOCS =
  'https://markets.newyorkfed.org/static/docs/markets-api.html';
const NY_FED_TERMS = 'https://www.newyorkfed.org/privacy/termsofuse.html';
const BEA_KEY_URL = 'https://apps.bea.gov/api/signup/';
const BEA_TERMS = 'https://apps.bea.gov/API/_pdf/bea_api_tos.pdf';
const OCC_DOWNLOAD_DOCS =
  'https://www.theocc.com/market-data/market-data-reports/other-market-data-info/batch-processing/daily-open-interest';
const OCC_TERMS =
  'https://www.theocc.com/specialpages/legal/terms-and-conditions';
const NVIDIA_RSS_TERMS = 'https://www.nvidia.com/en-us/about-nvidia/rss/';
const BENZINGA_API_DOCS =
  'https://docs.benzinga.com/api-reference/news-api/overview';
const BENZINGA_TERMS = 'https://www.benzinga.com/terms-and-conditions';

const DEFAULT_SEC_UNIVERSE = ['NVDA', 'AAPL', 'MU', 'NBIS', 'BE'] as const;
const MATERIAL_FORMS = new Set([
  '8-K',
  '8-K/A',
  '10-Q',
  '10-Q/A',
  '10-K',
  '10-K/A',
  '20-F',
  '20-F/A',
  '6-K',
]);

type CacheEntry = {
  expiresAt: number;
  value?: unknown;
  inFlight?: Promise<unknown>;
};

declare global {
  // eslint-disable-next-line no-var
  var __axio7PublicContextCache: Map<string, CacheEntry> | undefined;
  // eslint-disable-next-line no-var
  var __axio7SecFairAccessQueue: Promise<void> | undefined;
  // eslint-disable-next-line no-var
  var __axio7SecLastRequestAt: number | undefined;
}

const contextCache =
  globalThis.__axio7PublicContextCache ?? new Map<string, CacheEntry>();
globalThis.__axio7PublicContextCache = contextCache;

const SEC_FACTS = [
  {
    field: 'revenue',
    tags: [
      'RevenueFromContractWithCustomerExcludingAssessedTax',
      'Revenues',
      'SalesRevenueNet',
    ],
    units: ['USD'],
  },
  {
    field: 'net_income',
    tags: ['NetIncomeLoss', 'ProfitLoss'],
    units: ['USD'],
  },
  {
    field: 'eps_diluted',
    tags: ['EarningsPerShareDiluted'],
    units: ['USD/shares'],
  },
  {
    field: 'assets',
    tags: ['Assets'],
    units: ['USD'],
  },
  {
    field: 'liabilities',
    tags: ['Liabilities'],
    units: ['USD'],
  },
  {
    field: 'stockholders_equity',
    tags: ['StockholdersEquity'],
    units: ['USD'],
  },
] as const;

type SecTicker = {
  cik_str?: number;
  ticker?: string;
  title?: string;
};

type SecRecent = {
  accessionNumber?: string[];
  acceptanceDateTime?: string[];
  filingDate?: string[];
  reportDate?: string[];
  form?: string[];
  primaryDocument?: string[];
  primaryDocDescription?: string[];
};

type SecSubmissions = {
  filings?: {
    recent?: SecRecent;
  };
};

type SecFact = {
  accn?: string;
  end?: string;
  filed?: string;
  form?: string;
  fp?: string;
  frame?: string;
  fy?: number;
  start?: string;
  val?: number;
};

type SecCompanyFacts = {
  facts?: Record<
    string,
    Record<
      string,
      {
        label?: string;
        description?: string;
        units?: Record<string, SecFact[]>;
      }
    >
  >;
};

export class PublicContextError extends Error {
  readonly status: number;
  readonly code: string;
  readonly details?: Record<string, unknown>;

  constructor(
    code: string,
    message: string,
    status = 503,
    details?: Record<string, unknown>
  ) {
    super(message);
    this.name = 'PublicContextError';
    this.code = code;
    this.status = status;
    this.details = details;
  }
}

export function secUserAgentReady(value = process.env.SEC_USER_AGENT): boolean {
  const userAgent = value?.trim() ?? '';
  const email = userAgent.match(
    /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i
  )?.[0];
  return Boolean(
    /AXIO7/i.test(userAgent) &&
      email &&
      !/@(?:example|invalid|test)\./i.test(email)
  );
}

export function normalizeSecAcceptanceTimestamp(
  value: string | undefined
): string | null {
  if (!value || !/(?:Z|[+-]\d{2}:\d{2})$/i.test(value)) return null;
  const timestamp = new Date(value);
  return Number.isNaN(timestamp.valueOf()) ? null : timestamp.toISOString();
}

export function publicSecUniverse(): string[] {
  const configured = process.env.AXIO7_PUBLIC_CONTEXT_SYMBOLS;
  const values = configured
    ? configured.split(/[\s,;]+/)
    : [...DEFAULT_SEC_UNIVERSE];
  return Array.from(
    new Set(
      values
        .map((value) => value.trim().toUpperCase())
        .filter((value) => /^[A-Z][A-Z0-9.-]{0,9}$/.test(value))
    )
  );
}

export function buildPublicContextCatalog(origin: string) {
  const base = origin.replace(/\/+$/, '');
  const secReady = secUserAgentReady();

  return {
    schema_version: PUBLIC_CONTEXT_SCHEMA,
    generated_at: new Date().toISOString(),
    product_boundary:
      'Impersonal market research context only. No raw market-data redistribution, order placement, or personalized recommendation.',
    api: {
      sources: `${base}/api/context/v1/sources`,
      sec_nvda: `${base}/api/context/v1/sec?symbol=NVDA&limit=10`,
      macro: `${base}/api/context/v1/macro?series=CPI_US_ALL_SA,UNEMPLOYMENT_RATE_US,PAYROLL_EMPLOYMENT_US,UST_CMT_2Y,UST_CMT_10Y,UST_10Y2Y_SPREAD,EFFR`,
      occ_open_interest: `${base}/api/context/v1/occ-open-interest`,
      news: `${base}/api/context/v1/news?symbol=NVDA`,
    },
    sources: [
      {
        id: 'sec_edgar',
        name: 'SEC EDGAR',
        state: secReady ? 'ready' : 'configuration_required',
        fee: 'free_no_api_key',
        customer_facing_use: 'allowed_with_attribution_and_fair_access',
        coverage: '10-K, 10-Q, 8-K, exact acceptance time, selected XBRL facts',
        setup: secReady
          ? 'configured'
          : 'Set SEC_USER_AGENT to AXIO7 plus a real monitored contact email.',
        upstream: {
          ticker_map: SEC_TICKER_URL,
          api_docs: SEC_API_DOCS,
          usage_terms: SEC_USAGE_TERMS,
        },
      },
      {
        id: 'bls_public_api',
        name: 'U.S. Bureau of Labor Statistics Public Data API',
        state: 'ready',
        fee: 'free_no_api_key_v1',
        customer_facing_use: 'allowed_with_attribution_and_required_disclaimer',
        coverage:
          'Current revised CPI, unemployment-rate, and payroll-employment observations; not a point-in-time vintage archive.',
        setup:
          'No key is required at current AXIO7 volume. A free v2 registration key raises official limits but is not needed by this route.',
        upstream: {
          api_docs: BLS_API_DOCS,
          terms: BLS_API_TERMS,
          copyright: BLS_COPYRIGHT,
          optional_key: BLS_KEY_URL,
        },
      },
      {
        id: 'us_treasury_yield_curve',
        name: 'U.S. Treasury Daily Treasury Par Yield Curve Rates',
        state: 'ready',
        fee: 'free_no_api_key',
        customer_facing_use: 'allowed_public_government_data',
        coverage:
          'Official 2-year and 10-year Treasury par yield curve rates plus a transparently derived 10Y-2Y spread.',
        upstream: {
          api_docs: TREASURY_API_DOCS,
        },
      },
      {
        id: 'ny_fed_markets_api',
        name: 'Federal Reserve Bank of New York Markets API',
        state: 'ready',
        fee: 'free_no_api_key',
        customer_facing_use: 'allowed_with_source_and_disclaimer',
        coverage: 'Latest official Effective Federal Funds Rate (EFFR).',
        upstream: {
          api_docs: NY_FED_API_DOCS,
          terms: NY_FED_TERMS,
        },
      },
      {
        id: 'bea_api',
        name: 'U.S. Bureau of Economic Analysis API',
        state: 'free_key_required_not_connected',
        fee: 'free_api_key',
        customer_facing_use: 'allowed_with_bea_disclaimer',
        coverage: 'PCE price index and national accounts after a server-side key is added.',
        upstream: {
          request_key: BEA_KEY_URL,
          terms: BEA_TERMS,
        },
      },
      {
        id: 'fred_alfred',
        name: 'FRED / ALFRED',
        state: 'disabled_pending_written_permission',
        fee: 'free_api_key_but_restricted_use',
        customer_facing_use: 'disabled',
        coverage:
          'Do not use FRED services or content for AXIO7 software, model development, training, caching, or archiving without prior written consent.',
        replacement:
          'Connect the original BLS, BEA, Treasury, and Federal Reserve data owners directly after reviewing their terms.',
        upstream: {
          request_key: FRED_API_KEY_URL,
          api_docs: FRED_API_DOCS,
          terms: FRED_TERMS,
        },
      },

      {
        id: 'occ_daily_open_interest',
        name: 'OCC Daily Open Interest',
        state: 'disabled_pending_license',
        fee: 'free_download_but_commercial_rights_not_granted',
        customer_facing_use: 'disabled',
        coverage:
          'Market-wide aggregate open interest by product class; never contract-level OI, OPRA, or GEX.',
        upstream: {
          download_docs: OCC_DOWNLOAD_DOCS,
          terms: OCC_TERMS,
        },
      },
      {
        id: 'issuer_rss',
        name: 'Issuer IR / official RSS',
        state: 'disabled_pending_license',
        fee: 'varies_by_issuer',
        customer_facing_use: 'disabled_until_each_feed_is_licensed',
        coverage:
          'Use SEC 8-K and Exhibit 99.1 as the current production-safe company announcement source.',
        upstream: {
          example_terms: NVIDIA_RSS_TERMS,
        },
      },
      {
        id: 'benzinga_news',
        name: 'Benzinga News API',
        state: 'disabled_pending_commercial_contract',
        fee: 'commercial_quote_required',
        customer_facing_use: 'disabled',
        coverage:
          'A free key or trial does not prove redistribution rights for a paid customer-facing product.',
        upstream: {
          api_docs: BENZINGA_API_DOCS,
          terms: BENZINGA_TERMS,
        },
      },
    ],
  };
}

export async function fetchSecPublicContext(symbol: string, limit: number) {
  const normalizedSymbol = symbol.trim().toUpperCase();
  if (!publicSecUniverse().includes(normalizedSymbol)) {
    throw new PublicContextError(
      'SYMBOL_NOT_ALLOWLISTED',
      'The symbol is outside the configured AXIO7 public SEC research universe.',
      400,
      { allowed_symbols: publicSecUniverse() }
    );
  }

  const userAgent = process.env.SEC_USER_AGENT?.trim();
  if (!secUserAgentReady(userAgent)) {
    throw new PublicContextError(
      'SEC_USER_AGENT_REQUIRED',
      'SEC EDGAR is not configured with an AXIO7 fair-access identity.',
      503,
      { setup_url: SEC_API_DOCS }
    );
  }

  const tickerMap = await cachedJson<Record<string, SecTicker>>(
    SEC_TICKER_URL,
    24 * 60 * 60 * 1000,
    ['www.sec.gov'],
    { 'User-Agent': userAgent! },
    8 * 1024 * 1024
  );
  const issuer = Object.values(tickerMap).find(
    (row) => row.ticker?.toUpperCase() === normalizedSymbol
  );
  if (!issuer?.cik_str) {
    throw new PublicContextError(
      'SEC_ISSUER_NOT_FOUND',
      'SEC did not return a CIK mapping for the requested symbol.',
      404
    );
  }

  const cik = String(issuer.cik_str).padStart(10, '0');
  const submissionsUrl = `https://data.sec.gov/submissions/CIK${cik}.json`;
  const companyFactsUrl = `https://data.sec.gov/api/xbrl/companyfacts/CIK${cik}.json`;
  const [submissions, companyFacts] = await Promise.all([
    cachedJson<SecSubmissions>(
      submissionsUrl,
      2 * 60 * 1000,
      ['data.sec.gov'],
      { 'User-Agent': userAgent! },
      16 * 1024 * 1024
    ),
    cachedJson<SecCompanyFacts>(
      companyFactsUrl,
      5 * 60 * 1000,
      ['data.sec.gov'],
      { 'User-Agent': userAgent! },
      32 * 1024 * 1024
    ),
  ]);

  const generatedAt = new Date().toISOString();
  const recent = submissions.filings?.recent;
  const accessionNumbers = recent?.accessionNumber ?? [];
  const acceptanceByAccession = new Map<string, string>();
  const filingUrlByAccession = new Map<string, string>();
  let rejectedAvailability = 0;
  const filings: Array<Record<string, unknown>> = [];

  for (let index = 0; index < accessionNumbers.length; index += 1) {
    const accession = accessionNumbers[index];
    const form = recent?.form?.[index] ?? '';
    if (!accession || !MATERIAL_FORMS.has(form)) continue;
    const acceptedAt = normalizeSecAcceptanceTimestamp(
      recent?.acceptanceDateTime?.[index]
    );
    if (!acceptedAt) {
      rejectedAvailability += 1;
      continue;
    }

    const primaryDocument = recent?.primaryDocument?.[index] ?? '';
    const accessionPath = accession.replace(/-/g, '');
    const archiveUrl = primaryDocument
      ? `https://www.sec.gov/Archives/edgar/data/${Number(cik)}/${accessionPath}/${encodeURIComponent(primaryDocument)}`
      : `https://www.sec.gov/Archives/edgar/data/${Number(cik)}/${accessionPath}/`;
    acceptanceByAccession.set(accession, acceptedAt);
    filingUrlByAccession.set(accession, archiveUrl);

    if (filings.length >= limit) continue;
    const payload = {
      accession,
      form,
      accepted_at: acceptedAt,
      filing_date: recent?.filingDate?.[index] ?? null,
      report_date: recent?.reportDate?.[index] ?? null,
      primary_document: primaryDocument || null,
    };
    filings.push({
      kind: 'filing',
      source_record_id: `sec:${cik}:${accession}`,
      payload_sha256: sha256(JSON.stringify(payload)),
      availability_time: acceptedAt,
      availability_precision: 'exact_timestamp',
      archive_verified: false,
      model_eligible: false,
      model_eligibility_reason:
        'PUBLIC_ROUTE_NOT_IMMUTABLE_ARCHIVE_VERIFIED',
      ...payload,
      description: recent?.primaryDocDescription?.[index] ?? null,
      url: archiveUrl,
    });
  }

  if (filings.length === 0) {
    throw new PublicContextError(
      'DATA_UNAVAILABLE',
      'SEC returned no allowlisted filing with an exact acceptance timestamp.',
      503
    );
  }

  const factCandidates = selectedSecFacts(
    companyFacts,
    acceptanceByAccession,
    filingUrlByAccession,
    companyFactsUrl
  );
  const cutoff = filings
    .map((item) => String(item.availability_time))
    .sort()
    .at(-1)!;
  const ageSeconds = Math.max(
    0,
    Math.floor((Date.now() - new Date(cutoff).valueOf()) / 1000)
  );

  return {
    schema_version: PUBLIC_CONTEXT_SCHEMA,
    generated_at: generatedAt,
    observation_cutoff: cutoff,
    availability_time: cutoff,
    archive_verified: false,
    model_eligible: false,
    model_version: null,
    feature_version: null,
    freshness: {
      status: 'latest_official_filing',
      age_seconds: ageSeconds,
      meaning:
        'Age since the issuer’s latest material filing, not market-price latency.',
    },
    coverage: {
      symbol: normalizedSymbol,
      cik,
      requested_limit: limit,
      filings_returned: filings.length,
      filings_rejected_without_exact_availability: rejectedAvailability,
      xbrl_facts_returned: factCandidates.length,
      xbrl_selection_policy:
        'One deterministic latest fact per field and explicit period kind; ambiguous YTD durations are excluded.',
      forms: Array.from(new Set(filings.map((item) => item.form))).sort(),
    },
    source: {
      id: 'sec_edgar',
      name: 'U.S. Securities and Exchange Commission EDGAR',
      url: submissionsUrl,
      license_class: 'public_government_reuse',
      license_reference: SEC_USAGE_TERMS,
    },
    issuer: {
      symbol: normalizedSymbol,
      name: issuer.title ?? normalizedSymbol,
      cik,
    },
    items: [...filings, ...factCandidates],
    caveats: [
      'SEC actuals are not analyst consensus or company guidance estimates.',
      'Only records with an exact SEC acceptance timestamp are returned; this public route is not model-eligible until the separate immutable sync and Rust archive verification pass.',
      'This endpoint does not contain prices, orders, options chains, or trading recommendations.',
    ],
  };
}

export function licenseBlockedResponse(
  resource: 'occ-open-interest' | 'news'
) {
  const catalog = buildPublicContextCatalog('https://axio7.com');
  const selected =
    resource === 'occ-open-interest'
      ? catalog.sources.find((source) => source.id === 'occ_daily_open_interest')
      : catalog.sources.filter((source) =>
          ['issuer_rss', 'benzinga_news'].includes(source.id)
        );
  const coverage =
    resource === 'occ-open-interest'
      ? 'No customer-facing OCC observations are served. OCC totals are market-wide, not symbol or contract OI.'
      : 'Company announcements are served through SEC filings; issuer RSS and Benzinga require separate commercial rights.';
  return {
    schema_version: PUBLIC_CONTEXT_SCHEMA,
    generated_at: new Date().toISOString(),
    observation_cutoff: null,
    availability_time: null,
    archive_verified: false,
    model_eligible: false,
    model_version: null,
    feature_version: null,
    freshness: {
      status: 'unavailable',
      age_seconds: null,
    },
    coverage,
    source: selected,
    items: [],
    error: {
      code: 'SOURCE_LICENSE_REQUIRED',
      message:
        'AXIO7 fails closed until customer-facing commercial-use and software/model-use rights are documented.',
    },
  };
}

function secFactPeriodKind(
  field: string,
  fact: SecFact
): 'instant' | 'quarterly' | 'annual' | null {
  const durationField = ['revenue', 'net_income', 'eps_diluted'].includes(field);
  if (!durationField) return fact.start ? null : 'instant';
  if (!fact.start || !fact.end) return null;

  const start = new Date(`${fact.start}T00:00:00Z`);
  const end = new Date(`${fact.end}T00:00:00Z`);
  if (Number.isNaN(start.valueOf()) || Number.isNaN(end.valueOf())) return null;
  const durationDays = (end.valueOf() - start.valueOf()) / 86_400_000;
  if (durationDays >= 70 && durationDays <= 120) return 'quarterly';
  if (durationDays >= 300 && durationDays <= 400) return 'annual';
  return null;
}

function selectedSecFacts(
  companyFacts: SecCompanyFacts,
  acceptanceByAccession: Map<string, string>,
  filingUrlByAccession: Map<string, string>,
  companyFactsUrl: string
) {
  const taxonomy = companyFacts.facts?.['us-gaap'] ?? {};
  return SEC_FACTS.flatMap((definition) => {
    const candidates: Array<{
      fact: SecFact;
      tag: string;
      tagPriority: number;
      unit: string;
      label: string | null;
      acceptedAt: string;
      periodKind: 'instant' | 'quarterly' | 'annual';
    }> = [];

    for (const [tagPriority, tag] of definition.tags.entries()) {
      const concept = taxonomy[tag];
      if (!concept?.units) continue;
      for (const unit of definition.units) {
        for (const fact of concept.units[unit] ?? []) {
          const acceptedAt = fact.accn
            ? acceptanceByAccession.get(fact.accn)
            : undefined;
          const periodKind = secFactPeriodKind(definition.field, fact);
          if (
            !acceptedAt ||
            !fact.accn ||
            !fact.end ||
            !Number.isFinite(fact.val) ||
            !fact.form ||
            !MATERIAL_FORMS.has(fact.form) ||
            !periodKind
          ) {
            continue;
          }
          candidates.push({
            fact,
            tag,
            tagPriority,
            unit,
            label: concept.label ?? null,
            acceptedAt,
            periodKind,
          });
        }
      }
    }

    const periodKinds = Array.from(
      new Set(candidates.map((candidate) => candidate.periodKind))
    );
    return periodKinds.flatMap((periodKind) => {
      const latest = candidates
        .filter((candidate) => candidate.periodKind === periodKind)
        .sort(
          (left, right) =>
            right.acceptedAt.localeCompare(left.acceptedAt) ||
            (right.fact.end ?? '').localeCompare(left.fact.end ?? '') ||
            left.tagPriority - right.tagPriority ||
            Number(Boolean(right.fact.frame)) - Number(Boolean(left.fact.frame)) ||
            (right.fact.start ?? '').localeCompare(left.fact.start ?? '')
        )[0];
      if (!latest) return [];

      const payload = {
        accession: latest.fact.accn,
        tag: latest.tag,
        unit: latest.unit,
        period_start: latest.fact.start ?? null,
        period_end: latest.fact.end,
        value: latest.fact.val,
      };
      return [
        {
          kind: 'xbrl_fact',
          field: definition.field,
          period_kind: latest.periodKind,
          tag: latest.tag,
          tag_priority: latest.tagPriority,
          label: latest.label,
          value: latest.fact.val,
          unit: latest.unit,
          period_start: latest.fact.start ?? null,
          period_end: latest.fact.end ?? null,
          fiscal_year: latest.fact.fy ?? null,
          fiscal_period: latest.fact.fp ?? null,
          form: latest.fact.form ?? null,
          accession: latest.fact.accn ?? null,
          filed_date: latest.fact.filed ?? null,
          availability_time: latest.acceptedAt,
          availability_precision: 'exact_timestamp',
          archive_verified: false,
          model_eligible: false,
          model_eligibility_reason:
            'PUBLIC_ROUTE_NOT_IMMUTABLE_ARCHIVE_VERIFIED',
          source_record_id: `sec:xbrl:${latest.fact.accn}:${latest.tag}:${latest.fact.start ?? 'instant'}:${latest.fact.end}`,
          payload_sha256: sha256(JSON.stringify(payload)),
          url:
            (latest.fact.accn &&
              filingUrlByAccession.get(latest.fact.accn)) ||
            companyFactsUrl,
        },
      ];
    });
  });
}
async function cachedJson<T>(
  url: string,
  ttlMs: number,
  allowedHosts: string[],
  headers: Record<string, string>,
  maximumBytes: number
): Promise<T> {
  const safeUrl = new URL(url);
  if (
    safeUrl.protocol !== 'https:' ||
    !allowedHosts.includes(safeUrl.hostname)
  ) {
    throw new PublicContextError(
      'UPSTREAM_NOT_ALLOWED',
      'The configured upstream host is not allowlisted.',
      500
    );
  }

  const cacheKey = redactSecretQuery(safeUrl);
  const now = Date.now();
  const existing = contextCache.get(cacheKey);
  if (existing?.value !== undefined && existing.expiresAt > now) {
    return existing.value as T;
  }
  if (existing?.inFlight) return existing.inFlight as Promise<T>;

  const inFlight = fetchJson<T>(
    safeUrl,
    allowedHosts,
    headers,
    maximumBytes
  );
  contextCache.set(cacheKey, {
    expiresAt: existing?.expiresAt ?? 0,
    value: existing?.value,
    inFlight,
  });
  try {
    const value = await inFlight;
    contextCache.set(cacheKey, {
      expiresAt: Date.now() + ttlMs,
      value,
    });
    return value;
  } catch (error) {
    contextCache.delete(cacheKey);
    throw error;
  }
}

async function fetchJson<T>(
  url: URL,
  allowedHosts: string[],
  headers: Record<string, string>,
  maximumBytes: number
): Promise<T> {
  if (allowedHosts.some((host) => host.endsWith('sec.gov'))) {
    await waitForSecFairAccessSlot();
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 12_000);
  try {
    const response = await fetch(url.toString(), {
      cache: 'no-store',
      redirect: 'follow',
      signal: controller.signal,
      headers: {
        Accept: 'application/json',
        'Accept-Encoding': 'gzip, deflate',
        ...headers,
      },
    });
    const finalUrl = new URL(response.url || url.toString());
    if (
      finalUrl.protocol !== 'https:' ||
      !allowedHosts.includes(finalUrl.hostname)
    ) {
      throw new PublicContextError(
        'UPSTREAM_REDIRECT_REJECTED',
        'The upstream redirected outside the allowlisted official host.',
        503
      );
    }
    if (!response.ok) {
      throw new PublicContextError(
        'UPSTREAM_UNAVAILABLE',
        `The official upstream returned HTTP ${response.status}.`,
        503
      );
    }
    const contentType = response.headers.get('content-type') ?? '';
    if (!contentType.toLowerCase().includes('json')) {
      throw new PublicContextError(
        'UPSTREAM_FORMAT_REJECTED',
        'The official upstream did not return JSON.',
        503
      );
    }
    const contentLength = Number(response.headers.get('content-length') || 0);
    if (contentLength > maximumBytes) {
      throw new PublicContextError(
        'UPSTREAM_RESPONSE_TOO_LARGE',
        'The official upstream response exceeded the configured size limit.',
        503
      );
    }
    const text = await response.text();
    if (Buffer.byteLength(text, 'utf8') > maximumBytes) {
      throw new PublicContextError(
        'UPSTREAM_RESPONSE_TOO_LARGE',
        'The official upstream response exceeded the configured size limit.',
        503
      );
    }
    try {
      return JSON.parse(text) as T;
    } catch {
      throw new PublicContextError(
        'UPSTREAM_FORMAT_REJECTED',
        'The official upstream response was not valid JSON.',
        503
      );
    }
  } catch (error) {
    if (error instanceof PublicContextError) throw error;
    throw new PublicContextError(
      'UPSTREAM_UNAVAILABLE',
      'The official upstream request failed or timed out.',
      503
    );
  } finally {
    clearTimeout(timeout);
  }
}

async function waitForSecFairAccessSlot(): Promise<void> {
  const previous = globalThis.__axio7SecFairAccessQueue ?? Promise.resolve();
  const next = previous.then(async () => {
    const lastRequestAt = globalThis.__axio7SecLastRequestAt ?? 0;
    const delayMs = Math.max(0, lastRequestAt + 125 - Date.now());
    if (delayMs > 0) {
      await new Promise<void>((resolve) => setTimeout(resolve, delayMs));
    }
    globalThis.__axio7SecLastRequestAt = Date.now();
  });
  globalThis.__axio7SecFairAccessQueue = next.catch(() => undefined);
  await next;
}

function redactSecretQuery(url: URL): string {
  const redacted = new URL(url.toString());
  for (const key of ['api_key', 'token', 'key']) {
    if (redacted.searchParams.has(key)) {
      redacted.searchParams.set(key, '[redacted]');
    }
  }
  return redacted.toString();
}

function sha256(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}
