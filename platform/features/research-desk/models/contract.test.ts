import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { modelAtlasSchema } from './contract';
const source = JSON.parse(readFileSync(new URL('../data/model-atlas.json', import.meta.url), 'utf8'));
const platform = new URL('../../../', import.meta.url);
const digest = (path: string) => createHash('sha256').update(readFileSync(new URL(path, platform))).digest('hex');
test('the atlas lists the nine frozen candidates bound to their exact artifact bytes', () => {
  const data = modelAtlasSchema.parse(source);
  assert.deepEqual(data.models.map(item => item.symbol), ['SPX', 'QQQ', 'NVDA', 'AAPL', 'MU', 'SOXX', 'NBIS', 'BE', 'IGV']);
  assert.equal(data.registrySha256, digest('quant_engine_rs/data/models/universe/registry.json'));
  for (const item of data.models) assert.equal(item.lineage.artifactFileSha256, digest(item.lineage.artifactPath));
  assert.equal(data.hmmStepMinutes, 5);
});
test('contradictory regimes, matrices, and OU status are rejected before rendering', () => {
  for (const mutate of [
    (data: any) => { data.models[0].selection.selectedStates = 8; },
    (data: any) => { data.models[0].hmm.transition.pop(); },
    (data: any) => { data.models[0].regimes[3].persistence = 0.5; },
    (data: any) => { data.models[0].regimes[0].label = 'R9'; },
    (data: any) => { data.models[0].regimes[0].ou = null; },
    (data: any) => { data.models[0].regimes[0].timeShare = 1.5; },
    (data: any) => { data.models[1].symbol = 'SPX'; },
  ]) { const next = structuredClone(source); mutate(next); assert.equal(modelAtlasSchema.safeParse(next).success, false); }
});
test('candidate parameters cannot become promoted forecasts or execution authority', () => {
  for (const field of ['predictionEnabled', 'executionEnabled']) assert.equal(modelAtlasSchema.safeParse({ ...source, [field]: true }).success, false);
  assert.equal(modelAtlasSchema.safeParse({ ...source, dataMode: 'live' }).success, false);
  for (const [field, value] of [['promotionStatus', 'PROMOTED'], ['calibrationVersion', 'platt-v1']]) {
    const next = structuredClone(source); next.models[0][field] = value;
    assert.equal(modelAtlasSchema.safeParse(next).success, false);
  }
});

test('non-stochastic transition rows fail closed even when regime persistence agrees', () => {
  for (const fill of [0, 1]) {
    const next = structuredClone(source);
    next.models[0].hmm.transition[0].fill(fill);
    next.models[0].regimes[0].persistence = fill;
    const result = modelAtlasSchema.safeParse(next);
    assert.equal(result.success, false);
    if (!result.success) assert.ok(result.error.issues.some(issue => issue.message.includes('Transition row probabilities must sum to 1')));
  }
});
