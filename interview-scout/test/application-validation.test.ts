import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ApplicationRequestSchema, HuntRequestSchema, JobSchema, readJson, RequestBodyError, ResumeBase64Schema, workspaceHash } from '../src/applications/validation.ts';

const profile = { fullName: 'Taylor Example', firstName: 'Taylor', lastName: 'Example', email: 'taylor@example.com', phone: '', location: '', linkedin: '', website: '', github: '', currentTitle: '', currentCompany: '', education: '', skills: [], summary: '', targetTitles: [] };
const job = { key: 'forged-key', ats: 'ashby', company: 'acme', title: 'Software Engineer', location: 'Remote', remote: true, postedAt: '', url: 'https://jobs.lever.co/acme/abc-123', applyUrl: 'https://jobs.lever.co/acme/abc-123/apply?source=anything' };
const resume = { name: 'example.pdf', base64: Buffer.from('%PDF-1.4\n% fictional test\n').toString('base64') };
const facts = { workAuthorizedUS: '', needsSponsorship: '', notes: '' };

test('canonical employer job identity cannot be changed to evade duplicate protection', () => {
  const parsed = JobSchema.parse(job);
  assert.equal(parsed.key, 'lever:acme:abc-123');
  assert.equal(parsed.ats, 'lever');
  assert.equal(parsed.applyUrl, 'https://jobs.lever.co/acme/abc-123/apply');
  assert.equal(JobSchema.parse({ ...job, legacyStatus: 'needs_review' }).legacyStatus, 'needs_review');
  assert.equal(JobSchema.safeParse({ ...job, applyUrl: 'https://example.com/collect' }).success, false);
});

test('draft intake can save a PDF without AI, but hunts require identity and explicit consent', () => {
  assert.equal(ApplicationRequestSchema.safeParse({ profile: null, facts, preferences: { titles: ['quantitative researcher'], locations: ['Remote'], exclude: [], companies: [] }, jobs: [], resume }).success, true);
  const hunt = { profile, facts, jobs: [job], resume, submit: false };
  assert.equal(HuntRequestSchema.safeParse(hunt).success, false);
  assert.equal(HuntRequestSchema.safeParse({ ...hunt, consent: true }).success, true);
  assert.equal(HuntRequestSchema.safeParse({ ...hunt, consent: true, profile: { ...profile, email: '' } }).success, false);
  assert.equal(ResumeBase64Schema.safeParse('JVBER malformed').success, false);
  assert.equal(ResumeBase64Schema.safeParse(Buffer.from('not a PDF').toString('base64')).success, false);
});

test('workspace credentials must be strong and are hashed before storage', async () => {
  assert.equal(await workspaceHash(new Request('https://example.com')), null);
  assert.equal(await workspaceHash(new Request('https://example.com', { headers: { 'x-workspace-key': 'taylor@example.com' } })), null);
  const key = 'a'.repeat(64);
  const hash = await workspaceHash(new Request('https://example.com', { headers: { 'x-workspace-key': key } }));
  assert.match(hash!, /^[a-f0-9]{64}$/);
  assert.notEqual(hash, key);
});

test('request parsing rejects oversized and non-JSON inputs', async () => {
  await assert.rejects(readJson(new Request('https://example.com', { method: 'POST', body: 'x', headers: { 'content-type': 'application/json', 'content-length': '8000001' } })), (error: unknown) => error instanceof RequestBodyError && error.status === 413);
  await assert.rejects(readJson(new Request('https://example.com', { method: 'POST', body: 'x' })), (error: unknown) => error instanceof RequestBodyError && error.status === 415);
  assert.deepEqual(await readJson(new Request('https://example.com', { method: 'POST', body: '{"saved":true}', headers: { 'content-type': 'application/json' } })), { saved: true });
});
