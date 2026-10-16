// Drives a real headless Chromium through local mock application forms.
// Set CHROME_PATH to run outside the provisioned environment.
import assert from 'node:assert/strict';
import { createServer, type Server } from 'node:http';
import { readFile } from 'node:fs/promises';
import { after, before, test } from 'node:test';
import puppeteer, { type Browser } from 'puppeteer-core';
import type { Answer, FormField } from '../src/answers.ts';
import { runApplication, type AgentPage, type ApplyInput, type Answerer } from '../src/apply.ts';

const CHROME = process.env.CHROME_PATH ?? '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';
const fixtures = new URL('./fixtures/', import.meta.url);
let server: Server;
let origin: string;
let browser: Browser;
let submissions: { contentType: string; body: Buffer }[] = [];

before(async () => {
  server = createServer(async (req, res) => {
    if (req.method === 'POST' && req.url === '/submit') {
      const chunks: Buffer[] = [];
      for await (const chunk of req) chunks.push(chunk as Buffer);
      submissions.push({ contentType: req.headers['content-type'] ?? '', body: Buffer.concat(chunks) });
      res.writeHead(303, { location: '/thanks.html' }).end();
      return;
    }
    try {
      const name = new URL(req.url ?? '/', 'http://x').pathname.slice(1);
      const html = await readFile(new URL(name, fixtures));
      res.writeHead(200, { 'content-type': 'text/html' }).end(html);
    } catch {
      res.writeHead(404).end();
    }
  });
  await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  origin = `http://127.0.0.1:${typeof address === 'object' && address ? address.port : 0}`;
  browser = await puppeteer.launch({ executablePath: CHROME, headless: true, args: ['--no-sandbox'] });
});

after(async () => {
  await browser?.close();
  server?.close();
});

const PDF = Buffer.from('%PDF-1.4\n% test resume\n').toString('base64');

function input(path: string, submit: boolean): ApplyInput {
  return {
    job: { key: 'k', ats: 'lever', company: 'Acme', title: 'Data Analyst', location: '', remote: false, postedAt: '', url: '', applyUrl: origin + path },
    profile: {
      fullName: 'Jane Doe', firstName: 'Jane', lastName: 'Doe', email: 'jane@example.com', phone: '555-0100', location: 'New York, NY',
      linkedin: 'https://linkedin.com/in/jane', website: '', github: '', currentTitle: '', currentCompany: '', education: '', skills: [], summary: '', targetTitles: [],
    },
    facts: { workAuthorizedUS: 'yes', needsSponsorship: 'no', notes: '' },
    resume: { name: 'Jane Doe Resume.pdf', base64: PDF },
    submit,
  };
}

/** Stands in for Claude: answers by matching field labels. */
function answerer(rules: [RegExp, string[]][], seen: FormField[][] = []): Answerer {
  return async fields => {
    seen.push(fields);
    return fields.map((f): Answer => ({ id: f.id, values: rules.find(([re]) => re.test(f.label))?.[1] ?? [], note: '' }));
  };
}

async function run(path: string, submit: boolean, answer: Answerer, onSubmissionAttempt?: () => Promise<void>) {
  submissions = [];
  const page = await browser.newPage();
  try {
    return await runApplication(page as unknown as AgentPage, { ...input(path, submit), onSubmissionAttempt }, answer);
  } finally {
    await page.close();
  }
}

const leverRules: [RegExp, string[]][] = [
  [/full name/i, ['Jane Doe']], [/email/i, ['jane@example.com']], [/phone/i, ['555-0100']],
  [/linkedin/i, ['https://linkedin.com/in/jane']], [/authorized/i, ['Yes']], [/gender/i, ['Decline to self-identify']],
];

test('fills and submits a native Lever-style form', async () => {
  const seen: FormField[][] = [];
  const result = await run('/lever.html', true, answerer(leverRules, seen));
  assert.equal(result.status, 'submitted', result.message);

  const fields = seen[0];
  const radio = fields.find(f => f.type === 'radio');
  assert.match(radio?.label ?? '', /legally authorized/);
  assert.deepEqual(radio?.options, ['Yes', 'No']);
  assert.deepEqual(fields.find(f => f.type === 'select')?.options, ['Female', 'Male', 'Decline to self-identify']);
  assert.equal(fields.find(f => /full name/i.test(f.label))?.required, true);

  assert.equal(submissions.length, 1);
  const form = await new Response(new Uint8Array(submissions[0].body), { headers: { 'content-type': submissions[0].contentType } }).formData();
  assert.equal(form.get('name'), 'Jane Doe');
  assert.equal(form.get('email'), 'jane@example.com');
  assert.equal(form.get('cards[q][field0]'), 'Yes');
  assert.equal(form.get('eeo[gender]'), 'Decline');
  assert.equal((form.get('resume') as File).name, 'Jane Doe Resume.pdf');
});

const greenhouseRules: [RegExp, string[]][] = [
  [/first name/i, ['Jane']], [/last name/i, ['Doe']], [/email/i, ['jane@example.com']], [/sponsorship/i, ['No']],
  [/offices/i, ['New York', 'Remote']], [/privacy/i, ['Yes']], [/job alerts/i, []], [/why/i, ['I like data.']],
];

test('handles comboboxes, checkbox groups and an in-page confirmation', async () => {
  const seen: FormField[][] = [];
  const result = await run('/greenhouse.html', true, answerer(greenhouseRules, seen));
  assert.equal(result.status, 'submitted', result.message);
  assert.deepEqual(seen[0].find(f => f.type === 'combobox')?.options, ['Yes', 'No']);
  assert.equal(submissions.length, 1);
  assert.deepEqual(JSON.parse(submissions[0].body.toString()), {
    first_name: 'Jane', last_name: 'Doe', email: 'jane@example.com', phone: '', sponsorship: 'No',
    resume: `Jane Doe Resume.pdf:${Buffer.from(PDF, 'base64').length}`, offices: ['ny', 'remote'],
    privacy: true, newsletter: false, why: 'I like data.',
  });
});

test('a dry run fills the form but never submits', async () => {
  const result = await run('/greenhouse.html', false, answerer(greenhouseRules));
  assert.equal(result.status, 'dry_run');
  assert.match(result.screenshot ?? '', /^data:image\/jpeg;base64,/);
  assert.equal(submissions.length, 0);
});

test('an unresolved combobox never implicitly submits a native form during a dry run', { timeout: 20_000 }, async () => {
  const result = await run('/combobox-native.html', false, answerer([
    [/full name/i, ['Jane Doe']], [/location/i, ['New York']],
  ]));
  assert.equal(submissions.length, 0, 'Enter in a native combobox must not trigger form submission');
  assert.equal(result.status, 'needs_you');
  assert.match(result.missing[0]?.label ?? '', /location/i);
});

test('stops before submitting when a required answer is unknown', async () => {
  const result = await run('/lever.html', true, answerer(leverRules.filter(([re]) => !re.test('authorized'))));
  assert.equal(result.status, 'needs_you');
  assert.match(result.missing[0]?.label ?? '', /legally authorized/);
  assert.equal(submissions.length, 0);
});

test('hands visible CAPTCHAs back to the person', async () => {
  const result = await run('/captcha.html', true, answerer([[/name/i, ['Jane Doe']]]));
  assert.equal(result.status, 'needs_you');
  assert.match(result.message, /CAPTCHA/);
  assert.equal(submissions.length, 0);
});

test('records submission intent before the irreversible click, and never records it in a dry run', async () => {
  let attempts = 0;
  const record = async () => { assert.equal(submissions.length, 0); attempts++; };
  const dry = await run('/lever.html', false, answerer(leverRules), record);
  assert.equal(dry.status, 'dry_run');
  assert.equal(attempts, 0);
  const submitted = await run('/lever.html', true, answerer(leverRules), record);
  assert.equal(attempts, 1);
  assert.equal(submitted.submissionAttempted, true);
  assert.equal(submissions.length, 1);
});
