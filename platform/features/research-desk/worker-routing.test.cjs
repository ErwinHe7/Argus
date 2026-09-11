const assert = require('node:assert/strict');
const test = require('node:test');
const { createResearchHomeWorker } = require('./worker-routing.ts');

function fixture() {
  const calls = [];
  const context = { marker: 'original context' };
  const env = {
    RITUAL_FREE_PREVIEW: 'true',
    PUBLIC_MARKET_MAP: { marker: 'unchanged service' },
    ASSETS: { async fetch(request) {
      calls.push({ target: 'assets', request });
      return new Response(request.method === 'HEAD' ? null : '<html>Research Desk</html>', {
        headers: { 'content-type': 'text/html', etag: 'desk-release' },
      });
    } },
  };
  const original = { async fetch(request, passedEnv, passedContext) {
    calls.push({ target: 'original', request, env: passedEnv, context: passedContext });
    return new Response(request.method === 'HEAD' ? null : 'Original application', {
      status: 200, headers: { 'x-original': 'preserved' },
    });
  } };
  return { calls, env, context, worker: createResearchHomeWorker(original) };
}

test('shortlist reads use a fixed service URL with no caller credentials; writes are refused', async () => {
  const f = fixture(); const forwarded = [];
  f.env.SHORTLIST_FEED = { async fetch(request) { forwarded.push(request); return new Response('{"fixture":true}'); } };
  const path = 'https://leo.axio7.workers.dev/app/research-desk/data/shortlist-feed/current.json';
  const response = await f.worker.fetch(new Request(`${path}?secret=discard`, { headers: { cookie: 'session=private', authorization: 'Bearer private' } }), f.env, f.context);
  assert.equal(response.status, 200); assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.equal(forwarded[0].url, 'https://shortlist-feed/publication');
  assert.equal([...forwarded[0].headers].length, 0); assert.equal(f.calls.length, 0);
  const refused = await f.worker.fetch(new Request(path, { method: 'POST', body: 'unauthorized body' }), f.env, f.context);
  assert.equal(refused.status, 405); assert.equal(forwarded.length, 1);
});

test('shortlist unavailable or failed binding returns 503 without replacing the application', async () => {
  const f = fixture(); const url = 'https://leo.axio7.workers.dev/app/research-desk/data/shortlist-feed/current.json';
  assert.equal((await f.worker.fetch(new Request(url), f.env, f.context)).status, 503);
  f.env.SHORTLIST_FEED = { async fetch() { throw new Error('down'); } };
  const response = await f.worker.fetch(new Request(url, { method: 'HEAD' }), f.env, f.context);
  assert.equal(response.status, 503); assert.equal(await response.text(), ''); assert.equal(f.calls.length, 0);
});

test('radar public reads use the fixed binding with no caller credentials and forbid writes', async () => {
  const f = fixture(); const forwarded = [];
  f.env.EVENT_RADAR = { async fetch(request) { forwarded.push(request); return new Response('{"calendar":true}'); } };
  const path = 'https://leo.axio7.workers.dev/app/research-desk/data/event-radar.json';
  const result = await f.worker.fetch(new Request(`${path}?private=discard`, { headers: { authorization: 'secret', cookie: 'private' } }), f.env, f.context);
  assert.equal(result.status, 200); assert.equal(result.headers.get('cache-control'), 'no-store');
  assert.equal(forwarded[0].url, 'https://event-radar/radar'); assert.equal([...forwarded[0].headers].length, 0);
  assert.equal((await f.worker.fetch(new Request(path, { method: 'POST', body: 'never forwarded' }), f.env, f.context)).status, 405);
  const head = await f.worker.fetch(new Request(path, { method: 'HEAD' }), f.env, f.context);
  assert.equal(await head.text(), ''); assert.equal(f.calls.length, 0);
});

test('missing or failed radar binding never returns an old static asset as current', async () => {
  const f = fixture(); const path = 'https://leo.axio7.workers.dev/app/research-desk/data/event-radar.json';
  assert.equal((await f.worker.fetch(new Request(path), f.env, f.context)).status, 503);
  f.env.EVENT_RADAR = { async fetch() { throw new Error('down'); } };
  assert.equal((await f.worker.fetch(new Request(path), f.env, f.context)).status, 503);
  assert.equal(f.calls.length, 0);
});

for (const method of ['GET', 'HEAD']) {
  test(`${method} strategy callback serves the workspace without leaking the code to assets`, async () => {
    const f = fixture();
    const response = await f.worker.fetch(new Request('https://leo.axio7.workers.dev/strategy-auth/callback?code=single-use', { method }), f.env, f.context);
    assert.equal(f.calls[0].target, 'assets');
    assert.equal(f.calls[0].request.url, 'https://leo.axio7.workers.dev/app/research-desk/');
    assert.equal(response.headers.get('cache-control'), 'no-store');
    assert.equal(response.headers.get('referrer-policy'), 'no-referrer');
  });
  test(`${method} root serves the desk without a public redirect`, async () => {
    const f = fixture();
    const request = new Request('https://leo.axio7.workers.dev/?utm_source=launch', { method });
    const response = await f.worker.fetch(request, f.env, f.context);
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('location'), null);
    assert.equal(response.headers.get('etag'), 'desk-release');
    assert.equal(f.calls.length, 1);
    assert.equal(f.calls[0].target, 'assets');
    assert.equal(f.calls[0].request.url, 'https://leo.axio7.workers.dev/app/research-desk/?utm_source=launch');
    assert.equal(f.calls[0].request.method, method);
    assert.equal(await response.text(), method === 'HEAD' ? '' : '<html>Research Desk</html>');
  });

  test(`${method} original homepage retains request headers, query, env and context`, async () => {
    const f = fixture();
    const request = new Request('https://leo.axio7.workers.dev/original/?ref=kept', {
      method, headers: { cookie: 'session=fixture', accept: 'text/html' },
    });
    const response = await f.worker.fetch(request, f.env, f.context);
    assert.equal(response.headers.get('x-original'), 'preserved');
    assert.equal(f.calls.length, 1);
    assert.equal(f.calls[0].target, 'original');
    assert.equal(f.calls[0].request.url, 'https://leo.axio7.workers.dev/?ref=kept');
    assert.equal(f.calls[0].request.method, method);
    assert.equal(f.calls[0].request.headers.get('cookie'), 'session=fixture');
    assert.equal(f.calls[0].env, f.env);
    assert.equal(f.calls[0].context, f.context);
  });

  test(`${method} original canonicalization preserves its query`, async () => {
    const f = fixture();
    const response = await f.worker.fetch(new Request('https://leo.axio7.workers.dev/original?ref=kept', { method }), f.env, f.context);
    assert.equal(response.status, 308);
    assert.equal(response.headers.get('location'), 'https://leo.axio7.workers.dev/original/?ref=kept');
    assert.equal(f.calls.length, 0);
  });
}

test('all other application, asset, and billing routes delegate without cloning requests', async () => {
  for (const path of ['/app/?preview=1', '/pricing', '/api/paddle/checkout', '/api/auth/callback?code=fixture', '/originality', '/original/nested', '/app/research-desk/', '/_next/static/chunk.js']) {
    const f = fixture();
    const request = new Request(`https://leo.axio7.workers.dev${path}`);
    await f.worker.fetch(request, f.env, f.context);
    assert.equal(f.calls.length, 1);
    assert.equal(f.calls[0].target, 'original');
    assert.equal(f.calls[0].request, request);
    assert.equal(f.calls[0].env, f.env);
    assert.equal(f.calls[0].context, f.context);
  }
});

test('non-read homepage and API requests preserve their complete body and headers', async () => {
  for (const path of ['/', '/original', '/original/', '/api/paddle/webhook']) {
    const f = fixture();
    const request = new Request(`https://leo.axio7.workers.dev${path}`, {
      method: 'POST', body: 'exact-body', headers: { authorization: 'fixture', 'content-type': 'text/plain' },
    });
    await f.worker.fetch(request, f.env, f.context);
    assert.equal(f.calls[0].request, request);
    assert.equal(f.calls[0].request.headers.get('authorization'), 'fixture');
    assert.equal(await f.calls[0].request.text(), 'exact-body');
  }
});

test('missing desk assets remain an explicit missing response', async () => {
  const f = fixture();
  f.env.ASSETS.fetch = async () => new Response('Not Found', { status: 404 });
  const response = await f.worker.fetch(new Request('https://leo.axio7.workers.dev/'), f.env, f.context);
  assert.equal(response.status, 404);
  assert.equal(await response.text(), 'Not Found');
  assert.equal(f.calls.length, 0);
});

test('legacy chunk patch adds only the exact homepage aliases and rejects drift', async () => {
  const { originalCondition, patchedCondition, patchOriginalHomeLayout } = await import('./patch-original-home.mjs');
  const source = `prefix;function shell(l){${originalCondition}true:false};suffix;`;
  const patched = patchOriginalHomeLayout(source);
  assert.equal(patched.replace(patchedCondition, originalCondition), source);
  const oldBranch = new Function('l', `${originalCondition}true:false`);
  const newBranch = new Function('l', `${patchedCondition}true:false`);
  for (const path of ['/', '/research', '/acceptance/research', '/discover/market-map', '/pricing', '/app/', '/originality', '/original/nested']) {
    assert.equal(newBranch(path), oldBranch(path));
  }
  for (const path of ['/original', '/original/']) {
    assert.equal(oldBranch(path), false);
    assert.equal(newBranch(path), true);
  }
  assert.throws(() => patchOriginalHomeLayout('unrecognized chunk'));
  assert.throws(() => patchOriginalHomeLayout(source + source));
  assert.throws(() => patchOriginalHomeLayout(patched));
});

test('original HTML uses a versioned layout script while preserving the response stream', async () => {
  const priorRewriter = globalThis.HTMLRewriter;
  const observed = {};
  globalThis.HTMLRewriter = class {
    on(selector, handler) {
      observed.selector = selector;
      handler.element({ setAttribute(name, value) { observed[name] = value; } });
      return this;
    }
    transform(response) { observed.response = response; return response; }
  };
  try {
    const originalResponse = new Response('<html>Original</html>', { headers: { 'content-type':'text/html', 'x-original':'preserved' } });
    const worker = createResearchHomeWorker({ async fetch() { return originalResponse; } });
    const result = await worker.fetch(new Request('https://leo.axio7.workers.dev/original/'), {}, {});
    assert.equal(observed.selector, 'script[src="/_next/static/chunks/app/layout-17f5d2848155fa3a.js"]');
    assert.equal(observed.src, '/_next/static/chunks/app/layout-17f5d2848155fa3a.js?leo-home-alias=1');
    assert.equal(observed.response, originalResponse);
    assert.equal(result.headers.get('x-original'), 'preserved');
    assert.equal(await result.text(), '<html>Original</html>');
  } finally {
    if (priorRewriter === undefined) delete globalThis.HTMLRewriter;
    else globalThis.HTMLRewriter = priorRewriter;
  }
});
