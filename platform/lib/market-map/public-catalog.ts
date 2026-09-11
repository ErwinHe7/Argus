/** Public U.S. research universe. This contains display metadata, not market inputs. */
export const PUBLIC_MARKET_ASSETS = [
  { symbol: 'AAPL', label: 'Apple', asset_type: 'equity', exchange: 'NASDAQ' },
  { symbol: 'SPY', label: 'S&P 500 ETF', asset_type: 'etf', exchange: 'NYSE Arca' },
] as const;

export const DEFAULT_PUBLIC_MARKET_SYMBOL = 'AAPL';
export const isPublicMarketSymbol = (symbol: string): boolean =>
  PUBLIC_MARKET_ASSETS.some((asset) => asset.symbol === symbol);

export function isPublicUsMarketAsset(asset: { symbol: string; currency: string; market_timezone: string; asset_type: string; exchange: string }): boolean {
  const expected = PUBLIC_MARKET_ASSETS.find((entry) => entry.symbol === asset.symbol);
  return Boolean(expected && asset.currency === 'USD' && asset.market_timezone === 'America/New_York' &&
    asset.asset_type === expected.asset_type && asset.exchange === expected.exchange);
}
