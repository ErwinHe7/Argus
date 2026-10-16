import { z } from 'zod';
import { DEFAULT_COMPANIES } from './companies.ts';
import { applicationStore, databaseHuntStore, DuplicateApplicationError } from './applications/store.ts';
import { ApplicationRequestSchema, EMPTY_PREFERENCES, HuntRequestSchema, PreferencesSchema, readJson, RequestBodyError, ResumeBase64Schema, workspaceHash } from './applications/validation.ts';
import { fetchJobs, jobFromLink, matchJobs, MAX_COMPANIES, parseCompany, type Company } from './jobs.ts';
import { extractProfile } from './profile.ts';

export { HuntWorkflow } from './hunt-workflow.ts';

const HUNT_PATH = /^\/api\/hunts\/([0-9a-f-]{36})(?:\/(stop|shots\/([^/]{1,300})))?$/;
const json = (body: unknown, status = 200) => Response.json(body, { status, headers: { 'cache-control': 'no-store' } });

async function authorized(request: Request, env: Env): Promise<boolean> {
  if (!env.ACCESS_CODE) return false;
  const digest = (value: string) => crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return crypto.subtle.timingSafeEqual(await digest(request.headers.get('x-access-code') ?? ''), await digest(env.ACCESS_CODE));
}

async function workflowStatus(env: Env, id: string): Promise<string | null> {
  try { return (await (await env.HUNT.get(id)).status()).status; } catch { return null; }
}

async function routeHunt(request: Request, env: Env, path: string, owner: string): Promise<Response> {
  const vault = applicationStore(env.DB, env.HUNTS, owner);
  const store = databaseHuntStore(env.DB, env.HUNTS, owner);
  if (path === '/api/hunts' && request.method === 'GET') return json({ hunts: await vault.listHunts() });
  if (path === '/api/hunts' && request.method === 'POST') {
    const parsed = HuntRequestSchema.safeParse(await readJson(request));
    if (!parsed.success) return json({ error: parsed.error.issues[0]?.message ?? 'Invalid hunt.' }, 400);
    if (!env.GEMINI_API_KEY) return json({ error: 'Application preparation is not configured yet. Your saved application is still available.' }, 503);
    const jobs = [...new Map(parsed.data.jobs.map(job => [job.key, job])).values()];
    const saved = await vault.get();
    const priorAttempts = new Set((saved?.jobs ?? []).filter(job => 'legacyStatus' in job && job.legacyStatus).map(job => job.key));
    if (jobs.some(job => job.legacyStatus || priorAttempts.has(job.key))) {
      return json({ error: 'These jobs have an earlier application attempt. Check the employer form and your email before applying again.' }, 409);
    }
    const id = crypto.randomUUID();
    const authorizedAt = new Date().toISOString();
    await vault.save({ profile: parsed.data.profile, facts: parsed.data.facts, resume: parsed.data.resume,
      preferences: saved?.preferences ?? EMPTY_PREFERENCES,
      jobs: [...new Map([...(saved?.jobs ?? []), ...jobs].map(job => [job.key, job])).values()],
    });
    await store.create(id, { ...parsed.data, jobs, authorizedAt }, authorizedAt);
    try { await env.HUNT.create({ id, params: { huntId: id } }); } catch {
      // A failed response does not prove that the queue rejected the request.
      // Keep this ID and its reservations so retrying cannot submit twice.
      if (await workflowStatus(env, id)) return json({ id });
      return json({ id, error: 'Queue startup could not be confirmed. Your application was saved; open your saved history before retrying.' }, 503);
    }
    return json({ id });
  }
  const match = HUNT_PATH.exec(path);
  if (!match) return json({ error: 'Not found.' }, 404);
  const [, id, action, shotKey] = match;
  if (!(await vault.ownsHunt(id))) return json({ error: 'Hunt not found in this private workspace.' }, 404);
  if (!action && request.method === 'GET') {
    const meta = await store.meta(id);
    const live = await workflowStatus(env, id);
    return json({ ...meta, results: await store.results(id), status: live ?? await store.status(id) ?? 'unknown' });
  }
  if (action === 'stop' && request.method === 'POST') {
    const live = await workflowStatus(env, id);
    const stored = await store.status(id);
    if (live ? !['complete', 'errored', 'terminated'].includes(live) : stored === 'queued' || stored === 'running') {
      try { await (await env.HUNT.get(id)).terminate(); } catch {
        return json({ error: 'The background task could not be stopped. Try again.' }, 503);
      }
    }
    await store.deleteInput(id);
    await store.setStatus(id, 'stopped');
    return json({ status: 'stopped' });
  }
  if (shotKey && request.method === 'GET') {
    const shot = await store.shot(id, decodeURIComponent(shotKey));
    return shot ? new Response(shot, { headers: { 'content-type': 'image/jpeg', 'cache-control': 'no-store' } }) : json({ error: 'No screenshot, or its 30-day retention has ended.' }, 404);
  }
  return json({ error: 'Not found.' }, 404);
}

async function route(request: Request, env: Env, path: string): Promise<Response> {
  if (path === '/api/companies' && request.method === 'GET') return json({ companies: DEFAULT_COMPANIES });
  if (!(await authorized(request, env))) return json({ error: 'Enter the correct access code to open your saved application.' }, 401);
  const origin = request.headers.get('origin');
  if (origin && origin !== new URL(request.url).origin) return json({ error: 'Use this website to manage your application.' }, 403);
  const owner = await workspaceHash(request);
  if (!owner) return json({ error: 'Open or create your private application workspace first.' }, 401);
  if (!env.DB) return json({ error: 'Saved application storage is not configured yet.' }, 503);
  if (path === '/api/application') {
    const vault = applicationStore(env.DB, env.HUNTS, owner);
    if (request.method === 'GET') return json({ application: await vault.get(), hunts: await vault.listHunts() });
    if (request.method === 'POST') {
      const parsed = ApplicationRequestSchema.safeParse(await readJson(request));
      if (!parsed.success) return json({ error: parsed.error.issues[0]?.message ?? 'Check your application details.' }, 400);
      await vault.save(parsed.data);
      return json({ saved: true, updatedAt: new Date().toISOString() });
    }
    if (request.method === 'DELETE') {
      for (const hunt of await vault.listHunts()) {
        const live = await workflowStatus(env, hunt.id);
        if (live ? !['complete', 'errored', 'terminated'].includes(live) : hunt.status === 'queued' || hunt.status === 'running') {
          try { await (await env.HUNT.get(hunt.id)).terminate(); } catch {
            return json({ error: 'A background application is still running. Stop it before deleting your data.' }, 503);
          }
        }
      }
      await vault.delete();
      return json({ deleted: true });
    }
    return json({ error: 'Not found.' }, 404);
  }
  if (path.startsWith('/api/hunts')) return routeHunt(request, env, path, owner);
  if (request.method !== 'POST') return json({ error: 'Not found.' }, 404);
  const body = await readJson(request);
  if (path === '/api/profile') {
    if (!env.GEMINI_API_KEY) return json({ error: 'Resume reading is not configured. Your PDF can still be saved and your details entered manually.' }, 503);
    const parsed = z.object({ resume: ResumeBase64Schema }).safeParse(body);
    if (!parsed.success) return json({ error: 'Upload a PDF resume under 5 MB.' }, 400);
    return json({ profile: await extractProfile(env, parsed.data.resume) });
  }
  if (path === '/api/jobs') {
    const parsed = PreferencesSchema.omit({ companies: true }).extend({ companies: z.array(z.string().max(200)).max(MAX_COMPANIES).optional() }).safeParse(body);
    if (!parsed.success) return json({ error: 'Check the job titles, locations and company list.' }, 400);
    const entries = parsed.data.companies ?? DEFAULT_COMPANIES;
    const companies = entries.map(parseCompany).filter((company): company is Company => company !== null);
    const { jobs, skipped } = await fetchJobs(companies);
    return json({ jobs: matchJobs(jobs, parsed.data), searched: companies.length - skipped.length, skipped: [...entries.filter(entry => !parseCompany(entry)), ...skipped] });
  }
  if (path === '/api/links') {
    const parsed = z.object({ links: z.array(z.string().max(1000)).max(100) }).safeParse(body);
    if (!parsed.success) return json({ error: 'Invalid links.' }, 400);
    const links = parsed.data.links.map(link => link.trim()).filter(Boolean);
    return json({ jobs: links.map(jobFromLink).filter(job => job !== null), invalid: links.filter(link => !jobFromLink(link)) });
  }
  return json({ error: 'Not found.' }, 404);
}

export default {
  async fetch(request, env): Promise<Response> {
    const path = new URL(request.url).pathname;
    if (!path.startsWith('/api/')) return json({ error: 'Not found.' }, 404);
    try { return await route(request, env, path); } catch (error) {
      if (error instanceof DuplicateApplicationError) return json({ error: error.message }, 409);
      if (error instanceof RequestBodyError) return json({ error: error.message }, error.status);
      console.error('request failed', path, error instanceof Error ? error.name : 'Error');
      return json({ error: 'Something went wrong. Your saved data has not been cleared. Try again.' }, 502);
    }
  },
} satisfies ExportedHandler<Env>;
