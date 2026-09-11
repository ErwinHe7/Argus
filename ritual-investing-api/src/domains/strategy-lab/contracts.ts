import { z } from "zod";

export const strategyIdSchema = z.enum(["MR-v1", "MOM-v1"]);
export const symbolSchema = z.string().regex(/^[A-Z][A-Z0-9.-]{0,9}$/);
export const modeSchema = z.enum(["dry_run", "paper"]);
export const parametersSchema = z.object({}).strict();
export const configurationInputSchema = z.object({
  strategyId: strategyIdSchema, symbol: symbolSchema, parameters: parametersSchema.default({}),
}).strict();
export const strategyVersionSchema = configurationInputSchema.extend({
  schemaVersion: z.literal("leo.strategy-version.v1"), id: z.string().uuid(),
  symbols: z.array(symbolSchema).length(1), configurationHash: z.string().regex(/^[a-f0-9]{64}$/), createdAt: z.string().datetime({offset:true}),
});
export type StrategyVersion = z.infer<typeof strategyVersionSchema>;
export type ConfigurationInput = z.infer<typeof configurationInputSchema>;
export const accountSchema = z.object({accountId:z.string().min(1).max(96),environment:z.literal("SIMULATE"),currency:z.literal("USD")}).strict();
export const deviceSchema = z.object({
  schemaVersion:z.literal("leo.connector-device.v1"),id:z.string().uuid(),name:z.string().min(1).max(80),
  platform:z.enum(["windows","macos","linux"]),accounts:z.array(accountSchema).max(20),
  createdAt:z.string().datetime({offset:true}),lastSeenAt:z.string().datetime({offset:true}).nullable(),revokedAt:z.string().datetime({offset:true}).nullable(),
  lastSequence:z.number().int().nonnegative(),instanceId:z.string().uuid().nullable().default(null),
});
export type ConnectorDevice = z.infer<typeof deviceSchema>;
export const deploymentInputSchema = z.object({
  strategyVersionId:z.string().uuid(),deviceId:z.string().uuid(),accountId:z.string().min(1).max(96),
  mode:modeSchema,configurationHash:z.string().regex(/^[a-f0-9]{64}$/),
}).strict();
export const mandateSchema = deploymentInputSchema.extend({
  schemaVersion:z.literal("leo.deployment-mandate.v1"),id:z.string().uuid(),mandateVersion:z.number().int().positive(),
  state:z.enum(["paused","running","retired"]),createdAt:z.string().datetime({offset:true}),updatedAt:z.string().datetime({offset:true}),
  leaseGeneration:z.number().int().nonnegative(),leaseExpiresAt:z.string().datetime({offset:true}).nullable(),
  pauseReason:z.string().max(500).nullable(),strategyVersion:strategyVersionSchema,
  retiredAcknowledgedAt:z.string().datetime({offset:true}).nullable().optional(),
});
export type DeploymentMandate = z.infer<typeof mandateSchema>;
export const controlSchema=z.object({
  id:z.string().uuid(),deploymentId:z.string().uuid(),action:z.enum(["pause","resume","retire"]),
  reason:z.string().min(1).max(500),mandateVersion:z.number().int().positive(),configurationHash:z.string(),
  createdAt:z.string().datetime({offset:true}),status:z.enum(["pending","applied","rejected"]),acknowledgedAt:z.string().datetime({offset:true}).nullable(),
});
export type StrategyControl=z.infer<typeof controlSchema>;
export const controlInputSchema=z.object({action:z.enum(["pause","resume"]),reason:z.string().min(1).max(500),expectedVersion:z.number().int().positive()}).strict();
export const retireInputSchema=z.object({reason:z.string().min(1).max(500),expectedVersion:z.number().int().positive()}).strict();
export const revokeInputSchema=z.object({reason:z.string().min(1).max(500)}).strict();
export const eventSchema=z.object({
  schemaVersion:z.literal("leo.evidence-event.v1"),id:z.string().uuid(),deploymentId:z.string().uuid().nullable(),researchRunId:z.string().uuid().optional(),
  kind:z.enum(["decision","order_status","fill","reconciliation","incident","heartbeat","research_result"]),
  occurredAt:z.string().datetime({offset:true}),sequence:z.number().int().nonnegative(),
  payload:z.record(z.string(),z.unknown()),
}).strict();
export type EvidenceEvent=z.infer<typeof eventSchema>;
export const researchRunSchema=z.object({
  schemaVersion:z.literal("leo.research-run.v1"),id:z.string().uuid(),strategyVersionId:z.string().uuid(),
  status:z.enum(["blocked","queued","completed","failed"]),createdAt:z.string().datetime({offset:true}),
  reason:z.string(),evidenceEventId:z.string().uuid().nullable(),
});
export type ResearchRun=z.infer<typeof researchRunSchema>;
export const strategyStatusSchema=z.object({membership:z.object({userId:z.string().uuid(),status:z.literal("active")}),configurations:z.array(strategyVersionSchema),deployments:z.array(mandateSchema),devices:z.array(deviceSchema),researchRuns:z.array(researchRunSchema),evidence:z.array(eventSchema),controls:z.array(controlSchema)});
export type StrategyStatus=z.infer<typeof strategyStatusSchema>;
export const pairingInputSchema=z.object({}).strict();
export const devicePairInputSchema=z.object({pairingToken:z.string().regex(/^[a-f0-9]{64}$/),name:z.string().min(1).max(80),platform:z.enum(["windows","macos","linux"])}).strict();
export const devicePollInputSchema=z.object({
  sequence:z.number().int().positive(),instanceId:z.string().uuid(),accounts:z.array(accountSchema).max(20),
  acks:z.array(z.object({controlId:z.string().uuid(),status:z.enum(["applied","rejected"]),reason:z.string().max(500).optional()}).strict()).max(50).default([]),
}).strict();
export type DevicePollInput=z.infer<typeof devicePollInputSchema>;
export type DevicePollResponse={serverTime:string;leaseExpiresAt:string;deployments:DeploymentMandate[];controls:StrategyControl[]};
export const eventsInputSchema=z.object({events:z.array(eventSchema).min(1).max(50)}).strict();
export const researchInputSchema=z.object({strategyVersionId:z.string().uuid()}).strict();
const decimalSchema=z.string().regex(/^-?\d+(?:\.\d+)?$/).max(80);
const hashSchema=z.string().regex(/^[a-f0-9]{64}$/);
export const researchReportSchema=z.object({
 schema_version:z.literal("leo-strategy-research.v1"),run_id:hashSchema,artifact_sha256:hashSchema,
 strategy:strategyIdSchema,symbol:symbolSchema,evidence_status:z.literal("EXPLORATORY_NOT_PROMOTED"),
 research_variant:z.literal(false),research_parameters:z.null(),
 source_evidence:z.object({source:z.string().min(1).max(500),dataset_sha256:hashSchema,calendar_source:z.string().min(1).max(500),adjustment_verified:z.literal(true),coverage_verified:z.literal(true),availability_verified:z.literal(true),classification:z.literal("observed"),license_scope:z.string().min(1).max(500)}).strict(),
 observation_cutoff:z.string().datetime({offset:true}),availability_cutoff:z.string().datetime({offset:true}),code_revision:z.string().min(1).max(200),
 cost_assumptions:z.object({commission_per_order:decimalSchema,slippage_bps:z.number().int().nonnegative().max(10000)}).strict(),
 execution_authorized:z.literal(false),promotion_eligible:z.literal(false),
 metrics:z.object({evaluation_sessions:z.number().int().nonnegative(),completed_trades:z.number().int().nonnegative(),net_time_weighted_return:z.number().finite(),max_drawdown:z.number().finite(),realized_pnl:decimalSchema,unrealized_pnl:decimalSchema,fees:decimalSchema,time_in_market_fraction:z.number().finite(),largest_winner_share_of_positive_pnl:z.number().finite().nullable(),top_five_winners_share_of_positive_pnl:z.number().finite().nullable(),annualized_account_volatility:z.number().finite().nullable()}).strict(),
 uncertainty:z.record(z.string(),z.unknown()),holdout:z.record(z.string(),z.unknown()),benchmarks:z.record(z.string(),z.unknown()),
 fill_model:z.literal("DAILY_OPEN_PROXY_WITH_BAR_STOP_AND_ADVERSE_GAPS"),quote_window_experiment_available:z.literal(false),limitations:z.array(z.string().max(1000)).max(40),
}).strict();
export const researchReportInputSchema=z.object({report:researchReportSchema}).strict();
export type ResearchReport=z.infer<typeof researchReportSchema>;
export const explanationInputSchema=z.object({deploymentId:z.string().uuid().optional(),question:z.string().min(1).max(1500)}).strict();
export const pauseRequestSchema=z.object({deploymentId:z.string().uuid(),reason:z.string().min(1).max(500),evidenceIds:z.array(z.string().uuid()).min(1).max(30)}).strict();
export type PauseRequest=z.infer<typeof pauseRequestSchema>;
export type Explanation={id:string;answer:string;evidenceIds:string[];createdAt:string;providerStatus:"available"|"unavailable";pauseRequest?:PauseRequest|undefined;pauseControlId?:string|undefined};
export const STRATEGY_CATALOG=Object.freeze([
  {id:"MR-v1" as const,name:"Mean reversion",hypothesis:"An unusually stretched daily price may move back toward its recent mean.",failureMode:"Persistent downtrends and overnight gaps can keep losing after an oversold entry.",parameters:{},parameterPolicy:"Fixed v1 rules; custom overrides require a separately validated version.",rules:["220 completed sessions of warmup","20-session z-score at or below -2 and Wilder RSI14 at or below 30","Stop at fill minus 2 ATR; exit at SMA20 or after 10 sessions"]},
  {id:"MOM-v1" as const,name:"Momentum",hypothesis:"A breakout above an established trading range may continue.",failureMode:"Sideways markets and failed breakouts can cause repeated losses.",parameters:{},parameterPolicy:"Fixed v1 rules; custom overrides require a separately validated version.",rules:["220 completed sessions of warmup","Close above prior 55-session high and SMA200","3 ATR trailing stop; exit below prior 20-session low"]},
]);
export const RESEARCH_RISK_DEFAULTS=Object.freeze({riskPerTradeBps:25,positionLimitBps:500,grossLimitBps:2000,dailyLossLimitBps:100,drawdownLimitBps:500,wholeShares:true,borrowing:false});
