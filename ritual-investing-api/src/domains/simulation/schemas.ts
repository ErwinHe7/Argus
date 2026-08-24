import { z } from "@hono/zod-openapi";

export const uuidParams = z.object({ id: z.uuid() }).strict();
export const orderParams = z.object({ order_id: z.uuid() }).strict();
export const sourceParams = z.object({ source_id: z.uuid() }).strict();
export const portfolioParams = z.object({ portfolio_id: z.uuid() }).strict();
export const planParams = z.object({ plan_id: z.uuid() }).strict();
export const intentionParams = z.object({ intention_id: z.uuid() }).strict();
export const sessionParams = z.object({ session_id: z.uuid() }).strict();
export const runParams = z
  .object({ intention_id: z.uuid(), run_id: z.uuid() })
  .strict();

export const moneySchema = z
  .object({
    minor_units: z.number().int().min(0).max(Number.MAX_SAFE_INTEGER),
    currency: z.literal("USD"),
  })
  .strict()
  .openapi("Money");
export const signedMoneySchema = z
  .object({
    minor_units: z
      .number()
      .int()
      .min(-Number.MAX_SAFE_INTEGER)
      .max(Number.MAX_SAFE_INTEGER),
    currency: z.literal("USD"),
  })
  .strict()
  .openapi("SignedMoney");
export const inputMoneySchema = z
  .object({
    minor_units: z.number().int().min(0).max(1_000_000_000),
    currency: z.literal("USD"),
  })
  .strict()
  .openapi("InputMoney");
export const positiveMoneySchema = z
  .object({
    minor_units: z.number().int().min(1).max(1_000_000_000),
    currency: z.literal("USD"),
  })
  .strict()
  .openapi("PositiveInputMoney");
export const quantitySchema = z
  .object({
    value: z
      .string()
      .max(23)
      .regex(/^(?:0|[1-9]\d*)(?:\.\d{1,12})?$/)
      .refine((value) => Number(value) > 0 && Number(value) <= 1_000_000_000),
    scale: z.number().int().min(0).max(12),
  })
  .strict()
  .openapi("Quantity");
export const demoDisclosureSchema = z
  .object({
    is_demo: z.literal(true),
    observed_at: z.iso.datetime({ offset: true }),
    source_label: z.string().min(1).max(120),
    limitations: z.array(z.string().min(1).max(240)).min(1).max(8),
  })
  .strict()
  .openapi("SimulationDemoDisclosure");

export const portfolioAllocationSchema = z
  .object({
    asset_id: z.uuid(),
    target_bps: z.number().int().min(0).max(10_000),
  })
  .strict();
export const portfolioAllocationListSchema = z
  .array(portfolioAllocationSchema)
  .max(50)
  .superRefine((allocations, context) => {
    if (
      new Set(allocations.map((item) => item.asset_id)).size !==
      allocations.length
    )
      context.addIssue({ code: "custom", message: "assets must be unique" });
    if (
      allocations.length > 0 &&
      allocations.reduce((sum, item) => sum + item.target_bps, 0) !== 10_000
    )
      context.addIssue({ code: "custom", message: "targets must total 10000" });
  });
export const portfolioPositionSchema = z
  .object({
    asset_id: z.uuid(),
    symbol: z.string().min(1).max(16),
    quantity: quantitySchema,
    market_value: moneySchema,
    as_of_transaction_id: z.uuid(),
    ledger_watermark: z.number().int().nonnegative(),
  })
  .strict();
export const portfolioViewSchema = z
  .object({
    id: z.uuid(),
    name: z.string().min(1).max(80),
    currency: z.literal("USD"),
    status: z.enum(["active", "archived"]),
    is_default: z.boolean(),
    cash: moneySchema,
    positions: z.array(portfolioPositionSchema),
    target_allocation: portfolioAllocationListSchema,
    latest_valuation: moneySchema,
    as_of_transaction_id: z.uuid().nullable(),
    ledger_watermark: z.number().int().nonnegative(),
    version: z.number().int().positive(),
    demo: demoDisclosureSchema,
  })
  .strict()
  .openapi("PortfolioView");
export const portfolioActivitySchema = z
  .object({
    id: z.uuid(),
    type: z.enum(["contribution", "order", "rebalance", "recurring"]),
    effective_at: z.iso.datetime({ offset: true }),
    description_code: z.string().min(1).max(80),
    cash: signedMoneySchema,
    ledger_watermark: z.number().int().positive(),
    demo: demoDisclosureSchema,
  })
  .strict()
  .openapi("PortfolioActivity");
export const portfolioSnapshotSchema = z
  .object({
    id: z.uuid(),
    as_of_transaction_id: z.uuid(),
    ledger_watermark: z.number().int().positive(),
    as_of: z.iso.datetime({ offset: true }),
    cash: moneySchema,
    market_value: moneySchema,
    demo: demoDisclosureSchema,
  })
  .strict()
  .openapi("PortfolioSnapshot");

export const simulationResultSchema = z
  .object({
    command_id: z.uuid(),
    status: z.enum(["committed", "rejected"]),
    portfolio_version: z.number().int().positive(),
    ledger_transaction_ids: z.array(z.uuid()).max(1),
    summary: z.record(z.string(), z.unknown()),
    projection_links: z.array(z.string().startsWith("/v1/")).max(20),
    demo: demoDisclosureSchema,
  })
  .strict()
  .openapi("SimulationResult");

export const idempotencyHeaders = z.object({
  "idempotency-key": z
    .string()
    .min(16)
    .max(64)
    .regex(/^[\x21-\x7e]+$/),
});
export const ifMatchHeaders = z.object({
  "if-match": z.string().regex(/^"v[1-9]\d*"$/),
});
export const commandHeaders = idempotencyHeaders;
export const versionedCommandHeaders = idempotencyHeaders.merge(ifMatchHeaders);
export const listQuerySchema = z
  .object({
    limit: z.coerce.number().int().min(1).max(50).default(20),
    cursor: z.string().min(20).max(2_048).optional(),
  })
  .strict();
export const boundedDateQuerySchema = listQuerySchema
  .extend({ from: z.iso.date().optional(), to: z.iso.date().optional() })
  .superRefine((value, context) => {
    if (value.from === undefined || value.to === undefined) return;
    const from = new Date(`${value.from}T00:00:00Z`);
    const to = new Date(`${value.to}T00:00:00Z`);
    if (to < from || to.getTime() - from.getTime() > 366 * 86_400_000)
      context.addIssue({
        code: "custom",
        message: "date range must be 0-366 days",
      });
  });

export const contributionSchema = z
  .object({
    amount: positiveMoneySchema,
    source_id: z.uuid(),
    effective_at: z.iso.datetime({ offset: true }).optional(),
  })
  .strict();

export const portfolioCreateSchema = z
  .object({
    name: z.string().trim().min(1).max(80),
    currency: z.literal("USD"),
    target_allocation: portfolioAllocationListSchema.optional(),
  })
  .strict();
export const portfolioPatchSchema = z
  .object({
    name: z.string().trim().min(1).max(80).optional(),
    target_allocation: portfolioAllocationListSchema.optional(),
  })
  .strict()
  .refine((value) => Object.keys(value).length > 0);
export const fundingFixtureSchema = z
  .object({ fixture_key: z.enum(["moon_reserve", "constellation_savings"]) })
  .strict();
export const fundingSourceSchema = z
  .object({
    id: z.uuid(),
    fixture_key: z.enum(["moon_reserve", "constellation_savings"]),
    display_label: z.string().min(1).max(80),
    fictional_last4: z.string().regex(/^\d{4}$/),
    status: z.enum(["active", "inactive"]),
    demo: demoDisclosureSchema,
  })
  .strict()
  .openapi("DemoFundingSource");

const notionalOrQuantity = z
  .object({
    notional: positiveMoneySchema.optional(),
    quantity: quantitySchema.optional(),
  })
  .strict()
  .refine(
    (value) =>
      (value.notional === undefined) !== (value.quantity === undefined),
    {
      message: "exactly one of notional or quantity is required",
    },
  );
export const orderPreviewInputSchema = notionalOrQuantity.extend({
  asset_id: z.uuid(),
  side: z.enum(["buy", "sell"]),
});
export const orderPreviewSchema = z
  .object({
    id: z.uuid(),
    portfolio_id: z.uuid(),
    asset_id: z.uuid(),
    symbol: z.string().min(1).max(16),
    side: z.enum(["buy", "sell"]),
    notional: moneySchema,
    quantity: quantitySchema,
    frozen_price: moneySchema,
    quote_snapshot_id: z.uuid(),
    portfolio_version: z.number().int().positive(),
    observed_at: z.iso.datetime({ offset: true }),
    expires_at: z.iso.datetime({ offset: true }),
    status: z.enum(["active", "executed", "expired", "invalidated"]),
    demo: demoDisclosureSchema,
  })
  .strict()
  .openapi("OrderPreview");
export const orderCommitSchema = z
  .object({
    preview_id: z.uuid(),
    portfolio_version: z.number().int().positive(),
  })
  .strict();
export const orderListQuerySchema = listQuerySchema.extend({
  portfolio_id: z.uuid().optional(),
  status: z.enum(["accepted", "rejected"]).optional(),
});
export const orderViewSchema = z
  .object({
    id: z.uuid(),
    portfolio_id: z.uuid(),
    command_id: z.uuid(),
    asset_id: z.uuid(),
    symbol: z.string().min(1).max(16),
    side: z.enum(["buy", "sell"]),
    status: z.enum(["accepted", "rejected"]),
    quantity: quantitySchema.nullable(),
    notional: moneySchema.nullable(),
    fill: z
      .object({
        quantity: quantitySchema,
        price: moneySchema,
        filled_at: z.iso.datetime({ offset: true }),
      })
      .strict()
      .nullable(),
    demo: demoDisclosureSchema,
  })
  .strict()
  .openapi("SimulatedOrder");

export const recurringAllocationSchema = z
  .object({
    asset_id: z.uuid(),
    weight_bps: z.number().int().min(0).max(10_000),
  })
  .strict();
export const recurringAllocationListSchema = z
  .array(recurringAllocationSchema)
  .min(1)
  .max(50)
  .superRefine((allocations, context) => {
    if (
      new Set(allocations.map((item) => item.asset_id)).size !==
      allocations.length
    )
      context.addIssue({ code: "custom", message: "assets must be unique" });
    if (allocations.reduce((sum, item) => sum + item.weight_bps, 0) !== 10_000)
      context.addIssue({ code: "custom", message: "weights must total 10000" });
  });
export const recurringPlanCreateSchema = z
  .object({
    type: z.enum(["contribution", "allocation"]),
    amount: positiveMoneySchema,
    frequency: z.enum(["weekly", "monthly"]),
    source_id: z.uuid(),
    allocations: recurringAllocationListSchema,
    first_run_at: z.iso.datetime({ offset: true }),
  })
  .strict();
export const recurringPlanPatchSchema = z
  .object({
    amount: positiveMoneySchema.optional(),
    frequency: z.enum(["weekly", "monthly"]).optional(),
    allocations: recurringAllocationListSchema.optional(),
  })
  .strict()
  .refine((value) => Object.keys(value).length > 0);
export const recurringPlanSchema = z
  .object({
    id: z.uuid(),
    portfolio_id: z.uuid(),
    type: z.enum(["contribution", "allocation"]),
    amount: moneySchema,
    frequency: z.enum(["weekly", "monthly"]),
    next_run_at: z.iso.datetime({ offset: true }),
    status: z.enum(["active", "paused", "cancelled", "completed"]),
    allocations: recurringAllocationListSchema,
    recent_runs: z
      .array(
        z
          .object({
            id: z.uuid(),
            scheduled_for: z.iso.datetime({ offset: true }),
            status: z.enum(["due", "running", "completed", "rejected"]),
          })
          .strict(),
      )
      .max(10),
    version: z.number().int().positive(),
    demo: demoDisclosureSchema,
  })
  .strict()
  .openapi("RecurringPlan");
export const recurringListQuerySchema = listQuerySchema.extend({
  status: z.enum(["active", "paused", "cancelled", "completed"]).optional(),
});

export const rebalancePreviewInputSchema = z
  .object({ target_allocation: portfolioAllocationListSchema })
  .strict();
export const rebalanceTradeSchema = z
  .object({
    asset_id: z.uuid(),
    side: z.enum(["buy", "sell"]),
    quantity: quantitySchema,
    notional: moneySchema,
  })
  .strict();
export const rebalancePreviewSchema = z
  .object({
    id: z.uuid(),
    portfolio_id: z.uuid(),
    portfolio_version: z.number().int().positive(),
    target_allocation: portfolioAllocationListSchema,
    trades: z.array(rebalanceTradeSchema).max(50),
    expires_at: z.iso.datetime({ offset: true }),
    status: z.enum(["active", "executed", "expired", "invalidated"]),
    demo: demoDisclosureSchema,
  })
  .strict()
  .openapi("RebalancePreview");
export const rebalanceCommitSchema = orderCommitSchema;

export const intentionCreateSchema = z
  .object({
    title: z.string().trim().min(1).max(120),
    target: positiveMoneySchema,
    target_date: z.iso.date(),
    portfolio_id: z.uuid(),
  })
  .strict();
export const intentionPatchSchema = z
  .object({
    title: z.string().trim().min(1).max(120).optional(),
    target: positiveMoneySchema.optional(),
    target_date: z.iso.date().optional(),
    status: z.enum(["active", "completed"]).optional(),
  })
  .strict()
  .refine((value) => Object.keys(value).length > 0);
export const intentionListQuerySchema = listQuerySchema.extend({
  status: z.enum(["active", "completed", "archived"]).optional(),
});
export const intentionSchema = z
  .object({
    id: z.uuid(),
    portfolio_id: z.uuid(),
    title: z.string(),
    target: moneySchema,
    target_date: z.iso.date(),
    status: z.enum(["active", "completed", "archived"]),
    progress: moneySchema,
    progress_bps: z.number().int().min(0).max(10_000),
    latest_projection_id: z.uuid().nullable(),
    version: z.number().int().positive(),
    demo: demoDisclosureSchema,
  })
  .strict()
  .openapi("Intention");
export const futureMirrorInputSchema = z
  .object({
    name: z.string().trim().min(1).max(80),
    monthly_contribution: inputMoneySchema,
    annual_return_bps: z
      .object({
        low: z.number().int().min(-5_000).max(5_000),
        mid: z.number().int().min(-5_000).max(5_000),
        high: z.number().int().min(-5_000).max(5_000),
      })
      .strict()
      .refine((value) => value.low <= value.mid && value.mid <= value.high),
  })
  .strict();
export const futureMirrorPointSchema = z
  .object({
    date: z.iso.date(),
    low: moneySchema,
    mid: moneySchema,
    high: moneySchema,
  })
  .strict();
export const futureMirrorSchema = z
  .object({
    id: z.uuid(),
    intention_id: z.uuid(),
    assumptions: futureMirrorInputSchema,
    points: z.array(futureMirrorPointSchema).min(1).max(120),
    generated_at: z.iso.datetime({ offset: true }),
    model_version: z.literal("ritual-demo-v1"),
    input_hash: z.string().regex(/^[a-f0-9]{64}$/),
    ledger_watermark: z.number().int().positive(),
    uncertainty: z.string().min(1),
    demo: demoDisclosureSchema,
  })
  .strict()
  .openapi("FutureMirrorView");

export const demoPlanSchema = z
  .object({
    code: z.enum(["free", "premium_demo"]),
    display_name: z.string(),
    price_copy: z.string(),
    feature_codes: z.array(z.string()),
    demo: demoDisclosureSchema,
  })
  .strict()
  .openapi("DemoPlan");
export const entitlementSchema = z
  .object({
    id: z.uuid(),
    plan_code: z.enum(["free", "premium_demo"]),
    status: z.enum(["active", "expired", "revoked"]),
    source: z.literal("demo"),
    starts_at: z.iso.datetime({ offset: true }),
    ends_at: z.iso.datetime({ offset: true }).nullable(),
    version: z.number().int().positive(),
    demo: demoDisclosureSchema,
  })
  .strict()
  .openapi("DemoEntitlement");
export const checkoutCreateSchema = z
  .object({ plan_code: z.literal("premium_demo") })
  .strict();
export const checkoutSessionSchema = z
  .object({
    id: z.uuid(),
    plan_code: z.literal("premium_demo"),
    status: z.enum(["open", "completed", "expired", "cancelled"]),
    expires_at: z.iso.datetime({ offset: true }),
    version: z.number().int().positive(),
    demo: demoDisclosureSchema,
  })
  .strict()
  .openapi("DemoCheckoutSession");
export const demoResetSchema = z
  .object({
    confirmation: z.literal("RESET_DEMO"),
    seed_version: z.number().int().positive(),
  })
  .strict();
export const demoResetResultSchema = z
  .object({
    reset_generation: z.number().int().positive(),
    default_portfolio: z
      .object({
        id: z.uuid(),
        name: z.string(),
        currency: z.literal("USD"),
        status: z.literal("active"),
        version: z.number().int().positive(),
      })
      .strict(),
    entitlement: z
      .object({
        id: z.uuid(),
        plan_code: z.literal("free"),
        status: z.literal("active"),
        source: z.literal("demo"),
        version: z.number().int().positive(),
      })
      .strict(),
    demo: demoDisclosureSchema,
  })
  .strict()
  .openapi("DemoResetResult");

export type PortfolioCreateInput = z.infer<typeof portfolioCreateSchema>;
export type PortfolioPatchInput = z.infer<typeof portfolioPatchSchema>;
export type FundingFixtureInput = z.infer<typeof fundingFixtureSchema>;
export type FundingSource = z.infer<typeof fundingSourceSchema>;
export type OrderPreviewInput = z.infer<typeof orderPreviewInputSchema>;
export type OrderPreview = z.infer<typeof orderPreviewSchema>;
export type OrderCommitInput = z.infer<typeof orderCommitSchema>;
export type OrderView = z.infer<typeof orderViewSchema>;
export type RecurringPlanCreateInput = z.infer<
  typeof recurringPlanCreateSchema
>;
export type RecurringPlanPatchInput = z.infer<typeof recurringPlanPatchSchema>;
export type RecurringPlan = z.infer<typeof recurringPlanSchema>;
export type RebalancePreviewInput = z.infer<typeof rebalancePreviewInputSchema>;
export type RebalancePreview = z.infer<typeof rebalancePreviewSchema>;
export type IntentionCreateInput = z.infer<typeof intentionCreateSchema>;
export type IntentionPatchInput = z.infer<typeof intentionPatchSchema>;
export type Intention = z.infer<typeof intentionSchema>;
export type FutureMirrorInput = z.infer<typeof futureMirrorInputSchema>;
export type FutureMirror = z.infer<typeof futureMirrorSchema>;
export type DemoPlan = z.infer<typeof demoPlanSchema>;
export type DemoEntitlement = z.infer<typeof entitlementSchema>;
export type CheckoutSession = z.infer<typeof checkoutSessionSchema>;

export type Money = z.infer<typeof moneySchema>;
export type PortfolioView = z.infer<typeof portfolioViewSchema>;
export type SimulationResult = z.infer<typeof simulationResultSchema>;
export type ContributionInput = z.infer<typeof contributionSchema>;

export function etagVersion(value: string): number {
  return Number(value.slice(2, -1));
}
