import type { MarketUniverseEntry, UniverseSearchOptions } from '../market-universe/types';

export type ResearchCoverage = {
  symbol: string;
  observation_cutoff: string;
  expires_at: string;
  source: string;
  href: string;
};

export type DiscoveryEntry = MarketUniverseEntry & { research: ResearchCoverage | null };
export type DiscoveryResult = {
  available: boolean;
  reason?: string;
  entries: DiscoveryEntry[];
  total: number;
  offset: number;
  limit: number;
  directory_count: number;
  research_count: number;
  generated_at: string | null;
  expires_at: string | null;
  source_urls: string[];
  source_dates: string[];
};

export type DiscoveryQuery = UniverseSearchOptions & { coverage?: 'all' | 'ready' };

/** Strict public query boundary; no upstream URL, model name, or order fields accepted. */
export function parseDiscoveryQuery(params: URLSearchParams): DiscoveryQuery | null {
  const allowed = new Set(['q', 'exchange', 'kind', 'coverage', 'offset']);
  for (const key of params.keys()) {
    if (!allowed.has(key) || params.getAll(key).length !== 1) return null;
  }
  const rawQuery = params.get('q') ?? '';
  const query = rawQuery.trim();
  const exchange = params.get('exchange') ?? 'all';
  const kind = params.get('kind') ?? 'all';
  const coverage = params.get('coverage') ?? 'all';
  const offset = params.get('offset') ?? '0';
  if (rawQuery.length > 80 || /[\u0000-\u001f\u007f]/.test(rawQuery) ||
      !['all', 'NASDAQ', 'other'].includes(exchange) ||
      !['all', 'etf', 'non_etf'].includes(kind) || !['all', 'ready'].includes(coverage) ||
      !/^(0|[1-9]\d{0,5})$/.test(offset) || Number(offset) > 30000) return null;
  return { query, exchange: exchange as DiscoveryQuery['exchange'], kind: kind as DiscoveryQuery['kind'],
    coverage: coverage as DiscoveryQuery['coverage'], offset: Number(offset), limit: 40 };
}

export function currentResearchCoverage(coverage: ResearchCoverage[], now = new Date()): ResearchCoverage[] {
  return coverage.filter((item) =>
    Date.parse(item.observation_cutoff) <= now.getTime() && Date.parse(item.expires_at) > now.getTime() &&
    item.href === `/discover/market-map?symbol=${encodeURIComponent(item.symbol)}`
  );
}

export function attachResearchCoverage(entries: MarketUniverseEntry[], coverage: ResearchCoverage[], now = new Date()): DiscoveryEntry[] {
  const bySymbol = new Map(currentResearchCoverage(coverage, now).map((item) => [item.symbol, item]));
  return entries.map((entry) => ({ ...entry, research: bySymbol.get(entry.symbol) ?? null }));
}
