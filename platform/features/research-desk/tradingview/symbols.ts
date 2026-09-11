export type TradingViewMarket = {
  symbol: string;
  providerSymbol: string;
  name: string;
  venue: string;
  kind: 'stock' | 'fund' | 'crypto';
};

// Explicit listings, not a guessed exchange prefix. Provider availability can differ
// from TradingView's own website and is disclosed by the hosted widget.
export const TRADINGVIEW_MARKETS: readonly TradingViewMarket[] = [
  { symbol: 'SPY', providerSymbol: 'AMEX:SPY', name: 'SPDR S&P 500 ETF', venue: 'NYSE Arca', kind: 'fund' },
  { symbol: 'QQQ', providerSymbol: 'NASDAQ:QQQ', name: 'Invesco QQQ', venue: 'Nasdaq', kind: 'fund' },
  { symbol: 'DXYZ', providerSymbol: 'NYSE:DXYZ', name: 'Destiny Tech100', venue: 'NYSE', kind: 'fund' },
  { symbol: 'ZM', providerSymbol: 'NASDAQ:ZM', name: 'Zoom', venue: 'Nasdaq', kind: 'stock' },
  { symbol: 'AVGO', providerSymbol: 'NASDAQ:AVGO', name: 'Broadcom', venue: 'Nasdaq', kind: 'stock' },
  { symbol: 'AMZN', providerSymbol: 'NASDAQ:AMZN', name: 'Amazon', venue: 'Nasdaq', kind: 'stock' },
  { symbol: 'GOOGL', providerSymbol: 'NASDAQ:GOOGL', name: 'Alphabet Class A', venue: 'Nasdaq', kind: 'stock' },
  { symbol: 'NVDA', providerSymbol: 'NASDAQ:NVDA', name: 'NVIDIA', venue: 'Nasdaq', kind: 'stock' },
  { symbol: 'BTC-USD', providerSymbol: 'COINBASE:BTCUSD', name: 'Bitcoin / U.S. dollar', venue: 'Coinbase spot', kind: 'crypto' },
  { symbol: 'ETH-USD', providerSymbol: 'COINBASE:ETHUSD', name: 'Ether / U.S. dollar', venue: 'Coinbase spot', kind: 'crypto' },
];

// These strategy examples have verified listings, without expanding the site's
// established watchlist. Walmart's current TradingView listing is Nasdaq.
const OTHER_VERIFIED_MARKETS: readonly TradingViewMarket[] = [
  { symbol: 'MU', providerSymbol: 'NASDAQ:MU', name: 'Micron Technology', venue: 'Nasdaq', kind: 'stock' },
  { symbol: 'ADBE', providerSymbol: 'NASDAQ:ADBE', name: 'Adobe', venue: 'Nasdaq', kind: 'stock' },
  { symbol: 'AAPL', providerSymbol: 'NASDAQ:AAPL', name: 'Apple', venue: 'Nasdaq', kind: 'stock' },
  { symbol: 'MSFT', providerSymbol: 'NASDAQ:MSFT', name: 'Microsoft', venue: 'Nasdaq', kind: 'stock' },
  { symbol: 'WMT', providerSymbol: 'NASDAQ:WMT', name: 'Walmart', venue: 'Nasdaq', kind: 'stock' },
];

export function resolveTradingViewSymbol(input: string): TradingViewMarket | undefined {
  const symbol = input.trim().toUpperCase();
  const alias = symbol === 'BTC' || symbol === 'BTCUSD' ? 'BTC-USD' : symbol === 'ETH' || symbol === 'ETHUSD' ? 'ETH-USD' : symbol;
  return [...TRADINGVIEW_MARKETS, ...OTHER_VERIFIED_MARKETS].find(market => market.symbol === alias || market.providerSymbol === alias);
}

export function tradingViewLink(input: string): string {
  const market = resolveTradingViewSymbol(input);
  return market
    ? `https://www.tradingview.com/chart/?symbol=${encodeURIComponent(market.providerSymbol)}`
    : `https://www.tradingview.com/symbols/?query=${encodeURIComponent(input.trim().slice(0, 32))}`;
}

export function selectTradingViewMarkets(symbols: readonly string[]): TradingViewMarket[] {
  const unique = new Map<string, TradingViewMarket>();
  for (const symbol of symbols) {
    const market = resolveTradingViewSymbol(symbol);
    if (market) unique.set(market.providerSymbol, market);
  }
  return [...unique.values()];
}
