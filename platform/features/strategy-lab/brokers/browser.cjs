// Injected browser-boundary evidence only. Never signs in to Google or contacts a broker.
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { chromium } = require(process.env.LEO_PLAYWRIGHT_MODULE || 'playwright');
const { fixtureStatus } = require('../tests/fixtures.ts');
const base = (process.env.LEO_BROKER_TEST_BASE || 'http://127.0.0.1:3221').replace(/\/$/, '');
const project = 'https://katwbobjiyzipqlzarus.supabase.co';
const key = 'leo.strategy-lab.auth.v1';
const output = path.resolve(__dirname, '../../../.impeccable/review/brokers');
const config = { schemaVersion: 'strategy-public-config/v1', enabled: true, supabaseUrl: project,
  publishableKey: 'sb_publishable_fixture_only', apiUrl: project + '/functions/v1/strategy-api' };
const result = { evidence: 'Injected UI fixtures; no broker-backed account, fill, or profitability evidence.', checks: [], errors: [] };
function sessionFor(id = '10000000-0000-4000-8000-000000000001', anonymous = false) {
  const now = Math.floor(Date.now() / 1000);
  const user = { id, aud: 'authenticated', role: 'authenticated', email: 'fixture-user@example.invalid',
    app_metadata: { provider: 'google', providers: ['google'] }, user_metadata: {}, identities: [], created_at: new Date().toISOString(), is_anonymous: anonymous };
  const payload = Buffer.from(JSON.stringify({ sub: id, exp: now + 3600, role: 'authenticated' })).toString('base64url');
  return { access_token: `fixture.${payload}.signature`, refresh_token: 'fixture-refresh-only', expires_in: 3600, expires_at: now + 3600, token_type: 'bearer', user };
}
async function harness(browser, settings = {}) {
  const context = await browser.newContext({ viewport: { width: 1440, height: 1000 }, reducedMotion: 'reduce' });
  const page = await context.newPage(); page.setDefaultTimeout(15000);
  const state = { session: settings.session, status: fixtureStatus(), statusCode: 200, calls: [], archiveRequests: 0, ...settings };
  page.on('pageerror', error => result.errors.push(error.message));
  if (state.session) await context.addInitScript(({ key, session }) => {
    if (!sessionStorage.getItem('broker-fixture-seeded')) { localStorage.setItem(key, JSON.stringify(session)); sessionStorage.setItem('broker-fixture-seeded', 'true'); }
  }, { key, session: state.session });
  await context.route('**/*', async route => {
    const request = route.request(), url = new URL(request.url());
    if (url.origin === base) {
      if (url.pathname.endsWith('/strategy-config.json')) return route.fulfill({ json: config });
      if (url.pathname.startsWith('/app/research-desk/data/')) { state.archiveRequests++; return route.fulfill({ status: 503, body: 'Injected archive failure' }); }
      return route.continue();
    }
    state.calls.push({ method: request.method(), origin: url.origin, path: url.pathname, url: url.toString() });
    const headers = { 'Access-Control-Allow-Origin': base, 'Access-Control-Allow-Headers': 'authorization,apikey,content-type,idempotency-key,x-client-info,x-supabase-api-version', 'Access-Control-Allow-Methods': 'GET,POST,OPTIONS' };
    if (request.method() === 'OPTIONS') return route.fulfill({ status: 204, headers });
    if (url.origin === project && url.pathname === '/auth/v1/authorize') return route.fulfill({ headers, contentType: 'text/html', body: '<title>Injected Google boundary</title>' });
    if (url.origin === project && url.pathname === '/auth/v1/user') return route.fulfill({ headers, json: state.session.user });
    if (url.origin === project && url.pathname === '/functions/v1/strategy-api/v1/status') return route.fulfill({ headers, status: state.statusCode, json: state.statusCode === 200 ? { data: state.status, meta: { requestId: 'fixture' } } : { error: { message: 'Injected status unavailable' } } });
    result.errors.push('Unexpected request blocked: ' + request.method() + ' ' + url.origin + url.pathname);
    return route.fulfill({ status: 403, headers, body: 'Blocked fixture request' });
  });
  return { context, page, state };
}
async function check(name, body) {
  try { await body(); result.checks.push({ name, result: 'pass' }); console.log('PASS ' + name); }
  catch (error) { result.checks.push({ name, result: 'fail', error: String(error) }); console.log('FAIL ' + name + ': ' + String(error)); }
}
const noMutations = state => assert.equal(state.calls.filter(call => !['GET', 'OPTIONS'].includes(call.method)).length, 0);
async function noOrders(page) { assert.equal(await page.getByRole('button', { name: /start|buy|sell|authorize|place order/i }).count(), 0); }
(async () => {
  await fs.mkdir(output, { recursive: true });
  const browser = await chromium.launch({ headless: true });
  try {
    await check('Guest broker setup survives archive outage, supports keyboard and mobile, and cannot submit trades', async () => {
      const h = await harness(browser);
      try {
        await h.page.goto(base + '/#/brokers');
        await h.page.getByText('No broker connected', { exact: true }).waitFor();
        assert(h.state.archiveRequests > 0);
        assert.equal(await h.page.locator('iframe').count(), 0);
        const downloads = h.page.getByRole('link', { name: 'Windows tools · unsigned preview', exact: true });
        assert.equal(await downloads.count(), 2);
        for (const link of await downloads.all()) {
          assert.equal(await link.getAttribute('href'), '/app/research-desk/downloads/leo-broker-tools-windows-x64.zip');
          assert.notEqual(await link.getAttribute('download'), null);
        }
        await noOrders(h.page); assert.equal(h.state.calls.length, 0);
        await h.page.evaluate(() => document.fonts.ready);
        await h.page.screenshot({ path: path.join(output, 'desktop.png'), fullPage: true, animations: 'disabled' });
        await h.page.setViewportSize({ width: 390, height: 844 });
        assert(await h.page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
        await h.page.screenshot({ path: path.join(output, 'mobile.png'), fullPage: true, animations: 'disabled' });
        await h.page.getByRole('link', { name: 'Set up moomoo', exact: true }).focus(); await h.page.keyboard.press('Enter');
        await h.page.getByRole('heading', { name: 'Connect computer', exact: true }).waitFor();
        assert.equal(h.page.url(), base + '/#/strategies?step=connect');
        assert(await h.page.getByRole('button', { name: 'Create pairing token' }).isDisabled());
        noMutations(h.state);
      } finally { await h.context.close(); }
    });
    await check('Google sign-in reaches only the existing scoped OAuth boundary', async () => {
      const h = await harness(browser);
      try {
        await h.page.goto(base + '/#/brokers');
        await h.page.getByRole('button', { name: 'Sign in with Google', exact: true }).click();
        await h.page.waitForURL(project + '/auth/v1/authorize**');
        const url = new URL(h.page.url());
        assert.equal(url.searchParams.get('provider'), 'google'); assert.equal(url.searchParams.get('redirect_to'), base + '/strategy-auth/callback');
        assert.equal(url.searchParams.get('code_challenge_method').toUpperCase(), 'S256'); noMutations(h.state);
      } finally { await h.context.close(); }
    });
    await check('Verified identity displays reported paper accounts without broker-ready or trading claims', async () => {
      const h = await harness(browser, { session: sessionFor() });
      try {
        await h.page.goto(base + '/#/brokers'); await h.page.getByText('Computer reporting', { exact: true }).waitFor();
        const statusRegion = h.page.locator('.broker-identity').getByRole('status');
        assert.equal(await statusRegion.count(), 1);
        assert.equal(await statusRegion.getAttribute('aria-atomic'), 'true');
        assert.equal(await statusRegion.locator('button, a').count(), 0);
        assert.equal(await statusRegion.locator('strong').textContent(), 'Computer reporting');
        await h.page.getByRole('heading', { name: 'Test computer', exact: true }).waitFor();
        assert.equal(await h.page.locator('.broker-account').filter({ hasText: 'TEST-PAPER-001' }).count(), 1);
        await noOrders(h.page); noMutations(h.state);
        await h.page.screenshot({ path: path.join(output, 'reported-desktop.png'), fullPage: true, animations: 'disabled' });
        h.state.statusCode = 503; await h.page.getByRole('button', { name: 'Refresh status', exact: true }).click();
        await h.page.getByText('Computer offline or status expired', { exact: true }).waitFor();
        assert.equal(await statusRegion.locator('strong').textContent(), 'Computer offline or status expired');
        assert.equal(await h.page.locator('.broker-account').filter({ hasText: 'TEST-PAPER-001' }).count(), 1);
        assert.equal(await h.page.getByText('Reporting to Leo', { exact: true }).count(), 0);
        await h.page.getByRole('alert').waitFor(); await noOrders(h.page);
        await h.page.screenshot({ path: path.join(output, 'stale-desktop.png'), fullPage: true, animations: 'disabled' });
      } finally { await h.context.close(); }
    });
    await check('Expired and future-dated reports do not show reporting state; revoked devices remain hidden', async () => {
      for (const time of [new Date(Date.now() - 60000).toISOString(), new Date(Date.now() + 60000).toISOString()]) {
        const status = fixtureStatus(); status.devices[0].lastSeenAt = time;
        const h = await harness(browser, { session: sessionFor(), status });
        try {
          await h.page.goto(base + '/#/brokers'); await h.page.getByText('Computer offline or status expired', { exact: true }).waitFor();
          assert.equal(await h.page.getByText('Computer reporting', { exact: true }).count(), 0);
          h.state.status.devices[0].revokedAt = new Date().toISOString(); await h.page.getByRole('button', { name: 'Refresh status', exact: true }).click();
          await h.page.getByText('No computer paired', { exact: true }).waitFor();
          assert.equal(await h.page.locator('.broker-account').filter({ hasText: 'TEST-PAPER-001' }).count(), 0); noMutations(h.state);
        } finally { await h.context.close(); }
      }
    });
    await check('Anonymous or mismatched owners cannot view account evidence or authorize a trade', async () => {
      const anonymous = await harness(browser, { session: sessionFor(undefined, true) });
      try {
        await anonymous.page.goto(base + '/#/brokers'); await anonymous.page.getByText('No broker connected', { exact: true }).waitFor();
        assert.equal(anonymous.state.calls.length, 0); await noOrders(anonymous.page);
      } finally { await anonymous.context.close(); }
      const h = await harness(browser, { session: sessionFor('10000000-0000-4000-8000-000000000002') });
      try {
        await h.page.goto(base + '/#/brokers'); await h.page.getByRole('alert').waitFor();
        assert.equal(await h.page.locator('.broker-account').filter({ hasText: 'TEST-PAPER-001' }).count(), 0);
        assert.equal(await h.page.getByText('Computer reporting', { exact: true }).count(), 0); await noOrders(h.page); noMutations(h.state);
      } finally { await h.context.close(); }
    });
  } finally {
    await browser.close();
    await fs.writeFile(path.join(output, 'browser-checks.json'), JSON.stringify(result, null, 2) + '\n');
    console.log(JSON.stringify(result, null, 2));
    if (result.errors.length || result.checks.some(check => check.result === 'fail')) process.exitCode = 1;
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
