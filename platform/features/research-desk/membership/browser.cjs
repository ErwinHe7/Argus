// Isolated browser fixtures. All external requests are intercepted; no real payment.
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { chromium } = require(process.env.LEO_PLAYWRIGHT_MODULE || 'playwright');
const base = process.env.LEO_MEMBERSHIP_TEST_BASE || 'http://127.0.0.1:3231';
const billing = 'https://leo-whop-billing.axio7.workers.dev';
const project = 'https://katwbobjiyzipqlzarus.supabase.co';
const key = 'leo.strategy-lab.auth.v1';
const recordsKey = 'leo.research-desk.records.v1';
const output = path.resolve(process.env.LEO_MEMBERSHIP_TEST_OUTPUT || path.join(__dirname, '../../../.impeccable/review/membership'));
const receipt = { evidence: 'Injected browser fixtures only; no live sign-in, Whop purchase, membership grant, or broker operation.', checks: [], errors: [] };
const status = (state = 'none', checkedAt = new Date().toISOString()) => ({ provider: 'whop', status: state, checkedAt, cancelAtPeriodEnd: false, renewalPeriodEnd: null });
function sessionFor(id = '10000000-0000-4000-8000-000000000001') {
  const expires_at = Math.floor(Date.now() / 1000) + 3600;
  return { access_token: `fixture.${Buffer.from(JSON.stringify({ sub: id, exp: expires_at })).toString('base64url')}.signature`, refresh_token: 'fixture-only', expires_at, expires_in: 3600, token_type: 'bearer',
    user: { id, aud: 'authenticated', role: 'authenticated', email: id.endsWith('2') ? 'second@example.invalid' : 'member@example.invalid', app_metadata: { provider: 'google', providers: ['google'] }, user_metadata: {}, identities: [], created_at: new Date().toISOString(), is_anonymous: false } };
}
async function harness(browser, signedIn = true, viewport = { width: 1440, height: 1000 }) {
  const context = await browser.newContext({ viewport, reducedMotion: 'reduce' });
  context.setDefaultTimeout(10000);
  const state = { session: sessionFor(), value: status(), failure: false, checkoutUrl: 'https://whop.com/checkout/ch_fixture/', requests: [], whopVisits: 0, hold: null };
  const page = await context.newPage(); page.on('pageerror', error => receipt.errors.push(error.message));
  await context.addInitScript(({ key, recordsKey, session }) => { if (session) localStorage.setItem(key, JSON.stringify(session)); localStorage.setItem(recordsKey, '[]'); }, { key, recordsKey, session: signedIn ? state.session : null });
  await context.route('**/*', async route => {
    const req = route.request(); const url = new URL(req.url());
    if (url.origin === base) {
      if (url.pathname.endsWith('/strategy-config.json')) return route.fulfill({ json: { schemaVersion: 'strategy-public-config/v1', enabled: true, supabaseUrl: project, publishableKey: 'sb_publishable_fixture_only', apiUrl: project + '/functions/v1/strategy-api' } });
      if (url.pathname.includes('/research-desk/data/')) return route.fulfill({ status: 503, body: 'Fixture archive outage' });
      return route.continue();
    }
    const headers = { 'Access-Control-Allow-Origin': base, 'Access-Control-Allow-Headers': 'authorization,content-type,apikey,x-client-info,x-supabase-api-version', 'Access-Control-Allow-Methods': 'GET,POST,OPTIONS' };
    if (req.method() === 'OPTIONS') return route.fulfill({ status: 204, headers });
    if (url.origin === billing) {
      state.requests.push({ path: url.pathname, method: req.method(), authorization: req.headers().authorization });
      if (url.pathname === '/status') { const value = state.value; if (state.hold) await state.hold; return route.fulfill({ status: state.failure ? 503 : 200, headers, json: value }); }
      assert.equal(url.pathname, '/checkout'); assert.equal(req.method(), 'POST');
      return route.fulfill({ headers, json: { url: state.checkoutUrl } });
    }
    if (url.origin === project) return route.fulfill({ headers, json: url.pathname.endsWith('/user') ? state.session.user : state.session });
    if (url.origin === 'https://whop.com') state.whopVisits++;
    return route.fulfill({ status: 200, contentType: 'text/html', body: '<!doctype html><title>Intercepted external fixture</title><h1>Fixture checkout boundary</h1>' });
  });
  await page.goto(base + '/#/membership');
  return { context, page, state };
}
async function check(name, action) { try { await action(); receipt.checks.push({ name, result: 'pass' }); } catch (error) { receipt.checks.push({ name, result: 'fail', error: error.message }); } }
async function layout(page) {
  assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
  assert.equal(await page.locator('iframe').count(), 0);
  assert.equal(await page.locator('a[href="/pricing"]').count(), 1);
  assert.equal(await page.locator('a[href="https://whop.com/@me/settings/orders/"]').count(), 1);
  assert.equal(await page.evaluate(key => localStorage.getItem(key), recordsKey), '[]');
}
(async () => {
  await fs.mkdir(output, { recursive: true }); const browser = await chromium.launch({ headless: true });
  try {
    await check('Signed-out membership is readable despite archive failure, with Google and management links and no billing calls', async () => {
      const h = await harness(browser, false);
      try { await h.page.getByRole('button', { name: 'Sign in with Google', exact: true }).waitFor(); await layout(h.page); assert.equal(h.state.requests.length, 0); assert.equal(h.state.whopVisits, 0); await h.page.screenshot({ path: path.join(output, 'signed-out-desktop.png'), fullPage: true }); }
      finally { await h.context.close(); }
    });
    await check('No membership requests a server-created checkout only after the explicit click, with the current bearer token', async () => {
      const h = await harness(browser);
      try {
        const button = h.page.getByRole('button', { name: 'Continue to Whop checkout' }); await button.waitFor();
        assert.equal(h.state.requests.filter(r => r.path === '/checkout').length, 0); assert.equal(h.state.whopVisits, 0); await layout(h.page);
        await h.page.screenshot({ path: path.join(output, 'ready-desktop.png'), fullPage: true });
        await button.click(); await h.page.getByRole('heading', { name: 'Fixture checkout boundary' }).waitFor();
        const calls = h.state.requests.filter(r => r.path === '/checkout'); assert.equal(calls.length, 1); assert.equal(calls[0].authorization, 'Bearer ' + h.state.session.access_token); assert.equal(h.state.whopVisits, 1);
      } finally { await h.context.close(); }
    });
    await check('Untrusted checkout URL is rejected and cannot turn the membership active', async () => {
      const h = await harness(browser); h.state.checkoutUrl = 'https://whop.com.evil.invalid/checkout/plan_fixture/';
      try { await h.page.getByRole('button', { name: 'Continue to Whop checkout' }).click(); await h.page.getByRole('alert').waitFor(); assert.equal(h.page.url(), base + '/#/membership'); assert.equal(h.state.whopVisits, 0); assert.equal(await h.page.getByText('Active', { exact: true }).count(), 0); await h.page.getByRole('button', { name: 'Refresh membership', exact: true }).click(); await h.page.getByRole('button', { name: 'Continue to Whop checkout' }).waitFor(); }
      finally { await h.context.close(); }
    });
    await check('Active cancellation date is server-confirmed; outage removes active claim, retains dated context and offers retry on mobile', async () => {
      const h = await harness(browser, true, { width: 390, height: 844 });
      try {
        h.state.value = { ...status('active'), cancelAtPeriodEnd: true, renewalPeriodEnd: new Date(Date.now() + 86400000).toISOString() };
        await h.page.getByRole('button', { name: 'Refresh membership', exact: true }).click(); await h.page.getByText('Active', { exact: true }).waitFor();
        assert.match(await h.page.locator('.membership-state').innerText(), /Renewal is canceled/); assert.equal(await h.page.getByRole('button', { name: 'Continue to Whop checkout' }).count(), 0); await layout(h.page);
        await h.page.screenshot({ path: path.join(output, 'active-mobile.png'), fullPage: true });
        h.state.failure = true; await h.page.getByRole('button', { name: 'Refresh membership', exact: true }).click(); await h.page.getByRole('alert').waitFor();
        assert.equal(await h.page.getByText('Active', { exact: true }).count(), 0); assert.match(await h.page.locator('.membership-state').innerText(), /Last confirmation \(active\)/); await layout(h.page);
        await h.page.screenshot({ path: path.join(output, 'unavailable-mobile.png'), fullPage: true });
        h.state.failure = false; h.state.value = status('inactive'); await h.page.getByRole('button', { name: 'Refresh membership', exact: true }).click(); await h.page.getByText('Membership inactive', { exact: true }).waitFor();
      } finally { await h.context.close(); }
    });
    await check('Stale active response and client checkout return flags do not confirm active access', async () => {
      const h = await harness(browser);
      try { h.state.value = status('active', new Date(Date.now() - 600000).toISOString()); await h.page.goto(base + '/#/membership?checkout=success&status=active'); await h.page.getByText('Membership status unavailable', { exact: true }).waitFor(); assert.equal(await h.page.getByText('Active', { exact: true }).count(), 0); assert.equal(await h.page.getByRole('button', { name: 'Continue to Whop checkout' }).count(), 0); }
      finally { await h.context.close(); }
    });
    await check('Changing Google accounts discards the old membership and cannot apply an in-flight owner response', async () => {
      const h = await harness(browser); let release;
      try {
        await h.page.getByText('No linked Whop membership', { exact: true }).waitFor();
        h.state.value = status('active'); h.state.hold = new Promise(resolve => { release = resolve; });
        await h.page.getByRole('button', { name: 'Refresh membership', exact: true }).click();
        await h.page.getByText('Checking membership…', { exact: true }).waitFor();
        h.state.value = status('none'); h.state.session = sessionFor('10000000-0000-4000-8000-000000000002');
        await h.page.evaluate(({ key, session }) => { localStorage.setItem(key, JSON.stringify(session)); const channel = new BroadcastChannel(key); channel.postMessage({ event: 'SIGNED_IN', session }); channel.close(); }, { key, session: h.state.session });
        await h.page.getByText('second@example.invalid', { exact: true }).waitFor(); release(); h.state.hold = null;
        await h.page.getByText('No linked Whop membership', { exact: true }).waitFor(); assert.equal(await h.page.getByText('Active', { exact: true }).count(), 0); assert.equal(await h.page.getByText('member@example.invalid', { exact: true }).count(), 0);
      } finally { release?.(); await h.context.close(); }
    });
  } finally { await browser.close(); await fs.writeFile(path.join(output, 'browser-checks.json'), JSON.stringify(receipt, null, 2) + '\n'); console.log(JSON.stringify(receipt, null, 2)); if (receipt.errors.length || receipt.checks.some(c => c.result === 'fail')) process.exitCode = 1; }
})().catch(error => { console.error(error); process.exitCode = 1; });
