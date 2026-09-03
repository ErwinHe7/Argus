import type { SignalAction, StrategySignal } from './types';

export type BrokerSide = 'BUY' | 'SELL';
export type BrokerOrderType = 'MARKET' | 'LIMIT';
export type BrokerTimeInForce = 'DAY' | 'GTC';

export type BrokerOrderRequest = {
  signalId: string;
  ticker: string;
  side: BrokerSide;
  qty: number;
  type: BrokerOrderType;
  limitPrice?: number;
  timeInForce: BrokerTimeInForce;
  notes?: string;
};

export type BrokerOrderResult = {
  ok: boolean;
  orderId?: string;
  brokerName: string;
  mode: 'paper' | 'live' | 'disabled';
  rejectedReason?: string;
  acceptedAt?: string;
  filledPrice?: number;
  filledQty?: number;
};

export type BrokerPosition = {
  ticker: string;
  qty: number;
  avgPrice: number;
  marketValue?: number;
  unrealizedPnl?: number;
};

export type BrokerAccount = {
  brokerName: string;
  mode: 'paper' | 'live' | 'disabled';
  cash: number;
  equity: number;
  buyingPower: number;
};

export interface BrokerAdapter {
  readonly name: string;
  readonly mode: 'paper' | 'live' | 'disabled';
  submitOrder(req: BrokerOrderRequest): Promise<BrokerOrderResult>;
  getAccount(): Promise<BrokerAccount>;
  getPositions(): Promise<BrokerPosition[]>;
}

class DisabledLiveBrokerAdapter implements BrokerAdapter {
  readonly name = 'disabled-live';
  readonly mode = 'disabled' as const;

  async submitOrder(req: BrokerOrderRequest): Promise<BrokerOrderResult> {
    return {
      ok: false,
      brokerName: this.name,
      mode: 'disabled',
      rejectedReason:
        'Live broker disabled. AXIO7 does not execute live orders. Enable a licensed broker adapter explicitly and only with user-authorized credentials.',
    };
  }

  async getAccount(): Promise<BrokerAccount> {
    return { brokerName: this.name, mode: 'disabled', cash: 0, equity: 0, buyingPower: 0 };
  }

  async getPositions(): Promise<BrokerPosition[]> {
    return [];
  }
}

type PaperTrade = {
  id: string;
  signalId: string;
  ticker: string;
  side: BrokerSide;
  qty: number;
  price: number;
  ts: string;
};

class PaperBrokerAdapter implements BrokerAdapter {
  readonly name = 'axio7-paper';
  readonly mode = 'paper' as const;
  private startingCash: number;
  private cash: number;
  private positions = new Map<string, { qty: number; avgPrice: number }>();
  private trades: PaperTrade[] = [];

  constructor(startingCash = 100_000) {
    this.startingCash = startingCash;
    this.cash = startingCash;
  }

  async submitOrder(req: BrokerOrderRequest): Promise<BrokerOrderResult> {
    if (req.qty <= 0 || !Number.isFinite(req.qty)) {
      return {
        ok: false,
        brokerName: this.name,
        mode: 'paper',
        rejectedReason: 'Invalid qty.',
      };
    }

    const price = req.limitPrice ?? syntheticMarketPrice(req.ticker);
    const cost = price * req.qty;

    if (req.side === 'BUY') {
      if (cost > this.cash) {
        return {
          ok: false,
          brokerName: this.name,
          mode: 'paper',
          rejectedReason: `Paper account has insufficient cash. cash=${this.cash.toFixed(2)} required=${cost.toFixed(2)}`,
        };
      }
      this.cash -= cost;
      const pos = this.positions.get(req.ticker) || { qty: 0, avgPrice: 0 };
      const newQty = pos.qty + req.qty;
      const newAvg = newQty > 0 ? (pos.qty * pos.avgPrice + cost) / newQty : 0;
      this.positions.set(req.ticker, { qty: newQty, avgPrice: newAvg });
    } else {
      const pos = this.positions.get(req.ticker);
      if (!pos || pos.qty < req.qty) {
        return {
          ok: false,
          brokerName: this.name,
          mode: 'paper',
          rejectedReason: 'Paper account does not allow short selling in this build.',
        };
      }
      this.cash += cost;
      const newQty = pos.qty - req.qty;
      this.positions.set(req.ticker, { qty: newQty, avgPrice: newQty > 0 ? pos.avgPrice : 0 });
    }

    const trade: PaperTrade = {
      id: `paper-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
      signalId: req.signalId,
      ticker: req.ticker,
      side: req.side,
      qty: req.qty,
      price,
      ts: new Date().toISOString(),
    };
    this.trades.push(trade);

    return {
      ok: true,
      orderId: trade.id,
      brokerName: this.name,
      mode: 'paper',
      acceptedAt: trade.ts,
      filledPrice: price,
      filledQty: req.qty,
    };
  }

  async getAccount(): Promise<BrokerAccount> {
    let equity = this.cash;
    for (const [ticker, pos] of this.positions) {
      equity += pos.qty * syntheticMarketPrice(ticker);
    }
    return {
      brokerName: this.name,
      mode: 'paper',
      cash: this.cash,
      equity,
      buyingPower: this.cash,
    };
  }

  async getPositions(): Promise<BrokerPosition[]> {
    return Array.from(this.positions.entries())
      .filter(([, pos]) => pos.qty > 0)
      .map(([ticker, pos]) => {
        const mark = syntheticMarketPrice(ticker);
        return {
          ticker,
          qty: pos.qty,
          avgPrice: pos.avgPrice,
          marketValue: pos.qty * mark,
          unrealizedPnl: pos.qty * (mark - pos.avgPrice),
        };
      });
  }

  getTradeLog(): PaperTrade[] {
    return [...this.trades];
  }
}

declare global {
  // eslint-disable-next-line no-var
  var __axio7PaperBroker: PaperBrokerAdapter | undefined;
}

function paperBroker(): PaperBrokerAdapter {
  if (!globalThis.__axio7PaperBroker) {
    const seed = Number(process.env.PAPER_BROKER_STARTING_CASH || 100_000);
    globalThis.__axio7PaperBroker = new PaperBrokerAdapter(Number.isFinite(seed) ? seed : 100_000);
  }
  return globalThis.__axio7PaperBroker;
}

export function getBrokerAdapter(): BrokerAdapter {
  const live = process.env.BROKER_LIVE_ENABLED === 'true';
  if (!live) return paperBroker();
  return new DisabledLiveBrokerAdapter();
}

export type BrokerKind = 'memory_paper' | 'alpaca' | 'ibkr';

export type BrokerSelector = {
  kind: BrokerKind;
  env?: 'paper' | 'live';
  alpaca?: { apiKey: string; apiSecret: string };
  ibkr?: { baseUrl: string; accountId: string; sessionToken?: string };
};

export async function resolveBrokerAdapter(sel: BrokerSelector): Promise<BrokerAdapter> {
  const env: 'paper' | 'live' = sel.env || 'paper';
  if (env === 'live' && process.env.LIVE_EXECUTION_ENABLED !== 'true') {
    return new DisabledLiveBrokerAdapter();
  }

  if (sel.kind === 'alpaca' && sel.alpaca?.apiKey && sel.alpaca?.apiSecret) {
    const { AlpacaBrokerAdapter } = await import('./brokers/alpaca');
    return new AlpacaBrokerAdapter({
      apiKey: sel.alpaca.apiKey,
      apiSecret: sel.alpaca.apiSecret,
      env,
    });
  }

  if (sel.kind === 'ibkr' && sel.ibkr?.baseUrl && sel.ibkr?.accountId) {
    const { IbkrBrokerAdapter } = await import('./brokers/ibkr');
    return new IbkrBrokerAdapter({
      baseUrl: sel.ibkr.baseUrl,
      accountId: sel.ibkr.accountId,
      sessionToken: sel.ibkr.sessionToken,
      env,
    });
  }

  return paperBroker();
}

export function getPaperTradeLog() {
  return paperBroker().getTradeLog();
}

export function planOrderFromSignal(
  signal: StrategySignal,
  account: BrokerAccount,
  riskPercent = Number(process.env.PAPER_RISK_PER_TRADE_PCT || 1)
): BrokerOrderRequest | null {
  const side = sideForAction(signal.action);
  if (!side) return null;

  const price = syntheticMarketPrice(signal.ticker);
  if (!Number.isFinite(price) || price <= 0) return null;

  const riskCash = Math.max(0, (account.cash * riskPercent) / 100);
  const qty = Math.max(0, Math.floor(riskCash / price));
  if (qty <= 0) return null;

  return {
    signalId: signal.id,
    ticker: signal.ticker,
    side,
    qty,
    type: 'MARKET',
    timeInForce: 'DAY',
    notes: `Auto-derived from signal ${signal.id} score=${signal.score} conf=${signal.confidence}`,
  };
}

function sideForAction(action: SignalAction): BrokerSide | null {
  if (action === 'PAPER_LONG') return 'BUY';
  if (action === 'PAPER_SHORT') return 'SELL';
  return null;
}

function syntheticMarketPrice(ticker: string): number {
  let hash = 0;
  for (let i = 0; i < ticker.length; i += 1) hash = (hash * 31 + ticker.charCodeAt(i)) >>> 0;
  const base = 20 + (hash % 480);
  const drift = ((Date.now() / 60_000) % 60) - 30;
  return Number((base + drift * 0.05).toFixed(2));
}
