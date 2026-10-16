import { z } from 'zod';
import { MAX_HUNT_JOBS } from '../hunt.ts';
import { jobFromLink, MAX_COMPANIES } from '../jobs.ts';
import { ProfileSchema } from '../profile.ts';

const shortText = z.string().max(200);
export const ResumeBase64Schema = z.string().max(6_666_668)
  .regex(/^[A-Za-z0-9+/]+={0,2}$/, 'Upload a valid PDF.')
  .refine(value => value.length % 4 === 0 && value.startsWith('JVBERi0'), 'Resume must be a PDF.')
  .refine(value => value.length * 3 / 4 - (value.endsWith('==') ? 2 : value.endsWith('=') ? 1 : 0) <= 5_000_000, 'Upload a PDF under 5 MB.');
export const ResumeSchema = z.object({ name: shortText.min(1), base64: ResumeBase64Schema });
export const FactsSchema = z.object({ workAuthorizedUS: shortText, needsSponsorship: shortText, notes: z.string().max(5000) });
export const PreferencesSchema = z.object({
  titles: z.array(shortText).max(20), locations: z.array(shortText).max(20),
  exclude: z.array(shortText).max(50), companies: z.array(shortText).max(MAX_COMPANIES),
});
export const EMPTY_PREFERENCES = { titles: [], locations: [], exclude: [], companies: [] };

export const JobSchema = z.object({
  key: shortText, ats: z.enum(['greenhouse', 'lever', 'ashby']), company: shortText,
  title: z.string().max(300), location: z.string().max(300), remote: z.boolean(), postedAt: shortText,
  url: z.string().max(1000).refine(value => !value || /^https:\/\//i.test(value), 'Job links must use HTTPS.'),
  applyUrl: z.string().max(1000).refine(value => !!jobFromLink(value), 'Only Greenhouse, Lever and Ashby job application links are supported.'),
  unselected: z.boolean().optional(),
  legacyStatus: z.enum(['submitted', 'needs_review']).optional(),
}).transform(job => {
  const canonical = jobFromLink(job.applyUrl)!;
  return { ...job, key: canonical.key, ats: canonical.ats, applyUrl: canonical.applyUrl };
});

export const ApplicationRequestSchema = z.object({
  profile: ProfileSchema.nullable(), facts: FactsSchema, preferences: PreferencesSchema,
  jobs: z.array(JobSchema).max(1000), resume: ResumeSchema.nullable().optional(),
}).refine(value => JSON.stringify({ ...value, resume: undefined }).length <= 1_500_000, 'The saved job list is too large. Keep fewer jobs.');

export const HuntRequestSchema = z.object({
  jobs: z.array(JobSchema).min(1, 'Pick at least one job.').max(MAX_HUNT_JOBS, `A hunt can hold up to ${MAX_HUNT_JOBS} jobs.`),
  profile: ProfileSchema.extend({ fullName: shortText.trim().min(1, 'Enter your full name.'), email: z.email().max(254) }),
  facts: FactsSchema, resume: ResumeSchema, submit: z.boolean(), consent: z.literal(true, 'Authorize the selected applications first.'),
});

export async function workspaceHash(request: Request): Promise<string | null> {
  const key = request.headers.get('x-workspace-key') ?? '';
  if (!/^[a-f0-9]{64}$/.test(key)) return null;
  const bytes = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(key)));
  return Array.from(bytes, byte => byte.toString(16).padStart(2, '0')).join('');
}

export class RequestBodyError extends Error {
  readonly status: number;
  constructor(message: string, status: number) { super(message); this.name = 'RequestBodyError'; this.status = status; }
}

export async function readJson(request: Request): Promise<unknown> {
  const limit = 8_000_000;
  if (!request.headers.get('content-type')?.toLowerCase().includes('application/json')) throw new RequestBodyError('Send application data as JSON.', 415);
  if (Number(request.headers.get('content-length') ?? '0') > limit) throw new RequestBodyError('Upload a PDF under 5 MB.', 413);
  const reader = request.body?.getReader();
  if (!reader) return null;
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > limit) { await reader.cancel(); throw new RequestBodyError('Upload a PDF under 5 MB.', 413); }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let position = 0;
  for (const chunk of chunks) { bytes.set(chunk, position); position += chunk.byteLength; }
  try { return JSON.parse(new TextDecoder().decode(bytes)); } catch { return null; }
}
