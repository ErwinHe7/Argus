/** Decimal strings remain canonical. TypeScript only validates, formats, and draws engine output. */
export interface GridSourceEvidence {
  source: string;
  dataset_sha256: string;
  calendar_source: string;
  adjustment: 'split_adjusted' | 'unadjusted_no_actions';
  coverage: 'user_asserted_complete';
  availability: 'point_in_time';
  classification: 'observed' | 'synthetic_fixture';
  license_scope: string;
}

export interface GridBar {
  session_date: string;
  open_at: string;
  close_at: string;
  available_at: string;
  open: string;
  high: string;
  low: string;
  close: string;
  volume: number;
}

export interface GridRequest {
  schema_version: 'leo-grid-request.v1';
  symbol: string;
  configured_at: string;
  as_of: string;
  lower: string;
  upper: string;
  tick_size: string;
  starting_capital: string;
  commission_per_order: string;
  intervals: number;
  spacing: 'arithmetic' | 'geometric';
  slippage_bps: number;
  portfolio_loss_limit_bps: number;
  source_evidence: GridSourceEvidence;
  bars: GridBar[];
}

export interface GridSlot {
  slot_id: number;
  buy_level: string;
  sell_level: string;
  budget: string;
  quantity_per_cycle: number;
  held_quantity: number;
  entry_price: string | null;
  entry_fee: string;
  completed_cycles: number;
  pending: 'buy' | 'sell' | null;
}

export interface GridJournalEvent {
  event_id: string;
  at: string;
  session_date: string;
  slot_id: number | null;
  kind: string;
  reason: string;
  quantity_delta: number;
  price: string | null;
  cash_delta: string;
  fee: string;
}

export interface GridEquityPoint {
  session_date: string;
  at: string;
  cash: string;
  quantity: number;
  market_value: string;
  equity: string;
  total_pnl: string;
  total_return: number;
  drawdown: number;
  realized_cycle_pnl: string;
  realized_exit_pnl: string;
  unrealized_pnl: string;
  fees: string;
  loss_latched: boolean;
  out_of_range: boolean;
}

export interface GridResult {
  schema_version: 'leo-grid-result.v1';
  strategy: 'GRID-R1';
  run_id: string;
  configuration_hash: string;
  canonical_bars_sha256: string;
  configuration: Omit<GridRequest, 'bars'>;
  fill_model: 'DAILY_CLOSE_SIGNAL_NEXT_OPEN_LIMIT_APPROXIMATION';
  evidence_status: 'SYNTHETIC_DEMONSTRATION' | 'USER_SUPPLIED_OBSERVED_NOT_INDEPENDENTLY_VERIFIED';
  execution_authorized: false;
  paper_execution_available: false;
  promotion_eligible: false;
  limitations: string[];
  levels: string[];
  slots: GridSlot[];
  journal: GridJournalEvent[];
  equity: GridEquityPoint[];
  metrics: {
    sessions: number;
    completed_cycles: number;
    open_slots: number;
    ending_cash: string;
    ending_quantity: number;
    ending_equity: string;
    total_pnl: string;
    total_return: number;
    max_drawdown: number;
    realized_cycle_pnl: string;
    realized_exit_pnl: string;
    unrealized_pnl: string;
    fees: string;
    loss_latched: boolean;
    pending_liquidation: boolean;
    range_breach_sessions: number;
    return_bps: number;
    buy_hold_return_bps: number;
    realized_loss_exit_pnl: string;
    cash: string;
    marked_inventory: string;
    equity: string;
    max_drawdown_bps: number;
    range_breaches: number;
  };
  benchmarks: {
    cash_ending_equity: string;
    cash_total_return: number;
    buy_and_hold_ending_equity: string;
    buy_and_hold_total_return: number;
  };
}
