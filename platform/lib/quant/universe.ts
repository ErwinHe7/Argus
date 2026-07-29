// Default US-equity universe for the QUANT TRADING module.
// Picked to span large-cap tech, semis, AI infra, finance, energy and consumer
// — enough breadth for a cross-sectional factor scan without being noisy.

export const QUANT_DEFAULT_UNIVERSE = [
  // Mega-cap tech
  'AAPL', 'MSFT', 'GOOGL', 'META', 'AMZN', 'NFLX',
  // AI / Semis
  'NVDA', 'AMD', 'AVGO', 'TSM', 'MU', 'ARM', 'ASML', 'SMCI',
  // Software
  'ORCL', 'CRM', 'NOW', 'PLTR', 'SNOW', 'CRWD', 'PANW', 'DDOG',
  // EV / China ADR / Consumer
  'TSLA', 'BABA', 'PDD', 'JD', 'COIN', 'HOOD',
  // Finance
  'JPM', 'GS', 'BAC', 'BLK',
  // Energy / Utility for AI power
  'CEG', 'VST', 'XOM',
  // Index proxies (used as benchmark)
  'SPY', 'QQQ',
] as const;

export type QuantTicker = (typeof QUANT_DEFAULT_UNIVERSE)[number];

export const QUANT_BENCHMARK_SYMBOL = 'SPY';
