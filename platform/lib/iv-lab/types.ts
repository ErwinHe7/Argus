import { z } from 'zod';
import type { IvLabArtifact, IvLabSymbol } from './artifacts/schema';
export type { IvLabSymbol, IvLabConfiguration, TechnicalPoint, OptionEvidence, OptionRight } from './artifacts/schema';
export type { IvLabArtifact as IvLabBundle, ScenarioCell as IvLabCell } from './artifacts/schema';

export const IV_LAB_SYMBOLS = ['DXYZ', 'ZM', 'AVGO', 'AMZN', 'GOOGL', 'NVDA'] as const;
export type IvLabTicker = typeof IV_LAB_SYMBOLS[number];
const tickerSchema = z.enum(IV_LAB_SYMBOLS);
const textSchema = z.string().min(1);
const finiteSchema = z.number().finite();
const dateSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine((value) => {
  const date = new Date(`${value}T00:00:00.000Z`);
  return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value;
}, 'Invalid calendar date');
const timestampSchema = z.string().refine((value) => {
  const normalized = value.replace(/ UTC$/, 'Z').replace(' ', 'T');
  return /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.test(normalized)
    && dateSchema.safeParse(normalized.slice(0, 10)).success && Number.isFinite(Date.parse(normalized));
}, 'An explicit, valid observation timestamp is required');
const urlSchema = z.string().url().refine((value) => new URL(value).protocol === 'https:', 'HTTPS source required');

const relationshipSchema = z.object({
  symbol: tickerSchema, kind: textSchema, asOf: dateSchema, publicationDate: dateSchema.nullable(),
  factZh: textSchema, fact: textSchema, sourceTitle: textSchema, sourceUrl: urlSchema,
  additionalSourceUrls: z.array(urlSchema).optional(), locators: z.array(textSchema).optional(), qualification: textSchema,
}).strict();

const eventSchema = z.object({
  id: textSchema, titleZh: textSchema, type: textSchema,
  status: z.enum(['confirmed-past', 'unconfirmed-date', 'hypothesis']),
  eventDate: dateSchema.nullable(), eventTimestamp: timestampSchema.nullable(),
  publicationDate: dateSchema.nullable(), factsZh: textSchema, sourceTitle: textSchema,
  sourceUrl: urlSchema, additionalSourceUrls: z.array(urlSchema).optional(), implication: textSchema,
}).strict().superRefine((event, context) => {
  if (event.status !== 'confirmed-past' && (event.eventDate !== null || event.eventTimestamp !== null)) {
    context.addIssue({ code: z.ZodIssueCode.custom, message: 'Unconfirmed events must not acquire dates' });
  }
  if (event.status === 'confirmed-past' && event.eventDate === null) {
    context.addIssue({ code: z.ZodIssueCode.custom, message: 'Confirmed past events require an event date' });
  }
});

export const ivLabEventsSchema = z.object({
  schemaVersion: z.literal('1.0'), verifiedAt: timestampSchema, coverage: textSchema,
  relationships: z.array(relationshipSchema).length(6), events: z.array(eventSchema).min(1),
  methodologySources: z.array(z.object({
    topic: textSchema, sourceTitle: textSchema.optional(), sourceUrl: urlSchema.optional(),
    publicationDate: z.string().regex(/^\d{4}-\d{2}(?:-\d{2})?$/).optional(),
    status: textSchema.optional(), summaryZh: textSchema,
  }).strict()), unknowns: z.array(textSchema),
}).strict().superRefine((bundle, context) => {
  if (new Set(bundle.relationships.map((item) => item.symbol)).size !== 6
      || new Set(bundle.events.map((item) => item.id)).size !== bundle.events.length) {
    context.addIssue({ code: z.ZodIssueCode.custom, message: 'Duplicate research identities' });
  }
});

export type IvLabEvents = z.infer<typeof ivLabEventsSchema>;
export type IvLabOverview = Omit<IvLabArtifact, 'symbols'> & {
  symbols: Omit<IvLabSymbol, 'configurations'>[];
  events: IvLabEvents;
};

const positiveSchema = finiteSchema.positive();
const nonnegativeSchema = finiteSchema.nonnegative();
const optionRightSchema = z.enum(['call', 'put']);
const technicalPointSchema = z.object({
  date: dateSchema, close: positiveSchema, volume: nonnegativeSchema.nullable(),
  sma20: positiveSchema.nullable(), bollingerUpper: finiteSchema.nullable(), bollingerLower: finiteSchema.nullable(),
  rsi14: finiteSchema.min(0).max(100).nullable(), atr14: nonnegativeSchema.nullable(),
  k: finiteSchema.nullable(), d: finiteSchema.nullable(), j: finiteSchema.nullable(),
  macd: finiteSchema.nullable(), macdSignal: finiteSchema.nullable(), macdHistogram: finiteSchema.nullable(),
  realizedVol20Percent: nonnegativeSchema.nullable(), relativeVolume20: nonnegativeSchema.nullable(),
  return1dPercent: finiteSchema.nullable(), return5dPercent: finiteSchema.nullable(),
  priceVsSma20Percent: finiteSchema.nullable(), trend: z.enum(['bullish', 'bearish', 'neutral']),
}).strict();
const cellSchema = z.object({
  spotMovePercent: finiteSchema, ivShiftPp: finiteSchema, newSpot: positiveSchema,
  newIvPercent: finiteSchema, daysRemaining: nonnegativeSchema,
  status: z.enum(['valid', 'invalid_iv']),
  price: nonnegativeSchema.nullable(), pnl: finiteSchema.nullable(), pnlPercent: finiteSchema.nullable(),
  premiumPerContract: nonnegativeSchema.nullable(), pnlPerContract: finiteSchema.nullable(),
  priceOnlyPnl: finiteSchema.nullable(), ivOnlyPnl: finiteSchema.nullable(),
  timeOnlyPnl: finiteSchema.nullable(), interactionPnl: finiteSchema.nullable(),
}).strict().superRefine((cell, context) => {
  const values = [cell.price, cell.pnl, cell.premiumPerContract, cell.pnlPerContract,
    cell.priceOnlyPnl, cell.ivOnlyPnl, cell.timeOnlyPnl, cell.interactionPnl];
  if (cell.status === 'valid' && (cell.newIvPercent <= 0 || cell.newIvPercent > 500 || values.some((value) => value === null))) {
    context.addIssue({ code: z.ZodIssueCode.custom, message: 'Valid scenario has absent values or invalid IV' });
  }
  if (cell.status === 'invalid_iv' && ((cell.newIvPercent > 0 && cell.newIvPercent <= 500) || [...values, cell.pnlPercent].some((value) => value !== null))) {
    context.addIssue({ code: z.ZodIssueCode.custom, message: 'Invalid-IV scenarios must withhold calculated values' });
  }
});
const configurationSchema = z.object({
  id: textSchema, tenorDays: positiveSchema.int(), right: optionRightSchema,
  strikeOffsetPercent: finiteSchema, strike: positiveSchema,
  baseline: z.object({
    premium: nonnegativeSchema, premiumPerContract: nonnegativeSchema,
    delta: finiteSchema.nullable(), gamma: nonnegativeSchema.nullable(),
    vegaPerPp: nonnegativeSchema, thetaPerDay: finiteSchema.nullable(),
    breakevenAtExpiry: finiteSchema, fullPremiumLossPerContract: nonnegativeSchema,
  }).strict(),
  scenarios: z.array(z.object({ elapsedDays: nonnegativeSchema.int(), cells: z.array(cellSchema).min(1) }).strict()).min(1),
}).strict();
const optionEvidenceSchema = z.object({
  symbol: textSchema, expirationDate: dateSchema, expirationTimestamp: z.null(),
  side: optionRightSchema, strike: positiveSchema, description: textSchema, currency: textSchema, exchange: textSchema,
  multiplier: positiveSchema.nullable(), multiplierNote: textSchema,
  last: nonnegativeSchema.nullable(), lastTradeTime: timestampSchema.nullable(),
  bid: nonnegativeSchema.nullable(), ask: nonnegativeSchema.nullable(), mid: nonnegativeSchema.nullable(),
  midMethod: textSchema, bidAskAsOf: timestampSchema.nullable(),
  ivAnnual: positiveSchema.nullable(), ivAsOf: timestampSchema.nullable(), midpointIv: positiveSchema.nullable(),
  openInterest: nonnegativeSchema.nullable(), openInterestAsOf: timestampSchema.nullable(),
  volume: nonnegativeSchema.nullable(), greeks: z.null(), executionEligible: z.literal(false),
  evidenceStatus: z.literal('incomplete_independent_field_timestamps'),
}).strict();
const symbolSchema = z.object({
  symbol: tickerSchema, label: textSchema,
  market: z.object({
    spot: positiveSchema, currency: z.literal('USD'), observedAt: timestampSchema, availableAt: timestampSchema,
    source: textSchema, basis: z.literal('last_trade_reference_may_be_after_hours'),
    dailyBarLastDate: dateSchema, dailyBarCloseObservedAt: z.null(), dailyBarTimestampMeaning: textSchema,
    freshness: z.literal('historical_snapshot_not_live'), executionEligible: z.literal(false),
    coverage: z.object({
      state: z.literal('observed_sessions_only_calendar_unverified'), observedSessions: positiveSchema.int(),
      startDate: dateSchema, endDate: dateSchema, expectedSessions: z.null(), adjustmentPolicy: textSchema,
      sourceSessions: positiveSchema.int(), validationExcludedPrefixSessions: nonnegativeSchema.int(),
      invalidDates: z.array(dateSchema), validationNote: textSchema,
    }).strict(),
  }).strict(),
  ivAssumption: z.object({
    annualIv: positiveSchema, ivPercentilePercent: finiteSchema.min(0).max(100).nullable(),
    classification: z.literal('user_scenario_assumption'), observedAt: z.null(), source: textSchema,
    retrievedAt: timestampSchema, percentileObservedAt: z.null(), percentileLookback: textSchema,
    units: z.literal('annualIv decimal; ivPercentilePercent percent; IV shocks additive percentage points'),
  }).strict(),
  technical: z.object({
    latest: technicalPointSchema, series: z.array(technicalPointSchema).min(1), definitions: z.record(textSchema),
    featureVersion: textSchema, predictionModelApplied: z.literal(false),
  }).strict(),
  configurations: z.array(configurationSchema).min(1), optionEvidence: z.array(optionEvidenceSchema),
}).strict();
const axisSchema = z.array(finiteSchema).min(1).refine((values) => new Set(values).size === values.length, 'Duplicate axis');

export const ivLabBundleSchema = z.object({
  schemaVersion: z.literal('leo-iv-lab.v1'), generatedAt: timestampSchema,
  inputSha256: z.string().regex(/^[a-f0-9]{64}$/),
  methodology: z.object({
    model: textSchema, modelVersion: textSchema, rateAnnual: finiteSchema, dividendYieldAnnual: finiteSchema,
    rateAndDividendSource: textSchema, optionCalendarDaysPerYear: positiveSchema.int(),
    realizedVolSessionsPerYear: positiveSchema.int(), assumedContractMultiplier: z.literal(100),
    premiumAndPnlUnits: z.literal('USD per share'),
    vegaUnits: z.literal('USD per share per +1 IV percentage point'),
    thetaUnits: z.literal('USD per share per elapsed calendar day'),
    strikeDefinition: textSchema, pnlPercentDefinition: textSchema, invalidIvPolicy: textSchema, decomposition: textSchema,
    executionEnabled: z.literal(false), predictionModelPromoted: z.literal(false), limitations: z.array(textSchema).min(1),
  }).strict(),
  axes: z.object({
    tenorDays: axisSchema, rights: z.array(optionRightSchema).min(1), strikeOffsetPercent: axisSchema,
    elapsedDays: axisSchema, spotMovePercent: axisSchema, ivShiftPp: axisSchema,
  }).strict(),
  defaults: z.object({ symbol: tickerSchema, tenorDays: positiveSchema.int(), right: optionRightSchema,
    strikeOffsetPercent: finiteSchema, elapsedDays: nonnegativeSchema.int() }).strict(),
  symbols: z.array(symbolSchema).length(6),
}).strict().superRefine((bundle, context) => {
  const reject = (message: string) => context.addIssue({ code: z.ZodIssueCode.custom, message });
  if (new Set(bundle.symbols.map((item) => item.symbol)).size !== 6) reject('Six distinct allowed symbols are required');
  if (!bundle.axes.tenorDays.every((value) => Number.isInteger(value) && value > 0)
    || !bundle.axes.elapsedDays.every((value) => Number.isInteger(value) && value >= 0)
    || new Set(bundle.axes.rights).size !== bundle.axes.rights.length) reject('Invalid scenario axis');
  for (const key of ['tenorDays', 'right', 'strikeOffsetPercent', 'elapsedDays'] as const) {
    const values = key === 'right' ? bundle.axes.rights : bundle.axes[key];
    if (!(values as readonly (number | string)[]).includes(bundle.defaults[key])) reject('Default outside scenario axes');
  }
  for (const symbol of bundle.symbols) {
    if (Date.parse(symbol.market.observedAt) > Date.parse(symbol.market.availableAt)
      || Date.parse(symbol.market.availableAt) > Date.parse(bundle.generatedAt)) reject('Non-causal source timestamps');
    if (symbol.technical.series.length !== symbol.market.coverage.observedSessions
      || symbol.technical.series[0].date !== symbol.market.coverage.startDate
      || symbol.technical.series.at(-1)!.date !== symbol.market.coverage.endDate
      || symbol.technical.latest.date !== symbol.market.dailyBarLastDate
      || symbol.technical.latest.date !== symbol.technical.series.at(-1)!.date
      || symbol.technical.series.some((point, index, series) => index > 0 && point.date <= series[index - 1].date)) reject('Inconsistent observed-session coverage');
    const identifiers = new Set<string>();
    const selections = new Set<string>();
    for (const configuration of symbol.configurations) {
      const selection = `${configuration.tenorDays}:${configuration.right}:${configuration.strikeOffsetPercent}`;
      if (identifiers.has(configuration.id) || selections.has(selection)) reject('Duplicate configuration');
      identifiers.add(configuration.id); selections.add(selection);
      if (!bundle.axes.tenorDays.includes(configuration.tenorDays) || !bundle.axes.rights.includes(configuration.right)
        || !bundle.axes.strikeOffsetPercent.includes(configuration.strikeOffsetPercent)) reject('Configuration outside axes');
      const days = new Set<number>();
      for (const scenario of configuration.scenarios) {
        if (!bundle.axes.elapsedDays.includes(scenario.elapsedDays) || days.has(scenario.elapsedDays)) reject('Invalid elapsed-day selection');
        days.add(scenario.elapsedDays);
        const cells = new Set<string>();
        for (const cell of scenario.cells) {
          const key = `${cell.spotMovePercent}:${cell.ivShiftPp}`;
          if (cells.has(key) || !bundle.axes.spotMovePercent.includes(cell.spotMovePercent)
            || !bundle.axes.ivShiftPp.includes(cell.ivShiftPp)) reject('Invalid cell axes');
          cells.add(key);
        }
        if (cells.size !== bundle.axes.spotMovePercent.length * bundle.axes.ivShiftPp.length) reject('Incomplete scenario cells');
      }
      if (days.size !== bundle.axes.elapsedDays.length) reject('Incomplete elapsed-day scenarios');
    }
    if (selections.size !== bundle.axes.tenorDays.length * bundle.axes.rights.length * bundle.axes.strikeOffsetPercent.length) reject('Incomplete configurations');
  }
});

/** Validate serialization and provenance only; model outputs remain unchanged. */
export function validateIvLabBundle(value: unknown): IvLabArtifact | null {
  const parsed = ivLabBundleSchema.safeParse(value);
  return parsed.success ? parsed.data : null;
}

/** URL contract only; deliberately performs no quantitative calculation. */
export function parseIvLabQuery(query: URLSearchParams): IvLabTicker | null {
  if ([...query.keys()].some((key) => key !== 'symbol') || query.getAll('symbol').length !== 1) return null;
  const parsed = tickerSchema.safeParse(query.get('symbol'));
  return parsed.success ? parsed.data : null;
}
