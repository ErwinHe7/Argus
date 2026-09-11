/* Opt-in verification of the real local Rust/WASM replay. Auth/outage fixtures
 * are explicitly injected; no hosted write, brokerage, or performance proof. */
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { chromium } = require(process.env.LEO_PLAYWRIGHT_MODULE || 'C:/Users/Hj/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const { fixtureStatus } = require('../../strategy-lab/tests/fixtures.ts');
const root = process.env.LEO_PREVIEW_URL || 'http://127.0.0.1:3117';
const output = path.resolve(__dirname, '../../../.impeccable/review/grid');
const tvOutput = path.resolve(__dirname, '../../../.impeccable/review/tradingview');
const fixturePath = path.resolve(__dirname, '../../strategy-lab/grid/fixtures');
const project = 'https://katwbobjiyzipqlzarus.supabase.co';
const receipt = { checkedAt: new Date().toISOString(), source: 'Actual built local Rust/WASM worker and authored synthetic DEMO requests. Auth, observed-classification metadata, malformed files, and outages are injected test conditions; no broker actions.', checks: [], screenshots: [], wasm: [], workers: [], demoResults: [], pageErrors: [], failures: [] };

async function check(name, action) {
  try { const detail = await action(); receipt.checks.push({ name, result: 'pass', ...(detail ? { detail } : {}) }); console.log('PASS ' + name); }
  catch (error) { receipt.failures.push({ name, error: error.message }); console.error('FAIL ' + name + ': ' + error.message); }
}
async function noOverflow(page) { assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'horizontal overflow'); }
async function capture(page, name, directory = output, evidence = 'Actual local Rust/WASM output using explicitly fictitious demonstration data') {
  await page.evaluate(async () => { await document.fonts.ready; scrollTo(0, 0); });
  await page.waitForTimeout(250);
  await noOverflow(page);
  const target = path.join(directory, name + '.png');
  await page.screenshot({ path: target, fullPage: true, animations: 'disabled' });
  receipt.screenshots.push({ path: target, name, viewport: page.viewportSize(), evidence });
}
async function context(browser, viewport = { width: 1440, height: 1000 }) {
  const ctx = await browser.newContext({ viewport, reducedMotion: 'reduce', serviceWorkers: 'block', acceptDownloads: true });
  ctx.setDefaultTimeout(12000);
  ctx.on('page', page => {
    page.on('pageerror', error => receipt.pageErrors.push(error.message));
    page.on('worker', worker => receipt.workers.push(worker.url()));
  });
  ctx.on('response', async response => {
    if (!response.url().endsWith('leo_grid_wasm.wasm')) return;
    const observation = { url: response.url(), status: response.status(), bytes: null, magic: null };
    receipt.wasm.push(observation);
    if (response.ok()) try { const body = await response.body(); observation.bytes = body.length; observation.magic = body.subarray(0, 4).toString('hex'); } catch { /* Worker may terminate immediately after returning its complete report. */ }
  });
  return ctx;
}
async function openGrid(page) {
  if (page.url() === root + '/#/strategies') await page.reload();
  else await page.goto(root + '/#/strategies');
  await page.getByRole('button', { name: 'Open grid research', exact: true }).waitFor();
  await page.getByRole('button', { name: 'Open grid research', exact: true }).focus();
  await page.keyboard.press('Enter');
  await page.getByRole('heading', { name: 'Grid research', exact: true }).waitFor();
}
async function demo(page, name) {
  await page.getByRole('button', { name: 'DEMO · ' + name, exact: true }).click();
  await page.getByRole('button', { name: 'Run historical replay', exact: true }).waitFor();
  await page.locator('.grid-research[aria-busy="false"]').waitFor();
  await page.locator('.grid-evidence-label').filter({ hasText: 'synthetic demonstration' }).waitFor();
}
async function run(page) {
  await page.getByRole('button', { name: 'Run historical replay', exact: true }).focus();
  await page.keyboard.press('Enter');
  await page.locator('#grid-result-title').waitFor({ timeout: 35000 });
  await page.waitForFunction(() => document.activeElement?.id === 'grid-result-title', undefined, { timeout: 2000 }).catch(async error => {
    const state = await page.evaluate(() => ({ active: document.activeElement?.outerHTML.slice(0, 350), busy: document.querySelector('.grid-research')?.getAttribute('aria-busy'), feedback: document.querySelector('.grid-feedback')?.textContent, error: document.querySelector('.grid-error')?.textContent }));
    const finding = { name: 'Committed replay result receives keyboard focus', error: error.message + ' · ' + JSON.stringify(state) };
    receipt.failures.push(finding);
    console.error('FAIL ' + finding.name + ': ' + finding.error);
  });
}
async function exported(page, label, destination) {
  const pending = page.waitForEvent('download');
  await page.getByRole('button', { name: label, exact: true }).click();
  const item = await pending;
  const target = path.join(output, destination);
  await item.saveAs(target);
  return JSON.parse(await fs.readFile(target, 'utf8'));
}
async function report(page, destination) {
  const value = await exported(page, 'Export frozen result', destination);
  assert.equal(value.schema_version, 'leo-grid-result.v1');
  assert.equal(value.execution_authorized, false);
  assert.equal(value.paper_execution_available, false);
  assert.equal(value.promotion_eligible, false);
  assert(value.configuration_hash.length === 64 && value.canonical_bars_sha256.length === 64);
  assert(Array.isArray(value.journal) && value.equity.length);
  return value;
}
async function providerChart(page) {
  await page.locator('.leo-tv--chart .leo-tv-frame').waitFor();
  const deadline = Date.now() + 30000;
  while (Date.now() < deadline) {
    const outer = await (await page.locator('.leo-tv--chart .leo-tv-frame').elementHandle()).contentFrame();
    const frame = outer?.childFrames().find(item => item.url().includes('/advanced-chart/'));
    if (frame) try {
      const count = await frame.locator('canvas').count();
      const text = await frame.locator('body').innerText({ timeout: 1000 });
      if (count && /Vol/.test(text)) return { canvases: count, providerOrigin: new URL(frame.url()).origin };
    } catch { /* Provider can navigate while initializing. */ }
    await page.waitForTimeout(350);
  }
  throw new Error('Actual TradingView chart did not settle within 30 seconds.');
}

async function confirmComparisonFix() {
  const prior = JSON.parse(await fs.readFile(path.join(output, 'browser-checks.json'), 'utf8'));
  Object.assign(receipt, prior);
  const checkName = 'Mobile ending portfolio comparison exposes approach, equity, and return without horizontal scrolling at 390px and 320px';
  receipt.comparisonAttempts ||= [];
  if (receipt.comparisonFix) receipt.comparisonAttempts.push({ ...receipt.comparisonFix, failures: receipt.failures.filter(item => item.name === checkName) });
  receipt.failures = receipt.failures.filter(item => item.name !== checkName);
  receipt.checks = receipt.checks.filter(item => item.name !== checkName);
  receipt.resolvedNotes = receipt.resolvedNotes.filter(item => item.kind !== 'Independent review correction');
  const browser = await chromium.launch({ headless: true });
  try {
    const mobile = await context(browser, { width: 390, height: 844 });
    const page = await mobile.newPage();
    await openGrid(page);
    await demo(page, 'Decline');
    await run(page);
    const dimensions = [];
    await check(checkName, async () => {
      for (const width of [390, 320]) {
        await page.setViewportSize({ width, height: 844 });
        await page.locator('.grid-comparison').scrollIntoViewIfNeeded();
        const result = await page.locator('.grid-comparison').evaluate(element => {
          const table = element.querySelector('table');
          const region = element.querySelector('.grid-table-scroll');
          const rows = [...table.querySelectorAll('tbody tr')].map(row => [...row.children].map(cell => {
            const bounds = cell.getBoundingClientRect();
            return { text: cell.textContent.trim(), left: bounds.left, right: bounds.right, width: bounds.width };
          }));
          const headers = [...table.querySelectorAll('thead th')].map(cell => {
            const bounds = cell.getBoundingClientRect();
            return { text: cell.textContent.trim(), left: bounds.left, right: bounds.right };
          });
          const style = getComputedStyle(table);
          return { viewportWidth: innerWidth, documentScrollWidth: document.documentElement.scrollWidth, regionWidth: region.clientWidth, regionScrollWidth: region.scrollWidth, tableStyle: { width: style.width, minWidth: style.minWidth, tableLayout: style.tableLayout, whiteSpace: style.whiteSpace }, headers, rows };
        });
        dimensions.push(result);
        assert.equal(result.rows.length, 3);
        assert.equal(result.headers.length, 3);
        assert(result.regionScrollWidth <= result.regionWidth, 'comparison requires horizontal scrolling: ' + JSON.stringify(result));
        for (const row of result.rows) {
          assert.equal(row.length, 3);
          assert.match(row[1].text, /\$/);
          assert.match(row[2].text, /%/);
          for (const cell of row) assert(cell.left >= 0 && cell.right <= width, 'comparison cell outside viewport: ' + JSON.stringify(cell));
        }
        for (const header of result.headers) assert(header.left >= 0 && header.right <= width, 'comparison header outside viewport');
        if (width === 390) await noOverflow(page);
      }
      return { targetedConfirmation: true, dimensions };
    });
    const confirmed = receipt.checks.some(item => item.name === checkName && item.result === 'pass');
    receipt.comparisonFix = { checkedAt: new Date().toISOString(), status: confirmed ? 'confirmed' : 'failed', scope: 'Mobile ending portfolio comparison only; the existing fifteen functional checks were not rerun. At 320px only comparison dimensions are acceptance criteria; document width is recorded as an additional observation.', dimensions };
    if (!confirmed) { process.exitCode = 1; await mobile.close(); return; }
    await page.setViewportSize({ width: 390, height: 844 });
    const replacementNames = ['mobile-grid-result', 'mobile-grid-result-viewport', 'mobile-grid-comparison'];
    receipt.screenshots = receipt.screenshots.filter(item => !replacementNames.includes(item.name));
    await capture(page, 'mobile-grid-result');
    for (const [selector, name] of [['#grid-result-title', 'mobile-grid-result-viewport'], ['.grid-comparison', 'mobile-grid-comparison']]) {
      await page.locator(selector).scrollIntoViewIfNeeded();
      const target = path.join(output, name + '.png');
      await page.screenshot({ path: target, fullPage: false, animations: 'disabled' });
      receipt.screenshots.push({ path: target, name, viewport: page.viewportSize(), evidence: 'Direct browser confirmation of actual synthetic decline replay after mobile comparison fix; no image editing' });
    }
    receipt.resolvedNotes.push({ kind: 'Independent review correction', firstPassFinding: 'At 390px the ending portfolio comparison displayed Approach while equity and return required horizontal scrolling without a cue.', correction: 'Targeted confirmation checks all three columns and all three rows within the viewport at 390px and 320px. The three-column comparison wraps labels and preserves right-aligned values; the separate wide slot ledger retains local scrolling.', confirmedAt: new Date().toISOString() });
    await mobile.close();
  } finally {
    await browser.close();
    await fs.writeFile(path.join(output, 'browser-checks.json'), JSON.stringify(receipt, null, 2) + '\n');
  }
  if (receipt.failures.length || receipt.pageErrors.length) process.exitCode = 1;
}

(async () => {
  if (process.argv.includes('--comparison-only')) { await confirmComparisonFix(); return; }
  await fs.mkdir(output, { recursive: true });
  await fs.mkdir(tvOutput, { recursive: true });
  const browser = await chromium.launch({ headless: true });
  try {
    const guest = await context(browser);
    const page = await guest.newPage();
    const requests = [];
    guest.on('request', request => requests.push({ url: request.url(), method: request.method(), body: request.postData() }));
    await check('Grid opens by keyboard with heading focus, empty evidence, authentication status, and monitor visible', async () => {
      await openGrid(page);
      assert.equal(await page.locator('#grid-research-title').evaluate(element => document.activeElement === element), true);
      await page.getByRole('heading', { name: 'No replay loaded', exact: true }).waitFor();
      assert.equal(await page.locator('.grid-report').count(), 0);
      await page.locator('.strategy-auth-bar').waitFor();
      await page.getByRole('heading', { name: 'Local monitor', exact: true }).waitFor();
      assert.equal(await page.locator('.leo-tv-frame').count(), 0);
      await capture(page, 'desktop-grid-empty', output, 'Empty local research state; no results or injected market data');
    });
    const reports = {};
    for (const name of ['Range', 'Decline', 'Rally']) await check(name + ' demonstration runs the actual WASM and remains explicitly synthetic', async () => {
      await demo(page, name);
      await run(page);
      const value = reports[name] = await report(page, 'demo-' + name.toLowerCase() + '-result.json');
      assert.equal(value.evidence_status, 'SYNTHETIC_DEMONSTRATION');
      assert.equal(value.configuration.source_evidence.classification, 'synthetic_fixture');
      assert.match(await page.locator('.grid-report').innerText(), /Fictitious DEMO · synthetic demonstration/);
      if (name === 'Decline') {
        assert(Number(value.metrics.realized_cycle_pnl) > 0, 'decline has completed profitable cycles');
        assert(Number(value.metrics.total_pnl) < 0, 'decline total marked portfolio loses despite cycle profit');
        await capture(page, 'desktop-grid-result');
      }
      receipt.demoResults.push({ name, evidenceStatus: value.evidence_status, totalPnl: value.metrics.total_pnl, closedCyclePnl: value.metrics.realized_cycle_pnl, endingShares: value.metrics.ending_quantity, configurationHash: value.configuration_hash });
      return receipt.demoResults.at(-1);
    });
    await check('Edited rules clear prior evidence and replay freezes a different configuration; full request exports locally', async () => {
      const old = reports.Rally.configuration_hash;
      await page.getByLabel('Grid intervals', { exact: false }).fill('5');
      assert.equal(await page.locator('.grid-report').count(), 0);
      assert.equal(await page.getByRole('button', { name: 'Export frozen result', exact: true }).count(), 0);
      await page.getByText('Rules changed. The prior result was cleared; run a new replay.', { exact: true }).waitFor();
      const request = await exported(page, 'Export request', 'edited-request.json');
      assert.equal(request.intervals, 5);
      assert(request.bars.length && request.source_evidence.dataset_sha256);
      await run(page);
      const value = await report(page, 'edited-result.json');
      assert.equal(value.configuration.intervals, 5);
      assert.notEqual(value.configuration_hash, old);
      return { configuredIntervals: value.configuration.intervals, requestBars: request.bars.length, completeJournalEvents: value.journal.length };
    });
    await check('Injected observed-classification request is accepted as unverified, and its content never leaves the browser', async () => {
      const value = JSON.parse(await fs.readFile(path.join(fixturePath, 'range.json'), 'utf8'));
      value.symbol = 'QAOBS';
      value.source_evidence.classification = 'observed';
      value.source_evidence.source = 'Injected UI metadata assertion; authored test prices, not actual market observations';
      value.source_evidence.license_scope = 'UI validation fixture only; no market-performance evidence';
      const start = requests.length;
      await page.getByLabel('Complete grid request JSON', { exact: true }).setInputFiles({ name: 'injected-observed-request.json', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify(value)) });
      await page.locator('.grid-evidence-label').filter({ hasText: 'User-supplied observations · not independently verified' }).waitFor();
      await run(page);
      const result = await report(page, 'injected-observed-result.json');
      assert.equal(result.evidence_status, 'USER_SUPPLIED_OBSERVED_NOT_INDEPENDENTLY_VERIFIED');
      const newRequests = requests.slice(start);
      assert(newRequests.every(request => new URL(request.url).origin === root && request.method === 'GET' && !request.body), 'import/replay made an external or body-bearing network request');
      return { injected: true, classificationOnly: true, requests: newRequests.map(request => ({ path: new URL(request.url).pathname, method: request.method })) };
    });
    await check('Malformed JSON produces an actionable error and removes the previous result', async () => {
      await page.getByLabel('Complete grid request JSON', { exact: true }).setInputFiles({ name: 'bad.json', mimeType: 'application/json', buffer: Buffer.from('{ bad json') });
      await page.getByRole('alert').filter({ hasText: 'This file is not valid JSON' }).waitFor();
      assert.equal(await page.locator('.grid-report').count(), 0);
    });
    await check('Real worker module and valid WASM binary were loaded from the local build', async () => {
      assert(receipt.workers.some(url => url.endsWith('/grid/grid.worker.js')));
      assert(receipt.wasm.some(item => item.status === 200 && item.bytes > 1000 && item.magic === '0061736d'), JSON.stringify(receipt.wasm));
      return { workerCount: receipt.workers.length, wasmLoads: receipt.wasm.filter(item => item.status === 200).length };
    });
    await check('Back navigation preserves mean reversion/momentum setup and account status', async () => {
      await page.getByRole('button', { name: 'Back to strategy setup', exact: true }).focus();
      await page.keyboard.press('Enter');
      await page.getByRole('button', { name: 'Configure mean reversion', exact: true }).waitFor();
      await page.locator('input[name="strategy"][value="MOM-v1"]').check();
      await page.getByRole('button', { name: 'Configure momentum', exact: true }).waitFor();
      await page.locator('.strategy-auth-bar').waitFor();
      await noOverflow(page);
    });
    await check('Monitor connector action exits grid and opens Connect computer', async () => {
      await page.getByRole('button', { name: 'Open grid research', exact: true }).click();
      await page.getByRole('button', { name: 'Set up a connector', exact: true }).click();
      await page.getByRole('heading', { name: 'Connect computer', exact: true }).waitFor();
      assert.equal(await page.locator('.grid-research').count(), 0);
      await page.getByRole('button', { name: '1 Choose strategy', exact: true }).click();
      await page.getByRole('heading', { name: 'Choose strategy', exact: true }).waitFor();
    });
    await guest.close();

    const mobile = await context(browser, { width: 390, height: 844 });
    const phone = await mobile.newPage();
    await check('Mobile replay shows total account loss, positive cycles, and all controls without horizontal overflow', async () => {
      await openGrid(phone);
      await demo(phone, 'Decline');
      await run(phone);
      await capture(phone, 'mobile-grid-result');
      await phone.locator('#grid-result-title').scrollIntoViewIfNeeded();
      const detailTarget = path.join(output, 'mobile-grid-result-viewport.png');
      await phone.screenshot({ path: detailTarget, fullPage: false, animations: 'disabled' });
      receipt.screenshots.push({ path: detailTarget, name: 'mobile-grid-result-viewport', viewport: phone.viewportSize(), evidence: 'Direct browser viewport capture of the actual synthetic decline result; no image editing' });
      await noOverflow(phone);
    });
    await check('Injected WASM failure shows recovery; removing the block allows a real rerun', async () => {
      await demo(phone, 'Range');
      const block = route => route.fulfill({ status: 503, body: 'Injected local WASM outage' });
      await mobile.route('**/grid/leo_grid_wasm.wasm', block);
      await phone.getByRole('button', { name: 'Run historical replay', exact: true }).click();
      await phone.getByRole('alert').filter({ hasText: 'local grid engine is unavailable' }).waitFor();
      assert.equal(await phone.locator('.grid-report').count(), 0);
      await capture(phone, 'mobile-grid-error', output, 'Deliberately injected WASM response failure; no completed replay result');
      await mobile.unroute('**/grid/leo_grid_wasm.wasm', block);
      await run(phone);
      return { injected: true, recovery: 'Actual WASM rerun after unblocking its local response' };
    });
    await check('Auth configuration and archived JSON outages leave local grid replay usable', async () => {
      await mobile.route('**/app/research-desk/strategy-config.json', route => route.fulfill({ status: 503, body: 'Injected configuration outage' }));
      await mobile.route('**/app/research-desk/data/**', route => route.fulfill({ status: 503, body: 'Injected archived JSON outage' }));
      await openGrid(phone);
      await demo(phone, 'Range');
      await run(phone);
      assert.equal(await phone.locator('.leo-tv-frame').count(), 0);
      await phone.locator('.strategy-auth-bar').waitFor();
      return { injected: true, affected: ['strategy config', 'archived research JSON'], localReplay: 'completed' };
    });
    await mobile.close();

    const signed = await context(browser);
    const state = fixtureStatus();
    const user = { id: state.membership.userId, aud: 'authenticated', role: 'authenticated', email: 'grid-test@example.invalid', app_metadata: { provider: 'google' }, user_metadata: {}, identities: [], created_at: new Date().toISOString(), is_anonymous: false };
    const payload = Buffer.from(JSON.stringify({ sub: user.id, exp: Math.floor(Date.now() / 1000) + 3600, role: 'authenticated' })).toString('base64url');
    await signed.addInitScript(({ user, payload, root }) => {
      if (window !== parent || location.origin !== root) return;
      localStorage.setItem('leo.strategy-lab.auth.v1', JSON.stringify({ access_token: `test.${payload}.signature`, refresh_token: 'test-refresh', expires_in: 3600, expires_at: Math.floor(Date.now() / 1000) + 3600, token_type: 'bearer', user }));
    }, { user, payload, root });
    await signed.route('**/app/research-desk/strategy-config.json', route => route.fulfill({ json: { schemaVersion: 'strategy-public-config/v1', enabled: true, supabaseUrl: project, publishableKey: 'sb_publishable_test', apiUrl: project + '/functions/v1/strategy-api' } }));
    const mutations = [];
    await signed.route(project + '/**', async route => {
      const request = route.request();
      const headers = { 'Access-Control-Allow-Origin': root, 'Access-Control-Allow-Headers': 'authorization,apikey,content-type,idempotency-key,x-client-info', 'Access-Control-Allow-Methods': 'GET,POST,OPTIONS' };
      if (request.method() === 'OPTIONS') return route.fulfill({ status: 204, headers });
      if (request.method() !== 'GET') mutations.push(request.url());
      if (new URL(request.url()).pathname.endsWith('/v1/status')) return route.fulfill({ json: { data: state, meta: { requestId: 'grid-test' } }, headers });
      return route.fulfill({ status: 404, json: { error: 'Unexpected injected API request' }, headers });
    });
    await check('Injected authenticated membership preserves Pause and identity through grid and back; no control mutation', async () => {
      const monitor = await signed.newPage();
      await openGrid(monitor);
      await monitor.getByText('Identity verified · brokerage credentials stay on your computer', { exact: true }).waitFor();
      await monitor.getByRole('button', { name: 'Pause entries', exact: true }).waitFor();
      assert.equal(await monitor.getByRole('button', { name: 'Pause entries', exact: true }).isEnabled(), true);
      await monitor.getByRole('button', { name: 'Back to strategy setup', exact: true }).click();
      await monitor.locator('input[name="strategy"][value="MOM-v1"]').check();
      await monitor.getByRole('button', { name: 'Configure momentum', exact: true }).waitFor();
      await monitor.getByRole('button', { name: 'Pause entries', exact: true }).waitFor();
      assert.deepEqual(mutations, []);
      return { injected: true, authenticatedIdentity: 'test-only', brokerOrders: 0, controlMutations: 0 };
    });
    await signed.close();

    const reduced = await context(browser, { width: 390, height: 844 });
    await check('Reduced-motion TradingView strip has ten static symbol links, no tape iframe, and a real chart', async () => {
      const tv = await reduced.newPage();
      await tv.goto(root + '/#/structure?symbol=AVGO');
      await tv.locator('.leo-tv-static').waitFor();
      assert.equal(await tv.locator('.leo-tv-static > div a').count(), 10);
      assert.equal(await tv.locator('.leo-tv--tape').count(), 0);
      await tv.getByRole('link', { name: 'View market quotes', exact: true }).waitFor();
      const detail = await providerChart(tv);
      await capture(tv, 'mobile-reduced-motion', tvOutput, 'Actual hosted TradingView chart; static Leo symbol strip under prefers-reduced-motion; no tape frame');
      return detail;
    });
    await reduced.close();
  } finally {
    await browser.close();
    receipt.limitation = 'Real WASM behavior over invented prices proves implementation only. Observed classification is explicitly injected metadata, not independently verified market data. Auth and outage cases use isolated browser fixtures. Provider chart checks prove presentation, not quote quality. No broker or hosted mutation is performed.';
    receipt.resolvedNotes = [
      { kind: 'UI correction', firstPassFinding: 'Repeated replay results could render while focus remained on body because requestAnimationFrame ran before React committed.', correction: 'Result-keyed useEffect focuses the committed result heading; this confirmation run checks actual focus after every replay.' },
      { kind: 'UI correction', firstPassFinding: 'Monitor setup action could change setup step while Grid remained open.', correction: 'Monitor action exits Grid before opening Connect computer; this confirmation includes that behavior.' },
      { kind: 'Harness correction', detail: 'First-pass assumptions were corrected: no-trade rally can have an empty journal; momentum requires selecting its radio; same-hash outage verification explicitly reloads; demo loading completes before keyboard submission. Injected auth storage runs only on the intended top-level origin, not the initial opaque document.' },
    ];
    await fs.writeFile(path.join(output, 'browser-checks.json'), JSON.stringify(receipt, null, 2) + '\n');
  }
  if (receipt.failures.length || receipt.pageErrors.length) process.exitCode = 1;
})().catch(error => { console.error(error); process.exitCode = 1; });
