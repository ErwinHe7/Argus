import 'server-only';
import { loadMarketUniverse } from '../market-universe/server';
import { searchMarketUniverse } from '../market-universe/catalog';
import { getPublicMarketMapSnapshots, getPublicMarketMapStatus } from '../market-map/public-server';
import { attachResearchCoverage, currentResearchCoverage, type DiscoveryQuery, type DiscoveryResult, type ResearchCoverage } from './discovery';

async function researchCoverage(): Promise<ResearchCoverage[]> {
  const status = await getPublicMarketMapStatus();
  if (!status.available) return [];
  const snapshots = await Promise.all((status.symbols ?? []).slice(0, 20).map(async (symbol) => {
    const snapshot = (await getPublicMarketMapSnapshots(symbol).catch(() => []))
      .find((item) => item.horizon === '20d');
    return snapshot ? {
      symbol: snapshot.asset.symbol,
      observation_cutoff: snapshot.provenance.observation_cutoff,
      expires_at: snapshot.provenance.freshness.expires_at,
      source: snapshot.provenance.sources.map((source) => source.provider).join(', '),
      href: `/discover/market-map?symbol=${encodeURIComponent(snapshot.asset.symbol)}`,
    } : null;
  }));
  return snapshots.filter((item): item is ResearchCoverage => item !== null);
}

export async function getStockDiscovery(query: DiscoveryQuery): Promise<DiscoveryResult> {
  const [directory, loadedCoverage] = await Promise.all([loadMarketUniverse(), researchCoverage()]);
  const now = new Date();
  const coverage = currentResearchCoverage(loadedCoverage, now);
  if (!directory.available) return {
    available: false, reason: directory.reason, entries: [], total: 0, offset: 0, limit: 40,
    directory_count: 0, research_count: 0, generated_at: null, expires_at: null, source_urls: [], source_dates: [],
  };
  const catalog = directory.catalog;
  const covered = new Set(coverage.map((entry) => entry.symbol));
  const searchable = query.coverage === 'ready'
    ? { ...catalog, entries: catalog.entries.filter((entry) => covered.has(entry.symbol)) }
    : catalog;
  const result = searchMarketUniverse(searchable, query);
  return { ...result, available: true, entries: attachResearchCoverage(result.entries, coverage, now),
    directory_count: catalog.entries.length,
    research_count: catalog.entries.filter((entry) => covered.has(entry.symbol)).length,
    generated_at: catalog.generated_at, expires_at: catalog.expires_at,
    source_urls: catalog.sources.map((source) => source.url),
    source_dates: [...new Set(catalog.sources.map((source) => source.source_creation_date))].sort(),
  };
}
