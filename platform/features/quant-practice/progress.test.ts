import { test } from 'node:test';
import assert from 'node:assert/strict';
import { emptyProgress, mergeProgress, parseNumericAnswer, parseProgress, recordAnswer, recordExposure } from './progress';
const ids = new Set(['probability-1', 'principles-1']);
test('wrong and assisted answers enter review; an independent later pass clears review', () => {
  let p = recordAnswer(emptyProgress(), 'probability-1', false, false);
  assert.equal(p.answers['probability-1']!.needsReview, true);
  p = recordAnswer(p, 'probability-1', true, true);
  assert.equal(p.answers['probability-1']!.completed, true);
  assert.equal(p.answers['probability-1']!.independentCorrect, 0);
  assert.equal(p.answers['probability-1']!.needsReview, true);
  p = recordAnswer(p, 'probability-1', true, false);
  assert.equal(p.answers['probability-1']!.needsReview, false);
  assert.equal(p.answers['probability-1']!.independentCorrect, 1);
});
test('viewing help does not count as an answer or completion', () => {
  const p = recordExposure(emptyProgress(), 'probability-1');
  assert.equal(p.answers['probability-1']!.attempts, 0);
  assert.equal(p.answers['probability-1']!.completed, false);
  assert.equal(p.answers['probability-1']!.needsReview, true);
  assert.deepEqual(parseProgress(JSON.stringify(p), ids), p);
});
test('progress import rejects unknown IDs, malformed records, and excessive content', () => {
  const original = recordAnswer(emptyProgress(), 'probability-1', true, false);
  for (const mutate of [
    (p: any) => { p.answers['__proto_bad'] = p.answers['probability-1']; },
    (p: any) => { p.answers['probability-1'].independentCorrect = 9; },
    (p: any) => { p.answers['probability-1'].lastAt = 'yesterday'; },
    (p: any) => { p.labs = ['javascript:alert(1)']; },
  ]) { const p = structuredClone(original); mutate(p); assert.throws(() => parseProgress(JSON.stringify(p), ids)); }
  assert.throws(() => parseProgress(' '.repeat(200001), ids));
});
test('merging progress preserves the newest evidence and unions completed labs', () => {
  const older = recordAnswer(emptyProgress(), 'probability-1', false, false, '2026-10-20T12:00:00Z');
  const newer = recordAnswer(emptyProgress(), 'probability-1', true, false, '2026-10-22T12:00:00Z');
  older.labs = ['ch2:colors']; newer.labs = ['ch3:slope'];
  const merged = mergeProgress(newer, older);
  assert.equal(merged.answers['probability-1']!.needsReview, false);
  assert.deepEqual(merged.labs, ['ch3:slope', 'ch2:colors']);
});
test('numeric entry supports fractions, percentages and scientific notation without evaluating code', () => {
  assert.equal(parseNumericAnswer('1/4', 'probability'), .25);
  assert.equal(parseNumericAnswer('25%', 'probability'), .25);
  assert.equal(parseNumericAnswer('25%', '%'), 25);
  assert.equal(parseNumericAnswer('2.5e-3'), .0025);
  for (const raw of ['', '1/0', 'NaN', 'Infinity', '1+2', '1,2', 'alert(1)', '1e999']) assert.equal(parseNumericAnswer(raw), undefined);
});
