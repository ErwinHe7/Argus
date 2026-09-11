import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { eventRadarSchema } from './contract';
import { explainEvidence } from './explain';
import { eventDay, eventOrder, eventUpcoming, sourceCurrent, readRadar } from './useRadar';

const data = eventRadarSchema.parse(JSON.parse(readFileSync(new URL('../data/event-radar.json', import.meta.url), 'utf8')));
const now = Date.parse(data.generatedAt) + 1000;
test('Exact decision instant determines calendar day and order instead of the meeting start', () => {
  const decision = data.events.find(item => item.title === 'FOMC policy decision')!;
  assert.equal(eventDay(decision), '2026-09-16');
  assert.equal(eventOrder(decision), decision.scheduledAt);
  const releases = data.events.filter(event => eventUpcoming(event, now)).sort((a, b) => eventOrder(a).localeCompare(eventOrder(b)));
  const imports = releases.findIndex(item => item.title === 'U.S. import and export prices');
  assert(imports >= 0 && releases.indexOf(decision) > imports);
});
test('Evidence answers distinguish calendar facts, predictions, unsupported questions and stale sources', () => {
  const event = data.events[0];
  assert.match(explainEvidence('What should I buy?', data, event, now).paragraphs.join(' '), /old screen is not a current buy signal/);
  assert.match(explainEvidence('Predict tomorrow', data, event, now).paragraphs.join(' '), /No probability or win rate/);
  assert.match(explainEvidence('Write me a poem', data, event, now).title, /not in this evidence/);
  assert.match(explainEvidence('Explain Micron', data, event, now).title, /Micron/);
  assert.match(explainEvidence('Explain ADBE', data, event, now).title, /Adobe/);
  assert.equal(sourceCurrent(data, event, Date.parse(data.reviewAfter) + 1), false);
  assert.match(explainEvidence('What should I watch?', data, event, Date.parse(data.reviewAfter) + 1).paragraphs.join(' '), /needs review/);
});
test('Browser evidence reader bounds bytes, rejects future generations and illegal values', async () => {
  await assert.rejects(readRadar(new Response('x'.repeat(524289))));
  await assert.rejects(readRadar(new Response(JSON.stringify({ ...data, generatedAt: '2099-01-01T00:00:00Z' }))));
  await assert.rejects(readRadar(new Response(JSON.stringify({ ...data, executionEnabled: true }))));
  await assert.rejects(readRadar(new Response(new Uint8Array([0xff, 0xfe]))));
});
