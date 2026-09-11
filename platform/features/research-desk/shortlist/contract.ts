import { z } from 'zod';
const day = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(value => {
  const parsed = new Date(`${value}T00:00:00Z`);
  return Number.isFinite(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
}, 'Invalid observation date');
const timestamp = z.string().datetime({ offset: true });
const numeric = z.number().finite();
const criterion = z.object({ id: z.enum(['trend', 'momentum', 'price_discipline']), label: z.string(), passed: z.boolean(), detail: z.string() }).strict();
const row = z.object({
  rank: z.number().int().positive(), symbol: z.string().regex(/^[A-Z0-9.\-]{1,16}$/), name: z.string(), assetType: z.string(),
  criteriaMet: z.number().int().min(0).max(3), criteriaTotal: z.literal(3), summary: z.string(), counterpoint: z.string(), watch: z.string(),
  close: numeric.positive(), changePercent: numeric.nullable(), rsi14: numeric.min(0).max(100), sma20: numeric.positive(), sma50: numeric.positive(),
  atr14: numeric.nonnegative(), atrPercent: numeric.nonnegative(), priceVsSma20Percent: numeric,
  asOf: day, source: z.string(), sourceRetrievedAt: timestamp, priceObservedAt: timestamp, dailyCloseObservedAt: z.null(),
  coverage: z.object({ state: z.string(), observedSessions: z.number().int().nonnegative(), adjustmentPolicy: z.string() }).passthrough(),
  criteria: z.array(criterion).length(3),
}).strict().superRefine((value, context) => {
  if (new Set(value.criteria.map(item => item.id)).size !== 3 || value.criteria.filter(item => item.passed).length !== value.criteriaMet) context.addIssue({ code: z.ZodIssueCode.custom, message: 'Inconsistent criterion records' });
});
export const shortlistSchema = z.object({
  schemaVersion: z.literal('astra-shortlist.v1'), featureVersion: z.literal('astra-technical-shortlist.v1'),
  dataMode: z.literal('historical_snapshot_not_live'), asOf: day, sourceRetrievedAt: timestamp, inputSha256: z.string().regex(/^[a-f0-9]{64}$/),
  reviewAfter: timestamp.nullable(),
  universe: z.object({ observedAssets: z.number().int().nonnegative(), companyStocks: z.number().int().nonnegative(), funds: z.number().int().nonnegative(), eligibleCompanyStocks: z.number().int().nonnegative(), eligibleFunds: z.number().int().nonnegative() }).strict(),
  methodology: z.object({ criteria: z.array(z.object({ id: z.string(), label: z.string(), definition: z.string() }).strict()).length(3), ranking: z.string(), scoreMeaning: z.string(), sourceCutoffMeaning: z.string(), reviewAfterMeaning: z.string(), calendarSource: z.string().nullable(), calendarVerifiedAt: z.string().nullable() }).strict(),
  stocks: z.array(row).max(20000), funds: z.array(row).max(20000), exclusions: z.array(z.object({ symbol: z.string(), reason: z.string() }).strict()),
  limitations: z.array(z.string()), predictionEnabled: z.literal(false), executionEnabled: z.literal(false),
}).strict().superRefine((value, context) => {
  for (const group of [value.stocks, value.funds]) {
    if (group.some((item, index) => item.rank !== index + 1 || item.asOf !== value.asOf) || new Set(group.map(item => item.symbol)).size !== group.length) context.addIssue({ code: z.ZodIssueCode.custom, message: 'Inconsistent shortlist ordering or cutoff' });
  }
  if (value.universe.eligibleCompanyStocks !== value.stocks.length || value.universe.eligibleFunds !== value.funds.length) context.addIssue({ code: z.ZodIssueCode.custom, message: 'Inconsistent universe counts' });
});
export type Shortlist = z.infer<typeof shortlistSchema>;
export type ShortlistRow = Shortlist['stocks'][number];
/** Display freshness only. The browser never scores or recomputes a financial rule. */
export function shortlistAge(data: Shortlist, now = Date.now()): 'dated' | 'review-needed' | 'invalid-future' {
  if (Date.parse(`${data.asOf}T00:00:00Z`) > now || Date.parse(data.sourceRetrievedAt) > now) return 'invalid-future';
  return data.reviewAfter && now >= Date.parse(data.reviewAfter) ? 'review-needed' : 'dated';
}
