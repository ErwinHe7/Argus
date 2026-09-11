import assert from 'node:assert/strict';
import { before, test } from 'node:test';
import { createHash } from 'node:crypto';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { basename, dirname, join, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';
import { convertV4MiniflareOptions, Log, LogLevel, Miniflare } from 'miniflare';
import { publicationSchema } from '../../features/research-desk/shortlist/publication.ts';
import { canonicalJson, MAX_PUBLICATION_BYTES, readPublicationBody, validatePublication } from './validation.ts';

const root = fileURLToPath(new URL('../../', import.meta.url));
const token = 'unit-test-only-not-a-deployed-publisher-secret';
const base = Date.now() - 3600_000;
const digest = value => createHash('sha256').update(value).digest('hex');
let bundle;
let shortlist;
let artifactSha256;

before(async () => {
  const bytes = await readFile(join(root, 'features/research-desk/data/shortlist.json'));
  shortlist = JSON.parse(bytes.toString('utf8'));
  artifactSha256 = digest(bytes);
  const built = await build({ entryPoints: [join(root, 'workers/shortlist-feed/index.ts')], bundle: true, write: false,
    format: 'esm', platform: 'neutral', target: 'es2022', external: ['cloudflare:workers'] });
  bundle = built.outputFiles[0].text;
});

function publication(step = 0) {
  const heartbeatAt = new Date(base + step * 1000).toISOString();
  return {
    schemaVersion: 'astra-shortlist-publication.v1', shortlist: structuredClone(shortlist),
    publisher: { schemaVersion: 'astra-shortlist-publisher-status.v1', state: 'waiting', heartbeatAt,
      lastCheckedAt: heartbeatAt, publishedAt: new Date(base - 10_000).toISOString(), inputSha256: shortlist.inputSha256,
      artifactSha256, revision: digest('unit-test-revision'), lastError: null,
      intervalSeconds: 30, llmCalls: 0, executionEnabled: false, predictionEnabled: false },
  };
}

async function fixture(context, { secret = true } = {}) {
  const folder = await mkdtemp(join(tmpdir(), 'leo-shortlist-feed-'));
  let outboundCalls = 0;
  const options = convertV4MiniflareOptions({ name: 'leo-shortlist-feed', modules: true, script: bundle,
    compatibilityDate: '2026-09-04', compatibilityFlags: ['nodejs_compat'],
    durableObjects: { SHORTLIST_FEED: { className: 'ShortlistFeed', useSQLite: true } },
    bindings: secret ? { LEO_SHORTLIST_PUBLISH_TOKEN: token } : {},
    outboundService: () => { outboundCalls += 1; throw new Error('No outbound requests are permitted'); },
  });
  options.resourcePersistencePath = folder;
  options.cf = false;
  options.telemetry = { enabled: false };
  options.unsafeInspectDurableObjects = true;
  options.log = new Log(LogLevel.NONE);
  let runtime = new Miniflare(options);
  context.after(async () => {
    await runtime.dispose();
    assert.equal(outboundCalls, 0);
    if (dirname(folder) !== resolve(tmpdir()) || !basename(folder).startsWith('leo-shortlist-feed-')) throw new Error('Unsafe test cleanup path');
    await rm(folder, { recursive: true, force: true });
  });
  return {
    get runtime() { return runtime; },
    get(path = '/publication', options = {}) { return runtime.dispatchFetch(`https://feed.test${path}`, options); },
    post(value, extra = {}) { return runtime.dispatchFetch('https://feed.test/publication', { method: 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json', ...extra.headers },
      body: typeof value === 'string' ? value : JSON.stringify(value) }); },
    async restart() { await runtime.dispose(); runtime = new Miniflare(options); },
  };
}

test('bounded decoding rejects chunked overflow and invalid UTF-8 before publication', async () => {
  let cancelled = false;
  const stream = new ReadableStream({
    pull(controller) { controller.enqueue(new Uint8Array(MAX_PUBLICATION_BYTES + 1)); },
    cancel() { cancelled = true; },
  });
  await assert.rejects(readPublicationBody(new Request('https://feed.test/publication', { method: 'POST', body: stream, duplex: 'half' })),
    error => error.code === 'publication_too_large' && error.status === 413);
  assert.equal(cancelled, true);
  await assert.rejects(readPublicationBody(new Request('https://feed.test/publication', { method: 'POST', body: new Uint8Array([0xff]) })),
    error => error.code === 'invalid_publication');
});

test('shared schema rejects raw history, authority changes, extra fields, and future timestamps', () => {
  const valid = publication();
  assert.equal(publicationSchema.safeParse(valid).success, true);
  for (const mutate of [
    value => { value.shortlist.stocks[0].coverage.bars = [{ close: 999 }]; },
    value => { value.publisher.llmCalls = 1; },
    value => { value.publisher.executionEnabled = true; },
    value => { value.publisher.inputSha256 = '0'.repeat(64); },
    value => { value.history = []; },
  ]) {
    const invalid = structuredClone(valid); mutate(invalid);
    assert.throws(() => validatePublication(JSON.stringify(invalid)), error => error.code === 'invalid_publication');
  }
  const future = publication();
  future.publisher.heartbeatAt = new Date(Date.now() + 60_000).toISOString();
  assert.throws(() => validatePublication(JSON.stringify(future)), error => error.code === 'future_publication');
  const futureRow = publication();
  futureRow.shortlist.stocks[0].priceObservedAt = new Date(Date.now() + 60_000).toISOString();
  assert.throws(() => validatePublication(JSON.stringify(futureRow)), error => error.code === 'future_publication');
});

test('public routes fail closed before an authenticated publication', async context => {
  const feed = await fixture(context);
  assert.equal((await feed.get()).status, 503);
  assert.equal((await feed.get('/missing')).status, 404);
  assert.equal((await feed.get('/publication?token=never-accepted')).status, 404);
  assert.equal((await feed.get('/publication', { method: 'DELETE' })).status, 405);
  assert.equal((await feed.get('/publication', { method: 'POST', body: '{}' })).status, 401);
  assert.equal((await feed.post(publication(), { headers: { authorization: 'Bearer wrong' } })).status, 401);
  assert.equal((await feed.post(publication(), { headers: { 'content-type': 'text/plain' } })).status, 415);
  assert.equal((await feed.post('x'.repeat(MAX_PUBLICATION_BYTES + 1))).status, 413);
  assert.equal((await feed.post('{')).status, 400);
  assert.equal((await feed.get()).status, 503);
});

test('unconfigured publisher secret rejects writes without exposing configuration values', async context => {
  const feed = await fixture(context, { secret: false });
  const result = await feed.post(publication());
  assert.equal(result.status, 503);
  assert.deepEqual(await result.json(), { error: 'publisher_auth_unconfigured' });
});

test('SQLite feed preserves immutable revisions, serializes updates, and survives restart', async context => {
  const feed = await fixture(context);
  const first = publication();
  assert.deepEqual(await (await feed.post(first)).json(), { status: 'accepted' });
  assert.deepEqual(await (await feed.post(JSON.stringify(first, null, 2))).json(), { status: 'unchanged' });
  let response = await feed.get();
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.equal(response.headers.get('access-control-allow-origin'), null);
  assert.deepEqual(await response.json(), first);

  const heartbeat = publication(1);
  assert.equal((await feed.post(heartbeat)).status, 200);
  for (const [name, change] of [
    ['heartbeat_regressed', value => { value.publisher.heartbeatAt = first.publisher.heartbeatAt; value.publisher.lastCheckedAt = first.publisher.lastCheckedAt; }],
    ['source_regressed', value => { value.shortlist.sourceRetrievedAt = '2026-09-06T10:01:18Z'; value.publisher.revision = digest('regressed-source'); }],
    ['source_regressed', value => { value.shortlist.asOf = '2026-09-03'; for (const row of [...value.shortlist.stocks, ...value.shortlist.funds]) row.asOf = value.shortlist.asOf; value.publisher.revision = digest('regressed-cutoff'); }],
    ['revision_artifact_conflict', value => { value.shortlist.stocks[0].summary += ' changed'; }],
    ['revision_artifact_conflict', value => { value.publisher.artifactSha256 = '0'.repeat(64); }],
    ['published_artifact_required', value => { value.shortlist = null; for (const key of ['inputSha256', 'artifactSha256', 'revision', 'publishedAt']) value.publisher[key] = null; }],
  ]) {
    const invalid = publication(2); change(invalid);
    const result = await feed.post(invalid);
    assert.equal(result.status, 409, name);
    assert.deepEqual(await result.json(), { error: name });
  }
  assert.deepEqual(await (await feed.get()).json(), heartbeat);

  const updates = [3, 8, 4, 7, 2, 9, 6, 5].map(step => publication(step));
  const outcomes = await Promise.all(updates.map(value => feed.post(value)));
  assert.ok(outcomes.every(value => value.status === 200 || value.status === 409));
  assert.deepEqual(await (await feed.get()).json(), publication(9));

  const storage = await feed.runtime.unsafeGetDurableObjectStorage('leo-shortlist-feed', 'ShortlistFeed', { name: 'public-feed' });
  assert.equal((await storage.exec('SELECT COUNT(*) count FROM revisions'))[0].count, 1);
  assert.equal((await storage.exec('SELECT COUNT(*) count FROM latest'))[0].count, 1);
  await feed.restart();
  assert.deepEqual(await (await feed.get()).json(), publication(9));
  assert.deepEqual(await (await feed.post(publication(9))).json(), { status: 'unchanged' });
});

test('previous revision identities remain immutable after a later revision is published', async context => {
  const feed = await fixture(context);
  assert.equal((await feed.post(publication())).status, 200);
  const later = publication(1); later.publisher.revision = digest('later-unit-test-revision');
  assert.equal((await feed.post(later)).status, 200);
  const reused = publication(2); reused.shortlist.stocks[0].summary += ' illicit rewrite';
  const result = await feed.post(reused);
  assert.equal(result.status, 409);
  assert.deepEqual(await result.json(), { error: 'revision_artifact_conflict' });
  assert.deepEqual(await (await feed.get()).json(), later);
});

test('per-symbol times cannot regress behind advancing global metadata, including category moves', async context => {
  const feed = await fixture(context);
  const first = publication();
  assert.equal((await feed.post(first)).status, 200);
  for (const group of ['stocks', 'funds']) {
    for (const field of ['sourceRetrievedAt', 'priceObservedAt']) {
      const next = publication(1);
      next.publisher.revision = digest(`regressed-${group}-${field}`);
      next.shortlist.sourceRetrievedAt = new Date(Date.parse(first.shortlist.sourceRetrievedAt) + 60_000).toISOString();
      next.shortlist[group][0][field] = new Date(Date.parse(first.shortlist[group][0][field]) - 60_000).toISOString();
      const response = await feed.post(next);
      assert.equal(response.status, 409);
      assert.deepEqual(await response.json(), { error: 'source_regressed' });
    }
  }
  const moved = publication(2);
  moved.publisher.revision = digest('moved-symbol-regression');
  const row = moved.shortlist.stocks.shift();
  row.priceObservedAt = new Date(Date.parse(row.priceObservedAt) - 60_000).toISOString();
  moved.shortlist.funds.unshift(row);
  for (const group of ['stocks', 'funds']) moved.shortlist[group].forEach((item, index) => { item.rank = index + 1; });
  moved.shortlist.universe.eligibleCompanyStocks = moved.shortlist.stocks.length;
  moved.shortlist.universe.eligibleFunds = moved.shortlist.funds.length;
  assert.equal((await feed.post(moved)).status, 409);
  assert.deepEqual(await (await feed.get()).json(), first);
});

test('publisher error and pause status retain the original observed shortlist', async context => {
  const feed = await fixture(context);
  assert.equal((await feed.post(publication())).status, 200);
  const failed = publication(1);
  failed.publisher.state = 'error';
  failed.publisher.lastError = { code: 'source_invalid', message: 'The latest source failed validation.' };
  assert.equal((await feed.post(failed)).status, 200);
  assert.deepEqual(await (await feed.get()).json(), failed);
  const paused = publication(2); paused.publisher.state = 'paused';
  assert.equal((await feed.post(paused)).status, 200);
  assert.deepEqual(await (await feed.get()).json(), paused);
});

test('a metadata-only initial status is valid and corrupted persisted output fails closed', async context => {
  const feed = await fixture(context);
  const empty = publication(); empty.shortlist = null;
  for (const key of ['inputSha256', 'artifactSha256', 'revision', 'publishedAt']) empty.publisher[key] = null;
  assert.equal((await feed.post(empty)).status, 200);
  assert.deepEqual(await (await feed.get()).json(), empty);
  const valid = publication(1);
  assert.equal((await feed.post(valid)).status, 200);
  const storage = await feed.runtime.unsafeGetDurableObjectStorage('leo-shortlist-feed', 'ShortlistFeed', { name: 'public-feed' });
  await storage.exec('UPDATE latest SET envelope = ? WHERE singleton = 1', '{}');
  const response = await feed.get();
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: 'feed_unavailable' });
  assert.equal(canonicalJson(JSON.parse(canonicalJson(valid))), canonicalJson(valid));
});
