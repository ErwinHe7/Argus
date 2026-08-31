import {
  PUBLIC_CONTEXT_SCHEMA,
  PublicContextError,
} from './public-context';

export const PUBLIC_MACRO_SERIES = [
  'CPI_US_ALL_SA',
  'UNEMPLOYMENT_RATE_US',
  'PAYROLL_EMPLOYMENT_US',
  'UST_CMT_2Y',
  'UST_CMT_10Y',
  'UST_10Y2Y_SPREAD',
  'EFFR',
] as const;

export type PublicMacroSeries = (typeof PUBLIC_MACRO_SERIES)[number];

type FreshnessStatus = 'retrieval_fresh' | 'retrieval_stale';
type CutoffPrecision = 'month' | 'date';
type AvailabilityPrecision = 'axio7_retrieval_time';

type PublicMacroFreshness = {
  status: FreshnessStatus;
  age_seconds: number;
  basis: 'axio7_upstream_retrieval_time';
  meaning: string;
};

type PublicMacroSourceIdentity = {
  id: string;
  name: string;
  url: string;
  documentation_url: string;
  license_class: 'official_public_data_subject_to_source_terms';
  license_reference: string;
  cost: 'free_no_key';
};

export type PublicMacroDerivedObservation = {
  series: 'UST_CMT_2Y' | 'UST_CMT_10Y';
  upstream_series_id: 'BC_2YEAR' | 'BC_10YEAR';
  value: number;
  unit: 'percent_per_annum';
  observation_cutoff: string;
};

export type PublicMacroItem = {
  series: PublicMacroSeries;
  upstream_series_id: string;
  label: string;
  value: number;
  unit: string;
  observation_period: string;
  observation_cutoff: string;
  observation_cutoff_precision: CutoffPrecision;
  availability_time: string;
  availability_precision: AvailabilityPrecision;
  retrieved_at: string;
  source: PublicMacroSourceIdentity;
  source_record_id: string;
  point_in_time: false;
  archive_verified: false;
  model_eligible: false;
  model_eligibility_reason:
    | 'PUBLIC_ROUTE_NOT_IMMUTABLE_ARCHIVE_VERIFIED'
    | 'TRANSPARENT_ARITHMETIC_CONTEXT_ONLY';
  model_version: null;
  feature_version: null;
  revision_status: string;
  preliminary: boolean;
  derived: boolean;
  derivation:
    | null
    | {
        kind: 'arithmetic_difference';
        expression: 'UST_CMT_10Y - UST_CMT_2Y';
      };
  derived_from: PublicMacroDerivedObservation[];
  caveats: string[];
};

export type PublicMacroSourceReport = PublicMacroSourceIdentity & {
  observation_cutoff: string;
  availability_time: string;
  retrieved_at: string;
  freshness: PublicMacroFreshness;
  coverage: {
    requested_series: PublicMacroSeries[];
    returned_series: PublicMacroSeries[];
    complete: true;
    historical_vintage_guarantee: false;
  };
  point_in_time: false;
  archive_verified: false;
  model_eligible: false;
  model_version: null;
  feature_version: null;
  caveats: string[];
};

export type PublicMacroContext = {
  schema_version: typeof PUBLIC_CONTEXT_SCHEMA;
  generated_at: string;
  observation_cutoff: string;
  observation_cutoff_by_series: Record<PublicMacroSeries, string | null>;
  availability_time: string;
  retrieved_at: string;
  freshness: PublicMacroFreshness;
  coverage: {
    requested_series: PublicMacroSeries[];
    returned_series: PublicMacroSeries[];
    missing_series: PublicMacroSeries[];
    complete: true;
    source_count: number;
    point_in_time: false;
    historical_vintage_guarantee: false;
  };
  source: PublicMacroSourceReport[];
  items: PublicMacroItem[];
  point_in_time: false;
  archive_verified: false;
  model_eligible: false;
  model_eligibility_reason: 'PUBLIC_ROUTE_NOT_IMMUTABLE_ARCHIVE_VERIFIED';
  model_version: null;
  feature_version: null;
  caveats: string[];
};

type CacheEntry = {
  expiresAt: number;
  value?: unknown;
  inFlight?: Promise<unknown>;
};

type MacroSnapshot = {
  source: PublicMacroSourceIdentity;
  retrievedAt: string;
  cacheTtlMs: number;
  items: PublicMacroItem[];
  caveats: string[];
};

type BlsAlias =
  | 'CPI_US_ALL_SA'
  | 'UNEMPLOYMENT_RATE_US'
  | 'PAYROLL_EMPLOYMENT_US';

type BlsDefinition = {
  upstreamSeriesId: string;
  label: string;
  unit: string;
  min: number;
  max: number;
};

type OfficialFetchOptions = {
  url: string;
  allowedHost: string;
  method: 'GET' | 'POST';
  body?: string;
  accept: string;
  expectedContent: 'json' | 'xml';
  maxBytes: number;
};

type OfficialTextResponse = {
  body: string;
  finalUrl: string;
  retrievedAt: string;
};

const BLS_ENDPOINT = 'https://api.bls.gov/publicAPI/v1/timeseries/data/';
const BLS_DOCUMENTATION = 'https://www.bls.gov/developers/api_signature_v1.htm';
const BLS_TERMS = 'https://www.bls.gov/developers/termsOfService.htm';
const TREASURY_ENDPOINT =
  'https://home.treasury.gov/resource-center/data-chart-center/interest-rates/pages/xml';
const TREASURY_DOCUMENTATION =
  'https://home.treasury.gov/treasury-daily-interest-rate-xml-feed';
const TREASURY_TERMS =
  'https://home.treasury.gov/utility/policies-and-notices/web-policies-and-notices';
const NY_FED_EFFR_ENDPOINT =
  'https://markets.newyorkfed.org/api/rates/all/latest.json';
const NY_FED_DOCUMENTATION =
  'https://markets.newyorkfed.org/static/docs/markets-api.html';
const NY_FED_TERMS = 'https://www.newyorkfed.org/privacy/termsofuse.html';
const BLS_REQUIRED_DISCLAIMER =
  'BLS.gov cannot vouch for the data or analyses derived from these data after the data have been retrieved from BLS.gov.';
const NY_FED_REFERENCE_RATE_NOTICE =
  'The Effective Federal Funds Rate is subject to the Terms of Use posted at newyorkfed.org. The New York Fed is not responsible for publication of the Effective Federal Funds Rate by AXIO7, does not sanction or endorse any particular republication, and has no liability for your use.';
const NY_FED_AFFILIATION_DISCLAIMER =
  'AXIO7 is not affiliated with the New York Fed. The New York Fed does not sanction, endorse, or recommend any products or services offered by AXIO7.';

const FETCH_TIMEOUT_MS = 12_000;
const MAX_REDIRECTS = 3;
const BLS_CACHE_TTL_MS = 6 * 60 * 60 * 1_000;
const TREASURY_CACHE_TTL_MS = 30 * 60 * 1_000;
const NY_FED_CACHE_TTL_MS = 30 * 60 * 1_000;
const MAX_REQUESTED_SERIES = PUBLIC_MACRO_SERIES.length;

const PUBLIC_SERIES_SET = new Set<string>(PUBLIC_MACRO_SERIES);
const REDIRECT_STATUSES = new Set([301, 302, 303, 307, 308]);

const BLS_DEFINITIONS: Record<BlsAlias, BlsDefinition> = {
  CPI_US_ALL_SA: {
    upstreamSeriesId: 'CUSR0000SA0',
    label:
      'Consumer Price Index for All Urban Consumers: All Items in U.S. City Average, seasonally adjusted',
    unit: 'index_1982_1984_equals_100',
    min: 0,
    max: 1_000_000,
  },
  UNEMPLOYMENT_RATE_US: {
    upstreamSeriesId: 'LNS14000000',
    label: 'U.S. civilian unemployment rate, seasonally adjusted',
    unit: 'percent',
    min: 0,
    max: 100,
  },
  PAYROLL_EMPLOYMENT_US: {
    upstreamSeriesId: 'CES0000000001',
    label: 'U.S. total nonfarm payroll employment, seasonally adjusted',
    unit: 'thousands_of_persons',
    min: 0,
    max: 1_000_000_000,
  },
};

const BLS_ALIASES = Object.keys(BLS_DEFINITIONS) as BlsAlias[];

const BASE_CAVEATS = [
  'Availability time is the AXIO7 upstream retrieval timestamp, not an upstream release timestamp.',
  'The route exposes current official views and is not an immutable, archive-verified point-in-time dataset.',
  'Public macro context is ineligible for production model features until separately archived, versioned, causality-checked, and promoted.',
];

declare global {
  // eslint-disable-next-line no-var
  var __axio7PublicMacroCache: Map<string, CacheEntry> | undefined;
}

const macroCache =
  globalThis.__axio7PublicMacroCache ?? new Map<string, CacheEntry>();
globalThis.__axio7PublicMacroCache = macroCache;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isPublicMacroSeries(value: string): value is PublicMacroSeries {
  return PUBLIC_SERIES_SET.has(value);
}

function isBlsAlias(value: PublicMacroSeries): value is BlsAlias {
  return Object.prototype.hasOwnProperty.call(BLS_DEFINITIONS, value);
}

function normalizeSeries(series: string[]): PublicMacroSeries[] {
  if (!Array.isArray(series) || series.length === 0) {
    throw new PublicContextError(
      'INVALID_QUERY',
      'At least one public macro series is required.',
      400,
      { allowed_series: [...PUBLIC_MACRO_SERIES] }
    );
  }

  if (series.length > MAX_REQUESTED_SERIES) {
    throw new PublicContextError(
      'INVALID_QUERY',
      `At most ${MAX_REQUESTED_SERIES} public macro series may be requested.`,
      400,
      { allowed_series: [...PUBLIC_MACRO_SERIES] }
    );
  }

  const normalized: PublicMacroSeries[] = [];
  const seen = new Set<PublicMacroSeries>();

  for (const rawSeries of series) {
    if (typeof rawSeries !== 'string') {
      throw new PublicContextError(
        'INVALID_QUERY',
        'Every requested public macro series must be a string.',
        400,
        { allowed_series: [...PUBLIC_MACRO_SERIES] }
      );
    }

    const candidate = rawSeries.trim().toUpperCase();
    if (!isPublicMacroSeries(candidate)) {
      throw new PublicContextError(
        'SERIES_NOT_ALLOWLISTED',
        `Public macro series "${rawSeries}" is not allow-listed.`,
        400,
        { allowed_series: [...PUBLIC_MACRO_SERIES] }
      );
    }

    if (!seen.has(candidate)) {
      seen.add(candidate);
      normalized.push(candidate);
    }
  }

  return normalized;
}

function assertOfficialUrl(rawUrl: string, allowedHost: string): URL {
  let url: URL;
  try {
    url = new URL(rawUrl);
  } catch {
    throw new PublicContextError(
      'UPSTREAM_URL_REJECTED',
      'The configured public macro upstream URL is invalid.',
      500
    );
  }

  if (
    url.protocol !== 'https:' ||
    url.hostname !== allowedHost ||
    url.port !== '' ||
    url.username !== '' ||
    url.password !== ''
  ) {
    throw new PublicContextError(
      'UPSTREAM_URL_REJECTED',
      'The configured public macro upstream URL is outside the fixed HTTPS host allowlist.',
      500,
      { allowed_host: allowedHost }
    );
  }

  return url;
}

function contentTypeAllowed(
  contentType: string | null,
  expected: OfficialFetchOptions['expectedContent']
): boolean {
  if (!contentType) {
    return false;
  }

  const mediaType = contentType.split(';', 1)[0]?.trim().toLowerCase() ?? '';
  if (expected === 'json') {
    return mediaType === 'application/json' || mediaType.endsWith('+json');
  }

  return (
    mediaType === 'application/xml' ||
    mediaType === 'text/xml' ||
    mediaType === 'application/atom+xml' ||
    mediaType.endsWith('+xml')
  );
}

async function readBodyWithLimit(
  response: Response,
  maxBytes: number
): Promise<Uint8Array> {
  const declaredLength = response.headers.get('content-length');
  if (declaredLength !== null) {
    const parsedLength = Number(declaredLength);
    if (
      !Number.isSafeInteger(parsedLength) ||
      parsedLength < 0 ||
      parsedLength > maxBytes
    ) {
      throw new PublicContextError(
        'UPSTREAM_RESPONSE_TOO_LARGE',
        'The public macro upstream response exceeded the configured size limit.',
        503,
        { max_bytes: maxBytes }
      );
    }
  }

  if (!response.body) {
    const buffer = new Uint8Array(await response.arrayBuffer());
    if (buffer.byteLength > maxBytes) {
      throw new PublicContextError(
        'UPSTREAM_RESPONSE_TOO_LARGE',
        'The public macro upstream response exceeded the configured size limit.',
        503,
        { max_bytes: maxBytes }
      );
    }
    return buffer;
  }

  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;

  while (true) {
    const result = await reader.read();
    if (result.done) {
      break;
    }

    totalBytes += result.value.byteLength;
    if (totalBytes > maxBytes) {
      await reader.cancel().catch(() => undefined);
      throw new PublicContextError(
        'UPSTREAM_RESPONSE_TOO_LARGE',
        'The public macro upstream response exceeded the configured size limit.',
        503,
        { max_bytes: maxBytes }
      );
    }
    chunks.push(result.value);
  }

  const combined = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    combined.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return combined;
}

async function fetchOfficialText(
  options: OfficialFetchOptions
): Promise<OfficialTextResponse> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  let currentUrl = assertOfficialUrl(options.url, options.allowedHost);
  let method = options.method;
  let body = options.body;

  try {
    for (let redirectCount = 0; redirectCount <= MAX_REDIRECTS; redirectCount += 1) {
      const response = await fetch(currentUrl, {
        method,
        body,
        headers: {
          Accept: options.accept,
          ...(body === undefined
            ? {}
            : { 'Content-Type': 'application/json; charset=utf-8' }),
          'User-Agent': 'AXIO7 public macro context (https://axio7.com)',
        },
        cache: 'no-store',
        redirect: 'manual',
        signal: controller.signal,
      });

      if (REDIRECT_STATUSES.has(response.status)) {
        if (redirectCount === MAX_REDIRECTS) {
          throw new PublicContextError(
            'UPSTREAM_REDIRECT_REJECTED',
            'The public macro upstream exceeded the redirect limit.',
            503
          );
        }

        const location = response.headers.get('location');
        if (!location) {
          throw new PublicContextError(
            'UPSTREAM_REDIRECT_REJECTED',
            'The public macro upstream returned a redirect without a location.',
            503
          );
        }

        const redirectedUrl = new URL(location, currentUrl);
        currentUrl = assertOfficialUrl(
          redirectedUrl.toString(),
          options.allowedHost
        );

        if (method === 'POST' && ![307, 308].includes(response.status)) {
          throw new PublicContextError(
            'UPSTREAM_REDIRECT_REJECTED',
            'A public macro POST upstream attempted a method-changing redirect.',
            503
          );
        }

        if (response.status === 303) {
          method = 'GET';
          body = undefined;
        }
        continue;
      }

      if (!response.ok) {
        throw new PublicContextError(
          'UPSTREAM_UNAVAILABLE',
          'An official public macro upstream is unavailable.',
          503,
          { upstream_status: response.status }
        );
      }

      assertOfficialUrl(response.url || currentUrl.toString(), options.allowedHost);
      if (
        !contentTypeAllowed(
          response.headers.get('content-type'),
          options.expectedContent
        )
      ) {
        throw new PublicContextError(
          'UPSTREAM_FORMAT_REJECTED',
          'The official public macro upstream returned an unexpected content type.',
          503,
          { expected_content: options.expectedContent }
        );
      }

      const bytes = await readBodyWithLimit(response, options.maxBytes);
      let decoded: string;
      try {
        decoded = new TextDecoder('utf-8', { fatal: true }).decode(bytes);
      } catch {
        throw new PublicContextError(
          'UPSTREAM_FORMAT_REJECTED',
          'The official public macro upstream response was not valid UTF-8.',
          503
        );
      }

      return {
        body: decoded,
        finalUrl: currentUrl.toString(),
        retrievedAt: new Date().toISOString(),
      };
    }

    throw new PublicContextError(
      'UPSTREAM_REDIRECT_REJECTED',
      'The public macro upstream exceeded the redirect limit.',
      503
    );
  } catch (error) {
    if (error instanceof PublicContextError) {
      throw error;
    }
    if (error instanceof Error && error.name === 'AbortError') {
      throw new PublicContextError(
        'UPSTREAM_TIMEOUT',
        'An official public macro upstream timed out.',
        503,
        { timeout_ms: FETCH_TIMEOUT_MS }
      );
    }
    throw new PublicContextError(
      'UPSTREAM_UNAVAILABLE',
      'An official public macro upstream could not be reached.',
      503
    );
  } finally {
    clearTimeout(timeout);
  }
}

async function cached<T>(
  key: string,
  ttlMs: number,
  loader: () => Promise<T>
): Promise<T> {
  const now = Date.now();
  const existing = macroCache.get(key);
  if (existing?.value !== undefined && existing.expiresAt > now) {
    return existing.value as T;
  }
  if (existing?.inFlight) {
    return existing.inFlight as Promise<T>;
  }

  const entry: CacheEntry = { expiresAt: 0 };
  const inFlight = (async () => {
    try {
      const value = await loader();
      macroCache.set(key, {
        value,
        expiresAt: Date.now() + ttlMs,
      });
      return value;
    } catch (error) {
      if (macroCache.get(key) === entry) {
        macroCache.delete(key);
      }
      throw error;
    }
  })();

  entry.inFlight = inFlight;
  macroCache.set(key, entry);
  return inFlight;
}

function parseJson(raw: string): unknown {
  try {
    return JSON.parse(raw) as unknown;
  } catch {
    throw new PublicContextError(
      'UPSTREAM_FORMAT_REJECTED',
      'The official public macro upstream returned invalid JSON.',
      503
    );
  }
}

function parseDecimal(
  value: unknown,
  minimum: number,
  maximum: number,
  field: string
): number {
  let parsed: number;
  if (typeof value === 'number') {
    parsed = value;
  } else if (
    typeof value === 'string' &&
    /^-?(?:\d+(?:\.\d*)?|\.\d+)$/.test(value.trim())
  ) {
    parsed = Number(value.trim());
  } else {
    throw new PublicContextError(
      'UPSTREAM_FORMAT_REJECTED',
      `The official public macro upstream returned an invalid ${field} value.`,
      503
    );
  }

  if (!Number.isFinite(parsed) || parsed < minimum || parsed > maximum) {
    throw new PublicContextError(
      'UPSTREAM_FORMAT_REJECTED',
      `The official public macro upstream returned an out-of-range ${field} value.`,
      503
    );
  }
  return parsed;
}

function extractBlsFootnotes(row: Record<string, unknown>): string[] {
  if (!Array.isArray(row.footnotes)) {
    return [];
  }

  const footnotes: string[] = [];
  for (const rawFootnote of row.footnotes) {
    if (!isRecord(rawFootnote)) {
      continue;
    }
    const code =
      typeof rawFootnote.code === 'string' ? rawFootnote.code.trim() : '';
    const text =
      typeof rawFootnote.text === 'string' ? rawFootnote.text.trim() : '';
    const joined = [code, text].filter(Boolean).join(': ');
    if (joined && joined.length <= 500) {
      footnotes.push(joined);
    }
  }
  return footnotes;
}

function buildBlsItem(
  alias: BlsAlias,
  rawSeries: Record<string, unknown>,
  source: PublicMacroSourceIdentity,
  retrievedAt: string
): PublicMacroItem {
  const definition = BLS_DEFINITIONS[alias];
  if (rawSeries.seriesID !== definition.upstreamSeriesId) {
    throw new PublicContextError(
      'UPSTREAM_FORMAT_REJECTED',
      'BLS returned an unexpected series identifier.',
      503
    );
  }
  if (!Array.isArray(rawSeries.data) || rawSeries.data.length > 100) {
    throw new PublicContextError(
      'UPSTREAM_FORMAT_REJECTED',
      'BLS returned an invalid observation collection.',
      503
    );
  }

  let latest:
    | {
        key: string;
        period: string;
        value: number;
        preliminary: boolean;
        footnotes: string[];
      }
    | undefined;
  const seenPeriods = new Set<string>();

  for (const rawRow of rawSeries.data) {
    if (!isRecord(rawRow)) {
      throw new PublicContextError(
        'UPSTREAM_FORMAT_REJECTED',
        'BLS returned a malformed observation.',
        503
      );
    }

    const year = typeof rawRow.year === 'string' ? rawRow.year : '';
    const periodCode = typeof rawRow.period === 'string' ? rawRow.period : '';
    if (
      !/^\d{4}$/.test(year) ||
      !/^M(?:0[1-9]|1[0-2])$/.test(periodCode)
    ) {
      continue;
    }

    const month = periodCode.slice(1);
    const key = `${year}${month}`;
    if (seenPeriods.has(key)) {
      throw new PublicContextError(
        'UPSTREAM_FORMAT_REJECTED',
        'BLS returned duplicate observations for one reference period.',
        503
      );
    }
    seenPeriods.add(key);

    const rawValue =
      typeof rawRow.value === 'string' ? rawRow.value.trim() : rawRow.value;
    if (rawValue === '-' || rawValue === '') {
      continue;
    }
    const value = parseDecimal(
      rawValue,
      definition.min,
      definition.max,
      `${definition.upstreamSeriesId} observation`
    );
    const footnotes = extractBlsFootnotes(rawRow);
    const preliminary = footnotes.some((footnote) =>
      /(?:^P(?::|$)|preliminary)/i.test(footnote)
    );

    if (!latest || key > latest.key) {
      latest = {
        key,
        period: `${year}-${month}`,
        value,
        preliminary,
        footnotes,
      };
    }
  }

  if (!latest) {
    throw new PublicContextError(
      'DATA_UNAVAILABLE',
      `BLS has no usable current observation for ${alias}.`,
      503,
      { series: alias }
    );
  }

  return {
    series: alias,
    upstream_series_id: definition.upstreamSeriesId,
    label: definition.label,
    value: latest.value,
    unit: definition.unit,
    observation_period: latest.period,
    observation_cutoff: latest.period,
    observation_cutoff_precision: 'month',
    availability_time: retrievedAt,
    availability_precision: 'axio7_retrieval_time',
    retrieved_at: retrievedAt,
    source,
    source_record_id: `bls:${definition.upstreamSeriesId}:${latest.period}`,
    point_in_time: false,
    archive_verified: false,
    model_eligible: false,
    model_eligibility_reason:
      'PUBLIC_ROUTE_NOT_IMMUTABLE_ARCHIVE_VERIFIED',
    model_version: null,
    feature_version: null,
    revision_status: latest.preliminary
      ? 'preliminary_current_view'
      : 'current_revised_history',
    preliminary: latest.preliminary,
    derived: false,
    derivation: null,
    derived_from: [],
    caveats: [
      'BLS API v1 supplies the current published history; this observation is not a verified historical vintage.',
      'BLS release time is not inferred. Availability is conservatively recorded as the AXIO7 retrieval time.',
      ...latest.footnotes.map((footnote) => `BLS footnote: ${footnote}`),
    ],
  };
}

function parseBlsSnapshot(
  payload: unknown,
  finalUrl: string,
  retrievedAt: string
): MacroSnapshot {
  if (
    !isRecord(payload) ||
    payload.status !== 'REQUEST_SUCCEEDED' ||
    !isRecord(payload.Results) ||
    !Array.isArray(payload.Results.series)
  ) {
    throw new PublicContextError(
      'UPSTREAM_FORMAT_REJECTED',
      'BLS returned an unsuccessful or malformed response.',
      503
    );
  }

  const source: PublicMacroSourceIdentity = {
    id: 'bls_public_data_api_v1',
    name: 'U.S. Bureau of Labor Statistics Public Data API v1',
    url: finalUrl,
    documentation_url: BLS_DOCUMENTATION,
    license_class: 'official_public_data_subject_to_source_terms',
    license_reference: BLS_TERMS,
    cost: 'free_no_key',
  };

  const bySeriesId = new Map<string, Record<string, unknown>>();
  for (const rawSeries of payload.Results.series) {
    if (!isRecord(rawSeries) || typeof rawSeries.seriesID !== 'string') {
      throw new PublicContextError(
        'UPSTREAM_FORMAT_REJECTED',
        'BLS returned a malformed series object.',
        503
      );
    }
    if (bySeriesId.has(rawSeries.seriesID)) {
      throw new PublicContextError(
        'UPSTREAM_FORMAT_REJECTED',
        'BLS returned a duplicate series object.',
        503
      );
    }
    bySeriesId.set(rawSeries.seriesID, rawSeries);
  }

  const items = BLS_ALIASES.map((alias) => {
    const definition = BLS_DEFINITIONS[alias];
    const rawSeries = bySeriesId.get(definition.upstreamSeriesId);
    if (!rawSeries) {
      throw new PublicContextError(
        'DATA_UNAVAILABLE',
        `BLS omitted required series ${definition.upstreamSeriesId}.`,
        503,
        { series: alias }
      );
    }
    return buildBlsItem(alias, rawSeries, source, retrievedAt);
  });

  return {
    source,
    retrievedAt,
    cacheTtlMs: BLS_CACHE_TTL_MS,
    items,
    caveats: [
      'BLS API v1 is used without an API key, is cached per process for six hours, and remains subject to its public request limits.',
      'BLS observations are current revised history, not ALFRED-style immutable vintages.',
      'Availability is AXIO7 retrieval time because the adapter does not receive or infer an exact release timestamp.',      BLS_REQUIRED_DISCLAIMER,

    ],
  };
}

async function loadBlsSnapshot(): Promise<MacroSnapshot> {
  return cached('bls:v1:public-macro', BLS_CACHE_TTL_MS, async () => {
    const currentYear = new Date().getUTCFullYear();
    const response = await fetchOfficialText({
      url: BLS_ENDPOINT,
      allowedHost: 'api.bls.gov',
      method: 'POST',
      body: JSON.stringify({
        seriesid: BLS_ALIASES.map(
          (alias) => BLS_DEFINITIONS[alias].upstreamSeriesId
        ),
        startyear: String(currentYear - 1),
        endyear: String(currentYear),
      }),
      accept: 'application/json',
      expectedContent: 'json',
      maxBytes: 1_000_000,
    });
    return parseBlsSnapshot(
      parseJson(response.body),
      response.finalUrl,
      response.retrievedAt
    );
  });
}

function treasuryMonthUrl(month: string): string {
  if (!/^\d{6}$/.test(month)) {
    throw new PublicContextError(
      'UPSTREAM_URL_REJECTED',
      'The Treasury month parameter was invalid.',
      500
    );
  }
  const url = new URL(TREASURY_ENDPOINT);
  url.searchParams.set('data', 'daily_treasury_yield_curve');
  url.searchParams.set('field_tdr_date_value_month', month);
  return url.toString();
}

function utcMonth(value: Date): string {
  return `${value.getUTCFullYear()}${String(value.getUTCMonth() + 1).padStart(
    2,
    '0'
  )}`;
}

function previousUtcMonth(value: Date): Date {
  return new Date(
    Date.UTC(value.getUTCFullYear(), value.getUTCMonth() - 1, 1)
  );
}

function extractXmlValue(block: string, localName: string): string | null {
  const pattern = new RegExp(
    `<d:${localName}\\b[^>]*>([^<]*)<\\/d:${localName}>`,
    'i'
  );
  const match = pattern.exec(block);
  return match?.[1]?.trim() ?? null;
}

type TreasuryCurveRow = {
  date: string;
  twoYear: number | null;
  tenYear: number | null;
};

function parseTreasuryRows(xml: string): TreasuryCurveRow[] {
  const entryMatches = xml.match(/<entry\b[\s\S]*?<\/entry>/gi) ?? [];
  if (entryMatches.length > 400) {
    throw new PublicContextError(
      'UPSTREAM_FORMAT_REJECTED',
      'Treasury returned an unexpectedly large observation collection.',
      503
    );
  }

  const rows: TreasuryCurveRow[] = [];
  const seenDates = new Set<string>();
  for (const entry of entryMatches) {
    const rawDate = extractXmlValue(entry, 'NEW_DATE');
    if (!rawDate) {
      throw new PublicContextError(
        'UPSTREAM_FORMAT_REJECTED',
        'Treasury returned an observation without a date.',
        503
      );
    }
    const date = rawDate.slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || Number.isNaN(Date.parse(date))) {
      throw new PublicContextError(
        'UPSTREAM_FORMAT_REJECTED',
        'Treasury returned an invalid observation date.',
        503
      );
    }
    if (seenDates.has(date)) {
      throw new PublicContextError(
        'UPSTREAM_FORMAT_REJECTED',
        'Treasury returned duplicate observations for one date.',
        503
      );
    }
    seenDates.add(date);

    const rawTwoYear = extractXmlValue(entry, 'BC_2YEAR');
    const rawTenYear = extractXmlValue(entry, 'BC_10YEAR');
    rows.push({
      date,
      twoYear:
        rawTwoYear === null
          ? null
          : parseDecimal(rawTwoYear, -20, 100, 'BC_2YEAR'),
      tenYear:
        rawTenYear === null
          ? null
          : parseDecimal(rawTenYear, -20, 100, 'BC_10YEAR'),
    });
  }

  return rows.sort((left, right) => left.date.localeCompare(right.date));
}

function buildTreasurySnapshot(
  row: TreasuryCurveRow,
  finalUrl: string,
  retrievedAt: string
): MacroSnapshot {
  if (row.twoYear === null || row.tenYear === null) {
    throw new PublicContextError(
      'DATA_UNAVAILABLE',
      'The latest Treasury curve observation is incomplete for 2-year or 10-year CMT.',
      503,
      { observation_date: row.date }
    );
  }

  const source: PublicMacroSourceIdentity = {
    id: 'us_treasury_daily_treasury_par_yield_curve',
    name: 'U.S. Department of the Treasury Daily Treasury Par Yield Curve',
    url: finalUrl,
    documentation_url: TREASURY_DOCUMENTATION,
    license_class: 'official_public_data_subject_to_source_terms',
    license_reference: TREASURY_TERMS,
    cost: 'free_no_key',
  };

  const shared = {
    observation_period: row.date,
    observation_cutoff: row.date,
    observation_cutoff_precision: 'date' as const,
    availability_time: retrievedAt,
    availability_precision: 'axio7_retrieval_time' as const,
    retrieved_at: retrievedAt,
    source,
    point_in_time: false as const,
    archive_verified: false as const,
    model_eligible: false as const,
    model_version: null,
    feature_version: null,
    revision_status: 'latest_current_view',
    preliminary: false,
  };

  const twoYear: PublicMacroItem = {
    ...shared,
    series: 'UST_CMT_2Y',
    upstream_series_id: 'BC_2YEAR',
    label: 'U.S. Treasury 2-year constant maturity par yield',
    value: row.twoYear,
    unit: 'percent_per_annum',
    source_record_id: `treasury:BC_2YEAR:${row.date}`,
    model_eligibility_reason:
      'PUBLIC_ROUTE_NOT_IMMUTABLE_ARCHIVE_VERIFIED',
    derived: false,
    derivation: null,
    derived_from: [],
    caveats: [
      'This is a daily Treasury par yield curve observation, not an intraday tradable quote.',
      'Availability is the AXIO7 retrieval time; an exact upstream publication timestamp is not inferred.',
    ],
  };

  const tenYear: PublicMacroItem = {
    ...shared,
    series: 'UST_CMT_10Y',
    upstream_series_id: 'BC_10YEAR',
    label: 'U.S. Treasury 10-year constant maturity par yield',
    value: row.tenYear,
    unit: 'percent_per_annum',
    source_record_id: `treasury:BC_10YEAR:${row.date}`,
    model_eligibility_reason:
      'PUBLIC_ROUTE_NOT_IMMUTABLE_ARCHIVE_VERIFIED',
    derived: false,
    derivation: null,
    derived_from: [],
    caveats: [
      'This is a daily Treasury par yield curve observation, not an intraday tradable quote.',
      'Availability is the AXIO7 retrieval time; an exact upstream publication timestamp is not inferred.',
    ],
  };

  const spreadValue = Number((row.tenYear - row.twoYear).toFixed(6));
  const spread: PublicMacroItem = {
    ...shared,
    series: 'UST_10Y2Y_SPREAD',
    upstream_series_id: 'BC_10YEAR_MINUS_BC_2YEAR',
    label: 'U.S. Treasury 10-year minus 2-year constant maturity spread',
    value: spreadValue,
    unit: 'percentage_points',
    source_record_id: `treasury:BC_10YEAR_MINUS_BC_2YEAR:${row.date}`,
    model_eligibility_reason: 'TRANSPARENT_ARITHMETIC_CONTEXT_ONLY',
    derived: true,
    derivation: {
      kind: 'arithmetic_difference',
      expression: 'UST_CMT_10Y - UST_CMT_2Y',
    },
    derived_from: [
      {
        series: 'UST_CMT_10Y',
        upstream_series_id: 'BC_10YEAR',
        value: row.tenYear,
        unit: 'percent_per_annum',
        observation_cutoff: row.date,
      },
      {
        series: 'UST_CMT_2Y',
        upstream_series_id: 'BC_2YEAR',
        value: row.twoYear,
        unit: 'percent_per_annum',
        observation_cutoff: row.date,
      },
    ],
    caveats: [
      'This value is transparent arithmetic context: BC_10YEAR minus BC_2YEAR for the same Treasury observation date.',
      'It is not a model output, probability, trading signal, or immutable point-in-time feature.',
    ],
  };

  return {
    source,
    retrievedAt,
    cacheTtlMs: TREASURY_CACHE_TTL_MS,
    items: [twoYear, tenYear, spread],
    caveats: [
      'Treasury par yields are daily indicative curve observations and are not real-time executable market quotes.',
      'The 10Y-2Y spread is a transparent arithmetic difference, not quantitative model inference.',
      'Availability is AXIO7 retrieval time because no exact publication timestamp is inferred from the XML.',
    ],
  };
}

async function fetchTreasuryMonth(
  month: string
): Promise<{
  rows: TreasuryCurveRow[];
  finalUrl: string;
  retrievedAt: string;
}> {
  const response = await fetchOfficialText({
    url: treasuryMonthUrl(month),
    allowedHost: 'home.treasury.gov',
    method: 'GET',
    accept: 'application/atom+xml, application/xml, text/xml',
    expectedContent: 'xml',
    maxBytes: 2_000_000,
  });
  return {
    rows: parseTreasuryRows(response.body),
    finalUrl: response.finalUrl,
    retrievedAt: response.retrievedAt,
  };
}

async function loadTreasurySnapshot(): Promise<MacroSnapshot> {
  const now = new Date();
  const month = utcMonth(now);
  return cached(`treasury:daily-curve:${month}`, TREASURY_CACHE_TTL_MS, async () => {
    let response = await fetchTreasuryMonth(month);
    if (response.rows.length === 0) {
      response = await fetchTreasuryMonth(utcMonth(previousUtcMonth(now)));
    }
    const latest = response.rows.at(-1);
    if (!latest) {
      throw new PublicContextError(
        'DATA_UNAVAILABLE',
        'Treasury returned no usable daily yield curve observation.',
        503
      );
    }
    return buildTreasurySnapshot(
      latest,
      response.finalUrl,
      response.retrievedAt
    );
  });
}

function buildEffrSnapshot(
  payload: unknown,
  finalUrl: string,
  retrievedAt: string
): MacroSnapshot {
  if (!isRecord(payload) || !Array.isArray(payload.refRates)) {
    throw new PublicContextError(
      'UPSTREAM_FORMAT_REJECTED',
      'The New York Fed returned a malformed reference-rate response.',
      503
    );
  }

  const matchingRates = payload.refRates.filter(
    (candidate): candidate is Record<string, unknown> =>
      isRecord(candidate) && candidate.type === 'EFFR'
  );
  if (matchingRates.length !== 1) {
    throw new PublicContextError(
      'DATA_UNAVAILABLE',
      'The New York Fed latest response did not contain exactly one EFFR observation.',
      503
    );
  }

  const rate = matchingRates[0];
  const effectiveDate =
    typeof rate.effectiveDate === 'string' ? rate.effectiveDate : '';
  if (
    !/^\d{4}-\d{2}-\d{2}$/.test(effectiveDate) ||
    Number.isNaN(Date.parse(effectiveDate))
  ) {
    throw new PublicContextError(
      'UPSTREAM_FORMAT_REJECTED',
      'The New York Fed returned an invalid EFFR effective date.',
      503
    );
  }
  const value = parseDecimal(rate.percentRate, -20, 100, 'EFFR percentRate');
  const revisionIndicator =
    typeof rate.revisionIndicator === 'string'
      ? rate.revisionIndicator.trim().slice(0, 100)
      : '';

  const source: PublicMacroSourceIdentity = {
    id: 'new_york_fed_markets_api_effr',
    name: 'Federal Reserve Bank of New York Markets API',
    url: finalUrl,
    documentation_url: NY_FED_DOCUMENTATION,
    license_class: 'official_public_data_subject_to_source_terms',
    license_reference: NY_FED_TERMS,
    cost: 'free_no_key',
  };

  const item: PublicMacroItem = {
    series: 'EFFR',
    upstream_series_id: 'EFFR',
    label: 'Effective Federal Funds Rate',
    value,
    unit: 'percent_per_annum',
    observation_period: effectiveDate,
    observation_cutoff: effectiveDate,
    observation_cutoff_precision: 'date',
    availability_time: retrievedAt,
    availability_precision: 'axio7_retrieval_time',
    retrieved_at: retrievedAt,
    source,
    source_record_id: `nyfed:EFFR:${effectiveDate}`,
    point_in_time: false,
    archive_verified: false,
    model_eligible: false,
    model_eligibility_reason:
      'PUBLIC_ROUTE_NOT_IMMUTABLE_ARCHIVE_VERIFIED',
    model_version: null,
    feature_version: null,
    revision_status: revisionIndicator
      ? `current_view_revision_indicator:${revisionIndicator}`
      : 'latest_current_view',
    preliminary: false,
    derived: false,
    derivation: null,
    derived_from: [],
    caveats: [
      'EFFR is an official daily reference rate, not an intraday executable rate.',
      'The latest API response is a current view and is not treated as an immutable historical vintage.',
      NY_FED_REFERENCE_RATE_NOTICE,
      NY_FED_AFFILIATION_DISCLAIMER,
    ],
  };

  return {
    source,
    retrievedAt,
    cacheTtlMs: NY_FED_CACHE_TTL_MS,
    items: [item],
    caveats: [
      'EFFR is a daily official reference rate and not a real-time market quote.',
      'The route records AXIO7 retrieval time rather than inferring the official publication timestamp.',
      NY_FED_REFERENCE_RATE_NOTICE,
      NY_FED_AFFILIATION_DISCLAIMER,
    ],
  };
}

async function loadEffrSnapshot(): Promise<MacroSnapshot> {
  return cached('nyfed:effr:latest', NY_FED_CACHE_TTL_MS, async () => {
    const response = await fetchOfficialText({
      url: NY_FED_EFFR_ENDPOINT,
      allowedHost: 'markets.newyorkfed.org',
      method: 'GET',
      accept: 'application/json',
      expectedContent: 'json',
      maxBytes: 500_000,
    });
    return buildEffrSnapshot(
      parseJson(response.body),
      response.finalUrl,
      response.retrievedAt
    );
  });
}

function retrievalFreshness(
  retrievedAt: string,
  now: Date,
  cacheTtlMs: number
): PublicMacroFreshness {
  const retrievedTime = Date.parse(retrievedAt);
  if (!Number.isFinite(retrievedTime)) {
    throw new PublicContextError(
      'INTERNAL_CONTEXT_ERROR',
      'A public macro snapshot has an invalid retrieval timestamp.',
      500
    );
  }
  const ageSeconds = Math.max(
    0,
    Math.floor((now.getTime() - retrievedTime) / 1_000)
  );
  return {
    status:
      ageSeconds <= cacheTtlMs / 1_000
        ? 'retrieval_fresh'
        : 'retrieval_stale',
    age_seconds: ageSeconds,
    basis: 'axio7_upstream_retrieval_time',
    meaning:
      'Freshness measures AXIO7 cache age only; it does not assert that the underlying macro observation is real-time.',
  };
}

function aggregateRetrievalFreshness(
  snapshots: MacroSnapshot[],
  now: Date
): PublicMacroFreshness {
  if (snapshots.length === 0) {
    throw new PublicContextError(
      'DATA_UNAVAILABLE',
      'No official public macro snapshot was available for freshness checks.',
      503
    );
  }

  const sourceFreshness = snapshots.map((snapshot) =>
    retrievalFreshness(snapshot.retrievedAt, now, snapshot.cacheTtlMs)
  );
  return {
    status: sourceFreshness.every(
      (freshness) => freshness.status === 'retrieval_fresh'
    )
      ? 'retrieval_fresh'
      : 'retrieval_stale',
    age_seconds: Math.max(
      ...sourceFreshness.map((freshness) => freshness.age_seconds)
    ),
    basis: 'axio7_upstream_retrieval_time',
    meaning:
      'Freshness is fresh only while every source snapshot remains inside its source-specific AXIO7 cache lifetime; it does not assert that macro observations are real-time.',
  };
}
function buildSourceReport(
  snapshot: MacroSnapshot,
  selectedItems: PublicMacroItem[],
  now: Date
): PublicMacroSourceReport {
  const cutoffs = selectedItems.map((item) => item.observation_cutoff);
  return {
    ...snapshot.source,
    observation_cutoff: [...cutoffs].sort().at(-1) ?? '',
    availability_time: snapshot.retrievedAt,
    retrieved_at: snapshot.retrievedAt,
    freshness: retrievalFreshness(
      snapshot.retrievedAt,
      now,
      snapshot.cacheTtlMs
    ),
    coverage: {
      requested_series: selectedItems.map((item) => item.series),
      returned_series: selectedItems.map((item) => item.series),
      complete: true,
      historical_vintage_guarantee: false,
    },
    point_in_time: false,
    archive_verified: false,
    model_eligible: false,
    model_version: null,
    feature_version: null,
    caveats: [...snapshot.caveats],
  };
}

function emptyCutoffMap(): Record<PublicMacroSeries, string | null> {
  return {
    CPI_US_ALL_SA: null,
    UNEMPLOYMENT_RATE_US: null,
    PAYROLL_EMPLOYMENT_US: null,
    UST_CMT_2Y: null,
    UST_CMT_10Y: null,
    UST_10Y2Y_SPREAD: null,
    EFFR: null,
  };
}

export async function fetchPublicMacroContext(
  series: string[]
): Promise<PublicMacroContext> {
  const requestedSeries = normalizeSeries(series);
  const needsBls = requestedSeries.some(isBlsAlias);
  const needsTreasury = requestedSeries.some((candidate) =>
    [
      'UST_CMT_2Y',
      'UST_CMT_10Y',
      'UST_10Y2Y_SPREAD',
    ].includes(candidate)
  );
  const needsEffr = requestedSeries.includes('EFFR');

  const [blsSnapshot, treasurySnapshot, effrSnapshot] = await Promise.all([
    needsBls ? loadBlsSnapshot() : Promise.resolve(null),
    needsTreasury ? loadTreasurySnapshot() : Promise.resolve(null),
    needsEffr ? loadEffrSnapshot() : Promise.resolve(null),
  ]);

  const snapshots = [blsSnapshot, treasurySnapshot, effrSnapshot].filter(
    (snapshot): snapshot is MacroSnapshot => snapshot !== null
  );
  const allItems = snapshots.flatMap((snapshot) => snapshot.items);
  const bySeries = new Map(
    allItems.map((item) => [item.series, item] as const)
  );
  const items = requestedSeries.map((requested) => {
    const item = bySeries.get(requested);
    if (!item) {
      throw new PublicContextError(
        'DATA_UNAVAILABLE',
        `No validated official observation was available for ${requested}.`,
        503,
        { series: requested }
      );
    }
    return item;
  });

  const now = new Date();
  const source = snapshots.map((snapshot) =>
    buildSourceReport(
      snapshot,
      items.filter((item) => item.source.id === snapshot.source.id),
      now
    )
  );
  const retrievalTimes = snapshots.map((snapshot) => snapshot.retrievedAt);
  const availabilityTime = [...retrievalTimes].sort().at(-1);
  if (!availabilityTime) {
    throw new PublicContextError(
      'DATA_UNAVAILABLE',
      'No official public macro source snapshot was available.',
      503
    );
  }


  const cutoffBySeries = emptyCutoffMap();
  for (const item of items) {
    cutoffBySeries[item.series] = item.observation_cutoff;
  }
  const latestObservationCutoff = items
    .map((item) => item.observation_cutoff)
    .sort()
    .at(-1);
  if (!latestObservationCutoff) {
    throw new PublicContextError(
      'DATA_UNAVAILABLE',
      'No official public macro observation cutoff was available.',
      503
    );
  }

  return {
    schema_version: PUBLIC_CONTEXT_SCHEMA,
    generated_at: now.toISOString(),
    observation_cutoff: latestObservationCutoff,
    observation_cutoff_by_series: cutoffBySeries,
    availability_time: availabilityTime,
    retrieved_at: availabilityTime,
    freshness: aggregateRetrievalFreshness(snapshots, now),
    coverage: {
      requested_series: [...requestedSeries],
      returned_series: items.map((item) => item.series),
      missing_series: [],
      complete: true,
      source_count: source.length,
      point_in_time: false,
      historical_vintage_guarantee: false,
    },
    source,
    items,
    point_in_time: false,
    archive_verified: false,
    model_eligible: false,
    model_eligibility_reason:
      'PUBLIC_ROUTE_NOT_IMMUTABLE_ARCHIVE_VERIFIED',
    model_version: null,
    feature_version: null,
    caveats: [
      ...BASE_CAVEATS,
      ...Array.from(
        new Set(snapshots.flatMap((snapshot) => snapshot.caveats))
      ),
      'Treasury spread context, when requested, is only the disclosed 10-year minus 2-year arithmetic difference.',
    ],
  };
}
