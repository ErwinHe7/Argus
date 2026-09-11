import { z } from 'zod';
import type { MarketUniverseCatalog, UniverseSearchOptions, UniverseSearchResult } from './types';

export const DIRECTORY_URLS = {
  nasdaq_listed: 'https://www.nasdaqtrader.com/dynamic/SymDir/nasdaqlisted.txt',
  other_listed: 'https://www.nasdaqtrader.com/dynamic/SymDir/otherlisted.txt',
} as const;
export const DIRECTORY_MAX_AGE_DAYS = 7;
const symbol = z.string().min(1).max(14).regex(/^[A-Za-z0-9][A-Za-z0-9.$^#+\-/= ]*$/);
const text = z.string().min(1).max(512).refine((value) => !/[\u0000-\u001f\u007f]/.test(value));
const sourceSchema = z.object({
  id: z.enum(['nasdaq_listed', 'other_listed']), url: z.string().url(),
  retrieved_at: z.string().datetime(), sha256: z.string().regex(/^[a-f0-9]{64}$/),
  source_creation_time: z.string().regex(/^\d{8}\d{2}:?\d{2}$/),
  source_creation_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  rows: z.number().int().min(1).max(30000), excluded_test_issues: z.number().int().min(0).max(1000),
}).strict();
const catalogSchema = z.object({
  schema_version: z.literal('market-universe.v1'), scope: z.literal('us_exchange_listed_securities'),
  generated_at: z.string().datetime(), expires_at: z.string().datetime(),
  sources: z.array(sourceSchema).length(2),
  entries: z.array(z.object({
    symbol, name: text, exchange: text, exchange_code: z.string().regex(/^[A-Z]$/),
    directory: z.enum(['nasdaq_listed', 'other_listed']), security_kind: z.enum(['etf', 'non_etf']),
    nasdaq_symbol: symbol, cqs_symbol: symbol.nullable(), financial_status: z.string().regex(/^[A-Z]$/).nullable(),
  }).strict()).min(1).max(30000),
  index_membership: z.literal('not_supplied'), limitations: z.array(text).min(1),
}).strict();

/** Validate identity, receipt causality and completeness without computing market quantities. */
export function validateMarketUniverseCatalog(raw: unknown, now = new Date()): MarketUniverseCatalog | null {
  const result = catalogSchema.safeParse(raw);
  if (!result.success || !Number.isFinite(now.getTime())) return null;
  const catalog = result.data;
  const generated = Date.parse(catalog.generated_at), expiry = Date.parse(catalog.expires_at);
  if (generated > now.getTime() || expiry <= generated || new Set(catalog.sources.map((source) => source.id)).size !== 2 ||
      new Set(catalog.entries.map((entry) => entry.symbol)).size !== catalog.entries.length) return null;
  for (const source of catalog.sources) {
    const sourceDate = Date.parse(`${source.source_creation_date}T00:00:00Z`);
    const retrieved = Date.parse(source.retrieved_at);
    const stamp = source.source_creation_time;
    const dateFromStamp = `${stamp.slice(4, 8)}-${stamp.slice(0, 2)}-${stamp.slice(2, 4)}`;
    if (source.url !== DIRECTORY_URLS[source.id] || !Number.isFinite(sourceDate) ||
        new Date(sourceDate).toISOString().slice(0, 10) !== source.source_creation_date ||
        dateFromStamp !== source.source_creation_date || Number(stamp.slice(8, 10)) > 23 || Number(stamp.slice(-2)) > 59 ||
        retrieved > generated || sourceDate > retrieved || expiry > sourceDate + DIRECTORY_MAX_AGE_DAYS * 86400000 ||
        catalog.entries.filter((entry) => entry.directory === source.id).length + source.excluded_test_issues !== source.rows) return null;
  }
  if (catalog.entries.some((entry) => entry.directory === 'nasdaq_listed'
    ? entry.exchange !== 'NASDAQ' || entry.exchange_code !== 'Q' || entry.cqs_symbol !== null || entry.financial_status === null || entry.nasdaq_symbol !== entry.symbol
    : entry.exchange === 'NASDAQ' || entry.cqs_symbol === null || entry.financial_status !== null)) return null;
  return catalog;
}

export function isMarketUniverseFresh(catalog: MarketUniverseCatalog, now = new Date()): boolean {
  return Date.parse(catalog.generated_at) <= now.getTime() && Date.parse(catalog.expires_at) > now.getTime();
}

/** Exact symbol and prefix matches first; no scores imply expected returns. */
export function searchMarketUniverse(catalog: MarketUniverseCatalog, options: UniverseSearchOptions = {}, now = new Date()): UniverseSearchResult {
  if (!isMarketUniverseFresh(catalog, now)) throw new Error('directory_stale');
  const query = (options.query ?? '').trim().toUpperCase();
  const exchange = options.exchange ?? 'all', kind = options.kind ?? 'all';
  const limit = options.limit ?? 40, offset = options.offset ?? 0;
  if (query.length > 100 || /[\u0000-\u001f\u007f]/.test(query) ||
      !['all', 'NASDAQ', 'other'].includes(exchange) || !['all', 'etf', 'non_etf'].includes(kind) ||
      !Number.isInteger(limit) || limit < 1 || limit > 100 || !Number.isInteger(offset) || offset < 0 || offset > 30000) throw new Error('directory_query_invalid');
  const rank = (entry: MarketUniverseCatalog['entries'][number]) =>
    [entry.symbol, entry.nasdaq_symbol, entry.cqs_symbol].some((value) => value?.toUpperCase() === query) ? 0 : entry.symbol.toUpperCase().startsWith(query) ? 1 : 2;
  const entries = catalog.entries.filter((entry) =>
    (exchange === 'all' || (exchange === 'NASDAQ' ? entry.directory === 'nasdaq_listed' : entry.directory === 'other_listed')) &&
    (kind === 'all' || entry.security_kind === kind) &&
    (!query || [entry.symbol, entry.nasdaq_symbol, entry.cqs_symbol, entry.name].some((value) => value?.toUpperCase().includes(query))))
    .sort((a, b) => rank(a) - rank(b) || a.symbol.localeCompare(b.symbol, 'en'));
  return { entries: entries.slice(offset, offset + limit), total: entries.length, offset, limit };
}
