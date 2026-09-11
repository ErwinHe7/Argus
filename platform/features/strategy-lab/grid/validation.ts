import { z } from 'zod';
import type { GridRequest, GridResult } from './types';

export const GRID_MAX_IMPORT_BYTES = 4 * 1024 * 1024;
const decimal = z.string().max(64).regex(/^-?\d+(?:\.\d+)?$/, 'Use a decimal string, for example "100.00".');
const text = z.string().min(1).max(2048);
const hash = z.string().regex(/^[a-fA-F0-9]{64}$/, 'Provide a 64-character SHA-256 digest.');
const timestamp = z.string().datetime({ offset: true });
const session = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Use a YYYY-MM-DD session date.');
const count = z.number().int().nonnegative().safe();
const ratio = z.number().finite();

const sourceSchema = z.object({
  source: text,
  dataset_sha256: hash,
  calendar_source: text,
  adjustment: z.enum(['split_adjusted', 'unadjusted_no_actions']),
  coverage: z.literal('user_asserted_complete'),
  availability: z.literal('point_in_time'),
  classification: z.enum(['observed', 'synthetic_fixture']),
  license_scope: text,
}).strict();

export const gridConfigurationSchema = z.object({
  schema_version: z.literal('leo-grid-request.v1'),
  symbol: z.string().regex(/^[A-Z][A-Z0-9.\-]{0,9}$/, 'Use an uppercase U.S. instrument symbol.'),
  configured_at: timestamp,
  as_of: timestamp,
  lower: decimal,
  upper: decimal,
  tick_size: decimal,
  starting_capital: decimal,
  commission_per_order: decimal,
  intervals: z.number().int().min(2).max(100),
  spacing: z.enum(['arithmetic', 'geometric']),
  slippage_bps: z.number().int().min(0).max(1000),
  portfolio_loss_limit_bps: z.number().int().min(1).max(10000),
  source_evidence: sourceSchema,
}).strict();

export const gridRequestSchema = gridConfigurationSchema.extend({
  bars: z.array(z.object({
    session_date: session,
    open_at: timestamp,
    close_at: timestamp,
    available_at: timestamp,
    open: decimal,
    high: decimal,
    low: decimal,
    close: decimal,
    volume: count,
  }).strict()).min(2).max(5000),
}).strict();

export const gridResultSchema = z.object({
  schema_version: z.literal('leo-grid-result.v1'),
  strategy: z.literal('GRID-R1'),
  run_id: text,
  configuration_hash: hash,
  canonical_bars_sha256: hash,
  configuration: gridConfigurationSchema,
  fill_model: z.literal('DAILY_CLOSE_SIGNAL_NEXT_OPEN_LIMIT_APPROXIMATION'),
  evidence_status: z.enum(['SYNTHETIC_DEMONSTRATION', 'USER_SUPPLIED_OBSERVED_NOT_INDEPENDENTLY_VERIFIED']),
  execution_authorized: z.literal(false),
  paper_execution_available: z.literal(false),
  promotion_eligible: z.literal(false),
  limitations: z.array(text),
  levels: z.array(decimal).min(3).max(101),
  slots: z.array(z.object({
    slot_id: count,
    buy_level: decimal,
    sell_level: decimal,
    budget: decimal,
    quantity_per_cycle: count,
    held_quantity: count,
    entry_price: decimal.nullable(),
    entry_fee: decimal,
    completed_cycles: count,
    pending: z.enum(['buy', 'sell']).nullable(),
  }).strict()).min(2).max(100),
  journal: z.array(z.object({
    event_id: text,
    at: timestamp,
    session_date: session,
    slot_id: count.nullable(),
    kind: text,
    reason: text,
    quantity_delta: z.number().int().safe(),
    price: decimal.nullable(),
    cash_delta: decimal,
    fee: decimal,
  }).strict()),
  equity: z.array(z.object({
    session_date: session,
    at: timestamp,
    cash: decimal,
    quantity: count,
    market_value: decimal,
    equity: decimal,
    total_pnl: decimal,
    total_return: ratio,
    drawdown: ratio,
    realized_cycle_pnl: decimal,
    realized_exit_pnl: decimal,
    unrealized_pnl: decimal,
    fees: decimal,
    loss_latched: z.boolean(),
    out_of_range: z.boolean(),
  }).strict()).min(1),
  metrics: z.object({
    sessions: count,
    completed_cycles: count,
    open_slots: count,
    ending_cash: decimal,
    ending_quantity: count,
    ending_equity: decimal,
    total_pnl: decimal,
    total_return: ratio,
    max_drawdown: ratio,
    realized_cycle_pnl: decimal,
    realized_exit_pnl: decimal,
    unrealized_pnl: decimal,
    fees: decimal,
    loss_latched: z.boolean(),
    pending_liquidation: z.boolean(),
    range_breach_sessions: count,
    return_bps: ratio,
    buy_hold_return_bps: ratio,
    realized_loss_exit_pnl: decimal,
    cash: decimal,
    marked_inventory: decimal,
    equity: decimal,
    max_drawdown_bps: ratio,
    range_breaches: count,
  }).strict(),
  benchmarks: z.object({
    cash_ending_equity: decimal,
    cash_total_return: ratio,
    buy_and_hold_ending_equity: decimal,
    buy_and_hold_total_return: ratio,
  }).strict(),
}).strict();

function invalidMessage(error: z.ZodError, subject: string) {
  const first = error.issues[0];
  const location = first.path.length ? first.path.join('.') : 'document';
  return `${subject}: ${location} — ${first.message}`;
}

export function parseGridRequest(value: unknown): GridRequest {
  const parsed = gridRequestSchema.safeParse(value);
  if (!parsed.success) throw new Error(invalidMessage(parsed.error, 'Check the request'));
  return parsed.data;
}

export function parseGridResult(value: unknown): GridResult {
  const parsed = gridResultSchema.safeParse(value);
  if (!parsed.success) throw new Error(invalidMessage(parsed.error, 'The engine report could not be displayed'));
  return parsed.data;
}
