/** Listing identity only. Directory membership does not establish data or model coverage. */
export type MarketUniverseEntry = {
  symbol: string;
  name: string;
  exchange: string;
  exchange_code: string;
  directory: 'nasdaq_listed' | 'other_listed';
  security_kind: 'etf' | 'non_etf';
  nasdaq_symbol: string;
  cqs_symbol: string | null;
  financial_status: string | null;
};

export type MarketUniverseSource = {
  id: 'nasdaq_listed' | 'other_listed';
  url: string;
  retrieved_at: string;
  sha256: string;
  /** Nasdaq's file footer does not state a UTC offset; preserve it verbatim. */
  source_creation_time: string;
  source_creation_date: string;
  rows: number;
  excluded_test_issues: number;
};

export type MarketUniverseCatalog = {
  schema_version: 'market-universe.v1';
  scope: 'us_exchange_listed_securities';
  generated_at: string;
  expires_at: string;
  sources: MarketUniverseSource[];
  entries: MarketUniverseEntry[];
  index_membership: 'not_supplied';
  limitations: string[];
};

export type UniverseSearchOptions = {
  query?: string;
  exchange?: 'all' | 'NASDAQ' | 'other';
  kind?: 'all' | 'etf' | 'non_etf';
  limit?: number;
  offset?: number;
};

export type UniverseSearchResult = {
  entries: MarketUniverseEntry[];
  total: number;
  offset: number;
  limit: number;
};

export type MarketUniverseLoadResult =
  | { available: true; catalog: MarketUniverseCatalog }
  | { available: false; reason: 'directory_missing' | 'directory_invalid' | 'directory_stale' };
