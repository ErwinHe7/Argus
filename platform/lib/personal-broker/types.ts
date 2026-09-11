export type AccountMode = 'SIMULATE' | 'REAL';
export type PersonalAccount = { id: string; mode: AccountMode; label: string; status: string; markets: string[] };
export type PersonalStatus = {
  provider: 'moomoo'; sdk_available: boolean; opend_reachable: boolean; connected: boolean;
  live_enabled: boolean; unlocked?: boolean; account: { id: string; mode: AccountMode } | null; message: string;
};
export type OrderIntent = { symbol: string; side: 'BUY' | 'SELL'; quantity: string; limit_price: string };
export type PersonalSnapshot = {
  as_of: string;
  account: { id: string; mode: AccountMode; currency: string; cash: string | null; buying_power: string | null; equity: string | null };
  positions: { symbol: string; quantity: string; available_quantity: string | null; market_value: string | null }[];
  orders: { id: string; symbol: string; side: string; status: string; quantity: string; filled_quantity: string; limit_price: string | null }[];
};
export type OrderPreview = {
  id: string; expires_at: string; account_id: string; mode: AccountMode; intent: OrderIntent;
  max_notional: string; estimated_notional: string; warnings: string[];
};
export type OrderCommand = { id: string; preview_id: string; status: 'submitted' | 'rejected' | 'unknown'; broker_order_id: string | null; message: string };
