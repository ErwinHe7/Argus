import { z } from 'zod';
import { DEFAULT_COMPANIES } from './companies.ts';
import { kvStore, MAX_HUNT_JOBS } from './hunt.ts';
import { fetchJobs, jobFromLink, matchJobs, MAX_COMPANIES, parseCompany, type Company } from './jobs.ts';
import { extractProfile, ProfileSchema } from './profile.ts';

export { HuntWorkflow } from './hunt-workflow.ts';

const MAX_RESUME_BASE64 = 7_000_000; // About 5 MB of PDF.
const APPLY_HOSTS = new Set(['job-boards.greenhouse.io', 'boards.greenhouse.io', 'jobs.lever.co', 'jobs.eu.lever.co', 'jobs.ashbyhq.com']);
const HUNT_PATH = /^\/api\/hunts\/([0-9a-f-]{36})(?:\/(stop|shots\/([^/]{1,300})))?$/;

const shortText = z.string().max(200);
const Resume = z.string().max(MAX_RESUME_BASE64).refine(s => s.startsWith('JVBER'), 'Resume must be a PDF.');

const JobsRequest = z.object({
  titles: z.array(shortText).max(20),
  locations: z.array(shortText).max(20),
  exclude: z.array(shortText).max(50),
  companies: z.array(shortText).max(MAX_COMPANIES).optional(),
});

const Job = z.object({
  key: shortText, ats: z.enum(['greenhouse', 'lever', 'ashby']), company: shortText, title: z.string().max(300),
  location: z.string().max(300), remote: z.boolean(), postedAt: shortText, url: z.string().max(1000),
  applyUrl: z.string().max(1000).refine(u => {
    try {
      const url = new URL(u);
      return url.protocol === 'https:' && APPLY_HOSTS.has(url.hostname);
    } catch {
      return false;
    }
  }, 'Only Greenhouse, Lever and Ashby application pages are supported.'),
});

const HuntRequest = z.object({
  jobs: z.array(Job).min(1, 'Pick at least one job.').max(MAX_HUNT_JOBS, `A hunt can hold up to ${MAX_HUNT_JOBS} jobs.`),
  profile: ProfileSchema,
  facts: z.object({ workAuthorizedUS: shortText, needsSponsorship: shortText, notes: z.string().max(5000) }),
  resume: z.object({ name: shortText, base64: Resume }),
  submit: z.boolean(),
});

const json = (body: unknown, status = 200) => Response.json(body, { status });

async function digest(text: string): Promise<ArrayBuffer> {
  return crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
}

/** Fails closed: without a configured access code nothing is served. */
async function authorized(request: Request, env: Env): Promise<boolean> {
  if (!env.ACCESS_CODE || !env.GEMINI_API_KEY) return false;
  const given = request.headers.get('x-access-code') ?? '';
  return crypto.subtle.timingSafeEqual(await digest(given), await digest(env.ACCESS_CODE));
}

async function huntStatus(env: Env, id: string): Promise<string> {
  try {
    return (await (await env.HUNT.get(id)).status()).status;
  } catch {
    return 'unknown';
  }
}

async function routeHunt(request: Request, env: Env, path: string): Promise<Response | null> {
  const store = kvStore(env.HUNTS);
  if (path === '/api/hunts' && request.method === 'POST') {
    const parsed = HuntRequest.safeParse(await request.json().catch(() => null));
    if (!parsed.success) return json({ error: parsed.error.issues[0]?.message ?? 'Invalid hunt.' }, 400);
    const jobs = [...new Map(parsed.data.jobs.map(j => [j.key, j])).values()];
    const id = crypto.randomUUID();
    await store.create(id, { ...parsed.data, jobs }, new Date().toISOString());
    try {
      await env.HUNT.create({ id, params: { huntId: id } });
    } catch (error) {
      await store.deleteInput(id); // Don't keep the resume for a hunt that never started.
      throw error;
    }
    return json({ id });
  }
  const match = HUNT_PATH.exec(path);
  if (!match) return null;
  const [, id, action, shotKey] = match;
  if (!action && request.method === 'GET') {
    const meta = await store.meta(id);
    if (!meta) return json({ error: 'Hunt not found. Hunts are kept for 30 days.' }, 404);
    return json({ ...meta, results: await store.results(id), status: await huntStatus(env, id) });
  }
  if (action === 'stop' && request.method === 'POST') {
    try {
      await (await env.HUNT.get(id)).terminate();
    } catch {
      // Already finished.
    }
    await store.deleteInput(id);
    return json({ status: await huntStatus(env, id) });
  }
  if (shotKey && request.method === 'GET') {
    const shot = await store.shot(id, decodeURIComponent(shotKey));
    return shot ? new Response(shot, { headers: { 'content-type': 'image/jpeg', 'cache-control': 'private, max-age=86400' } }) : json({ error: 'No screenshot.' }, 404);
  }
  return null;
}

async function route(request: Request, env: Env, path: string): Promise<Response> {
  if (path === '/api/companies' && request.method === 'GET') return json({ companies: DEFAULT_COMPANIES });
  if (!(await authorized(request, env))) return json({ error: 'Wrong access code, or the site is not configured yet.' }, 401);
  if (path.startsWith('/api/hunts')) return (await routeHunt(request, env, path)) ?? json({ error: 'Not found.' }, 404);
  if (request.method !== 'POST') return json({ error: 'Not found.' }, 404);
  const body: unknown = await request.json().catch(() => null);

  if (path === '/api/profile') {
    const parsed = z.object({ resume: Resume }).safeParse(body);
    if (!parsed.success) return json({ error: 'Upload a PDF resume under 5 MB.' }, 400);
    return json({ profile: await extractProfile(env, parsed.data.resume) });
  }
  if (path === '/api/jobs') {
    const parsed = JobsRequest.safeParse(body);
    if (!parsed.success) return json({ error: 'Invalid search.' }, 400);
    const entries = parsed.data.companies ?? DEFAULT_COMPANIES;
    const companies = entries.map(parseCompany).filter((c): c is Company => c !== null);
    const invalid = entries.filter(e => !parseCompany(e));
    const { jobs, skipped } = await fetchJobs(companies);
    return json({ jobs: matchJobs(jobs, parsed.data), searched: companies.length - skipped.length, skipped: [...invalid, ...skipped] });
  }
  if (path === '/api/links') {
    const parsed = z.object({ links: z.array(z.string().max(1000)).max(100) }).safeParse(body);
    if (!parsed.success) return json({ error: 'Invalid links.' }, 400);
    const links = parsed.data.links.map(l => l.trim()).filter(Boolean);
    return json({ jobs: links.map(jobFromLink).filter(j => j !== null), invalid: links.filter(l => !jobFromLink(l)) });
  }
  return json({ error: 'Not found.' }, 404);
}

export default {
  async fetch(request, env): Promise<Response> {
    const path = new URL(request.url).pathname;
    if (!path.startsWith('/api/')) return json({ error: 'Not found.' }, 404);
    try {
      return await route(request, env, path);
    } catch (error) {
      console.error('request failed', path, error instanceof Error ? error.message : error);
      return json({ error: 'Something went wrong. Try again.' }, 502);
    }
  },
} satisfies ExportedHandler<Env>;
