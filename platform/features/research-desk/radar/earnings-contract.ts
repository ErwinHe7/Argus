import { z } from 'zod';

const finite = z.number().finite();
const nonnegative = finite.nonnegative();
const timestamp = z.string().datetime({ offset: true });
const source = z.object({
  title: z.string().trim().min(1).max(300),
  url: z.string().url().max(2048).refine(value => {
    const url = new URL(value);
    return url.protocol === 'https:' && !url.username && !url.password;
  }, 'An HTTPS source without credentials is required'),
}).strict();

const comparison = z.object({
  historical_count: z.number().int().min(3).max(9),
  event_ids: z.array(z.string().trim().min(1).max(100)).min(3).max(9),
  absolute_moves_percent: z.array(nonnegative).min(3).max(9),
  median_absolute_move_percent: nonnegative,
  raw_up_count: z.number().int().min(0).max(9),
  raw_down_count: z.number().int().min(0).max(9),
  raw_flat_count: z.number().int().min(0).max(9),
  raw_up_frequency_percent: nonnegative.max(100),
  straddle_mid_cost_percent: nonnegative,
  straddle_ask_cost_percent: nonnegative,
  cost_to_historical_median_ratio: nonnegative.nullable(),
}).strict().superRefine((value, context) => {
  if (value.event_ids.length !== value.historical_count
    || new Set(value.event_ids).size !== value.historical_count
    || value.absolute_moves_percent.length !== value.historical_count
    || value.raw_up_count + value.raw_down_count + value.raw_flat_count !== value.historical_count) {
    context.addIssue({ code: z.ZodIssueCode.custom, message: 'Historical sample counts do not agree' });
  }
  if (value.straddle_ask_cost_percent < value.straddle_mid_cost_percent) {
    context.addIssue({ code: z.ZodIssueCode.custom, message: 'Ask cost cannot be below midpoint cost' });
  }
  if ((value.median_absolute_move_percent === 0) !== (value.cost_to_historical_median_ratio === null)) {
    context.addIssue({ code: z.ZodIssueCode.custom, message: 'A zero historical median must withhold the ratio' });
  }
});

/** Validates report structure, never certifies imported source data or engine execution. */
export const earningsReportSchema = z.object({
  schema_version: z.literal('leo-earnings-comparison.v1'),
  feature_version: z.literal('earnings-comparison-1.0.0'),
  status: z.enum(['available', 'unavailable']),
  symbol: z.string().regex(/^[A-Z0-9.-]{1,12}$/),
  as_of: timestamp,
  event_at: timestamp,
  reason_codes: z.array(z.string().regex(/^[a-z_]+$/).max(100)).max(20),
  comparison: comparison.nullable(),
  sources: z.array(source).max(13),
  input_sha256: z.string().regex(/^[a-f0-9]{64}$/),
  prediction_enabled: z.literal(false),
  execution_enabled: z.literal(false),
  limitations: z.array(z.string().min(1).max(1000)).min(1).max(20),
}).strict().superRefine((value, context) => {
  if (value.status === 'available' && (value.comparison === null || value.reason_codes.length > 0
    || value.sources.length < 4 || Date.parse(value.as_of) >= Date.parse(value.event_at))) {
    context.addIssue({ code: z.ZodIssueCode.custom, message: 'Available evidence must precede its event and include sources' });
  }
  if (value.status === 'unavailable' && (value.comparison !== null || value.reason_codes.length === 0)) {
    context.addIssue({ code: z.ZodIssueCode.custom, message: 'Unavailable evidence must withhold calculations and explain the limit' });
  }
});

export type EarningsReport = z.infer<typeof earningsReportSchema>;

/** Deliberately incomplete; fill from entitled sources before sending to the native CLI. */
export const earningsRequestTemplate = {
  schema_version: 'leo-earnings-comparison-request.v1',
  symbol: '',
  as_of: null,
  event_at: null,
  event_known_at: null,
  event_source: { title: '', url: '' },
  history_source: { title: '', url: '' },
  history_price_basis: 'split_adjusted_regular_close',
  history_entitled: false,
  calendar: null,
  history: [],
  options: null,
} as const;
