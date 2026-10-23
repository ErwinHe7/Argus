import assert from 'node:assert/strict';
import test from 'node:test';
import {catalog, validateCatalog} from './content';

test('catalog supplies all seven chapters with original teaching support', () => {
  assert.equal(catalog.chapters.length, 7);
  assert.equal(catalog.chapters.flatMap(chapter => chapter.challenges).length, 58);
  assert.equal(catalog.provenance.originalExercises, true);
  assert.equal(catalog.provenance.calculationEngine, 'offline Python');
  for (const chapter of catalog.chapters) {
    assert.ok(chapter.challenges.length >= 8);
    for (const question of chapter.challenges) {
      assert.equal(question.hints.length, 2);
      assert.ok(question.workedSteps.length >= 2);
      assert.ok(question.explanation.length > 40);
    }
  }
});

test('numeric probability answers are explicitly labelled and bounded', () => {
  const probabilities = catalog.chapters.flatMap(chapter => chapter.challenges)
    .filter(question => question.answer.unit === 'probability');
  assert.equal(probabilities.length, 8);
  for (const question of probabilities) {
    assert.equal(question.type, 'numeric');
    assert.ok(question.answer.numericValue! >= 0 && question.answer.numericValue! <= 1);
  }
});

test('validator rejects duplicate question ids and missing teaching data', () => {
  const duplicate = structuredClone(catalog);
  duplicate.chapters[0].challenges[1].id = duplicate.chapters[0].challenges[0].id;
  assert.throws(() => validateCatalog(duplicate), /Invalid Quant Quest/);
  const hints = structuredClone(catalog);
  hints.chapters[0].challenges[0].hints[1] = '';
  assert.throws(() => validateCatalog(hints), /Invalid Quant Quest/);
  const steps = structuredClone(catalog);
  steps.chapters[0].challenges[0].workedSteps = ['One step only'];
  assert.throws(() => validateCatalog(steps), /Invalid Quant Quest/);
});

test('validator rejects missing choices, nonfinite numeric answers and invalid tolerances', () => {
  const invalidChoice = structuredClone(catalog);
  invalidChoice.chapters[0].challenges[0].answer.choiceId = 'does-not-exist';
  assert.throws(() => validateCatalog(invalidChoice), /Invalid Quant Quest/);
  for (const invalid of [Number.NaN, Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY]) {
    const malformed = structuredClone(catalog);
    malformed.chapters[1].challenges[2].answer.numericValue = invalid;
    assert.throws(() => validateCatalog(malformed), /Invalid Quant Quest/);
  }
  for (const tolerance of [0, -1, Number.POSITIVE_INFINITY, Number.NaN]) {
    const malformed = structuredClone(catalog);
    malformed.chapters[1].challenges[2].answer.tolerance = tolerance;
    assert.throws(() => validateCatalog(malformed), /Invalid Quant Quest/);
  }
});

test('validator rejects a changed chapter order or probability outside its domain', () => {
  const reordered = structuredClone(catalog);
  [reordered.chapters[0], reordered.chapters[1]] = [reordered.chapters[1], reordered.chapters[0]];
  assert.throws(() => validateCatalog(reordered), /Invalid Quant Quest/);
  const invalidProbability = structuredClone(catalog);
  invalidProbability.chapters[1].challenges[2].answer.numericValue = 50;
  assert.throws(() => validateCatalog(invalidProbability), /Invalid Quant Quest/);
});
