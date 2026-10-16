import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { test } from 'node:test';
import { applicationStore, databaseHuntStore, DuplicateApplicationError, type ApplicationData } from '../src/applications/store.ts';
import type { HuntInput, JobResult } from '../src/hunt.ts';
import type { Job } from '../src/jobs.ts';

/** SQLite adapter exercises the actual migration, constraints and SQL, without live data. */
function disposableStorage() {
  const sqlite = new DatabaseSync(':memory:');
  sqlite.exec(readFileSync(new URL('../migrations/0001_applications.sql', import.meta.url), 'utf8'));
  const stats = { queries: 0, changedRows: 0 };
  function prepare(query: string, parameters: unknown[] = []) {
    return {
      query, parameters,
      bind(...values: unknown[]) { return prepare(query, values); },
      async first() { stats.queries++; return sqlite.prepare(query).get(...parameters as []) ?? null; },
      async all() { stats.queries++; return { results: sqlite.prepare(query).all(...parameters as []), success: true }; },
      async run() { stats.queries++; stats.changedRows += Number(sqlite.prepare(query).run(...parameters as []).changes); return { success: true }; },
    };
  }
  const db = {
    prepare,
    async batch(statements: ReturnType<typeof prepare>[]) {
      sqlite.exec('BEGIN');
      try {
        const results = [];
        for (const statement of statements) results.push(await statement.run());
        sqlite.exec('COMMIT');
        return results;
      } catch (error) { sqlite.exec('ROLLBACK'); throw error; }
    },
  } as unknown as D1Database;
  const files = new Map<string, string | Uint8Array>();
  const kv = {
    async put(key: string, value: string | Uint8Array) { files.set(key, value); },
    async get(key: string, mode?: string) {
      const value = files.get(key);
      if (value === undefined) return null;
      return mode === 'json' ? JSON.parse(value as string) : mode === 'arrayBuffer' ? (value as Uint8Array).buffer : value;
    },
    async delete(key: string) { files.delete(key); },
    async list(options: { prefix: string }) { return { keys: [...files.keys()].filter(key => key.startsWith(options.prefix)).map(name => ({ name })), list_complete: true }; },
  } as unknown as KVNamespace;
  return { db, kv, files, sqlite, stats };
}

const job = (key: string): Job => ({ key, ats: 'lever', company: 'acme', title: 'Engineer', location: 'NY', remote: false, postedAt: '', url: '', applyUrl: '' });
const intake = (): ApplicationData => ({
  profile: null, facts: { workAuthorizedUS: 'yes', needsSponsorship: 'no', notes: 'Candidate supplied.' },
  preferences: { titles: ['Engineer'], locations: ['New York'], exclude: ['staff'], companies: ['lever:acme'] },
  jobs: [job('a')], resume: { name: 'resume.pdf', base64: 'JVBERi0xLjQ=' },
});
const input = (keys = ['a'], submit = true): HuntInput & { authorizedAt: string } => ({
  profile: {} as HuntInput['profile'], facts: intake().facts, jobs: keys.map(job), resume: intake().resume!, submit, authorizedAt: '2026-10-16T12:00:00.000Z',
});
const at = '2026-10-16T12:00:00.000Z';
const outcome = (status: JobResult['status'], submissionAttempted = false): JobResult & { submissionAttempted: boolean } => ({ status, submissionAttempted, message: status, missing: [], hasShot: false, at });

test('candidate intake and resume persist privately, partial resume saves preserve the file', async () => {
  const { db, kv, sqlite } = disposableStorage();
  try {
    const own = applicationStore(db, kv, 'owner-a');
    assert.equal(await own.get(), null);
    await own.save(intake());
    const saved = await own.get();
    assert.deepEqual(saved?.facts, intake().facts);
    assert.deepEqual(saved?.preferences, intake().preferences);
    assert.deepEqual(saved?.jobs, intake().jobs);
    assert.deepEqual(saved?.resume, intake().resume);
    assert.ok(saved?.createdAt);
    const { resume: _, ...data } = intake();
    await own.save({ ...data, preferences: { ...data.preferences, titles: ['Quant researcher'] } });
    assert.deepEqual((await own.get())?.resume, intake().resume);
    assert.deepEqual((await own.get())?.preferences.titles, ['Quant researcher']);
    await own.save({ ...data, jobs: [job('b'), { ...job('a'), title: 'Updated title' }] });
    assert.deepEqual((await own.get())?.jobs.map(job => [job.key, job.title]), [['b', 'Engineer'], ['a', 'Updated title']]);
    await own.save({ ...data, jobs: [{ ...job('a'), legacyStatus: 'needs_review' }] });
    await own.save({ ...data, jobs: [{ ...job('a'), title: 'Refreshed search result' }] });
    assert.equal((await own.get())?.jobs[0]?.legacyStatus, 'needs_review', 'refreshing a job must preserve an earlier uncertain attempt');
    await own.save({ ...data, jobs: [] });
    assert.equal((await own.get())?.jobs[0]?.legacyStatus, 'needs_review', 'a stale empty snapshot must not erase a previous attempt');
    assert.equal(await applicationStore(db, kv, 'owner-b').get(), null);
    await own.delete();
    assert.equal(await own.get(), null, 'explicit workspace deletion removes retained legacy guards');
  } finally { sqlite.close(); }
});

test('real submissions reserve jobs transactionally; duplicates roll back the entire new hunt', async () => {
  const { db, kv, files, sqlite } = disposableStorage();
  try {
    const store = databaseHuntStore(db, kv, 'owner-a');
    await store.create('h1', input(), at);
    await assert.rejects(store.create('h2', input(['b', 'a']), at), DuplicateApplicationError);
    assert.equal(await store.meta('h2'), null);
    assert.equal(files.has('hunt:h2:input'), false);
    // The failed transaction must not reserve b.
    await store.create('h3', input(['b']), at);
    assert.equal((await store.meta('h1') as HuntInput & { authorizedAt: string }).authorizedAt, at);
    assert.deepEqual((await store.input('h1'))?.jobs.map(j => j.key), ['a']);
    await databaseHuntStore(db, kv, 'owner-b').create('h4', input(), at);
    await store.create('dry1', input(['a'], false), at);
    await store.create('dry2', input(['a'], false), at);
  } finally { sqlite.close(); }
});

test('pre-submit needs-you releases a job while attempted outcomes stay blocked despite stale writes', async () => {
  const { db, kv, sqlite } = disposableStorage();
  try {
    const store = databaseHuntStore(db, kv, 'owner-a');
    await store.create('safe', input(), at);
    await store.putResults('safe', { a: outcome('needs_you') });
    await store.create('retry', input(), at);
    await store.putResults('retry', { a: outcome('needs_you', true) });
    await store.putResults('retry', { a: outcome('failed', false) });
    assert.equal((await store.results('retry')).a.submissionAttempted, true);
    await store.setStatus('retry', 'errored');
    await assert.rejects(store.create('blocked', input(), at), DuplicateApplicationError);
  } finally { sqlite.close(); }
});

test('stopped hunts release queued jobs and preserve unknown working reservations', async () => {
  const { db, kv, sqlite } = disposableStorage();
  try {
    const store = databaseHuntStore(db, kv, 'owner-a');
    await store.create('h1', input(['a', 'b']), at);
    await store.putResults('h1', { a: outcome('working') });
    await store.setStatus('h1', 'stopped');
    await store.create('safe', input(['b']), at);
    await assert.rejects(store.create('unknown', input(['a']), at), DuplicateApplicationError);
    const history = await applicationStore(db, kv, 'owner-a').listHunts();
    assert.equal(history.find(hunt => hunt.id === 'h1')?.status, 'stopped');
  } finally { sqlite.close(); }
});

test('ownership gates reads and writes; deleting one workspace removes only its files and records', async () => {
  const { db, kv, files, sqlite } = disposableStorage();
  try {
    const alice = applicationStore(db, kv, 'owner-a');
    const bob = applicationStore(db, kv, 'owner-b');
    await alice.save(intake());
    await bob.save(intake());
    const a = databaseHuntStore(db, kv, 'owner-a');
    const b = databaseHuntStore(db, kv, 'owner-b');
    await a.create('h1', input(), at);
    await b.create('h2', input(), at);
    await a.putShot('h1', 'a', 'data:image/jpeg;base64,AAAA');
    await b.putShot('h2', 'a', 'data:image/jpeg;base64,AAAA');
    assert.equal(await bob.ownsHunt('h1'), false);
    assert.equal(await b.input('h1'), null);
    assert.equal(await b.meta('h1'), null);
    assert.equal(await b.status('h1'), null);
    assert.equal(await a.status('h1'), 'queued');
    assert.equal(await b.shot('h1', 'a'), null);
    await b.deleteHunt('h1');
    assert.ok(await a.meta('h1'));
    assert.ok(await databaseHuntStore(db, kv).input('h1'), 'Workflow can read the owned hunt internally');
    await alice.delete();
    assert.equal(await alice.get(), null);
    assert.equal(await a.meta('h1'), null);
    assert.deepEqual(await alice.listHunts(), []);
    assert.ok(await bob.get());
    assert.ok(await b.meta('h2'));
    assert.equal([...files.keys()].some(key => key.includes('owner-a') || key.startsWith('hunt:h1:')), false);
    assert.ok(files.has('hunt:h2:input'));
    assert.ok(files.has('hunt:h2:shot:a'));
  } finally { sqlite.close(); }
});

test('large job collections use a fixed query count and progress updates write only changed results', async () => {
  const { db, kv, sqlite, stats } = disposableStorage();
  try {
    const jobs = Array.from({ length: 1000 }, (_, index) => job(String(index)));
    await applicationStore(db, kv, 'owner-a').save({ ...intake(), jobs });
    assert.equal(stats.queries, 5, '1 resume lookup and 4 transactional statements for 1000 jobs');
    assert.equal((await applicationStore(db, kv, 'owner-a').get())?.jobs.length, 1000);
    stats.changedRows = 0;
    await applicationStore(db, kv, 'owner-a').save({ ...intake(), jobs });
    assert.equal(stats.changedRows, 1, 'unchanged saved jobs are not rewritten during a profile save');
    const store = databaseHuntStore(db, kv, 'owner-a');
    stats.queries = 0;
    await store.create('large', input(jobs.slice(0, 400).map(job => job.key), false), at);
    assert.equal(stats.queries, 3, 'create uses three statements regardless of hunt length');
    const results = Object.fromEntries(jobs.slice(0, 400).map(job => [job.key, outcome('dry_run')]));
    stats.queries = 0;
    await store.putResults('large', results);
    assert.equal(stats.queries, 4);
    stats.queries = 0;
    stats.changedRows = 0;
    await store.putResults('large', { ...results, '399': { ...results['399'], message: 'Updated one result.' } });
    assert.equal(stats.queries, 4);
    assert.equal(stats.changedRows, 2, 'only hunt timestamp and the changed job are updated');
    stats.changedRows = 0;
    await store.putResults('large', { ...results, '399': { ...results['399'], message: 'Updated one result.' } });
    assert.equal(stats.changedRows, 0, 'an identical snapshot performs no writes');
  } finally { sqlite.close(); }
});

test('oversized UTF-8 collection bindings fail before changing the workspace', async () => {
  const { db, kv, sqlite } = disposableStorage();
  try {
    const jobs = Array.from({ length: 1000 }, (_, index) => ({ ...job(String(index)), title: '工'.repeat(300), company: '工'.repeat(200), location: '工'.repeat(300) }));
    const vault = applicationStore(db, kv, 'owner-a');
    await assert.rejects(vault.save({ ...intake(), jobs }), /too large/);
    assert.equal(await vault.get(), null);
  } finally { sqlite.close(); }
});
