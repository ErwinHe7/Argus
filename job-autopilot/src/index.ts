import puppeteer from '@cloudflare/puppeteer';
import { z } from 'zod';
import { answerFields } from './answers.ts';
import { runApplication, type AgentPage, type ApplyResult } from './apply.ts';
import { DEFAULT_COMPANIES } from './companies.ts';
import { fetchJobs, jobFromLink, matchJobs, MAX_COMPANIES, parseCompany, type Company } from './jobs.ts';
import { extractProfile, ProfileSchema } from './profile.ts';

const MAX_RESUME_BASE64 = 7_000_000; // About 5 MB of PDF.
const APPLY_HOSTS = new Set(['job-boards.greenhouse.io', 'boards.greenhouse.io', 'jobs.lever.co', 'jobs.eu.lever.co', 'jobs.ashbyhq.com']);

const shortText = z.string().max(200);
const Resume = z.string().max(MAX_RESUME_BASE64).refine(s => s.startsWith('JVBER'), 'Resume must be a PDF.');

const JobsRequest = z.object({
  titles: z.array(shortText).max(20),
  locations: z.array(shortText).max(20),
  exclude: z.array(shortText).max(50),
  companies: z.array(shortText).max(MAX_COMPANIES).optional(),
});

const ApplyRequest = z.object({
  job: z.object({
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
  }),
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
  if (!env.ACCESS_CODE || !env.ANTHROPIC_API_KEY) return false;
  const given = request.headers.get('x-access-code') ?? '';
  return crypto.subtle.timingSafeEqual(await digest(given), await digest(env.ACCESS_CODE));
}

async function apply(env: Env, body: z.infer<typeof ApplyRequest>): Promise<ApplyResult> {
  const browser = await puppeteer.launch(env.BROWSER);
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1280, height: 1000 });
    return await runApplication(page as unknown as AgentPage, body, (fields, pageText) => answerFields(env, {
      resumeBase64: body.resume.base64, profile: body.profile, facts: body.facts,
      job: { company: body.job.company, title: body.job.title, url: body.job.url }, pageText, fields,
    }));
  } finally {
    await browser.close();
  }
}

async function route(request: Request, env: Env, path: string): Promise<Response> {
  if (path === '/api/companies' && request.method === 'GET') return json({ companies: DEFAULT_COMPANIES });
  if (request.method !== 'POST') return json({ error: 'Not found.' }, 404);
  if (!(await authorized(request, env))) return json({ error: 'Wrong access code, or the site is not configured yet.' }, 401);
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
  if (path === '/api/apply') {
    const parsed = ApplyRequest.safeParse(body);
    if (!parsed.success) return json({ error: parsed.error.issues[0]?.message ?? 'Invalid application request.' }, 400);
    try {
      return json(await apply(env, parsed.data));
    } catch (error) {
      const result: ApplyResult = { status: 'failed', message: error instanceof Error ? error.message : 'The agent failed.', missing: [], screenshot: null };
      return json(result);
    }
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
