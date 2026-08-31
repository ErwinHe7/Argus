import type {
  BrokerAccount,
  BrokerAdapter,
  BrokerOrderRequest,
  BrokerOrderResult,
  BrokerPosition,
} from '../broker';

type AlpacaEnv = 'paper' | 'live';

export type AlpacaCredentials = {
  apiKey: string;
  apiSecret: string;
  env: AlpacaEnv;
};

type AlpacaAccount = {
  cash?: string;
  equity?: string;
  buying_power?: string;
  status?: string;
};

type AlpacaPosition = {
  symbol?: string;
  qty?: string;
  avg_entry_price?: string;
  market_value?: string;
  unrealized_pl?: string;
};

type AlpacaOrder = {
  id?: string;
  status?: string;
  filled_avg_price?: string | null;
  filled_qty?: string | null;
  created_at?: string;
  rejected_reason?: string | null;
};

export class AlpacaBrokerAdapter implements BrokerAdapter {
  readonly name: string;
  readonly mode: 'paper' | 'live';
  private base: string;
  private headers: HeadersInit;

  constructor(creds: AlpacaCredentials) {
    this.mode = creds.env === 'live' ? 'live' : 'paper';
    this.name = `alpaca-${this.mode}`;
    this.base =
      creds.env === 'live' ? 'https://api.alpaca.markets' : 'https://paper-api.alpaca.markets';
    this.headers = {
      'APCA-API-KEY-ID': creds.apiKey,
      'APCA-API-SECRET-KEY': creds.apiSecret,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    };
  }

  async submitOrder(req: BrokerOrderRequest): Promise<BrokerOrderResult> {
    const body = {
      symbol: req.ticker,
      qty: String(req.qty),
      side: req.side === 'BUY' ? 'buy' : 'sell',
      type: req.type === 'LIMIT' ? 'limit' : 'market',
      time_in_force: req.timeInForce === 'GTC' ? 'gtc' : 'day',
      limit_price: req.limitPrice ? String(req.limitPrice) : undefined,
      client_order_id: req.signalId.slice(0, 48),
    };

    try {
      const res = await this.fetch('/v2/orders', {
        method: 'POST',
        body: JSON.stringify(body),
      });
      if (!res.ok) {
        const text = await safeText(res);
        return {
          ok: false,
          brokerName: this.name,
          mode: this.mode,
          rejectedReason: `Alpaca ${res.status}: ${text.slice(0, 240)}`,
        };
      }
      const order = (await res.json()) as AlpacaOrder;
      return {
        ok: true,
        orderId: order.id,
        brokerName: this.name,
        mode: this.mode,
        acceptedAt: order.created_at || new Date().toISOString(),
        filledPrice: order.filled_avg_price ? Number(order.filled_avg_price) : undefined,
        filledQty: order.filled_qty ? Number(order.filled_qty) : undefined,
      };
    } catch (err) {
      return {
        ok: false,
        brokerName: this.name,
        mode: this.mode,
        rejectedReason: err instanceof Error ? err.message : 'alpaca submit failed',
      };
    }
  }

  async getAccount(): Promise<BrokerAccount> {
    try {
      const res = await this.fetch('/v2/account');
      if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
      const acc = (await res.json()) as AlpacaAccount;
      return {
        brokerName: this.name,
        mode: this.mode,
        cash: Number(acc.cash || 0),
        equity: Number(acc.equity || 0),
        buyingPower: Number(acc.buying_power || 0),
      };
    } catch {
      return { brokerName: this.name, mode: this.mode, cash: 0, equity: 0, buyingPower: 0 };
    }
  }

  async getPositions(): Promise<BrokerPosition[]> {
    try {
      const res = await this.fetch('/v2/positions');
      if (!res.ok) return [];
      const positions = (await res.json()) as AlpacaPosition[];
      return positions.map((pos) => ({
        ticker: pos.symbol || '',
        qty: Number(pos.qty || 0),
        avgPrice: Number(pos.avg_entry_price || 0),
        marketValue: Number(pos.market_value || 0),
        unrealizedPnl: Number(pos.unrealized_pl || 0),
      }));
    } catch {
      return [];
    }
  }

  private async fetch(path: string, init?: RequestInit) {
    const controller = new AbortController();
    const t = setTimeout(() => controller.abort(), 8000);
    try {
      return await fetch(`${this.base}${path}`, {
        ...init,
        headers: { ...this.headers, ...(init?.headers || {}) },
        signal: controller.signal,
        cache: 'no-store',
      });
    } finally {
      clearTimeout(t);
    }
  }
}

async function safeText(res: Response): Promise<string> {
  try {
    return await res.text();
  } catch {
    return '';
  }
}
