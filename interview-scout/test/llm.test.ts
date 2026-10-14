import assert from 'node:assert/strict';
import { test } from 'node:test';
import { z } from 'zod';
import { ask, pdfPart, STRING, type ResponseSchema } from '../src/llm.ts';

const env = { GEMINI_API_KEY: 'fixture-key-not-a-real-credential', GEMINI_MODEL: '' };
const schema = z.object({ name: z.string() });
const responseSchema: ResponseSchema = { type: 'OBJECT', properties: { name: STRING }, required: ['name'] };
const request = { system: 'Extract only the supplied fixture name.', parts: [pdfPart('Zml4dHVyZQ==')], schema, responseSchema };
const envelope = (answer: unknown, finishReason = 'STOP') => ({ candidates: [{ finishReason, content: { parts: [{ text: JSON.stringify(answer) }] } }] });

test('uses the free-tier PDF/JSON model and returns only validated structured data', async t => {
  t.mock.method(globalThis, 'fetch', async (url: string, init: RequestInit) => {
    assert.equal(url, 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent');
    assert.equal(init.redirect, 'manual');
    assert.ok(init.signal instanceof AbortSignal);
    assert.equal(new Headers(init.headers).get('x-goog-api-key'), env.GEMINI_API_KEY);
    const body = JSON.parse(String(init.body));
    assert.deepEqual(body.contents[0].parts, [{ inlineData: { mimeType: 'application/pdf', data: 'Zml4dHVyZQ==' } }]);
    assert.deepEqual(body.generationConfig, { responseMimeType: 'application/json', responseSchema });
    return Response.json(envelope({ name: 'Fixture Candidate' }));
  });
  assert.deepEqual(await ask(env, request), { name: 'Fixture Candidate' });
});

test('rejects a valid JSON response that fails the application schema', async t => {
  t.mock.method(globalThis, 'fetch', async () => Response.json(envelope({ name: 17 })));
  await assert.rejects(ask(env, request), /did not match the expected shape/);
});

test('fails closed for provider refusals without echoing provider-authored fields', async t => {
  t.mock.method(globalThis, 'fetch', async () => Response.json({ promptFeedback: { blockReason: 'private fixture details' } }));
  await assert.rejects(ask(env, request), error => error instanceof Error && error.message === 'Gemini declined this request.');
});

test('HTTP errors and redirects never expose provider response bodies', async t => {
  for (const status of [503, 302]) {
    t.mock.method(globalThis, 'fetch', async () => new Response('private fixture details; fixture-key-not-a-real-credential', { status }));
    await assert.rejects(ask(env, request), error => error instanceof Error && error.message === `Gemini request failed (${status}).`);
  }
});

test('rejects truncated output even when its partial text happens to be valid JSON', async t => {
  t.mock.method(globalThis, 'fetch', async () => Response.json(envelope({ name: 'Fixture Candidate' }, 'MAX_TOKENS')));
  await assert.rejects(ask(env, request), /before returning a complete answer/);
});

test('rejects malformed JSON and malformed response envelopes', async t => {
  for (const body of ['private fixture data', JSON.stringify(null), JSON.stringify({ candidates: 'not an array' }), JSON.stringify({ candidates: [{ content: { parts: [{ text: '{}' }] } }] })]) {
    t.mock.method(globalThis, 'fetch', async () => new Response(body, { status: 200 }));
    await assert.rejects(ask(env, request), error => error instanceof Error && !error.message.includes('private fixture data'));
  }
  t.mock.method(globalThis, 'fetch', async () => Response.json({ candidates: [{ finishReason: 'STOP', content: { parts: [{ text: '{unfinished' }] } }] }));
  await assert.rejects(ask(env, request), /unreadable JSON/);
});

test('sanitizes network failures and bounds requests to twenty seconds', async t => {
  t.mock.method(globalThis, 'fetch', async () => { throw new Error('private fixture data; fixture-key-not-a-real-credential'); });
  await assert.rejects(ask(env, request), error => error instanceof Error && error.message === 'Gemini request could not be completed. Try again.');
  t.mock.timers.enable({ apis: ['setTimeout'] });
  t.mock.method(globalThis, 'fetch', (_url: string, init: RequestInit) => new Promise((_resolve, reject) => {
    init.signal!.addEventListener('abort', () => reject(new Error('fixture abort')), { once: true });
  }));
  const pending = assert.rejects(ask(env, request), /timed out/);
  t.mock.timers.tick(20_000);
  await pending;
});
