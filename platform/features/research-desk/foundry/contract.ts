import { z } from 'zod';

/**
 * Transport contract for leo-foundry-publication.v1. Python computes every figure;
 * the browser validates, then formats. Nothing here derives a return, risk, or price.
 */
const stamp = z.string().datetime({ offset: true }).refine(value => value.endsWith('Z') || value.endsWith('+00:00'), 'UTC timestamp required');
const day = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(value => { const date = new Date(`${value}T00:00:00Z`); return Number.isFinite(date.valueOf()) && date.toISOString().slice(0, 10) === value; }, 'Invalid date');
const dated = z.union([day, stamp]);
const text = z.string().min(1).max(2000);
const label = z.string().min(1).max(200);
const id = z.string().min(1).max(180).regex(/^[a-zA-Z0-9_.:-]+$/);
const sha = z.string().regex(/^[a-f0-9]{64}$/);
const value = z.number().finite();
const count = z.number().int().nonnegative();

export const ROLE_IDS = ['prototype_builder', 'sweeper', 'grower', 'maintainer'] as const;
const roleId = z.enum(ROLE_IDS);
const actor = z.union([roleId, z.literal('human')]);
const workingStage = z.enum(['PROBE', 'BACKTEST', 'PAPER']);
const specStatus = z.enum(['ACTIVE', 'AWAITING_HUMAN_RESUME', 'FORWARD_SHADOW', 'PAUSED', 'REJECTED_NO_DEPLOYABLE_EDGE', 'BLOCKED']);
const eventKind = z.enum(['SPEC_FROZEN', 'SPEC_REJECTED', 'PROBE_COMPLETED', 'BACKTEST_COMPLETED', 'PROMOTED', 'HOLDOUT_EVALUATED', 'PAPER_PROPOSAL_ISSUED',
  'FORWARD_SHADOW_STARTED', 'MAINTAINER_CHECK', 'PAUSE_REQUESTED', 'HUMAN_RESUMED', 'REJECTED_NO_DEPLOYABLE_EDGE', 'BLOCKED']);

const role = <T extends typeof ROLE_IDS[number]>(roleIdValue: T) => z.object({ id: z.literal(roleIdValue), name: label, duty: text, boundary: text }).strict();
const openStage = <T extends string>(stageId: T) => z.object({
  id: z.literal(stageId), name: label, owner: actor, automatic: z.boolean(), locked: z.literal(false), gate: text, lockReason: z.null(), futureGates: z.array(text).length(0),
}).strict();
const lockedStage = <T extends string>(stageId: T) => z.object({
  id: z.literal(stageId), name: label, owner: actor, automatic: z.literal(false), locked: z.literal(true), gate: text, lockReason: text, futureGates: z.array(text).min(1).max(20),
}).strict();
const pending = z.object({ status: z.literal('ARTIFACT_PENDING'), reason: text, command: text }).strict();

const leg = z.object({ right: z.enum(['call', 'put']), side: z.enum(['short', 'long']), strikeMoneynessPct: value, dte: count, fillSide: z.enum(['bid', 'ask', 'model']) }).strict();
const overlayPublicSchema = z.object({
  symbolLabel: label, structure: z.enum(['covered_call', 'collar', 'protective_put']),
  pricingMode: z.enum(['EXECUTABLE_QUOTES', 'MODEL_PRICED']),
  evidenceStatus: z.enum(['EXECUTABLE_QUOTES_OBSERVED', 'MODEL_PRICED_NOT_EXECUTABLE', 'SYNTHETIC_FIXTURE_NOT_MARKET_EVIDENCE']),
  engineVersion: label, inputSha256: sha, configSha256: sha,
  observationCutoff: dated, availabilityCutoff: dated, freshness: z.literal('historical_backtest_not_live'),
  coverage: z.object({ sessions: count, start: dated, end: dated, calendarSource: label, cycles: count, deferredRolls: count }).strict(),
  source: z.object({ name: label, licenseScope: text, quoteSources: z.array(label).max(20), ivSources: z.array(label).max(20) }).strict(),
  metrics: z.object({
    overlay: z.object({ totalReturnPct: value, annualizedReturnPct: value.nullable(), annualizedVolatilityPct: value, maxDrawdownPct: value,
      downsideCapturePct: value.nullable(), upsideCapturePct: value.nullable(), premiumYieldAnnualizedPct: value.nullable() }).strict(),
    buyAndHold: z.object({ totalReturnPct: value, annualizedReturnPct: value.nullable(), annualizedVolatilityPct: value, maxDrawdownPct: value }).strict(),
    difference: z.object({ totalReturnPct: value, maxDrawdownPct: value }).strict(),
    counts: z.object({ assignments: count, capHits: count, putExercises: count, deferredRolls: count, exDividendItmShortCallEvents: count }).strict(),
    activeReturnBootstrap: z.object({ status: label, lower95Pct: value.nullable(), upper95Pct: value.nullable(), resamples: count.nullable(), blockLength: count.nullable() }).strict(),
    activeReturnSignFlipP: z.number().min(0).max(1).nullable(),
  }).strict(),
  cycles: z.array(z.object({ cycleId: id, opened: dated, expiry: dated, outcome: label, overlayReturnPct: value, baselineReturnPct: value, legs: z.array(leg).min(1).max(4) }).strict()).max(5000),
  assumptions: z.array(text).max(50), caveats: z.array(text).min(1).max(50),
  executionAuthorized: z.literal(false), optionsExecutionEnabled: z.literal(false), promotionEligible: z.literal(false),
}).strict();

const ledgerPublicSchema = z.object({
  headSha256: sha, eventCount: count, trialsTotal: count, llmCalls: z.literal(0),
  specs: z.array(z.object({
    specId: id, template: z.enum(['MR-v1', 'MOM-v1', 'OVERLAY-v1', 'GRID-R1']), symbolLabel: label, stage: workingStage, status: specStatus,
    familyTrialCount: count, survivors: count, gates: z.array(z.object({ id, passed: z.boolean(), detail: text }).strict()).max(50), nextAction: text,
  }).strict()).max(500),
  events: z.array(z.object({
    seq: z.number().int().positive(), at: stamp, specId: id, role: actor, kind: eventKind,
    fromStage: workingStage.nullable(), toStage: workingStage.nullable(), status: specStatus, reasons: z.array(text).max(50),
  }).strict()).max(50),
}).strict();

const overlaySection = z.discriminatedUnion('status', [pending, z.object({ status: z.literal('PUBLISHED'), artifact: overlayPublicSchema }).strict()]);
const ledgerSection = z.discriminatedUnion('status', [pending, z.object({ status: z.literal('PUBLISHED'), ledger: ledgerPublicSchema }).strict()]);
const ALLOWED_LEGS = { covered_call: ['short call'], collar: ['short call', 'long put'], protective_put: ['long put'] } as const;
const instant = (value: string) => Date.parse(value.length === 10 ? `${value}T00:00:00Z` : value);

/** Observation-side times only. Option expiries may legitimately follow the publication. */
function evidenceTimes(value: { overlay: z.infer<typeof overlaySection>; ledger: z.infer<typeof ledgerSection> }): string[] {
  const times: string[] = [];
  if (value.overlay.status === 'PUBLISHED') {
    const artifact = value.overlay.artifact;
    times.push(artifact.observationCutoff, artifact.availabilityCutoff, artifact.coverage.start, artifact.coverage.end, ...artifact.cycles.map(cycle => cycle.opened));
  }
  if (value.ledger.status === 'PUBLISHED') times.push(...value.ledger.ledger.events.map(event => event.at));
  return times;
}

export const foundryPublicationSchema = z.object({
  schemaVersion: z.literal('leo-foundry-publication.v1'), generatedAt: stamp.nullable(),
  executionAuthorized: z.literal(false), optionsExecutionEnabled: z.literal(false), liveStagesLocked: z.literal(true), llmCalls: z.literal(0),
  derivedPublicationRightsConfirmed: z.boolean(),
  roles: z.tuple([role('prototype_builder'), role('sweeper'), role('grower'), role('maintainer')]),
  ladder: z.tuple([openStage('PROBE'), openStage('BACKTEST'), openStage('PAPER'), lockedStage('LIVE_SMALL'), lockedStage('LIVE_SCALED')]),
  overlay: overlaySection, ledger: ledgerSection,
}).strict().superRefine((value, context) => {
  const fail = (message: string) => context.addIssue({ code: z.ZodIssueCode.custom, message });
  if ((value.overlay.status === 'PUBLISHED' || value.ledger.status === 'PUBLISHED') && (!value.derivedPublicationRightsConfirmed || value.generatedAt === null)) {
    fail('Published evidence requires confirmed derived-publication rights and a generation time');
  }
  if (value.overlay.status === 'PUBLISHED') {
    const artifact = value.overlay.artifact;
    if ((artifact.pricingMode === 'MODEL_PRICED') !== (artifact.evidenceStatus === 'MODEL_PRICED_NOT_EXECUTABLE')) fail('Model-priced overlays must be labelled not executable');
    for (const item of artifact.cycles.flatMap(cycle => cycle.legs)) {
      if (!(ALLOWED_LEGS[artifact.structure] as readonly string[]).includes(`${item.side} ${item.right}`)) fail('Leg does not belong to the declared structure');
      if (item.fillSide !== (artifact.pricingMode === 'MODEL_PRICED' ? 'model' : item.side === 'short' ? 'bid' : 'ask')) fail('Leg fill side contradicts the pricing mode');
    }
    if (artifact.coverage.deferredRolls !== artifact.metrics.counts.deferredRolls) fail('Deferred-roll counts disagree');
    if (instant(artifact.coverage.start) > instant(artifact.coverage.end)) fail('Invalid coverage window');
  }
  if (value.ledger.status === 'PUBLISHED') {
    const { events, eventCount, specs } = value.ledger.ledger;
    if (events.length > eventCount || events.some((event, index) => event.seq > eventCount || (index > 0 && (event.seq <= events[index - 1].seq || instant(event.at) < instant(events[index - 1].at))))) fail('Ledger events are out of order');
    if (new Set(specs.map(spec => spec.specId)).size !== specs.length || specs.some(spec => spec.survivors > spec.familyTrialCount)) fail('Inconsistent ledger specs');
  }
  if (value.generatedAt !== null) {
    const limit = instant(value.generatedAt) + 300000;
    if (evidenceTimes(value).some(time => instant(time) > limit)) fail('Evidence timestamp follows the publication time');
  }
});

export type FoundryPublication = z.infer<typeof foundryPublicationSchema>;
export type OverlayPublic = z.infer<typeof overlayPublicSchema>;
export type LedgerPublic = z.infer<typeof ledgerPublicSchema>;

/** Build and browser gate: a synthetic drift fixture is never shipped as market evidence. */
export function assertPublishable(value: FoundryPublication): FoundryPublication {
  if (value.overlay.status === 'PUBLISHED' && value.overlay.artifact.evidenceStatus === 'SYNTHETIC_FIXTURE_NOT_MARKET_EVIDENCE') {
    throw new Error('Synthetic fixture evidence cannot be published');
  }
  return value;
}

/** Display freshness only. Results are historical backtests; this never marks them live. */
export function foundryAge(value: FoundryPublication, now = Date.now()): 'pending' | 'historical' | 'invalid-future' {
  const times = value.generatedAt === null ? evidenceTimes(value) : [value.generatedAt, ...evidenceTimes(value)];
  if (times.some(time => instant(time) > now + 300000)) return 'invalid-future';
  return value.generatedAt === null ? 'pending' : 'historical';
}
