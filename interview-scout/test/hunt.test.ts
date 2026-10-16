import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { ApplyResult } from '../src/apply.ts';
import { runHunt, type HuntInput, type HuntStore, type Results, type StepConfig, type Steps } from '../src/hunt.ts';
import type { Job } from '../src/jobs.ts';

const job = (key: string): Job => ({ key, ats: 'lever', company: 'acme', title: key, location: '', remote: false, postedAt: '', url: '', applyUrl: '' });

function memoryStore(input: HuntInput | null) {
  const state = { input, results: [] as Results[], shots: new Map<string, string>() };
  const store: HuntStore = {
    create: async () => {},
    input: async () => state.input,
    deleteInput: async () => { state.input = null; },
    meta: async () => null,
    results: async () => state.results.at(-1) ?? {},
    putResults: async (_id, results) => { state.results.push(structuredClone(results)); },
    putShot: async (_id, key, dataUrl) => { state.shots.set(key, dataUrl); },
    shot: async () => null,
  };
  return { store, state };
}

/** Runs each step once, like Workflows with retries disabled, and records its config. */
function fakeSteps() {
  const calls: { name: string; config: StepConfig }[] = [];
  const steps: Steps = {
    async do(name, config, callback) {
      calls.push({ name, config });
      return callback();
    },
  };
  return { steps, calls };
}

const input = (keys: string[]): HuntInput => ({
  profile: {} as HuntInput['profile'], facts: { workAuthorizedUS: '', needsSponsorship: '', notes: '' },
  resume: { name: 'r.pdf', base64: 'JVBER' }, submit: true, jobs: keys.map(job),
});

const result = (status: ApplyResult['status'], screenshot: string | null = null): ApplyResult =>
  ({ status, message: status, missing: [], screenshot });

test('applies to every job in order, keeps results and screenshots, then deletes the resume', async () => {
  const { store, state } = memoryStore(input(['a', 'b', 'c']));
  const { steps, calls } = fakeSteps();
  const applied: string[] = [];
  const outcomes: Record<string, ApplyResult> = { a: result('submitted', 'data:image/jpeg;base64,AAAA'), b: result('needs_you'), c: result('failed') };

  const summary = await runHunt('h1', steps, { store, applyOne: async (_input, j) => { applied.push(j.key); return outcomes[j.key]; } });

  assert.deepEqual(summary, { done: 3, stopped: false });
  assert.deepEqual(applied, ['a', 'b', 'c']);
  const final = state.results.at(-1)!;
  assert.deepEqual(Object.fromEntries(Object.entries(final).map(([k, v]) => [k, v.status])), { a: 'submitted', b: 'needs_you', c: 'failed' });
  assert.equal(final.a.hasShot, true);
  assert.equal(state.shots.get('a'), 'data:image/jpeg;base64,AAAA');
  // Each job is shown as working before its result lands.
  assert.equal(state.results[2].b.status, 'working');
  assert.equal(state.input, null);
  assert.deepEqual(calls.map(c => c.name), ['load', 'apply a', 'apply b', 'apply c', 'cleanup']);
  assert.ok(calls.filter(c => c.name !== 'load').every(c => c.config.retries.limit === 0), 'application steps must never retry');
  assert.ok(calls[0].config.retries.limit > 0, 'the initial storage read can retry before any employer action');
});

test('stops when the hunt input is gone', async () => {
  const { store, state } = memoryStore(input(['a', 'b']));
  const { steps } = fakeSteps();
  const summary = await runHunt('h1', steps, {
    store,
    applyOne: async () => { state.input = null; return result('submitted'); },
  });
  assert.deepEqual(summary, { done: 1, stopped: true });
  assert.deepEqual(Object.keys(state.results.at(-1)!), ['a']);
});

test('a crashed step is recorded as failed and the hunt moves on', async () => {
  const { store, state } = memoryStore(input(['a', 'b']));
  const { steps } = fakeSteps();
  const summary = await runHunt('h1', steps, {
    store,
    applyOne: async (_input, j) => {
      if (j.key === 'a') throw new Error('worker evicted');
      return result('submitted');
    },
  });
  assert.deepEqual(summary, { done: 2, stopped: false });
  const final = state.results.at(-1)!;
  assert.equal(final.a.status, 'failed');
  assert.match(final.a.message, /interrupted/);
  assert.equal(final.b.status, 'submitted');
});

test('an interrupted submission keeps its durable attempt marker and requires manual review', async () => {
  const { store, state } = memoryStore(input(['a']));
  const { steps } = fakeSteps();
  await runHunt('h1', steps, { store, applyOne: async (_input, _job, onSubmissionAttempt) => {
    await onSubmissionAttempt();
    assert.equal(state.results.at(-1)?.a.submissionAttempted, true);
    throw new Error('browser interrupted after submit');
  } });
  assert.equal(state.results.at(-1)?.a.status, 'needs_you');
  assert.equal(state.results.at(-1)?.a.submissionAttempted, true);
  assert.match(state.results.at(-1)?.a.message ?? '', /outcome is unknown/);
});

test('a transient missing input is not reported as a successful empty hunt', async () => {
  const { store } = memoryStore(null);
  store.meta = async () => ({ id: 'h1', createdAt: '', submit: false, jobs: [job('a')] });
  const { steps } = fakeSteps();
  let applied = false;
  await assert.rejects(runHunt('h1', steps, { store, applyOne: async () => { applied = true; return result('submitted'); } }), /has not reached/);
  assert.equal(applied, false);
});
