// Browser-boundary fixtures only. No real Google, Supabase, broker or trade calls.
const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const fs = require('node:fs/promises');
const path = require('node:path');
const { chromium } = require(process.env.LEO_PLAYWRIGHT_MODULE || 'playwright');
const { fixtureStatus } = require('../../strategy-lab/tests/fixtures.ts');

const base = (process.env.LEO_AUTH_TEST_BASE || 'http://127.0.0.1:3220').replace(/\/$/, '');
const project = 'https://katwbobjiyzipqlzarus.supabase.co';
const key = 'leo.strategy-lab.auth.v1';
const returnKey = key + '.return';
const config = { schemaVersion: 'strategy-public-config/v1', enabled: true, supabaseUrl: project,
  publishableKey: 'sb_publishable_fixture_only', apiUrl: project + '/functions/v1/strategy-api' };
const output = path.resolve(__dirname, '../../../.impeccable/review/account-auth');
const receipt = { schemaVersion: 'leo-account-browser-fixtures.v1', checkedAt: new Date().toISOString(), base,
  evidence: 'Injected authentication and owner-scoped API responses only; no real Google login, broker or trading evidence.', checks: [], errors: [] };
async function within(promise, label) {
  let timer;
  try { return await Promise.race([promise, new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('Fixture boundary timeout: ' + label)), 15000); })]); }
  finally { clearTimeout(timer); }
}
const deferred = () => { let resolve; const promise = new Promise(done => { resolve = done; }); return { promise, resolve }; };

function sessionFor(id = '10000000-0000-4000-8000-000000000001', anonymous = false) {
  const now = Math.floor(Date.now() / 1000);
  const user = { id, aud: 'authenticated', role: 'authenticated', email: id.endsWith('2') ? 'second-user@example.invalid' : 'fixture-user@example.invalid',
    email_confirmed_at: new Date().toISOString(), app_metadata: { provider: 'google', providers: ['google'] }, user_metadata: {},
    identities: [], created_at: new Date().toISOString(), is_anonymous: anonymous };
  const payload = Buffer.from(JSON.stringify({ sub: id, exp: now + 3600, role: 'authenticated' })).toString('base64url');
  return { access_token: `fixture.${payload}.signature`, refresh_token: 'fixture-refresh-only', expires_in: 3600,
    expires_at: now + 3600, token_type: 'bearer', user };
}

async function harness(browser, settings = {}) {
  const context = await browser.newContext({ viewport: { width: 1536, height: 960 }, reducedMotion: 'reduce' });
  context.setDefaultTimeout(15000);
  const page = await context.newPage();
  const state = { configFails: false, archiveRequests: 0, external: [], authRequests: [], statusRequests: [],
    storageWrites: {}, storageSeen: deferred(),
    authorizeSeen: deferred(), authorizeRelease: deferred(), exchangeSeen: deferred(), exchangeRelease: deferred(),
    exchangeHeld: Boolean(settings.exchangeHeld), exchangeRejected: Boolean(settings.exchangeRejected),
    statusASeen: deferred(), statusARelease: deferred(), statusBSeen: deferred(), statusBRelease: deferred(),
    holdA: false, holdB: false, session: sessionFor(), ...settings };
  page.on('pageerror', error => receipt.errors.push(error.message));
  await context.exposeBinding('__leoFixtureStorageWrite', (_source, item) => {
    state.storageWrites[item.key] = item.value;
    if (state.storageWrites[returnKey] && state.storageWrites[key + '-code-verifier']) state.storageSeen.resolve();
  });
  await context.addInitScript(({ key, returnKey }) => {
    const write = Storage.prototype.setItem;
    Storage.prototype.setItem = function (name, value) {
      const result = write.call(this, name, value);
      if (name === returnKey || name === key + '-code-verifier') void window.__leoFixtureStorageWrite({ key: name, value });
      return result;
    };
  }, { key, returnKey });
  await context.route('**/*', async route => {
    const request = route.request(); const url = new URL(request.url());
    if (url.origin === base) {
      if (url.pathname === '/app/research-desk/strategy-config.json') {
        await route.fulfill(state.configFails ? { status: 503, body: 'Injected configuration outage' } : { json: config }); return;
      }
      if (url.pathname.startsWith('/app/research-desk/data/')) {
        state.archiveRequests++; await route.fulfill({ status: 503, body: 'Injected archive outage' }); return;
      }
      await route.continue(); return;
    }
    state.external.push({ origin: url.origin, path: url.pathname, method: request.method(), frame: request.isNavigationRequest() });
    if (url.origin !== project) { await route.fulfill({ status: 200, contentType: 'text/html', body: '<!doctype html><title>Blocked external fixture</title>' }); return; }
    const headers = { 'Access-Control-Allow-Origin': base, 'Access-Control-Allow-Headers': 'authorization,apikey,content-type,idempotency-key,x-client-info,x-supabase-api-version',
      'Access-Control-Allow-Methods': 'GET,POST,OPTIONS' };
    const respond = options => route.fulfill({ ...options, headers });
    if (request.method() === 'OPTIONS') { await respond({ status: 204 }); return; }
    state.authRequests.push({ path: url.pathname, method: request.method(), query: url.searchParams.toString() });
    if (url.pathname === '/auth/v1/authorize') {
      state.authorizeSeen.resolve(new URL(request.url())); await state.authorizeRelease.promise;
      await respond({ status: 200, contentType: 'text/html', body: '<!doctype html><title>Injected Google authorization boundary</title>' }); return;
    }
    if (url.pathname === '/auth/v1/token') {
      const body = request.postDataJSON(); state.exchangeSeen.resolve({ url, body });
      if (state.exchangeHeld) await state.exchangeRelease.promise;
      await respond(state.exchangeRejected ? { status: 400, json: { error: 'invalid_grant', error_description: 'Injected expired code', code: 'bad_code_verifier' } } : { json: state.session }); return;
    }
    if (url.pathname === '/auth/v1/user') { await respond({ json: state.session.user }); return; }
    if (url.pathname === '/auth/v1/logout') { await respond({ status: 204 }); return; }
    if (url.pathname === '/functions/v1/strategy-api/v1/status') {
      const token = request.headers().authorization?.replace('Bearer ', '') || '';
      const id = JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString()).sub;
      const isB = id.endsWith('2'); state.statusRequests.push(id);
      if (state.holdA && !isB) { state.statusASeen.resolve(); await state.statusARelease.promise; }
      if (state.holdB && isB) { state.statusBSeen.resolve(); await state.statusBRelease.promise; }
      const status = fixtureStatus(); status.membership.userId = id;
      status.devices[0].name = isB ? 'Second fixture computer' : 'First fixture computer';
      await respond({ json: { data: status, meta: { requestId: 'fixture-only' } } }); return;
    }
    throw new Error('Unexpected fixture API call: ' + request.method() + ' ' + url.pathname);
  });
  return { context, page, state };
}

async function seedCallback(context, returnTo) {
  await context.addInitScript(({ key, returnKey, returnTo }) => {
    if (location.pathname !== '/strategy-auth/callback') return;
    sessionStorage.setItem(returnKey, returnTo);
    localStorage.setItem(key + '-code-verifier', JSON.stringify('fixture-pkce-verifier-for-callback-only'));
  }, { key, returnKey, returnTo });
}

async function assertAuthorization(page, state, buttonName, returnTo) {
  await page.getByRole('button', { name: buttonName, exact: true }).focus();
  const pressed = page.keyboard.press('Enter');
  const url = await within(state.authorizeSeen.promise, 'OAuth authorization');
  await within(state.storageSeen.promise, 'OAuth state storage');
  const stored = { returnTo: state.storageWrites[returnKey], verifier: JSON.parse(state.storageWrites[key + '-code-verifier']) };
  assert.equal(url.searchParams.get('provider'), 'google');
  assert.equal(url.searchParams.get('redirect_to'), base + '/strategy-auth/callback');
  assert.equal(url.searchParams.get('code_challenge_method').toUpperCase(), 'S256');
  assert.equal(url.searchParams.get('code_challenge'), createHash('sha256').update(stored.verifier).digest('base64url'));
  assert.equal(stored.returnTo, returnTo);
  assert(!url.searchParams.has('access_token'));
  state.authorizeRelease.resolve();
  await pressed;
  await page.waitForURL(project + '/auth/v1/authorize**');
}

async function callbackResult(browser, returnTo, destination, after) {
  const h = await harness(browser, { exchangeHeld: true });
  try {
    await seedCallback(h.context, returnTo);
    await h.page.goto(base + '/strategy-auth/callback?code=fixture-code-only');
    const exchange = await within(h.state.exchangeSeen.promise, 'PKCE token exchange');
    assert.equal(exchange.url.searchParams.get('grant_type'), 'pkce');
    assert.deepEqual(exchange.body, { auth_code: 'fixture-code-only', code_verifier: 'fixture-pkce-verifier-for-callback-only' });
    assert.equal(h.page.url(), base + '/#/welcome');
    assert.equal(await h.page.locator('iframe').count(), 0);
    assert.equal(h.state.external.filter(r => r.origin !== project).length, 0);
    assert.equal(h.state.statusRequests.length, 0);
    assert.equal(await h.page.evaluate(returnKey => sessionStorage.getItem(returnKey), returnKey), null);
    h.state.exchangeRelease.resolve();
    await h.page.waitForURL(base + destination);
    await h.page.getByRole('link', { name: 'Your account', exact: true }).waitFor();
    assert.equal(h.state.authRequests.filter(r => r.path === '/auth/v1/token').length, 1);
    assert.equal(await h.page.evaluate(key => localStorage.getItem(key + '-code-verifier'), key), null);
    if (after) await after(h);
  } finally { h.state.authorizeRelease.resolve(); h.state.exchangeRelease.resolve(); await h.context.close(); }
}

async function check(name, action) {
  console.log('CHECK ' + name);
  try { await action(); receipt.checks.push({ name, result: 'pass' }); console.log('PASS ' + name); }
  catch (error) { receipt.checks.push({ name, result: 'fail', error: String(error) }); console.log('FAIL ' + name + ': ' + String(error)); }
}

(async () => {
  await fs.mkdir(output, { recursive: true });
  const browser = await chromium.launch({ headless: true });
  try {
    await check('Welcome survives archive outage; keyboard Google action uses exact PKCE callback and home return', async () => {
      const h = await harness(browser);
      try {
        await h.page.goto(base + '/#/welcome');
        await h.page.getByRole('button', { name: 'Sign in with Google', exact: true }).waitFor();
        assert(h.state.archiveRequests > 0); assert.equal(await h.page.locator('iframe').count(), 0);
        await h.page.evaluate(() => document.fonts.ready);
        if (!process.env.LEO_AUTH_SKIP_WELCOME_CAPTURES) await h.page.screenshot({ path: path.join(output, 'welcome-desktop.png'), fullPage: true, animations: 'disabled' });
        await h.page.setViewportSize({ width: 390, height: 844 });
        assert(await h.page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
        if (!process.env.LEO_AUTH_SKIP_WELCOME_CAPTURES) await h.page.screenshot({ path: path.join(output, 'welcome-mobile.png'), fullPage: true, animations: 'disabled' });
        await assertAuthorization(h.page, h.state, 'Sign in with Google', '/#/home');
      } finally { h.state.authorizeRelease.resolve(); await h.context.close(); }
    });
    await check('Successful home callback strips code before exchange, restores identity across reload, and logout persists', () => callbackResult(browser, '/#/home', '/#/home', async h => {
      await h.page.getByRole('link', { name: 'Your account', exact: true }).click();
      await h.page.getByText('fixture-user@example.invalid', { exact: true }).waitFor();
      await h.page.screenshot({ path: path.join(output, 'signed-in-desktop.png'), fullPage: true, animations: 'disabled' });
      await h.page.reload(); await h.page.getByText('fixture-user@example.invalid', { exact: true }).waitFor();
      assert.equal(h.state.authRequests.filter(r => r.path === '/auth/v1/token').length, 1);
      await h.page.getByRole('button', { name: 'Sign out', exact: true }).click();
      await h.page.getByRole('button', { name: 'Sign in with Google', exact: true }).waitFor();
      assert.equal(await h.page.getByText('fixture-user@example.invalid', { exact: true }).count(), 0);
      await h.page.reload(); await h.page.getByRole('button', { name: 'Sign in with Google', exact: true }).waitFor();
      assert.equal(await h.page.evaluate(key => localStorage.getItem(key), key), null);
    }));
    await check('Strategy callback returns only after exchange and loads matched owner evidence', () => callbackResult(browser, '/#/strategies', '/#/strategies', async h => {
      await h.page.getByText('First fixture computer', { exact: true }).waitFor();
      assert(h.state.statusRequests.every(id => id === h.state.session.user.id));
    }));
    await check('Untrusted callback return cannot leave the bounded home/strategies allowlist', () => callbackResult(browser, 'https://outside.example.invalid/#/strategies', '/#/home'));
    await check('Provider denial, hash denial and missing code remain recoverable without code exchange', async () => {
      for (const suffix of ['?error=access_denied&error_description=fixture-only', '#error=access_denied', '']) {
        const h = await harness(browser);
        try {
          await seedCallback(h.context, '/#/strategies');
          await h.page.goto(base + '/strategy-auth/callback' + suffix);
          await h.page.getByRole('alert').filter({ hasText: 'interrupted' }).waitFor();
          assert.equal(h.page.url(), base + '/#/welcome');
          assert.equal(h.state.authRequests.filter(r => r.path === '/auth/v1/token').length, 0);
          assert.equal(await h.page.locator('iframe').count(), 0);
          if (suffix.startsWith('?')) await h.page.screenshot({ path: path.join(output, 'denied-desktop.png'), fullPage: true, animations: 'disabled' });
          await assertAuthorization(h.page, h.state, 'Sign in with Google', '/#/home');
        } finally { h.state.authorizeRelease.resolve(); await h.context.close(); }
      }
    });
    await check('Rejected code exchange reports expiry and offers a fresh Google PKCE attempt', async () => {
      const h = await harness(browser, { exchangeRejected: true });
      try {
        await seedCallback(h.context, '/#/strategies');
        await h.page.goto(base + '/strategy-auth/callback?code=fixture-expired-code');
        await h.page.getByRole('alert').filter({ hasText: 'expired' }).waitFor();
        assert.equal(h.page.url(), base + '/#/welcome'); assert.equal(await h.page.locator('iframe').count(), 0);
        assert.equal(h.state.authRequests.filter(r => r.path === '/auth/v1/token').length, 1);
        await assertAuthorization(h.page, h.state, 'Sign in with Google', '/#/home');
      } finally { h.state.authorizeRelease.resolve(); await h.context.close(); }
    });
    await check('Configuration outage retries independently of archive failure', async () => {
      const h = await harness(browser, { configFails: true });
      try {
        await h.page.goto(base + '/#/welcome'); await h.page.getByRole('button', { name: 'Try again', exact: true }).waitFor();
        h.state.configFails = false; await h.page.getByRole('button', { name: 'Try again', exact: true }).click();
        await h.page.getByRole('button', { name: 'Sign in with Google', exact: true }).waitFor();
        assert.equal(await h.page.getByRole('alert').count(), 0);
      } finally { await h.context.close(); }
    });
    await check('Cross-tab identity change hides old evidence and ignores an older in-flight response', async () => {
      const h = await harness(browser); const next = sessionFor('10000000-0000-4000-8000-000000000002');
      try {
        await h.context.addInitScript(({ key, session }) => {
          if (!sessionStorage.getItem('fixture-session-seeded')) { localStorage.setItem(key, JSON.stringify(session)); sessionStorage.setItem('fixture-session-seeded', 'true'); }
        }, { key, session: h.state.session });
        await h.page.goto(base + '/#/strategies'); await h.page.getByText('First fixture computer', { exact: true }).waitFor();
        h.state.holdA = true; h.state.holdB = true;
        await h.page.getByRole('button', { name: 'Refresh connector status' }).click(); await within(h.state.statusASeen.promise, 'old owner request');
        h.state.session = next;
        await h.page.evaluate(({ key, session }) => {
          localStorage.setItem(key, JSON.stringify(session));
          const channel = new BroadcastChannel(key); channel.postMessage({ event: 'SIGNED_IN', session }); channel.close();
        }, { key, session: next });
        await within(h.state.statusBSeen.promise, 'new owner request');
        assert.equal(await h.page.getByText('First fixture computer', { exact: true }).count(), 0);
        h.state.statusARelease.resolve();
        await h.page.getByText('second-user@example.invalid', { exact: true }).waitFor();
        assert.equal(await h.page.getByText('First fixture computer', { exact: true }).count(), 0);
        h.state.statusBRelease.resolve(); await h.page.getByText('Second fixture computer', { exact: true }).waitFor();
        await h.page.getByRole('button', { name: 'Sign out', exact: true }).click();
        await h.page.getByRole('button', { name: 'Sign in with Google', exact: true }).waitFor();
        assert.equal(await h.page.getByText('Second fixture computer', { exact: true }).count(), 0);
        await assertAuthorization(h.page, h.state, 'Sign in with Google', '/#/strategies');
      } finally { h.state.statusARelease.resolve(); h.state.statusBRelease.resolve(); h.state.authorizeRelease.resolve(); await h.context.close(); }
    });
    await check('Anonymous cached session remains a guest and never requests private strategy evidence', async () => {
      const h = await harness(browser, { session: sessionFor(undefined, true) });
      try {
        await h.context.addInitScript(({ key, session }) => localStorage.setItem(key, JSON.stringify(session)), { key, session: h.state.session });
        await h.page.goto(base + '/#/strategies'); await h.page.getByRole('button', { name: 'Sign in with Google', exact: true }).waitFor();
        assert.equal(h.state.statusRequests.length, 0);
        assert.equal(await h.page.getByText('First fixture computer', { exact: true }).count(), 0);
      } finally { await h.context.close(); }
    });
  } finally {
    await browser.close();
    await fs.writeFile(path.join(output, 'browser-checks.json'), JSON.stringify(receipt, null, 2) + '\n');
    console.log(JSON.stringify(receipt, null, 2));
    if (receipt.errors.length || receipt.checks.some(check => check.result === 'fail')) process.exitCode = 1;
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
