import { z } from 'zod';
const timestamp = z.string().datetime({ offset: true });
const hash = z.string().regex(/^[a-f0-9]{40,64}$/);
const numeric = z.number().finite();
const unit = numeric.min(0).max(1);
const feature = z.object({ id: z.string(), label: z.string() }).strict();
const regime = z.object({
  state: z.number().int().nonnegative(), label: z.string().regex(/^R\d{1,2}$/),
  timeShare: unit, persistence: unit, meanStayMinutes: numeric.positive().nullable(),
  driftBpPerMinute: numeric, volatilityBpPerSqrtMinute: numeric.nonnegative(),
  inputMeans: z.array(numeric).length(4),
  ou: z.object({ halfLifeMinutes: numeric.positive().nullable(), longRunResidualBp: numeric, autoregressivePhi: numeric }).strict().nullable(),
}).strict();
const model = z.object({
  symbol: z.string().regex(/^[A-Z0-9.:\-]{1,16}$/), modelSymbol: z.string(), priceSymbol: z.string(), targetStatus: z.string(),
  promotionStatus: z.literal('CANDIDATE_NOT_PROMOTED'), calibrationVersion: z.literal('UNAVAILABLE_FAIL_CLOSED'),
  lineage: z.object({
    artifactPath: z.string().regex(/^quant_engine_rs\/data\/models\/[\w./-]+\.frozen\.json$/), artifactFileSha256: hash, artifactSha256: hash,
    modelHash: hash, modelVersion: z.string(), createdAt: timestamp, trainingCutoff: timestamp, codeCommit: hash,
    trainingDatasetHash: hash, trainingRows: z.number().int().positive(),
  }).strict(),
  selection: z.object({
    criterion: z.string(), selectedStates: z.number().int().min(2), atBoundary: z.boolean(), warning: z.string().nullable(),
    fitSessions: z.number().int().positive(), validationSessions: z.number().int().positive(), minimumStateOccupancy: unit,
    candidates: z.array(z.object({ states: z.number().int().positive(), validationLogLikelihood: numeric, eligible: z.boolean(), status: z.string() }).strict()).min(1),
  }).strict(),
  hmm: z.object({ states: z.number().int().min(2).max(24), logLikelihood: numeric, bic: numeric, transition: z.array(z.array(unit)) }).strict(),
  regimes: z.array(regime),
  kernel: z.object({
    metric: z.string(), neighbors: z.number().int().positive(), bandwidthRule: z.string(), bandwidthMultiplier: numeric.positive(),
    covarianceShrinkage: unit, regimeMatchPolicy: z.string(), minimumRegimeSimilarity: unit, minimumDominantRegimeProbability: unit,
    minimumEffectiveSampleSize: numeric.nonnegative(), sameTimeBucket: z.boolean(), oodQuantile: unit, oodDistanceThreshold: numeric.positive(),
    metricWeights: z.array(numeric.nonnegative()).length(12), metricWeightsFitted: z.boolean(), analogRows: z.number().int().nonnegative(), trainEnd: timestamp,
  }).strict(),
  shadow: z.object({
    stepMinutes: z.number().int().positive(), observations: z.number().int().positive(), observationCutoff: timestamp,
    ouEnabled: z.boolean(), ouRejectionReasons: z.array(z.string()), jumpEnabled: z.boolean(), jumpRejectionReasons: z.array(z.string()), policy: z.string(),
  }).strict(),
}).strict().superRefine((value, context) => {
  const states = value.hmm.states;
  if (value.selection.selectedStates !== states || !value.selection.candidates.some(item => item.states === states && item.eligible)) context.addIssue({ code: z.ZodIssueCode.custom, message: 'Selected state count is not an eligible candidate' });
  if (value.hmm.transition.length !== states || value.hmm.transition.some(row => row.length !== states)) return context.addIssue({ code: z.ZodIssueCode.custom, message: 'Transition matrix does not match the state count' });
  if (value.regimes.length !== states || value.regimes.some((item, index) => item.state !== index || item.label !== `R${index + 1}` || item.persistence !== value.hmm.transition[index]![index])) context.addIssue({ code: z.ZodIssueCode.custom, message: 'Regimes do not match the HMM' });
  if (value.regimes.some(item => (item.ou !== null) !== value.shadow.ouEnabled)) context.addIssue({ code: z.ZodIssueCode.custom, message: 'OU parameters disagree with the shadow layer status' });
});
export const modelAtlasSchema = z.object({
  schemaVersion: z.literal('astra-model-atlas.v1'), dataMode: z.literal('frozen_candidate_parameters_not_live'),
  registrySha256: z.string().regex(/^[a-f0-9]{64}$/), registryGeneratedAt: timestamp, featureSchemaVersion: z.string(),
  hmmStepMinutes: z.number().int().positive(),
  features: z.object({ hmm: z.array(feature).length(4), kernel: z.array(feature).length(12) }).strict(),
  models: z.array(model).min(1).max(50), limitations: z.array(z.string()).min(1),
  predictionEnabled: z.literal(false), executionEnabled: z.literal(false),
}).strict().superRefine((value, context) => {
  if (new Set(value.models.map(item => item.symbol)).size !== value.models.length) context.addIssue({ code: z.ZodIssueCode.custom, message: 'Duplicate model symbols' });
});
export type ModelAtlas = z.infer<typeof modelAtlasSchema>;
export type AtlasModel = ModelAtlas['models'][number];
export type AtlasRegime = AtlasModel['regimes'][number];
