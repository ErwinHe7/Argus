import assert from "node:assert/strict";
import test from "node:test";
import { INITIAL_SEARCH, REASONING_ORDER, SEARCH_NUMBERS, BAYES_CASES, VECTOR_CASES, WEATHER_PATHS, PAYOFF_CASES, PAYOFF_CURVES, PAYOFF_SAMPLE_PRICES, isReasoningOrdered, isUniform, meetChameleons, moveReasoningStep, searchStep } from "./labs-state";

test("chameleon meeting preserves population and rejects impossible moves", () => {
  assert.deepEqual(meetChameleons([2, 2, 2], [0, 1]), [1, 1, 4]);
  assert.deepEqual(meetChameleons([1, 1, 4], [0, 1]), [0, 0, 6]);
  assert.equal(isUniform([0, 0, 6]), true);
  assert.equal(isUniform([0, 2, 4]), false);
  assert.equal(isUniform([0, 0, 0]), false);
  assert.equal(meetChameleons([0, 1, 5], [0, 1]), null);
  assert.equal(meetChameleons([1, 1, 4], [0, 0]), null);
});

test("all legal color-pair moves preserve the difference residues", () => {
  const initial = [13, 15, 17] as const;
  for (const pair of [[0, 1], [0, 2], [1, 2]] as const) {
    const result = meetChameleons(initial, pair)!;
    assert.equal(result.reduce((a, b) => a + b, 0), 45);
    for (const [a, b] of [[0, 1], [0, 2], [1, 2]]) {
      assert.equal(((result[a] - result[b]) % 3 + 3) % 3, ((initial[a] - initial[b]) % 3 + 3) % 3);
    }
  }
});

test("reasoning order is exact, reversible, and cannot move outside its list", () => {
  const original = [...REASONING_ORDER];
  const moved = moveReasoningStep(original, 0, 1);
  assert.equal(isReasoningOrdered(original), true);
  assert.equal(isReasoningOrdered(moved), false);
  assert.deepEqual(moveReasoningStep(moved, 1, -1), original);
  assert.deepEqual(moveReasoningStep(original, 0, -1), original);
  assert.deepEqual(moveReasoningStep(original, 4, 1), original);
  assert.equal(isReasoningOrdered([]), false);
});

test("binary search accepts only the active middle, narrows bounds and stops after discovery", () => {
  const invalid = searchStep(INITIAL_SEARCH, 6);
  assert.equal(invalid.comparisons, 0);
  assert.equal(invalid.low, 0);
  let state = INITIAL_SEARCH;
  for (const middle of [7, 3, 5, 6]) state = searchStep(state, middle);
  assert.equal(state.found, true);
  assert.equal(state.comparisons, 4);
  assert.equal(state.low, 6);
  assert.equal(state.high, 6);
  assert.equal(SEARCH_NUMBERS[6], 37);
  assert.equal(searchStep(state, 8), state);
});

test("authored teaching fixtures have complete answer references", () => {
  assert.equal(BAYES_CASES.length, 3);
  for (const item of BAYES_CASES) {
    assert.ok(item.answer >= 0 && item.answer <= item.denominator);
    assert.equal(item.labels.length, item.denominator + 1);
    assert.equal(item.labels[item.answer], item.result);
  }
  assert.equal(VECTOR_CASES.length, 3);
  assert.deepEqual(Object.keys(WEATHER_PATHS).sort(), ["clear-clear", "clear-cloudy", "cloudy-clear", "cloudy-cloudy"]);
  for (const item of PAYOFF_CASES) assert.ok(PAYOFF_CURVES.some((curve) => curve.id === item.answer));
});

test("payoff diagrams expose a complete, consistent nonvisual sample table", () => {
  assert.deepEqual(PAYOFF_SAMPLE_PRICES, [30, 40, 50, 60, 70]);
  assert.equal(new Set(PAYOFF_CURVES.map((curve) => curve.label)).size, 4);
  for (const curve of PAYOFF_CURVES) {
    assert.equal(curve.values.length, PAYOFF_SAMPLE_PRICES.length);
    assert.ok(curve.description.length > 30);
    assert.ok(curve.values.every((value) => Number.isFinite(value) && value >= 0));
  }
  const call = PAYOFF_CURVES.find((curve) => curve.id === "call")!;
  const put = PAYOFF_CURVES.find((curve) => curve.id === "put")!;
  const straddle = PAYOFF_CURVES.find((curve) => curve.id === "straddle")!;
  assert.deepEqual([...call.values].reverse(), put.values);
  assert.deepEqual(straddle.values, [20, 10, 0, 10, 20]);
  assert.deepEqual(PAYOFF_CURVES.find((curve) => curve.id === "spread")!.values, [0, 0, 5, 10, 10]);
});
