import assert from 'node:assert/strict';
import { test } from 'node:test';
import { jobFromLink, matchJobs, normalizeBoard, parseCompany, type Job } from '../src/jobs.ts';

test('normalizes Greenhouse, Lever and Ashby board payloads', () => {
  const [gh] = normalizeBoard({ ats: 'greenhouse', slug: 'acme' }, {
    jobs: [{ id: 123, title: 'Data Analyst', location: { name: 'New York, NY' }, absolute_url: 'https://acme.com/jobs?gh_jid=123', updated_at: '2026-10-01T00:00:00Z', company_name: 'Acme' }],
  });
  assert.equal(gh.key, 'greenhouse:acme:123');
  assert.equal(gh.company, 'Acme');
  assert.equal(gh.applyUrl, 'https://job-boards.greenhouse.io/embed/job_app?for=acme&token=123');

  const [lever] = normalizeBoard({ ats: 'lever', slug: 'acme' }, [
    { id: 'abc-1', text: 'Business Analyst', categories: { location: 'Austin' }, workplaceType: 'remote', hostedUrl: 'https://jobs.lever.co/acme/abc-1', applyUrl: 'https://jobs.lever.co/acme/abc-1/apply', createdAt: Date.UTC(2026, 8, 1) },
  ]);
  assert.equal(lever.remote, true);
  assert.equal(lever.postedAt, '2026-09-01T00:00:00.000Z');
  assert.equal(lever.applyUrl, 'https://jobs.lever.co/acme/abc-1/apply');

  const ashby = normalizeBoard({ ats: 'ashby', slug: 'acme' }, {
    jobs: [
      { id: 'u1', title: 'Analyst', location: 'Remote', isRemote: true, publishedAt: '2026-09-02', jobUrl: 'https://jobs.ashbyhq.com/acme/u1', applyUrl: 'https://jobs.ashbyhq.com/acme/u1/application' },
      { id: 'u2', title: 'Hidden', isListed: false },
    ],
  });
  assert.deepEqual(ashby.map(j => j.key), ['ashby:acme:u1']);
});

test('unexpected payloads produce no jobs instead of throwing', () => {
  assert.deepEqual(normalizeBoard({ ats: 'greenhouse', slug: 'x' }, { error: 'not found' }), []);
  assert.deepEqual(normalizeBoard({ ats: 'lever', slug: 'x' }, null), []);
  assert.deepEqual(normalizeBoard({ ats: 'ashby', slug: 'x' }, { jobs: [{ title: 'No id' }] }), []);
});

const job = (title: string, location: string, postedAt: string, remote = false): Job => ({
  key: title + location, ats: 'lever', company: 'acme', title, location, remote, postedAt, url: '', applyUrl: '',
});

test('matches every word of a target title, honours exclusions and locations, newest first', () => {
  const jobs = [
    job('Analyst, Data', 'New York, NY', '2026-09-01'),
    job('Senior Data Analyst', 'New York, NY', '2026-09-03'),
    job('Data Analyst', 'Anywhere', '2026-09-02', true),
    job('Data Engineer', 'New York, NY', '2026-09-04'),
    job('Data Analyst', 'Newark, NJ', '2026-09-05'),
  ];
  const matched = matchJobs(jobs, { titles: ['data analyst'], locations: ['New York', 'Remote'], exclude: ['senior'] });
  assert.deepEqual(matched.map(j => `${j.title}@${j.location}`), ['Data Analyst@Anywhere', 'Analyst, Data@New York, NY']);
  assert.equal(matchJobs(jobs, { titles: [], locations: [], exclude: [] }).length, jobs.length);
});

test('parses pasted job links and rejects other sites', () => {
  assert.equal(jobFromLink('https://job-boards.greenhouse.io/acme/jobs/4567')?.applyUrl,
    'https://job-boards.greenhouse.io/embed/job_app?for=acme&token=4567');
  assert.equal(jobFromLink('https://boards.greenhouse.io/embed/job_app?for=acme&token=99')?.key, 'greenhouse:acme:99');
  assert.equal(jobFromLink('https://jobs.lever.co/acme/5f1e-22aa/apply')?.applyUrl, 'https://jobs.lever.co/acme/5f1e-22aa/apply');
  assert.equal(jobFromLink('https://jobs.ashbyhq.com/acme/0b9c-11')?.applyUrl, 'https://jobs.ashbyhq.com/acme/0b9c-11/application');
  assert.equal(jobFromLink('https://www.linkedin.com/jobs/view/123'), null);
  assert.equal(jobFromLink('http://jobs.lever.co/acme/1'), null);
  assert.equal(jobFromLink('https://job-boards.greenhouse.io/acme'), null);
});

test('parses company entries', () => {
  assert.deepEqual(parseCompany(' lever:acme '), { ats: 'lever', slug: 'acme' });
  assert.equal(parseCompany('workday:acme'), null);
  assert.equal(parseCompany('greenhouse:../etc'), null);
});
