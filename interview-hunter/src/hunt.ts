// A hunt applies to a list of jobs one by one in the background. This module
// holds its storage layout and loop; hunt-workflow.ts runs it on Cloudflare.
import type { Facts, Missing } from './answers.ts';
import type { ApplyResult } from './apply.ts';
import type { Job } from './jobs.ts';
import type { Profile } from './profile.ts';

export const MAX_HUNT_JOBS = 400;
const DAY = 86_400;
const INPUT_TTL = 7 * DAY; // Backstop only: the resume is deleted when the hunt ends.
const RECORD_TTL = 30 * DAY;

export interface HuntInput {
  profile: Profile;
  facts: Facts;
  resume: { name: string; base64: string };
  submit: boolean;
  jobs: Job[];
}

export interface HuntMeta { id: string; createdAt: string; submit: boolean; jobs: Job[] }

export interface JobResult {
  status: ApplyResult['status'] | 'working';
  message: string;
  missing: Missing[];
  hasShot: boolean;
  at: string;
}

export type Results = Record<string, JobResult>;

export interface HuntStore {
  create(id: string, input: HuntInput, createdAt: string): Promise<void>;
  input(id: string): Promise<HuntInput | null>;
  deleteInput(id: string): Promise<void>;
  meta(id: string): Promise<HuntMeta | null>;
  results(id: string): Promise<Results>;
  putResults(id: string, results: Results): Promise<void>;
  putShot(id: string, jobKey: string, dataUrl: string): Promise<void>;
  shot(id: string, jobKey: string): Promise<ArrayBuffer | null>;
}

export function kvStore(kv: KVNamespace): HuntStore {
  const key = (id: string, part?: string) => (part ? `hunt:${id}:${part}` : `hunt:${id}`);
  return {
    async create(id, input, createdAt) {
      const meta: HuntMeta = { id, createdAt, submit: input.submit, jobs: input.jobs };
      await kv.put(key(id, 'input'), JSON.stringify(input), { expirationTtl: INPUT_TTL });
      await kv.put(key(id), JSON.stringify(meta), { expirationTtl: RECORD_TTL });
    },
    input: id => kv.get<HuntInput>(key(id, 'input'), 'json'),
    deleteInput: id => kv.delete(key(id, 'input')),
    meta: id => kv.get<HuntMeta>(key(id), 'json'),
    results: async id => (await kv.get<Results>(key(id, 'results'), 'json')) ?? {},
    putResults: (id, results) => kv.put(key(id, 'results'), JSON.stringify(results), { expirationTtl: RECORD_TTL }),
    async putShot(id, jobKey, dataUrl) {
      const bytes = Uint8Array.from(atob(dataUrl.slice(dataUrl.indexOf(',') + 1)), c => c.charCodeAt(0));
      await kv.put(key(id, `shot:${jobKey}`), bytes, { expirationTtl: RECORD_TTL });
    },
    shot: (id, jobKey) => kv.get(key(id, `shot:${jobKey}`), 'arrayBuffer'),
  };
}

/** The part of the Workflows step API the hunt uses. */
export interface Steps {
  do<T>(name: string, config: StepConfig, callback: () => Promise<T>): Promise<T>;
}
export interface StepConfig { retries: { limit: number; delay: number }; timeout?: string }

// Never retry: a retried step could submit the same application twice.
export const NO_RETRY: StepConfig = { retries: { limit: 0, delay: 0 } };
const APPLY_STEP: StepConfig = { ...NO_RETRY, timeout: '10 minutes' };

export interface HuntDeps {
  store: HuntStore;
  applyOne(input: HuntInput, job: Job): Promise<ApplyResult>;
  now?: () => Date;
}

/**
 * Applies to each job in order. Results live in the workflow's step outputs, so
 * every KV write is a full overwrite and nothing depends on reading KV back.
 */
export async function runHunt(huntId: string, step: Steps, deps: HuntDeps): Promise<{ done: number; stopped: boolean }> {
  const now = () => (deps.now?.() ?? new Date()).toISOString();
  const keys = await step.do('load', NO_RETRY, async () => (await deps.store.input(huntId))?.jobs.map(j => j.key) ?? []);
  const results: Results = {};
  let stopped = false;

  for (const key of keys) {
    let result: JobResult | null;
    try {
      result = await step.do(`apply ${key}`, APPLY_STEP, async () => {
        const input = await deps.store.input(huntId);
        const job = input?.jobs.find(j => j.key === key);
        if (!input || !job) return null;
        await deps.store.putResults(huntId, { ...results, [key]: { status: 'working', message: '', missing: [], hasShot: false, at: now() } });
        const applied = await deps.applyOne(input, job);
        if (applied.screenshot) await deps.store.putShot(huntId, key, applied.screenshot);
        const done: JobResult = { status: applied.status, message: applied.message, missing: applied.missing, hasShot: !!applied.screenshot, at: now() };
        await deps.store.putResults(huntId, { ...results, [key]: done });
        return done;
      });
    } catch {
      result = { status: 'failed', message: 'The agent was interrupted. Check the form before trying again.', missing: [], hasShot: false, at: now() };
      const snapshot = { ...results, [key]: result };
      await step.do(`record ${key}`, NO_RETRY, async () => { await deps.store.putResults(huntId, snapshot); return true; });
    }
    if (!result) {
      stopped = true;
      break;
    }
    results[key] = result;
  }

  await step.do('cleanup', NO_RETRY, async () => { await deps.store.deleteInput(huntId); return true; });
  return { done: Object.keys(results).length, stopped };
}
