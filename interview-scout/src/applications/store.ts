import type { Facts } from '../answers.ts';
import type { HuntInput, HuntMeta, HuntStore, JobResult, Results } from '../hunt.ts';
import type { Job } from '../jobs.ts';
import type { Profile } from '../profile.ts';

const DAY = 86_400;
const INPUT_TTL = 7 * DAY;
const SHOT_TTL = 30 * DAY;
export interface ApplicationData {
  profile: Profile | null;
  facts: Facts;
  preferences: { titles: string[]; locations: string[]; exclude: string[]; companies: string[] };
  jobs: (Job & { legacyStatus?: 'submitted' | 'needs_review'; unselected?: boolean })[];
  resume?: { name: string; base64: string } | null;
}

export interface SavedApplication extends ApplicationData { createdAt: string; updatedAt: string }
export type StoredHuntStatus = 'queued' | 'running' | 'complete' | 'stopped' | 'errored';
export interface StoredHunt extends HuntMeta { results: Results; status: StoredHuntStatus; updatedAt: string }
export interface DatabaseHuntStore extends HuntStore {
  status(id: string): Promise<StoredHuntStatus | null>;
  setStatus(id: string, status: StoredHuntStatus): Promise<void>;
  deleteHunt(id: string): Promise<void>;
}

interface WorkspaceRow {
  profile_json: string | null;
  facts_json: string;
  preferences_json: string;
  resume_name: string | null;
  resume_key: string | null;
  created_at: string;
  updated_at: string;
}
interface HuntRow { id: string; owner_hash: string; submit_mode: number; status: StoredHuntStatus; authorized_at: string | null; created_at: string; updated_at: string }
interface HuntJobRow { job_key: string; job_json: string; result_json: string | null; submission_attempted: number }

export class DuplicateApplicationError extends Error {
  constructor() { super('One or more jobs already have a queued, active, submitted, or uncertain application in this workspace.'); this.name = 'DuplicateApplicationError'; }
}

const huntKey = (id: string, part: string) => `hunt:${id}:${part}`;
const resumePrefix = (ownerHash: string) => `application:${ownerHash}:resume:`;
function json(value: unknown, maxCharacters = 100_000): string {
  const encoded = JSON.stringify(value);
  if (encoded.length > maxCharacters) throw new Error('Saved application data is too large.');
  return encoded;
}

/** Stay below D1's 2 MB bound-value limit, including multi-byte job text. */
function collectionJson(value: unknown): string {
  const encoded = JSON.stringify(value);
  if (new TextEncoder().encode(encoded).byteLength > 1_500_000) throw new Error('Saved application data is too large. Save a smaller job selection.');
  return encoded;
}

function workspaceStatement(db: D1Database, ownerHash: string, at: string) {
  return db.prepare(`INSERT INTO application_workspaces (owner_hash, created_at, updated_at) VALUES (?, ?, ?) ON CONFLICT(owner_hash) DO NOTHING`).bind(ownerHash, at, at);
}

function ownerCondition(ownerHash?: string): { sql: string; values: string[] } {
  return ownerHash ? { sql: ' AND owner_hash = ?', values: [ownerHash] } : { sql: '', values: [] };
}

async function readHunt(db: D1Database, id: string, ownerHash?: string): Promise<HuntRow | null> {
  const owner = ownerCondition(ownerHash);
  return db.prepare(`SELECT * FROM application_hunts WHERE id = ?${owner.sql}`).bind(id, ...owner.values).first<HuntRow>();
}

async function readJobs(db: D1Database, id: string): Promise<HuntJobRow[]> {
  return (await db.prepare('SELECT job_key, job_json, result_json, submission_attempted FROM application_hunt_jobs WHERE hunt_id = ? ORDER BY position').bind(id).all<HuntJobRow>()).results;
}

function resultsFromRows(rows: HuntJobRow[]): Results {
  const results: Results = {};
  for (const row of rows) {
    if (!row.result_json) continue;
    const result: JobResult & { submissionAttempted?: boolean } = JSON.parse(row.result_json);
    // Once an attempt has been recorded it cannot be cleared by a stale write.
    if (row.submission_attempted) result.submissionAttempted = true;
    results[row.job_key] = result;
  }
  return results;
}

function metaFromRow(row: HuntRow, jobs: HuntJobRow[]): HuntMeta {
  return {
    id: row.id, createdAt: row.created_at, submit: Boolean(row.submit_mode), jobs: jobs.map(j => JSON.parse(j.job_json)),
    ...(row.authorized_at ? { authorizedAt: row.authorized_at } : {}),
  };
}

async function removeHuntFiles(kv: KVNamespace, id: string, jobs: { job_key: string }[]): Promise<void> {
  await kv.delete(huntKey(id, 'input'));
  await Promise.all(jobs.map(j => kv.delete(huntKey(id, `shot:${j.job_key}`))));
}

/** Private candidate intake and history. Callers pass only the hash of the workspace credential. */
export function applicationStore(db: D1Database, kv: KVNamespace, ownerHash: string) {
  return {
    async get(): Promise<SavedApplication | null> {
      const row = await db.prepare('SELECT * FROM application_workspaces WHERE owner_hash = ?').bind(ownerHash).first<WorkspaceRow>();
      if (!row) return null;
      const jobs = (await db.prepare('SELECT job_json FROM application_saved_jobs WHERE owner_hash = ? ORDER BY position').bind(ownerHash).all<{ job_json: string }>()).results;
      const savedResume = row.resume_key ? await kv.get<string>(row.resume_key) : null;
      return {
        profile: row.profile_json ? JSON.parse(row.profile_json) : null,
        facts: JSON.parse(row.facts_json), preferences: JSON.parse(row.preferences_json), jobs: jobs.map(j => JSON.parse(j.job_json)),
        resume: savedResume && row.resume_name ? { name: row.resume_name, base64: savedResume } : null,
        createdAt: row.created_at, updatedAt: row.updated_at,
      };
    },
    async save(data: ApplicationData): Promise<void> {
      const at = new Date().toISOString();
      const profile = data.profile ? json(data.profile, 200_000) : null;
      const facts = json(data.facts);
      const preferences = json(data.preferences);
      const jobs = [...new Map(data.jobs.map(job => [job.key, job])).values()];
      for (const job of jobs) json(job, 20_000);
      const encodedJobs = collectionJson(jobs);
      let resumeKey: string | null | undefined;
      if (data.resume) {
        const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(data.resume.base64)));
        const hash = Array.from(digest, byte => byte.toString(16).padStart(2, '0')).join('');
        resumeKey = `${resumePrefix(ownerHash)}${hash}`;
        // PDFs stay private in KV; no expiring public URL or database-sized PDF row.
        const existing = await db.prepare('SELECT resume_key FROM application_workspaces WHERE owner_hash = ?').bind(ownerHash).first<{ resume_key: string | null }>();
        if (existing?.resume_key !== resumeKey || await kv.get(resumeKey) === null) await kv.put(resumeKey, data.resume.base64);
      } else if (data.resume === null) resumeKey = null;

      const updates = ['profile_json = ?', 'facts_json = ?', 'preferences_json = ?', 'updated_at = ?'];
      const values: (string | null)[] = [profile, facts, preferences, at];
      if (resumeKey !== undefined) {
        updates.push('resume_key = ?', 'resume_name = ?');
        values.push(resumeKey, data.resume?.name ?? null);
      }
      await db.batch([
        workspaceStatement(db, ownerHash, at),
        db.prepare(`UPDATE application_workspaces SET ${updates.join(', ')} WHERE owner_hash = ?`).bind(...values, ownerHash),
        db.prepare(`DELETE FROM application_saved_jobs WHERE owner_hash = ?
          AND json_extract(job_json, '$.legacyStatus') IS NULL
          AND job_key NOT IN (SELECT json_extract(value, '$.key') FROM json_each(?))`).bind(ownerHash, encodedJobs),
        db.prepare(`INSERT INTO application_saved_jobs (owner_hash, job_key, position, job_json)
          SELECT ?, json_extract(value, '$.key'), CAST(key AS INTEGER), value FROM json_each(?) WHERE 1
          ON CONFLICT(owner_hash, job_key) DO UPDATE SET position = excluded.position,
            job_json = CASE WHEN json_extract(application_saved_jobs.job_json, '$.legacyStatus') IS NOT NULL
              THEN json_set(excluded.job_json, '$.legacyStatus', json_extract(application_saved_jobs.job_json, '$.legacyStatus'))
              ELSE excluded.job_json END
          WHERE application_saved_jobs.position != excluded.position OR application_saved_jobs.job_json != excluded.job_json`).bind(ownerHash, encodedJobs),
      ]);
    },
    async ownsHunt(id: string): Promise<boolean> { return !!(await readHunt(db, id, ownerHash)); },
    async listHunts(): Promise<StoredHunt[]> {
      const rows = (await db.prepare('SELECT * FROM application_hunts WHERE owner_hash = ? ORDER BY created_at DESC').bind(ownerHash).all<HuntRow>()).results;
      const allJobs = (await db.prepare('SELECT hunt_id, job_key, job_json, result_json, submission_attempted FROM application_hunt_jobs WHERE owner_hash = ? ORDER BY hunt_id, position').bind(ownerHash).all<HuntJobRow & { hunt_id: string }>()).results;
      const byHunt = new Map<string, HuntJobRow[]>();
      for (const job of allJobs) {
        if (!byHunt.has(job.hunt_id)) byHunt.set(job.hunt_id, []);
        byHunt.get(job.hunt_id)!.push(job);
      }
      return rows.map(row => {
        const jobs = byHunt.get(row.id) ?? [];
        return { ...metaFromRow(row, jobs), status: row.status, updatedAt: row.updated_at, results: resultsFromRows(jobs) };
      });
    },
    async delete(): Promise<void> {
      const hunts = (await db.prepare('SELECT id FROM application_hunts WHERE owner_hash = ?').bind(ownerHash).all<{ id: string }>()).results;
      const jobs = (await db.prepare('SELECT hunt_id, job_key FROM application_hunt_jobs WHERE owner_hash = ?').bind(ownerHash).all<{ hunt_id: string; job_key: string }>()).results;
      // The API terminates active workflows before invoking this method.
      for (const { id } of hunts) await removeHuntFiles(kv, id, jobs.filter(job => job.hunt_id === id));
      const resume = await db.prepare('SELECT resume_key FROM application_workspaces WHERE owner_hash = ?').bind(ownerHash).first<{ resume_key: string | null }>();
      if (resume?.resume_key) await kv.delete(resume.resume_key);
      // Also remove superseded or interrupted PDF saves belonging to this owner.
      let cursor: string | undefined;
      do {
        const page = await kv.list({ prefix: resumePrefix(ownerHash), ...(cursor ? { cursor } : {}) });
        await Promise.all(page.keys.map(key => kv.delete(key.name)));
        cursor = page.list_complete ? undefined : page.cursor;
      } while (cursor);
      await db.prepare('DELETE FROM application_workspaces WHERE owner_hash = ?').bind(ownerHash).run();
    },
  };
}

/** Durable hunt metadata and submission reservations, with private expiring binary artifacts in KV. */
export function databaseHuntStore(db: D1Database, kv: KVNamespace, ownerHash?: string): DatabaseHuntStore {
  const find = (id: string) => readHunt(db, id, ownerHash);
  return {
    async create(id, input, createdAt) {
      if (!ownerHash) throw new Error('A private workspace is required to create a hunt.');
      const jobs = [...new Map(input.jobs.map(job => [job.key, job])).values()];
      for (const job of jobs) json(job, 20_000);
      const encodedJobs = collectionJson(jobs);
      await kv.put(huntKey(id, 'input'), JSON.stringify({ ...input, jobs }), { expirationTtl: INPUT_TTL });
      try {
        await db.batch([
          workspaceStatement(db, ownerHash, createdAt),
          db.prepare(`INSERT INTO application_hunts (id, owner_hash, submit_mode, status, authorized_at, created_at, updated_at) VALUES (?, ?, ?, 'queued', ?, ?, ?)`).bind(id, ownerHash, Number(input.submit), (input as HuntInput & { authorizedAt?: string }).authorizedAt ?? null, createdAt, createdAt),
          db.prepare(`INSERT INTO application_hunt_jobs (hunt_id, owner_hash, job_key, position, job_json, submit_mode, updated_at)
            SELECT ?, ?, json_extract(value, '$.key'), CAST(key AS INTEGER), value, ?, ? FROM json_each(?)`).bind(id, ownerHash, Number(input.submit), createdAt, encodedJobs),
        ]);
      } catch (error) {
        await kv.delete(huntKey(id, 'input'));
        if (/UNIQUE constraint failed: application_hunt_jobs\.owner_hash, application_hunt_jobs\.job_key/i.test(error instanceof Error ? error.message : String(error))) throw new DuplicateApplicationError();
        throw error;
      }
    },
    async input(id) { return await find(id) ? kv.get<HuntInput>(huntKey(id, 'input'), 'json') : null; },
    async deleteInput(id) { if (await find(id)) await kv.delete(huntKey(id, 'input')); },
    async status(id) { return (await find(id))?.status ?? null; },
    async meta(id) { const row = await find(id); return row ? metaFromRow(row, await readJobs(db, id)) : null; },
    async results(id) { return await find(id) ? resultsFromRows(await readJobs(db, id)) : {}; },
    async putResults(id, results) {
      const hunt = await find(id);
      if (!hunt) return;
      const existing = new Map((await readJobs(db, id)).map(row => [row.job_key, row.result_json]));
      const changed = Object.fromEntries(Object.entries(results).filter(([key, result]) => existing.has(key) && existing.get(key) !== json(result)));
      if (!Object.keys(changed).length) return;
      const encodedResults = collectionJson(changed);
      const at = new Date().toISOString();
      await db.batch([
        db.prepare('UPDATE application_hunts SET updated_at = ? WHERE id = ?').bind(at, id),
        db.prepare(`UPDATE application_hunt_jobs
          SET status = json_extract(changes.value, '$.status'), result_json = changes.value,
            submission_attempted = MAX(submission_attempted,
              CASE WHEN json_extract(changes.value, '$.status') = 'submitted' OR json_extract(changes.value, '$.submissionAttempted') = 1 THEN 1 ELSE 0 END),
            blocked = CASE WHEN submission_attempted = 1 OR json_extract(changes.value, '$.status') IN ('working', 'submitted') OR json_extract(changes.value, '$.submissionAttempted') = 1 THEN 1 ELSE 0 END,
            updated_at = ?
          FROM json_each(?) AS changes
          WHERE hunt_id = ? AND job_key = changes.key`).bind(at, encodedResults, id),
      ]);
    },
    async putShot(id, jobKey, dataUrl) {
      if (!(await find(id)) || !(await readJobs(db, id)).some(job => job.job_key === jobKey)) return;
      const bytes = Uint8Array.from(atob(dataUrl.slice(dataUrl.indexOf(',') + 1)), char => char.charCodeAt(0));
      await kv.put(huntKey(id, `shot:${jobKey}`), bytes, { expirationTtl: SHOT_TTL });
    },
    async shot(id, jobKey) {
      if (!(await find(id)) || !(await readJobs(db, id)).some(job => job.job_key === jobKey)) return null;
      return kv.get(huntKey(id, `shot:${jobKey}`), 'arrayBuffer');
    },
    async setStatus(id, status) {
      if (!(await find(id))) return;
      const at = new Date().toISOString();
      const statements = [db.prepare('UPDATE application_hunts SET status = ?, updated_at = ? WHERE id = ?').bind(status, at, id)];
      if (status === 'complete' || status === 'stopped' || status === 'errored') {
        // Queued jobs did not reach the browser. Preserve unknown in-flight attempts.
        statements.push(db.prepare(`UPDATE application_hunt_jobs SET blocked = 0, updated_at = ? WHERE hunt_id = ? AND status = 'queued' AND submission_attempted = 0`).bind(at, id));
      }
      await db.batch(statements);
    },
    async deleteHunt(id) {
      if (!(await find(id))) return;
      await removeHuntFiles(kv, id, await readJobs(db, id));
      await db.prepare('DELETE FROM application_hunts WHERE id = ?').bind(id).run();
    },
  };
}
