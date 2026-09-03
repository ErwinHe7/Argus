import http from 'node:http';
import https from 'node:https';
import { URL } from 'node:url';
import type { OptionContract, OptionsChain, OptionSide } from './options';
import type { OrderFlowReport } from './order-flow';

type IbkrConfig = {
  baseUrl: string;
  accountId?: string;
  sessionToken?: string;
  allowInsecureTls: boolean;
  timeoutMs: number;
  maxOptionStrikes: number;
};

type IbkrSearchContract = {
  conid?: number;
  symbol?: string;
  description?: string;
  sections?: Array<{ secType?: string; months?: string }>;
};

type IbkrStrikesResponse = {
  call?: number[];
  put?: number[];
};

type IbkrSecdefInfo = {
  conid?: number;
  symbol?: string;
  secType?: string;
  right?: 'C' | 'P';
  strike?: number;
  maturityDate?: string;
  desc2?: string;
};

type IbkrSnapshotRow = {
  conid?: number;
  conidEx?: string;
  _updated?: number;
  '31'?: string | number;
  '84'?: string | number;
  '85'?: string | number;
  '86'?: string | number;
  '87'?: string | number;
  '88'?: string | number;
  '6509'?: string;
  '7059'?: string | number;
  '7089'?: string | number;
  '7308'?: string | number;
  '7309'?: string | number;
  '7633'?: string | number;
  '7762'?: string | number;
};

type IbkrSsoValidation = {
  RESULT?: boolean | number | string;
  result?: boolean | number | string;
  authenticated?: boolean | number | string;
};

type IbkrAuthStatus = {
  authenticated?: boolean | number | string;
  competing?: boolean | number | string;
  connected?: boolean | number | string;
  message?: string;
};

type IbkrRequestOptions = {
  method?: 'GET' | 'POST';
  body?: unknown;
};

export type IbkrHealth = {
  configured: boolean;
  enabled: boolean;
  baseUrlConfigured: boolean;
  accountIdConfigured: boolean;
  ok: boolean;
  authenticated?: boolean;
  ssoAuthenticated?: boolean;
  brokerageAuthenticated?: boolean;
  brokerageConnected?: boolean;
  competing?: boolean;
  accountsPrimed?: boolean;
  marketDataEnabled: boolean;
  executionEnabled: false;
  sessionTakeoverAttempted: false;
  reason?: string;
  checkedAt: string;
};

export function isIbkrMarketDataEnabled(): boolean {
  return Boolean(process.env.IBKR_BASE_URL && process.env.IBKR_MARKET_DATA_ENABLED === 'true');
}

export function getIbkrPublicConfig() {
  const cfg = readConfig();
  return {
    enabled: isIbkrMarketDataEnabled(),
    configured: Boolean(cfg),
    baseUrlConfigured: Boolean(process.env.IBKR_BASE_URL),
    accountIdConfigured: Boolean(process.env.IBKR_ACCOUNT_ID),
    allowInsecureTls: process.env.IBKR_ALLOW_INSECURE_TLS === 'true',
  };
}

export async function checkIbkrHealth(): Promise<IbkrHealth> {
  const cfg = readConfig();
  const base = {
    configured: Boolean(cfg),
    enabled: isIbkrMarketDataEnabled(),
    baseUrlConfigured: Boolean(process.env.IBKR_BASE_URL),
    accountIdConfigured: Boolean(process.env.IBKR_ACCOUNT_ID),
    marketDataEnabled: isIbkrMarketDataEnabled(),
    executionEnabled: false as const,
    sessionTakeoverAttempted: false as const,
    ok: false,
    checkedAt: new Date().toISOString(),
  };

  if (!cfg) {
    return { ...base, reason: 'Set IBKR_BASE_URL to enable the Client Portal connector.' };
  }
  if (!isIbkrMarketDataEnabled()) {
    return { ...base, reason: 'Set IBKR_MARKET_DATA_ENABLED=true after the gateway is reachable.' };
  }

  try {
    const validate = await ibkrRequestJson<IbkrSsoValidation>(cfg, '/sso/validate');
    const ssoAuthenticated = readSsoAuthentication(validate);

    if (!ssoAuthenticated) {
      return {
        ...base,
        authenticated: false,
        ssoAuthenticated: false,
        brokerageAuthenticated: false,
        brokerageConnected: false,
        competing: false,
        accountsPrimed: false,
        reason: 'IBKR Gateway is reachable, but the outer SSO session is not authenticated. Complete the owner login and two-factor authentication.',
      };
    }

    let authStatus: IbkrAuthStatus;
    try {
      authStatus = await ibkrRequestJson<IbkrAuthStatus>(cfg, '/iserver/auth/status', {
        method: 'POST',
        body: {},
      });
    } catch {
      return {
        ...base,
        authenticated: false,
        ssoAuthenticated: true,
        brokerageAuthenticated: false,
        brokerageConnected: false,
        competing: false,
        accountsPrimed: false,
        reason: 'IBKR outer SSO is valid, but the brokerage authentication endpoint rejected or could not verify this session. Complete the brokerage login in Client Portal; AXIO7 will not auto-compete or execute.',
      };
    }
    const brokerageAuthenticated = parseIbkrBoolean(authStatus.authenticated);
    const brokerageConnected = parseIbkrBoolean(authStatus.connected);
    const competing = parseIbkrBoolean(authStatus.competing);

    if (!brokerageAuthenticated || !brokerageConnected || competing) {
      const reason = competing
        ? 'IBKR reports a competing brokerage session. AXIO7 will not take over or auto-compete.'
        : !brokerageConnected
          ? 'IBKR outer SSO is valid, but the brokerage session is disconnected. Re-authenticate in Client Portal.'
          : 'IBKR outer SSO is valid, but the brokerage session is not authenticated. Re-authenticate in Client Portal; AXIO7 will not auto-compete or execute.';
      return {
        ...base,
        authenticated: false,
        ssoAuthenticated: true,
        brokerageAuthenticated,
        brokerageConnected,
        competing,
        accountsPrimed: false,
        reason,
      };
    }

    const accountsPrimed = await primeAccounts(cfg).then(() => true).catch(() => false);

    return {
      ...base,
      ok: accountsPrimed,
      authenticated: accountsPrimed,
      ssoAuthenticated: true,
      brokerageAuthenticated: true,
      brokerageConnected: true,
      competing: false,
      accountsPrimed,
      reason: accountsPrimed
        ? undefined
        : 'IBKR SSO and brokerage sessions are authenticated, but the read-only account context is not ready.',
    };
  } catch (err) {
    return {
      ...base,
      reason: err instanceof Error ? err.message : 'IBKR health check failed.',
    };
  }
}

export async function fetchIbkrStockQuote(ticker: string) {
  const cfg = requireEnabledConfig();
  const sym = normalizeTicker(ticker);
  const under = await resolveUnderlying(cfg, sym);
  await primeAccounts(cfg);
  const rows = await snapshot(cfg, [under.conid], ['31', '84', '85', '86', '88', '6509', '7059', '7762']);
  const row = rows[0] || {};
  const bid = parseIbkrNumber(row['84']);
  const ask = parseIbkrNumber(row['86']);
  const bidSize = parseIbkrNumber(row['88']);
  const askSize = parseIbkrNumber(row['85']);
  const last = parseIbkrNumber(row['31']);
  const midpoint = bid && ask ? (bid + ask) / 2 : undefined;
  return {
    ticker: sym,
    conid: under.conid,
    spot: last || midpoint || 0,
    bid,
    ask,
    bidSize,
    askSize,
    spread: bid && ask ? ask - bid : undefined,
    midpoint,
    lastSize: parseIbkrNumber(row['7059']),
    volume: parseIbkrNumber(row['7762']),
    marketDataAvailability: row['6509'],
    updatedAt: row._updated ? new Date(row._updated).toISOString() : undefined,
  };
}

export async function buildIbkrOrderFlowReport(ticker: string): Promise<OrderFlowReport> {
  const q = await fetchIbkrStockQuote(ticker);
  const generatedAt = new Date();
  const observationCutoff = q.updatedAt ?? null;
  const ageSeconds = observationCutoff
    ? Math.max(0, Math.floor((generatedAt.getTime() - new Date(observationCutoff).getTime()) / 1000))
    : null;
  const unsubscribed = Boolean(q.marketDataAvailability?.startsWith('N'));
  const regularSessionWindow = isUsRegularSessionWindow(generatedAt);
  const freshnessState = unsubscribed
    ? 'unsubscribed'
    : !regularSessionWindow
      ? 'outside_regular_session'
      : q.bid && q.ask && observationCutoff
        ? 'realtime_snapshot'
        : 'unavailable';
  const buyPressurePct =
    q.bidSize && q.askSize && q.bidSize + q.askSize > 0
      ? Math.round((q.bidSize / (q.bidSize + q.askSize)) * 100)
      : null;

  return {
    ticker: q.ticker,
    spot: q.spot,
    provider: 'ibkr',
    quote: {
      bid: q.bid,
      ask: q.ask,
      bidSize: q.bidSize,
      askSize: q.askSize,
      spread: q.spread,
      midpoint: q.midpoint,
    },
    lastTrades:
      q.spot && q.lastSize && q.updatedAt
        ? [{ price: q.spot, size: q.lastSize, ts: q.updatedAt }]
        : [],
    bars: [],
    vwap: null,
    buyPressurePct,
    notable:
      unsubscribed
        ? [{
            ts: q.updatedAt ?? generatedAt.toISOString(),
            price: q.spot,
            size: 0,
            note: 'IBKR market data not subscribed for this contract',
          }]
        : [],
    generatedAt: generatedAt.toISOString(),
    observationCutoff,
    availabilityTime: generatedAt.toISOString(),
    freshness: {
      state: freshnessState,
      ageSeconds,
      marketDataAvailability: q.marketDataAvailability,
      coverage: 'IBKR Level 1 stock snapshot; owner-authorized internal display only',
      caveats: [
        'Snapshot coverage is not a consolidated public redistribution license.',
        regularSessionWindow
          ? 'A realtime label requires a timestamped bid and ask during the regular-session window.'
          : 'US regular-session window is closed; no live-session freshness claim is made.',
      ],
    },
  };
}

function isUsRegularSessionWindow(now: Date): boolean {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'America/New_York',
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(now);
  const value = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((part) => part.type === type)?.value;
  const weekday = value('weekday');
  if (!weekday || weekday === 'Sat' || weekday === 'Sun') return false;
  const hour = Number(value('hour'));
  const minute = Number(value('minute'));
  const minutes = hour * 60 + minute;
  return minutes >= 9 * 60 + 30 && minutes < 16 * 60;
}

export async function fetchIbkrOptionsChain(ticker: string, expiration: string): Promise<OptionsChain> {
  const cfg = requireEnabledConfig();
  const sym = normalizeTicker(ticker);
  const under = await resolveUnderlying(cfg, sym);
  const quote = await fetchIbkrStockQuote(sym);
  const month = ibkrMonth(expiration);
  const strikes = await ibkrRequestJson<IbkrStrikesResponse>(
    cfg,
    `/iserver/secdef/strikes?conid=${under.conid}&secType=OPT&month=${encodeURIComponent(month)}`
  );
  const selectedStrikes = chooseStrikes(strikes, quote.spot, cfg.maxOptionStrikes);
  const infos: IbkrSecdefInfo[] = [];

  for (const strike of selectedStrikes) {
    for (const right of ['C', 'P'] as OptionSide[]) {
      const rows = await ibkrRequestJson<IbkrSecdefInfo[]>(
        cfg,
        `/iserver/secdef/info?conid=${under.conid}&secType=OPT&month=${encodeURIComponent(month)}&strike=${encodeURIComponent(
          String(strike)
        )}&right=${right}`
      ).catch(() => []);
      infos.push(...rows.filter((row) => normalizeIbkrMaturity(row.maturityDate) === expiration));
    }
  }

  const conids = infos.map((info) => info.conid).filter((conid): conid is number => Boolean(conid));
  const snapshotRows = conids.length
    ? await snapshot(cfg, conids, ['31', '84', '85', '86', '87', '88', '6509', '7059', '7089', '7308', '7309', '7633'])
    : [];
  const snapByConid = new Map(snapshotRows.map((row) => [row.conid, row]));

  const contracts: OptionContract[] = infos
    .filter((info) => info.conid && info.right && typeof info.strike === 'number')
    .map((info) => {
      const row = snapByConid.get(info.conid);
      const ivRaw = parseIbkrNumber(row?.['7633']);
      const iv = ivRaw ? (ivRaw > 2 ? ivRaw / 100 : ivRaw) : undefined;
      return {
        symbol: `${sym}${expiration.replace(/-/g, '')}${info.right}${info.strike}`,
        underlying: sym,
        expiration,
        strike: info.strike!,
        side: info.right!,
        openInterest: 0,
        volume: parseIbkrNumber(row?.['7089']) || parseIbkrNumber(row?.['87']) || 0,
        lastPrice: parseIbkrNumber(row?.['31']),
        bid: parseIbkrNumber(row?.['84']),
        ask: parseIbkrNumber(row?.['86']),
        bidSize: parseIbkrNumber(row?.['88']),
        askSize: parseIbkrNumber(row?.['85']),
        iv,
        delta: parseIbkrNumber(row?.['7308']),
        gamma: parseIbkrNumber(row?.['7309']),
      };
    });

  return {
    underlying: sym,
    spot: quote.spot,
    expiration,
    fetchedAt: new Date().toISOString(),
    provider: 'ibkr',
    contracts,
  };
}

async function resolveUnderlying(cfg: IbkrConfig, ticker: string): Promise<{ conid: number; months: string[] }> {
  const rows = await ibkrRequestJson<IbkrSearchContract[]>(
    cfg,
    `/iserver/secdef/search?symbol=${encodeURIComponent(ticker)}`
  );
  const exact =
    rows.find((row) => row.symbol?.toUpperCase() === ticker && hasSection(row, 'STK')) ||
    rows.find((row) => row.symbol?.toUpperCase() === ticker) ||
    rows[0];
  if (!exact?.conid) throw new Error(`IBKR conid lookup failed for ${ticker}`);
  const opt = exact.sections?.find((section) => section.secType === 'OPT');
  return {
    conid: exact.conid,
    months: opt?.months ? opt.months.split(';').filter(Boolean) : [],
  };
}

function hasSection(row: IbkrSearchContract, secType: string): boolean {
  return Boolean(row.sections?.some((section) => section.secType === secType));
}

async function primeAccounts(cfg: IbkrConfig): Promise<void> {
  await ibkrRequestJson<unknown>(cfg, '/iserver/accounts');
}

async function snapshot(cfg: IbkrConfig, conids: number[], fields: string[]): Promise<IbkrSnapshotRow[]> {
  if (!conids.length) return [];
  await primeAccounts(cfg).catch(() => undefined);
  const path = `/iserver/marketdata/snapshot?conids=${encodeURIComponent(conids.join(','))}&fields=${encodeURIComponent(
    fields.join(',')
  )}`;
  await ibkrRequestJson<IbkrSnapshotRow[]>(cfg, path).catch(() => []);
  await sleep(Number(process.env.IBKR_PREFLIGHT_DELAY_MS || 450));
  return ibkrRequestJson<IbkrSnapshotRow[]>(cfg, path);
}

async function ibkrRequestJson<T>(
  cfg: IbkrConfig,
  path: string,
  options: IbkrRequestOptions = {}
): Promise<T> {
  const url = cfg.baseUrl.replace(/\/+$/, '') + '/' + path.replace(/^\/+/, '');
  const parsed = new URL(url);
  const isHttps = parsed.protocol === 'https:';
  const transport = isHttps ? https : http;
  const method = options.method ?? 'GET';
  const requestBody = options.body === undefined ? undefined : JSON.stringify(options.body);

  return new Promise<T>((resolve, reject) => {
    const req = transport.request(
      {
        protocol: parsed.protocol,
        hostname: parsed.hostname,
        port: parsed.port,
        path: `${parsed.pathname}${parsed.search}`,
        method,
        timeout: cfg.timeoutMs,
        rejectUnauthorized: isHttps ? !cfg.allowInsecureTls : undefined,
        headers: {
          Accept: 'application/json',
          'User-Agent': 'AXIO7-MarketIntel/1.0',
          ...(cfg.sessionToken ? { Cookie: `api=${cfg.sessionToken}` } : {}),
          ...(requestBody === undefined
            ? {}
            : {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(requestBody),
              }),
        },
      },
      (res) => {
        let body = '';
        res.setEncoding('utf8');
        res.on('data', (chunk) => {
          body += chunk;
        });
        res.on('end', () => {
          if (!res.statusCode || res.statusCode < 200 || res.statusCode >= 300) {
            reject(new Error(`IBKR ${res.statusCode || 'ERR'} ${body.slice(0, 240)}`));
            return;
          }
          try {
            resolve(JSON.parse(body || 'null') as T);
          } catch (err) {
            reject(err);
          }
        });
      }
    );
    req.on('timeout', () => {
      req.destroy(new Error('IBKR request timeout'));
    });
    req.on('error', reject);
    if (requestBody !== undefined) req.write(requestBody);
    req.end();
  });
}

function readSsoAuthentication(validate: IbkrSsoValidation): boolean {
  if (Object.prototype.hasOwnProperty.call(validate, 'RESULT')) {
    return parseIbkrBoolean(validate.RESULT);
  }
  if (Object.prototype.hasOwnProperty.call(validate, 'result')) {
    return parseIbkrBoolean(validate.result);
  }
  return parseIbkrBoolean(validate.authenticated);
}

function parseIbkrBoolean(value: unknown): boolean {
  if (value === true || value === 1) return true;
  return typeof value === 'string' && value.trim().toLowerCase() === 'true';
}

function readConfig(): IbkrConfig | null {
  const baseUrl = process.env.IBKR_BASE_URL?.trim();
  if (!baseUrl) return null;
  return {
    baseUrl,
    accountId: process.env.IBKR_ACCOUNT_ID?.trim(),
    sessionToken: process.env.IBKR_SESSION_TOKEN?.trim(),
    allowInsecureTls: process.env.IBKR_ALLOW_INSECURE_TLS === 'true',
    timeoutMs: Number(process.env.IBKR_TIMEOUT_MS || 8000),
    maxOptionStrikes: Math.max(4, Math.min(40, Number(process.env.IBKR_MAX_OPTION_STRIKES || 18))),
  };
}

function requireEnabledConfig(): IbkrConfig {
  const cfg = readConfig();
  if (!cfg) throw new Error('IBKR_BASE_URL is not configured.');
  if (!isIbkrMarketDataEnabled()) throw new Error('IBKR_MARKET_DATA_ENABLED is not true.');
  return cfg;
}

function chooseStrikes(strikes: IbkrStrikesResponse, spot: number, maxCount: number): number[] {
  const all = Array.from(new Set([...(strikes.call || []), ...(strikes.put || [])]))
    .map(Number)
    .filter((n) => Number.isFinite(n) && n > 0);
  if (!all.length) return [];
  const center = spot > 0 ? spot : median(all);
  return all
    .sort((a, b) => Math.abs(a - center) - Math.abs(b - center))
    .slice(0, maxCount)
    .sort((a, b) => a - b);
}

function median(values: number[]): number {
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)] || 0;
}

function ibkrMonth(expiration: string): string {
  const d = new Date(`${expiration}T00:00:00Z`);
  const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  return `${months[d.getUTCMonth()]}${String(d.getUTCFullYear()).slice(-2)}`;
}

function normalizeIbkrMaturity(maturity?: string): string | null {
  if (!maturity || !/^\d{8}$/.test(maturity)) return null;
  return `${maturity.slice(0, 4)}-${maturity.slice(4, 6)}-${maturity.slice(6, 8)}`;
}

function normalizeTicker(ticker: string): string {
  return ticker.replace(/^\$/, '').trim().toUpperCase();
}

function parseIbkrNumber(value: unknown): number | undefined {
  if (typeof value === 'number') return Number.isFinite(value) ? value : undefined;
  if (typeof value !== 'string') return undefined;
  const raw = value.trim();
  if (!raw) return undefined;
  const multiplier = raw.endsWith('M') ? 1_000_000 : raw.endsWith('K') ? 1_000 : 1;
  const cleaned = raw.replace(/^[A-Z]/, '').replace(/[,%KM]/g, '');
  const n = Number(cleaned);
  return Number.isFinite(n) ? n * multiplier : undefined;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
