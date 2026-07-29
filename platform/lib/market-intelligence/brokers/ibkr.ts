import type {
  BrokerAccount,
  BrokerAdapter,
  BrokerOrderRequest,
  BrokerOrderResult,
  BrokerPosition,
} from '../broker';

export type IbkrCredentials = {
  baseUrl: string;
  sessionToken?: string;
  accountId: string;
  env: 'paper' | 'live';
};

type IbkrAccountSummary = {
  netliquidation?: { amount?: number };
  totalcashvalue?: { amount?: number };
  availablefunds?: { amount?: number };
};

type IbkrPosition = {
  contractDesc?: string;
  ticker?: string;
  position?: number;
  avgCost?: number;
  mktValue?: number;
  unrealizedPnl?: number;
};

type IbkrOrderResponse = Array<{
  order_id?: string;
  local_order_id?: string;
  order_status?: string;
  warning_message?: string;
}>;

export class IbkrBrokerAdapter implements BrokerAdapter {
  readonly name: string;
  readonly mode: 'paper' | 'live';
  private base: string;
  private accountId: string;
  private sessionToken?: string;

  constructor(creds: IbkrCredentials) {
    this.mode = creds.env;
    this.name = `ibkr-${this.mode}`;
    this.base = creds.baseUrl.replace(/\/+$/, '');
    this.accountId = creds.accountId;
    this.sessionToken = creds.sessionToken;
  }

  async submitOrder(req: BrokerOrderRequest): Promise<BrokerOrderResult> {
    try {
      const conid = await this.resolveConid(req.ticker);
      if (!conid) {
        return {
          ok: false,
          brokerName: this.name,
          mode: this.mode,
          rejectedReason: `IBKR conid lookup failed for ${req.ticker}`,
        };
      }

      const body = {
        orders: [
          {
            acctId: this.accountId,
            conid,
            orderType: req.type === 'LIMIT' ? 'LMT' : 'MKT',
            side: req.side,
            tif: req.timeInForce,
            quantity: req.qty,
            price: req.limitPrice,
            cOID: req.signalId.slice(0, 48),
          },
        ],
      };

      const res = await this.fetch(`/iserver/account/${this.accountId}/orders`, {
        method: 'POST',
        body: JSON.stringify(body),
      });
      if (!res.ok) {
        return {
          ok: false,
          brokerName: this.name,
          mode: this.mode,
          rejectedReason: `IBKR ${res.status}: ${(await safeText(res)).slice(0, 240)}`,
        };
      }
      const out = (await res.json()) as IbkrOrderResponse;
      const first = out[0] || {};
      if (first.warning_message) {
        return {
          ok: false,
          brokerName: this.name,
          mode: this.mode,
          rejectedReason: `IBKR warning: ${first.warning_message}`,
        };
      }
      return {
        ok: Boolean(first.order_id),
        orderId: first.order_id || first.local_order_id,
        brokerName: this.name,
        mode: this.mode,
        acceptedAt: new Date().toISOString(),
      };
    } catch (err) {
      return {
        ok: false,
        brokerName: this.name,
        mode: this.mode,
        rejectedReason: err instanceof Error ? err.message : 'ibkr submit failed',
      };
    }
  }

  async getAccount(): Promise<BrokerAccount> {
    try {
      const res = await this.fetch(`/portfolio/${this.accountId}/summary`);
      if (!res.ok) throw new Error(`${res.status}`);
      const data = (await res.json()) as IbkrAccountSummary;
      return {
        brokerName: this.name,
        mode: this.mode,
        cash: Number(data.totalcashvalue?.amount || 0),
        equity: Number(data.netliquidation?.amount || 0),
        buyingPower: Number(data.availablefunds?.amount || 0),
      };
    } catch {
      return { brokerName: this.name, mode: this.mode, cash: 0, equity: 0, buyingPower: 0 };
    }
  }

  async getPositions(): Promise<BrokerPosition[]> {
    try {
      const res = await this.fetch(`/portfolio/${this.accountId}/positions/0`);
      if (!res.ok) return [];
      const data = (await res.json()) as IbkrPosition[];
      return data
        .filter((p) => (p.position || 0) !== 0)
        .map((p) => ({
          ticker: p.ticker || p.contractDesc || '',
          qty: Number(p.position || 0),
          avgPrice: Number(p.avgCost || 0),
          marketValue: Number(p.mktValue || 0),
          unrealizedPnl: Number(p.unrealizedPnl || 0),
        }));
    } catch {
      return [];
    }
  }

  private async resolveConid(ticker: string): Promise<number | null> {
    const res = await this.fetch(`/iserver/secdef/search?symbol=${encodeURIComponent(ticker)}`);
    if (!res.ok) return null;
    const arr = (await res.json()) as Array<{ conid?: number; symbol?: string }>;
    const match = arr.find((row) => row.symbol?.toUpperCase() === ticker.toUpperCase());
    return match?.conid || arr[0]?.conid || null;
  }

  private async fetch(path: string, init?: RequestInit) {
    const controller = new AbortController();
    const t = setTimeout(() => controller.abort(), 10_000);
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      Accept: 'application/json',
    };
    if (this.sessionToken) headers.Cookie = `api=${this.sessionToken}`;
    try {
      return await fetch(`${this.base}${path}`, {
        ...init,
        headers: { ...headers, ...(init?.headers || {}) },
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
