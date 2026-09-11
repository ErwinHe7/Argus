import assert from 'node:assert/strict';
import { test, before } from 'node:test';
import { readFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname, basename, resolve } from 'node:path';
import { build } from 'esbuild';
import { Miniflare, convertV4MiniflareOptions, Log, LogLevel } from 'miniflare';
import { assertRadarMonotonic, eventRadarSchema, validateRadar, validateRadarIntegrity } from '../../features/research-desk/radar/contract.ts';
import { MAX_SOURCE_BYTES, mergeManualSeed, parseFed, parseBls, readBounded, refreshRadar } from './collector.ts';

let seed; let bundle;
const months = ['January', 'March', 'April', 'June', 'July', 'September', 'October', 'December'];
const days = ['27-28', '17-18*', '28-29', '16-17', '28-29', '15-16*', '27-28', '8-9*'];
const fed = `<h4><a>2026 FOMC Meetings</a></h4>${months.map((month, index) => `<div class="fomc-meeting__month">${month}</div><div class="fomc-meeting__date">${days[index]}</div>`).join('')}<div class="panel-heading"><h4><a>2027 FOMC Meetings</a></h4>`;
const ics = ['BEGIN:VCALENDAR', ...[1, 2, 3, 4].flatMap(month => ['BEGIN:VEVENT', `DTSTART;TZID=America/New_York:2026${String(month).padStart(2, '0')}15T083000`, 'SUMMARY:Consumer Price Index', 'END:VEVENT']), 'END:VCALENDAR'].join('\r\n');
before(async () => {
  seed = validateRadar(JSON.parse(await readFile('features/research-desk/data/event-radar.json', 'utf8')));
  const built = await build({ entryPoints: ['workers/event-radar/index.ts'], bundle: true, write: false, format: 'esm', platform: 'neutral', target: 'es2022', external: ['cloudflare:workers'] });
  bundle = built.outputFiles[0].text;
});

test('shared contract rejects authority changes, invalid dates, counts, chronology and mismatched event time', () => {
  for (const mutate of [
    value => { value.executionEnabled = true; }, value => { value.coverage.eventCount++; },
    value => { value.events[0].startDate = '2026-99-99'; }, value => { value.events[0].sourceId = 'missing'; },
    value => { value.events[0].scheduledAt = '2026-01-01T12:00:00Z'; }, value => { value.sources[0].retrievedAt = '2030-01-01T00:00:00Z'; },
    value => { value.reviewAfter = '2030-01-01T00:00:00Z'; }, value => { value.events.push(value.events[0]); value.coverage.eventCount++; },
  ]) { const invalid = structuredClone(seed); mutate(invalid); assert.equal(eventRadarSchema.safeParse(invalid).success, false); }
  const future = structuredClone(seed); future.generatedAt = new Date(Date.now() + 60_000).toISOString();
  assert.throws(() => validateRadar(future), /Future/);
});

test('normalization preserves date-only FOMC ranges, ignores next-year section, and handles BLS Eastern DST', () => {
  const events = parseFed(fed, seed.generatedAt, 2026);
  assert.equal(events.length, 8); assert.equal(events[5].startDate, '2026-09-15'); assert.equal(events[5].endDate, '2026-09-16');
  assert.equal(events[5].scheduledAt, null);
  assert.throws(() => parseFed('<html>layout changed</html>', seed.generatedAt, 2026), /layout/);
  assert.throws(() => parseFed(fed.replace('January', 'Unknown month'), seed.generatedAt, 2026), /layout/);
  const releases = parseBls(ics, seed.generatedAt);
  assert.equal(releases[0].scheduledAt, '2026-01-15T13:30:00.000Z');
  assert.equal(releases[2].scheduledAt, '2026-03-15T12:30:00.000Z');
  assert.equal(parseBls(ics.replaceAll('America/New_York', 'US-Eastern'), seed.generatedAt)[0].scheduledAt, '2026-01-15T13:30:00.000Z');
  const retainedHistory = ['BEGIN:VCALENDAR', ...Array.from({ length: 108 }, (_, index) => {
    const date = new Date(Date.UTC(2026, 0, index + 1)).toISOString().slice(0, 10).replaceAll('-', '');
    return `BEGIN:VEVENT\nDTSTART;TZID=US-Eastern:${date}T083000\nSUMMARY:Consumer Price Index\nEND:VEVENT`;
  }), 'END:VCALENDAR'].join('\n');
  assert.equal(parseBls(retainedHistory, seed.generatedAt).length, 108);
  assert.throws(() => parseBls(ics.replaceAll(';TZID=America/New_York', ''), seed.generatedAt), /timezone/);
});

test('source refresh is bounded and rejects invalid UTF-8', async () => {
  let cancelled = false;
  await assert.rejects(readBounded(new Response(new ReadableStream({ pull(controller) { controller.enqueue(new Uint8Array(MAX_SOURCE_BYTES + 1)); }, cancel() { cancelled = true; } }))), /too_large/);
  assert.equal(cancelled, true);
  await assert.rejects(readBounded(new Response(new Uint8Array([0xff]))));
});

test('calendar polls keep manual provenance, preserve unchanged availability and retain last good evidence on failure', async () => {
  const calls = [];
  const fetcher = async (url, options) => { calls.push({ url, options }); return url.includes('federalreserve') ? new Response(fed) : new Response('Forbidden', { status: 403 }); };
  const first = await refreshRadar(seed, Date.now(), fetcher);
  assert.equal(calls.length, 2); assert.ok(calls.every(call => call.options.redirect === 'manual'));
  assert.equal(first.sources.find(source => source.id === 'bls-calendar').state, 'error');
  assert.equal(first.sources.find(source => source.id === 'bls-september-reviewed').retrievedAt, seed.sources[0].retrievedAt);
  const retained = first.events.find(event => event.id === 'fed-fomc-2026-10-28');
  assert.ok(retained); assert.equal(first.records.length, 0);
  assert.equal(first.events.filter(event => event.id === 'fed-fomc-2026-09-16').length, 1);
  assert.equal(first.events.find(event => event.id === 'fed-fomc-2026-09-16').sourceId, 'fed-september-reviewed');
  assert.equal(first.events.find(event => event.id === 'fed-fomc-2026-09-16').scheduledAt, '2026-09-16T18:00:00Z');
  const second = await refreshRadar(first, Date.now() + 1, fetcher);
  assert.equal(second.events.find(event => event.id === retained.id).availableAt, retained.availableAt);
  const failed = await refreshRadar(second, Date.now() + 2, async () => new Response('down', { status: 503 }));
  assert.deepEqual(failed.events, second.events);
  const oldFed = second.sources.find(source => source.id === 'fed-fomc');
  const failedFed = failed.sources.find(source => source.id === 'fed-fomc');
  assert.equal(failedFed.retrievedAt, oldFed.retrievedAt); assert.equal(failedFed.contentSha256, oldFed.contentSha256); assert.equal(failedFed.state, 'error');
  const changedSameTime = structuredClone(first); changedSameTime.sources[0].contentSha256 = '0'.repeat(64);
  assert.throws(() => assertRadarMonotonic(first, changedSameTime), /identity/);
});

test('journal rejects invented observations, broken ordering and hashes', async () => {
  const invalid = structuredClone(seed);
  invalid.records.push({ id: 'invented', sequence: 2, kind: 'outcome', eventId: seed.events[0].id, registeredAt: seed.generatedAt,
    statement: 'Claim', sourceUrl: null, sourceAvailableAt: null, hypothesisId: null, previousSha256: null, contentSha256: '0'.repeat(64) });
  await assert.rejects(validateRadarIntegrity(invalid));
});

test('only a newer deployed manual verification can atomically update issuer events', () => {
  const nextSeed = structuredClone(seed); const now = Date.now(); const timestamp = new Date(now).toISOString();
  const source = nextSeed.sources.find(item => item.id === 'micron-reviewed');
  Object.assign(source, { lastAttemptAt: timestamp, retrievedAt: timestamp, reviewAfter: new Date(now + 86400_000).toISOString(), contentSha256: 'a'.repeat(64) });
  const event = nextSeed.events.find(item => item.sourceId === source.id); event.availableAt = timestamp; event.watchFor = 'Newly verified issuer disclosure checklist.';
  nextSeed.generatedAt = timestamp; nextSeed.reviewAfter = nextSeed.sources.map(item => item.reviewAfter).sort()[0];
  const merged = mergeManualSeed(seed, nextSeed, now);
  assert.equal(merged.events.find(item => item.id === event.id).watchFor, event.watchFor);
  assert.equal(merged.sources.find(item => item.id === source.id).mode, 'manual_verified');
  assert.equal(mergeManualSeed(merged, seed, now), merged);
  const forgedSameTime = structuredClone(nextSeed); forgedSameTime.events.find(item => item.id === event.id).watchFor = 'Unverified change';
  assert.equal(mergeManualSeed(merged, forgedSameTime, now), merged);
  const automatic = structuredClone(nextSeed); automatic.sources.find(item => item.id === source.id).mode = 'automatic';
  assert.equal(mergeManualSeed(seed, automatic, now), seed);
});

test('native SQLite feed denies public mutations, performs no fetch on reads, and survives restart', async context => {
  const folder = await mkdtemp(join(tmpdir(), 'leo-event-radar-'));
  let outbound = 0;
  const options = convertV4MiniflareOptions({ name: 'leo-event-radar', modules: true, script: bundle, compatibilityDate: '2026-09-04', compatibilityFlags: ['nodejs_compat'],
    durableObjects: { EVENT_RADAR: { className: 'EventRadarFeed', useSQLite: true } }, outboundService: () => { outbound++; throw new Error('Unexpected outbound'); } });
  options.resourcePersistencePath = folder; options.cf = false; options.telemetry = { enabled: false }; options.log = new Log(LogLevel.NONE);
  let runtime = new Miniflare(options);
  context.after(async () => { await runtime.dispose(); assert.equal(outbound, 0);
    if (dirname(folder) !== resolve(tmpdir()) || !basename(folder).startsWith('leo-event-radar-')) throw new Error('Unsafe cleanup'); await rm(folder, { recursive: true, force: true }); });
  for (const [path, method, status] of [['/radar', 'GET', 200], ['/radar', 'HEAD', 200], ['/radar', 'POST', 405], ['/radar?refresh=1', 'GET', 404], ['/refresh', 'POST', 404]]) {
    assert.equal((await runtime.dispatchFetch(`https://radar.test${path}`, { method })).status, status);
  }
  const first = await (await runtime.dispatchFetch('https://radar.test/radar')).json(); assert.deepEqual(first, seed);
  await runtime.dispose(); runtime = new Miniflare(options);
  assert.deepEqual(await (await runtime.dispatchFetch('https://radar.test/radar')).json(), first);
});

test('native scheduled refresh publishes a last-good calendar and serializes competing collectors', async context => {
  const options = convertV4MiniflareOptions({ name: 'leo-event-radar', modules: true, script: bundle, compatibilityDate: '2026-09-04', compatibilityFlags: ['nodejs_compat'],
    durableObjects: { EVENT_RADAR: { className: 'EventRadarFeed', useSQLite: true } }, outboundService: async request => {
      const url = new URL(request.url); assert.ok(['www.federalreserve.gov', 'www.bls.gov'].includes(url.hostname));
      await new Promise(resolve => setTimeout(resolve, 100));
      return url.hostname === 'www.federalreserve.gov' ? new Response(fed) : new Response('blocked', { status: 403 });
    } });
  options.cf = false; options.telemetry = { enabled: false }; options.log = new Log(LogLevel.NONE);
  const runtime = new Miniflare(options); context.after(() => runtime.dispose());
  const namespace = await runtime.getDurableObjectNamespace('EVENT_RADAR'); const stub = namespace.getByName('official-calendar');
  const results = await Promise.all([stub.refresh(), stub.refresh()]);
  assert.ok(results.some(result => result.status === 'published'), JSON.stringify(results)); assert.ok(results.every(result => ['published', 'already_running'].includes(result.status)), JSON.stringify(results));
  const artifact = validateRadar(await (await runtime.dispatchFetch('https://radar.test/radar')).json());
  assert.equal(artifact.sources.find(source => source.id === 'fed-fomc').state, 'success');
  assert.equal(artifact.sources.find(source => source.id === 'bls-calendar').state, 'error');
  assert.ok(artifact.events.some(event => event.id === 'fed-fomc-2026-10-28'));
});
