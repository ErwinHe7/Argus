import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { parseGridRequest, parseGridResult } from '../features/strategy-lab/grid/validation';
import { strategyIdSchema } from '../../ritual-investing-api/src/domains/strategy-lab/contracts';

const root = process.cwd();
const fixture = async (name: string) => JSON.parse(await readFile(resolve(root, `features/strategy-lab/grid/fixtures/${name}.json`), 'utf8'));
async function compute(request: unknown) {
  const {instance} = await WebAssembly.instantiate(await readFile(resolve(root, '.quant-runtime/grid/leo_grid_wasm.wasm')), {});
  const api = instance.exports as unknown as {memory: WebAssembly.Memory; grid_alloc(n: number): number; grid_compute(p: number,n: number): bigint; grid_dealloc(p: number,n: number): void};
  const input = new TextEncoder().encode(JSON.stringify(request));
  const pointer = api.grid_alloc(input.length);
  assert.ok(pointer);
  new Uint8Array(api.memory.buffer, pointer, input.length).set(input);
  const packed = api.grid_compute(pointer, input.length);
  const outputPointer = Number(packed >> 32n), outputLength = Number(packed & 0xffffffffn);
  const output = JSON.parse(new TextDecoder().decode(new Uint8Array(api.memory.buffer, outputPointer, outputLength)));
  api.grid_dealloc(outputPointer, outputLength); api.grid_dealloc(pointer, input.length);
  return output;
}

test('canonical WASM demonstrations fit the frontend contract and retain honest evidence labels', async () => {
  await mkdir(resolve(root, '.quant-runtime/grid/reports'), {recursive: true});
  for (const name of ['range', 'decline', 'rally']) {
    const request = parseGridRequest(await fixture(name));
    const output = await compute(request);
    assert.equal(output.ok, true, output.error);
    const result = parseGridResult(output.result);
    assert.equal(result.evidence_status, 'SYNTHETIC_DEMONSTRATION');
    assert.equal(result.promotion_eligible, false);
    assert.equal(result.execution_authorized, false);
    assert.equal(result.paper_execution_available, false);
    assert.equal(result.equity.length, request.bars.length);
    if (name === 'decline') {
      assert.ok(Number(result.metrics.realized_cycle_pnl) > 0);
      assert.ok(Number(result.metrics.total_pnl) < 0);
      assert.equal(result.metrics.loss_latched, true);
    }
    if (name === 'rally') {
      assert.equal(result.metrics.completed_cycles, 0);
      assert.equal(result.metrics.total_return, 0);
      assert.ok(result.benchmarks.buy_and_hold_total_return > 0);
    }
    await writeFile(resolve(root, `.quant-runtime/grid/reports/${name}.json`), JSON.stringify(result, null, 2));
  }
});

test('WASM refuses future observations, duplicate sessions, collapsed levels and hostile schema fields', async () => {
  const base = await fixture('range');
  const invalid = [
    {...base, broker_order: {side: 'buy'}},
    {...base, as_of: '2026-01-01T00:00:00Z'},
    {...base, bars: [base.bars[0], base.bars[0]]},
    {...base, lower: '100.00', upper: '100.01', intervals: 4},
    {...base, starting_capital: '1.00'},
    {...base, source_evidence: {...base.source_evidence, classification: 'verified_profitable'}},
  ];
  for (const request of invalid) {
    const output = await compute(request);
    assert.equal(output.ok, false);
    assert.equal(typeof output.error, 'string');
    assert.equal(output.result, undefined);
  }
});

test('adding future sessions never changes preceding WASM decisions or equity', async () => {
  const base = await fixture('range');
  const before = await compute({...base, bars: base.bars.slice(0, 12)});
  const after = await compute(base);
  assert.equal(before.ok, true); assert.equal(after.ok, true);
  assert.deepEqual(after.result.equity.slice(0, 12), before.result.equity);
  assert.deepEqual(after.result.journal.slice(0, before.result.journal.length), before.result.journal);
});

test('observed imports remain unverified and do not grant execution or promotion', async () => {
  assert.equal(strategyIdSchema.safeParse('GRID-R1').success, false);
  const request = await fixture('range');
  request.source_evidence.classification = 'observed';
  const output = await compute(request);
  const result = parseGridResult(output.result);
  assert.equal(result.evidence_status, 'USER_SUPPLIED_OBSERVED_NOT_INDEPENDENTLY_VERIFIED');
  assert.equal(result.execution_authorized, false);
  assert.equal(result.promotion_eligible, false);
  assert.throws(() => parseGridResult({...result, execution_authorized: true}));
  assert.throws(() => parseGridRequest({...request, operation: 'grid_replay'}));
});

test('native and browser WASM reports agree for arithmetic and geometric grids', async () => {
  for (const name of ['range', 'decline', 'rally', 'geometric']) {
    const request = await fixture(name === 'geometric' ? 'range' : name);
    if (name === 'geometric') request.spacing = 'geometric';
    const native = JSON.parse(await readFile(resolve(root, `.quant-runtime/grid/native/${name}.json`), 'utf8'));
    const browser = await compute(request);
    assert.equal(browser.ok, true, browser.error);
    assert.deepEqual(browser.result, native);
  }
});
