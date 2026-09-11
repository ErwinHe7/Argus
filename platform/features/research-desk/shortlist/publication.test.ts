import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { publicationSchema, publicationFuture, publisherView } from './publication';

const shortlist = JSON.parse(readFileSync(new URL('../data/shortlist.json', import.meta.url), 'utf8'));
function fixture() {
  return { schemaVersion: 'astra-shortlist-publication.v1', shortlist: structuredClone(shortlist), publisher: {
    schemaVersion: 'astra-shortlist-publisher-status.v1', state: 'waiting',
    heartbeatAt: '2026-09-08T12:00:00Z', lastCheckedAt: '2026-09-08T12:00:00Z', publishedAt: '2026-09-08T11:00:00Z',
    inputSha256: shortlist.inputSha256, artifactSha256: 'a'.repeat(64), revision: 'b'.repeat(64),
    lastError: null, intervalSeconds: 30, llmCalls: 0, executionEnabled: false, predictionEnabled: false,
  } };
}
test('publication binds actual evidence and presents automation separately from source age', () => {
  const value = publicationSchema.parse(fixture());
  assert.equal(publisherView(value, Date.parse('2026-09-08T12:00:30Z')).active, true);
  assert.equal(value.shortlist!.asOf, '2026-09-04');
  assert.equal(publisherView(value, Date.parse('2026-09-08T12:02:00Z')).active, false);
  assert.equal(publicationFuture(value, Date.parse('2026-09-07T12:00:00Z')), true);
  value.shortlist!.stocks[0].priceObservedAt = '2026-10-01T00:00:00Z';
  assert.equal(publicationFuture(value, Date.parse('2026-09-08T12:00:30Z')), true);
});
test('rejects raw history extras, mismatched source identity and enabled execution', () => {
  for (const mutate of [
    (v: any) => { v.shortlist.stocks[0].coverage.rawBars = [{ close: 1 }]; },
    (v: any) => { v.publisher.inputSha256 = 'c'.repeat(64); },
    (v: any) => { v.publisher.executionEnabled = true; },
    (v: any) => { v.publisher.lastCheckedAt = '2026-09-09T12:00:00Z'; },
  ]) { const value = fixture(); mutate(value); assert.equal(publicationSchema.safeParse(value).success, false); }
});
test('failed, paused and absent publishers never claim active screening', () => {
  const value: any = fixture(); value.publisher.state = 'error';
  assert.equal(publicationSchema.safeParse(value).success, false);
  value.publisher.lastError = { code: 'source_invalid', message: 'Latest source rejected.' };
  assert.equal(publisherView(publicationSchema.parse(value), Date.parse(value.publisher.heartbeatAt)).active, false);
  assert.equal(value.shortlist.asOf, '2026-09-04');
  value.publisher.state = 'paused'; value.publisher.lastError = null;
  assert.equal(publisherView(publicationSchema.parse(value), Date.parse(value.publisher.heartbeatAt)).label, 'Updates paused');
  assert.equal(publisherView(null).label, 'Saved shortlist');
});
