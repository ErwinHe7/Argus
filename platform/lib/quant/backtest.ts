// Walk-forward single-ticker backtest.
// Given a closing-price series, runs a rules-based long/cash strategy and
// returns per-bar equity, trades, and summary stats. This is the "High-Flyer
// shrunk for one person" backtest layer: deterministic, no look-ahead, fees +
// slippage modelled, benchmark comparison built in.

import { rsi, sma, realizedVol } from './factors';

export type BacktestStrategy =
  | 'momentum_breakout'   // long when price > SMA200 and 1m return > 0
  | 'mean_reversion_rsi'  // long when RSI(14) < 30, exit when > 55
  | 'trend_sma_cross'     // long when SMA20 > SMA50 > SMA200
  | 'vol_target_trend'    // trend cross sized by inverse realized vol
  | 'buy_and_hold';       // baseline

export type BacktestConfig = {
  strategy: BacktestStrategy;
  feeBps?: number;       // round-trip fee in basis points (default 5 = 0.05%)
  slippageBps?: number;  // per-trade slippage in basis points (default 5)
  startCash?: number;    // starting capital (default 100000)
};

export type BacktestEquityPoint = {
  t: number;            // bar index (oldest = 0)
  date: string;         // ISO date for the bar
  price: number;        // close
  position: number;     // 0..1 fraction of equity invested
  equity: number;       // mark-to-market equity
  benchmark: number;    // buy-and-hold equity using same starting capital
};

export type BacktestTrade = {
  date: string;
  side: 'BUY' | 'SELL';
  price: number;
  shares: number;
  notional: number;
  reason: string;
};

export type BacktestSummary = {
  ticker: string;
  strategy: BacktestStrategy;
  bars: number;
  totalReturnPct: number;
  benchmarkReturnPct: number;
  alphaPct: number;        // total return - benchmark return
  cagrPct: number;
  maxDrawdownPct: number;
  sharpe: number;          // annualized, daily-based, rf=0
  hitRate: number;         // closed trades that ended profitable (round-trip)
  tradeCount: number;
  exposurePct: number;     // % of bars with position > 0
};

export type BacktestResult = {
  summary: BacktestSummary;
  equity: BacktestEquityPoint[];
  trades: BacktestTrade[];
  config: Required<BacktestConfig>;
};

const DEFAULTS: Required<Omit<BacktestConfig, 'strategy'>> = {
  feeBps: 5,
  slippageBps: 5,
  startCash: 100_000,
};

export function runBacktest(
  ticker: string,
  closes: number[],
  dates: string[],
  config: BacktestConfig
): BacktestResult {
  const cfg = { ...DEFAULTS, ...config };
  if (closes.length < 220) {
    throw new Error(`backtest requires at least 220 bars, got ${closes.length}`);
  }
  if (dates.length !== closes.length) {
    throw new Error(`closes/dates length mismatch (${closes.length} vs ${dates.length})`);
  }

  const equity: BacktestEquityPoint[] = [];
  const trades: BacktestTrade[] = [];

  let cash = cfg.startCash;
  let shares = 0;
  let currentEntry: BacktestTrade | null = null;
  let exposedBars = 0;
  let wins = 0;
  let closedRoundTrips = 0;

  const benchStartIdx = 200; // align with longest lookback (SMA200) so benchmark fair
  const benchStartPrice = closes[benchStartIdx];

  for (let i = 0; i < closes.length; i += 1) {
    const price = closes[i];
    const date = dates[i];

    // Strategy needs at least 200 bars of history to evaluate signals fairly.
    if (i < benchStartIdx) {
      equity.push({ t: i, date, price, position: 0, equity: cfg.startCash, benchmark: cfg.startCash });
      continue;
    }

    const currentWeight = shares > 0 ? (shares * price) / (cash + shares * price) : 0;
    const window = closes.slice(0, i + 1);
    const rawTargetWeight = computeTargetWeight(cfg.strategy, window);
    const targetWeight =
      rawTargetWeight < 0 ? currentWeight : Math.max(0, Math.min(1, rawTargetWeight));
    const drift = Math.abs(targetWeight - currentWeight);

    // Rebalance when target weight changes meaningfully (avoid noise trades).
    if (drift > 0.10) {
      const portfolio = cash + shares * price;
      const targetNotional = portfolio * targetWeight;
      const targetShares = targetNotional / price;
      const deltaShares = targetShares - shares;

      if (Math.abs(deltaShares) > 1e-6 && Math.abs(deltaShares * price) > portfolio * 0.02) {
        const side: 'BUY' | 'SELL' = deltaShares > 0 ? 'BUY' : 'SELL';
        const slip = (cfg.slippageBps / 10_000) * (side === 'BUY' ? 1 : -1);
        const fillPrice = price * (1 + slip);
        const fee = Math.abs(deltaShares) * fillPrice * (cfg.feeBps / 10_000);
        const notional = deltaShares * fillPrice;
        cash -= notional + fee;
        shares += deltaShares;

        const trade: BacktestTrade = {
          date,
          side,
          price: fillPrice,
          shares: Math.abs(deltaShares),
          notional: Math.abs(notional),
          reason: reasonForStrategy(cfg.strategy, window),
        };
        trades.push(trade);

        if (side === 'BUY' && !currentEntry) {
          currentEntry = trade;
        } else if (side === 'SELL' && currentEntry && shares < 1e-6) {
          closedRoundTrips += 1;
          if (trade.price > currentEntry.price) wins += 1;
          currentEntry = null;
        }
      }
    }

    const portfolio = cash + shares * price;
    const benchmarkEquity = cfg.startCash * (price / benchStartPrice);
    const exposure = (shares * price) / Math.max(1, portfolio);
    if (exposure > 0.05) exposedBars += 1;

    equity.push({
      t: i,
      date,
      price,
      position: exposure,
      equity: portfolio,
      benchmark: benchmarkEquity,
    });
  }

  const summary = summarise(ticker, cfg.strategy, equity, trades, closedRoundTrips, wins, exposedBars, benchStartIdx);

  return {
    summary,
    equity,
    trades,
    config: cfg,
  };
}

function computeTargetWeight(strategy: BacktestStrategy, closes: number[]): number {
  switch (strategy) {
    case 'buy_and_hold':
      return 1;
    case 'momentum_breakout': {
      const sma200 = sma(closes, 200);
      const oneMonth = closes.length >= 22 ? closes.at(-1)! / closes.at(-22)! - 1 : 0;
      if (!sma200) return 0;
      return closes.at(-1)! > sma200 && oneMonth > 0 ? 1 : 0;
    }
    case 'mean_reversion_rsi': {
      const r = rsi(closes, 14);
      if (r === null) return 0;
      if (r < 30) return 1;
      if (r > 55) return 0;
      return -1; // sentinel: hold previous weight
    }
    case 'trend_sma_cross': {
      const s20 = sma(closes, 20);
      const s50 = sma(closes, 50);
      const s200 = sma(closes, 200);
      if (!s20 || !s50 || !s200) return 0;
      return s20 > s50 && s50 > s200 ? 1 : 0;
    }
    case 'vol_target_trend': {
      const s50 = sma(closes, 50);
      const s200 = sma(closes, 200);
      const v = realizedVol(closes, 20);
      if (!s50 || !s200 || !v) return 0;
      if (s50 < s200) return 0;
      // Scale to ~15% annualised target vol, cap at 1.0
      const target = Math.min(1, Math.max(0, 0.15 / v));
      return target;
    }
    default:
      return 0;
  }
}

function reasonForStrategy(strategy: BacktestStrategy, closes: number[]): string {
  switch (strategy) {
    case 'buy_and_hold':
      return 'buy and hold';
    case 'momentum_breakout': {
      const sma200 = sma(closes, 200);
      return sma200 && closes.at(-1)! > sma200 ? 'price > SMA200, 1m momentum positive' : 'momentum lost';
    }
    case 'mean_reversion_rsi': {
      const r = rsi(closes, 14);
      return r !== null && r < 30 ? `RSI ${r.toFixed(1)} < 30 oversold` : `RSI ${r?.toFixed(1) ?? '?'} exit`;
    }
    case 'trend_sma_cross':
      return 'SMA 20/50/200 stack';
    case 'vol_target_trend':
      return 'trend up, inverse-vol position size';
    default:
      return '';
  }
}

function summarise(
  ticker: string,
  strategy: BacktestStrategy,
  equity: BacktestEquityPoint[],
  trades: BacktestTrade[],
  closedRoundTrips: number,
  wins: number,
  exposedBars: number,
  benchStartIdx: number
): BacktestSummary {
  const startEquity = equity[benchStartIdx]?.equity ?? equity[0].equity;
  const endEquity = equity.at(-1)?.equity ?? startEquity;
  const startBench = equity[benchStartIdx]?.benchmark ?? startEquity;
  const endBench = equity.at(-1)?.benchmark ?? startBench;

  const totalReturnPct = (endEquity / startEquity - 1) * 100;
  const benchmarkReturnPct = (endBench / startBench - 1) * 100;
  const bars = equity.length - benchStartIdx;
  const years = Math.max(1 / 252, bars / 252);
  const cagrPct = (Math.pow(endEquity / startEquity, 1 / years) - 1) * 100;

  // Sharpe (daily) using full equity curve from benchStartIdx onward
  const rets: number[] = [];
  for (let i = benchStartIdx + 1; i < equity.length; i += 1) {
    const a = equity[i - 1].equity;
    const b = equity[i].equity;
    if (a > 0) rets.push(b / a - 1);
  }
  const sharpe = annualizedSharpe(rets);
  const maxDrawdownPct = maxDrawdown(equity.slice(benchStartIdx).map((p) => p.equity));
  const hitRate = closedRoundTrips > 0 ? wins / closedRoundTrips : 0;
  const exposurePct = bars > 0 ? (exposedBars / bars) * 100 : 0;

  return {
    ticker,
    strategy,
    bars,
    totalReturnPct,
    benchmarkReturnPct,
    alphaPct: totalReturnPct - benchmarkReturnPct,
    cagrPct,
    maxDrawdownPct,
    sharpe,
    hitRate,
    tradeCount: trades.length,
    exposurePct,
  };
}

function annualizedSharpe(returns: number[]): number {
  if (returns.length < 5) return 0;
  const mean = returns.reduce((s, v) => s + v, 0) / returns.length;
  const variance = returns.reduce((s, v) => s + (v - mean) ** 2, 0) / Math.max(1, returns.length - 1);
  const std = Math.sqrt(variance);
  if (std === 0) return 0;
  return (mean / std) * Math.sqrt(252);
}

function maxDrawdown(series: number[]): number {
  let peak = -Infinity;
  let worst = 0;
  for (const v of series) {
    if (v > peak) peak = v;
    if (peak > 0) {
      const dd = (v / peak - 1) * 100;
      if (dd < worst) worst = dd;
    }
  }
  return worst;
}

export const STRATEGY_PRESETS: Array<{ id: BacktestStrategy; label: string; description: string }> = [
  {
    id: 'momentum_breakout',
    label: 'Momentum Breakout',
    description: 'Long when price > SMA200 and 1-month return is positive. Flat otherwise.',
  },
  {
    id: 'trend_sma_cross',
    label: 'Trend (SMA 20/50/200)',
    description: 'Long only when SMA20 > SMA50 > SMA200 (classic trend stack).',
  },
  {
    id: 'vol_target_trend',
    label: 'Vol-Targeted Trend',
    description: 'Trend signal sized inversely to 20d realised vol, targeting ~15% annualised.',
  },
  {
    id: 'mean_reversion_rsi',
    label: 'RSI Mean Reversion',
    description: 'Buy when RSI(14) < 30, exit when RSI(14) > 55.',
  },
  {
    id: 'buy_and_hold',
    label: 'Buy & Hold (baseline)',
    description: 'Always-in benchmark — useful as a sanity floor.',
  },
];
