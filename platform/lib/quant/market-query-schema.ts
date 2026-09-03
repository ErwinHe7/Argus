import { z } from 'zod';

export const MarketQueryFiltersSchema = z
  .object({
    direction: z.enum(['down', 'up']).optional(),
    require_realtime: z.boolean().default(true),
    include_historical: z.boolean().default(false),
    max_data_age_seconds: z.number().int().min(1).max(3600).default(120),
    max_dte: z.number().int().min(0).max(60).default(14),
    exclude_earnings_within_days: z.number().int().min(0).max(60).optional(),
    maximum_option_spread_pct: z.number().min(0).max(1).optional(),
    minimum_option_quote_coverage: z.number().min(0).max(1).optional(),
  })
  .strict();

export const MarketQuerySchema = z
  .object({
    version: z.enum(['axio.market-query.v1', 'axio.market-query.v2']),
    intent: z.enum(['scan', 'forecast', 'backtest']),
    setup_type: z.enum([
      'model_forecast',
      'momentum',
      'gamma_squeeze',
      'vwap_reversal',
      'opening_turn',
      'closing_short_cover',
      'statistical_dislocation',
    ]),
    symbols: z
      .array(z.string().regex(/^[A-Za-z][A-Za-z0-9.]{0,9}$/))
      .min(1)
      .max(30),
    horizon_minutes: z
      .union([
        z.literal(5),
        z.literal(15),
        z.literal(30),
        z.literal(60),
      ])
      .optional(),
    limit: z.number().int().min(1).max(20),
    filters: MarketQueryFiltersSchema,
  })
  .strict()
  .superRefine((query, context) => {
    if (
      query.version === 'axio.market-query.v1' &&
      query.setup_type === 'model_forecast'
    ) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['version'],
        message:
          'model_forecast requires axio.market-query.v2; v1 is retained only for stored explicit-rule monitors.',
      });
      return;
    }
    if (query.setup_type === 'model_forecast') {
      if (query.intent === 'backtest') {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['intent'],
          message:
            'The live model forecast route does not substitute a rule backtest.',
        });
      }
      if (query.filters.direction !== undefined) {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['filters', 'direction'],
          message:
            'A neutral model forecast cannot carry a compiler-selected direction.',
        });
      }
      if (query.filters.include_historical) {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['filters', 'include_historical'],
          message:
            'A live model forecast does not include an unrelated historical rule replay.',
        });
      }
      return;
    }
    if (query.horizon_minutes === undefined) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['horizon_minutes'],
        message:
          'Deterministic rule research requires an explicit 5, 15, 30, or 60 minute horizon.',
      });
    }
    if (query.filters.direction === undefined) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['filters', 'direction'],
        message:
          'Deterministic rule research requires an explicit up or down direction.',
      });
    }
  });
