import test from 'node:test';
import assert from 'node:assert/strict';
import { createProxy, publicCookie, publicLocation } from './index.mjs';

test('fixed host and origin cannot be overridden by path, query or headers', async () => {
  let observed;
  const proxy = createProxy(async request => { observed = request; return new Response('ok'); });
  await proxy.fetch(new Request('https://leoinvesting.com//evil.example/a?url=https://evil.example/', {
    headers: { 'x-forwarded-host': 'evil.example', 'cf-access-client-secret': 'test-access' },
  }));
  assert.equal(new URL(observed.url).origin, 'https://leo.axio7.workers.dev');
  assert.equal(new URL(observed.url).pathname, '//evil.example/a');
  assert.equal(observed.headers.get('x-forwarded-host'), 'leoinvesting.com');
  assert.equal(observed.headers.get('cf-access-client-secret'), null);
  observed = undefined;
  assert.equal((await proxy.fetch(new Request('https://leoinvesting.com.evil.example/'))).status, 421);
  assert.equal(observed, undefined);
});

test('application methods, body, origin and authorization reach only the fixed upstream', async () => {
  const proxy = createProxy(async request => {
    assert.equal(request.method, 'POST');
    assert.equal(await request.text(), '{"sample":true}');
    assert.equal(request.headers.get('authorization'), 'Bearer test-only');
    assert.equal(request.headers.get('cookie'), 'session=test-only');
    assert.equal(request.headers.get('origin'), 'https://leoinvesting.com');
    assert.equal(request.redirect, 'manual');
    return new Response(null, { status: 204 });
  });
  assert.equal((await proxy.fetch(new Request('https://leoinvesting.com/api/example', {
    method: 'POST', body: '{"sample":true}', headers: {
      authorization: 'Bearer test-only', cookie: 'session=test-only', origin: 'https://leoinvesting.com',
    },
  }))).status, 204);
});

test('redirects are returned without fetching another host or replaying a request', async () => {
  let calls = 0;
  const proxy = createProxy(async request => { calls++; assert.equal(request.redirect, 'manual');
    return new Response(null, { status: 307, headers: { location: 'https://external.example/signin' } }); });
  const result = await proxy.fetch(new Request('https://leoinvesting.com/auth'));
  assert.equal(result.status, 307);
  assert.equal(result.headers.get('location'), 'https://external.example/signin');
  assert.equal(calls, 1);
  assert.equal(publicLocation('https://leo.axio7.workers.dev/original/?a=1#b'), 'https://leoinvesting.com/original/?a=1#b');
  assert.equal(publicLocation('/original/'), 'https://leoinvesting.com/original/');
  assert.equal(publicLocation('https://leo.axio7.workers.dev.evil.example/'), 'https://leo.axio7.workers.dev.evil.example/');
});

test('cookies retain separate headers and only exact upstream Domain is removed', async () => {
  const headers = new Headers();
  headers.append('set-cookie', 'a=1; Domain=.leo.axio7.workers.dev; Path=/; Secure; HttpOnly');
  headers.append('set-cookie', 'b=2; Expires=Wed, 21 Oct 2030 07:28:00 GMT; Path=/; SameSite=Lax');
  const proxy = createProxy(async () => new Response('ok', { headers }));
  const response = await proxy.fetch(new Request('https://leoinvesting.com/'));
  assert.deepEqual(response.headers.getSetCookie(), [
    'a=1; Path=/; Secure; HttpOnly',
    'b=2; Expires=Wed, 21 Oct 2030 07:28:00 GMT; Path=/; SameSite=Lax',
  ]);
  assert.equal(publicCookie('a=1; Domain=leo.axio7.workers.dev.evil.example'), 'a=1; Domain=leo.axio7.workers.dev.evil.example');
});

test('status, byte stream, cache policy, range and CORS are preserved', async () => {
  const bytes = new Uint8Array([0, 1, 2, 255]);
  const proxy = createProxy(async () => new Response(bytes, { status: 206, headers: {
    'cache-control': 'private, no-store', 'content-range': 'bytes 0-3/10',
    'access-control-allow-origin': 'https://allowed.example', 'content-type': 'application/octet-stream',
  } }));
  const result = await proxy.fetch(new Request('https://leoinvesting.com/model.wasm'));
  assert.equal(result.status, 206);
  assert.deepEqual(new Uint8Array(await result.arrayBuffer()), bytes);
  assert.equal(result.headers.get('cache-control'), 'private, no-store');
  assert.equal(result.headers.get('content-range'), 'bytes 0-3/10');
  assert.equal(result.headers.get('access-control-allow-origin'), 'https://allowed.example');
});

test('auth callback query stays in browser and HEAD has no response body', async () => {
  const proxy = createProxy(async request => {
    assert.equal(request.url, 'https://leo.axio7.workers.dev/strategy-auth/callback');
    return new Response('shell', { headers: { 'cache-control': 'no-store' } });
  });
  const result = await proxy.fetch(new Request('https://leoinvesting.com/strategy-auth/callback?code=test-only', { method: 'HEAD' }));
  assert.equal(result.body, null);
  assert.equal(result.headers.get('cache-control'), 'no-store');
});

test('upstream failures expose no exception, URL, query, cookie or body', async () => {
  const proxy = createProxy(async () => { throw new Error('test-secret-value'); });
  const result = await proxy.fetch(new Request('https://leoinvesting.com/?code=test-secret-value'));
  assert.equal(result.status, 502);
  assert.equal(result.headers.get('cache-control'), 'no-store');
  assert.equal((await result.text()).includes('test-secret-value'), false);
});
