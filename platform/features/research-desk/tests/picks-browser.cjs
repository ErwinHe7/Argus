/* Opt-in local UI verification. Provider displays are real; labeled route
 * injections test failure/freshness behavior and never establish trading edge. */
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { chromium } = require(process.env.LEO_PLAYWRIGHT_MODULE || 'C:/Users/Hj/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root = process.env.LEO_PREVIEW_URL || 'http://127.0.0.1:3117';
const output = path.resolve(__dirname, '../../../.impeccable/review/picks');
const receipt = { checkedAt: new Date().toISOString(), preview: root, checks: [], screenshots: [], failures: [], pageErrors: [], externalPageErrors: [], firstPartyMutations: [], providerObservations: [], injections: [], limitation: 'Local interface behavior over the retained dated shortlist and actual hosted provider displays. Deliberate network and timestamp injections are labeled separately. No brokerage or hosted application writes; no proof of profitability, live price quality, or exhaustive market coverage.' };
let browser;

async function check(name, action) {
  try { const detail = await action(); receipt.checks.push({ name, result: 'pass', ...(detail ? { detail } : {}) }); console.log('PASS ' + name); }
  catch (error) { receipt.failures.push({ name, error: error.message }); console.error('FAIL ' + name + ': ' + error.message); }
}
async function context(viewport = { width: 1440, height: 900 }) {
  const context = await browser.newContext({ viewport, reducedMotion: 'reduce', serviceWorkers: 'block' });
  context.setDefaultTimeout(12000);
  context.on('page', page => page.on('pageerror', error => {
    const entry = { pageUrl: page.url(), message: error.message, stack: error.stack || null };
    if (page.url().startsWith(root + '/')) receipt.pageErrors.push(entry);
    else receipt.externalPageErrors.push(entry);
  }));
  context.on('request', request => {
    if (new URL(request.url()).origin === root && !['GET', 'HEAD', 'OPTIONS'].includes(request.method())) receipt.firstPartyMutations.push({ url: request.url(), method: request.method() });
  });
  return context;
}
async function noOverflow(page) { assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'horizontal document overflow'); }
async function capture(page, name, evidence, fullPage = true) {
  await page.evaluate(async full => { await document.fonts.ready; if (full) scrollTo(0, 0); }, fullPage);
  await page.waitForTimeout(200);
  await noOverflow(page);
  const target = path.join(output, name + '.png');
  await page.screenshot({ path: target, fullPage, animations: 'disabled' });
  receipt.screenshots.push({ name, path: target, viewport: page.viewportSize(), fullPage, evidence });
}
async function home(page) {
  if (page.url() === root + '/#/home') await page.reload();
  else await page.goto(root + '/#/home');
  await page.getByRole('heading', { name: 'What’s worth buying?', exact: true }).waitFor();
}
async function shortlist(page) { await page.getByRole('button', { name: 'Review NVDA, rank 1', exact: true }).waitFor(); }
async function selectedNames(page) { return page.locator('.pick-title strong').allTextContents(); }
async function provider(page, kind, targetSymbol) {
  const host = page.locator(kind === 'chart' ? '.pick-detail .leo-tv-frame' : '.explore-markets .leo-tv-frame');
  await host.waitFor();
  const deadline = Date.now() + 30000;
  let last = '';
  while (Date.now() < deadline) {
    const outer = await (await host.elementHandle())?.contentFrame();
    const nested = outer?.childFrames().find(frame => frame.url().includes(kind === 'chart' ? '/advanced-chart/' : '/embed-widget/'));
    if (nested) try {
      const body = await nested.locator('body').innerText({ timeout: 800 });
      last = body.slice(0, 400);
      if (kind === 'chart') {
        const canvases = await nested.locator('canvas').count();
        if (canvases && /Vol/.test(body)) {
          const hash = JSON.parse(decodeURIComponent(new URL(nested.url()).hash.slice(1)));
          if (targetSymbol) assert.equal(hash.symbol, targetSymbol);
          return { frame: nested, observation: { kind, symbol: hash.symbol, canvases, providerPath: new URL(nested.url()).pathname } };
        }
      } else {
        const rows = await nested.locator('tbody tr').count();
        if (rows > 0 && /MATCHES/i.test(body)) return { frame: nested, observation: { kind, rows, providerPath: new URL(nested.url()).pathname, toolbar: /Filters/.test(body) } };
      }
    } catch (error) { last = String(error); }
    await page.waitForTimeout(250);
  }
  throw new Error('Provider did not render ' + kind + ': ' + last);
}
async function frameIsolation(page) {
  const outer = await (await page.locator('.explore-markets .leo-tv-frame').elementHandle()).contentFrame();
  assert(await outer.evaluate(() => { try { void parent.localStorage; return false; } catch (error) { return error instanceof DOMException && error.name === 'SecurityError'; } }));
}
async function observeMobileChart(page) {
  await page.locator('.pick-detail .leo-tv[data-widget-state="embedded"]').waitFor({ timeout: 22000 });
  await page.waitForTimeout(700);
  const outer = await (await page.locator('.pick-detail .leo-tv-frame').elementHandle()).contentFrame();
  const frame = outer?.childFrames().find(frame => frame.url().includes('/advanced-chart/'));
  assert(frame, 'provider chart frame missing');
  const body = await frame.locator('body').innerText();
  const observation = { kind: 'mobile chart presentation', providerPath: new URL(frame.url()).pathname, canvases: await frame.locator('canvas').count(), statusText: body.slice(0, 300), quoteObservation: /∅/.test(body) ? 'Provider OHLC unavailable; no local quote fallback' : /Vol/.test(body) ? 'Volume label observed; quote accuracy not asserted' : 'Quote availability not asserted' };
  receipt.providerObservations.push(observation);
  return observation;
}
async function market(page, name, keyboard = false) {
  const tab = page.getByRole('tab', { name, exact: true });
  if (keyboard) { await tab.focus(); await page.keyboard.press('Enter'); } else await tab.click();
  await page.waitForFunction(name => [...document.querySelectorAll('.explore-tabs [role=tab]')].some(element => element.textContent === name && element.getAttribute('aria-selected') === 'true'), name);
  assert.equal(await page.locator('.explore-markets .leo-tv-frame').count(), 1);
}

async function completeFirstMobilePass() {
  Object.assign(receipt, JSON.parse(await fs.readFile(path.join(output, 'browser-checks.json'), 'utf8')));
  browser = await chromium.launch({ headless: true });
  try {
    const mobile = await context({ width: 390, height: 844 });
    const phone = await mobile.newPage();
    await check('Mobile controls completed after the separately recorded external quote-availability failure', async () => {
      await home(phone); await shortlist(phone);
      await observeMobileChart(phone);
      await capture(phone, 'mobile-home', 'Actual retained shortlist and provider chart presentation; provider OHLC availability recorded separately');
      const candidate = phone.getByRole('button', { name: 'Review ZM, rank 2', exact: true });
      await candidate.focus(); await phone.keyboard.press('Enter');
      await phone.waitForFunction(() => document.activeElement?.textContent === 'A closer look at ZM');
      await observeMobileChart(phone);
      const heading = await phone.locator('.pick-detail h2').boundingBox();
      assert(heading && heading.y >= 0 && heading.y < 300);
      await capture(phone, 'mobile-candidate', 'Actual ZM candidate selected by keyboard; provider OHLC availability recorded separately', false);
      await phone.getByRole('button', { name: 'Back to shortlist', exact: true }).click();
      assert(await candidate.evaluate(element => document.activeElement === element));
      const bounds = await candidate.boundingBox(); assert(bounds && bounds.y >= 0 && bounds.y < 844);
      await noOverflow(phone);
    });
    await check('Past review deadline keeps Historical labels visible independently of provider quote availability', async () => {
      const old = JSON.parse(await fs.readFile(path.resolve(__dirname, '../data/shortlist.json'), 'utf8'));
      old.reviewAfter = '2000-01-01T00:00:00Z';
      await mobile.route('**/data/shortlist.json', route => route.fulfill({ json: old }));
      await home(phone); await shortlist(phone);
      assert.deepEqual(await phone.locator('.pick-verdict>span:first-child').allTextContents(), ['Historical', 'Historical', 'Historical']);
      await observeMobileChart(phone);
      await capture(phone, 'mobile-stale', 'Injected past reviewAfter; retained values remain dated and provider OHLC availability is recorded separately');
      receipt.injections.push({ kind: 'past reviewAfter', injectedValue: old.reviewAfter });
    });
    await mobile.close();
  } finally { await browser.close(); await fs.writeFile(path.join(output, 'browser-checks.json'), JSON.stringify(receipt, null, 2) + '\n'); }
}

(async () => {
  if (process.argv.includes('--complete-mobile-first-pass')) { await completeFirstMobilePass(); return; }
  await fs.mkdir(output, { recursive: true });
  const fixture = JSON.parse(await fs.readFile(path.resolve(__dirname, '../data/shortlist.json'), 'utf8'));
  const storageSource = await fs.readFile(path.resolve(__dirname, '../storage.ts'), 'utf8');
  const storageKey = storageSource.match(/STORAGE_KEY\s*=\s*['"]([^'"]+)/)?.[1];
  assert(storageKey, 'journal storage key remains discoverable');
  browser = await chromium.launch({ headless: true });
  try {
    const desktop = await context();
    const page = await desktop.newPage();
    await check('Picks starts with three dated ranked companies and concise navigation without a tape', async () => {
      await home(page); await shortlist(page);
      assert.deepEqual(await selectedNames(page), ['NVDA', 'ZM', 'AMZN']);
      await page.getByText('Snapshot · Sep 4, 2026', { exact: true }).waitFor();
      const nav = page.getByRole('navigation', { name: 'Main navigation', exact: true });
      for (const label of ['Picks', 'Markets', 'My plans']) await nav.getByRole('link', { name: label, exact: true }).waitFor();
      await nav.locator('summary').filter({ hasText: 'Tools' }).waitFor();
      assert.equal(await page.locator('.leo-tv--tape,.leo-tv-static').count(), 0);
      const { observation } = await provider(page, 'chart', 'NASDAQ:NVDA'); receipt.providerObservations.push(observation);
      await capture(page, 'desktop-home', 'Actual retained September 4 shortlist with a separately hosted NVDA chart');
    });
    await check('Candidate selection changes the real chart; stock/fund controls and all five companies remain usable', async () => {
      await page.getByRole('button', { name: 'Review ZM, rank 2', exact: true }).focus(); await page.keyboard.press('Enter');
      await page.getByRole('heading', { name: 'A closer look at ZM', exact: true }).waitFor();
      const { observation } = await provider(page, 'chart', 'NASDAQ:ZM'); receipt.providerObservations.push(observation);
      await page.getByRole('button', { name: /^ETFs & funds/ }).click();
      assert.deepEqual(await selectedNames(page), fixture.funds.map(row => row.symbol));
      await page.getByRole('button', { name: /^Stocks/ }).click(); await shortlist(page);
      await page.getByRole('button', { name: 'Compare all 5 stocks', exact: true }).click();
      assert.deepEqual(await selectedNames(page), fixture.stocks.map(row => row.symbol));
      await page.getByRole('button', { name: 'Show the shortlist', exact: true }).click();
      assert.equal((await selectedNames(page)).length, 3);
    });
    await check('Methods open in place and the selected symbol reaches plans without replacing saved browser records', async () => {
      const oldUrl = page.url();
      await page.getByRole('link', { name: 'How we choose', exact: true }).click();
      assert.equal(page.url(), oldUrl);
      assert.equal(await page.locator('#picks-method').getAttribute('open'), '');
      assert(await page.locator('#picks-method summary').evaluate(element => element === document.activeElement));
      await page.getByRole('button', { name: 'Review AMZN, rank 3', exact: true }).click();
      const record = [{ id: 'picks-ui-fixture', kind: 'positions', symbol: 'TEST', date: '2026-09-04', session: 'After close', thesis: 'Injected local QA record', source: '', reference: '', status: 'open', review: '' }];
      const frozen = JSON.stringify(record);
      await page.evaluate(({ key, value }) => localStorage.setItem(key, value), { key: storageKey, value: frozen });
      await page.getByRole('link', { name: 'Make a plan for AMZN', exact: true }).click();
      await page.getByLabel('Symbol', { exact: true }).waitFor();
      assert.match(page.url(), /#\/positions\?symbol=AMZN$/);
      assert.equal(await page.getByLabel('Symbol', { exact: true }).inputValue(), 'AMZN');
      assert.equal(await page.evaluate(key => localStorage.getItem(key), storageKey), frozen);
      receipt.injections.push({ kind: 'browser storage', purpose: 'Isolated seeded record to verify navigation preservation; no user record altered' });
    });
    await check('Markets stocks, crypto, and forex render provider-owned rows in one isolated frame at a time', async () => {
      await page.goto(root + '/#/board');
      await page.getByRole('heading', { name: 'Markets', exact: true }).waitFor();
      for (const name of ['Stocks', 'Crypto', 'Forex']) {
        await market(page, name, name === 'Forex');
        const { frame, observation } = await provider(page, 'screener');
        if (name !== 'Crypto') assert(observation.toolbar, name + ' provider toolbar missing');
        await frameIsolation(page);
        receipt.providerObservations.push({ market: name, ...observation });
        assert.equal(await page.locator('.leo-tv--tape,.leo-tv-static').count(), 0);
        if (name === 'Stocks') {
          await capture(page, 'desktop-markets', 'Actual TradingView stock screener rows; ordering is provider-owned');
          const before = await frame.locator('input:visible').count();
          await frame.getByText('Filters', { exact: true }).click();
          await page.waitForTimeout(300);
          const visibleInputs = await frame.locator('input:visible').count();
          const dialogs = await frame.locator('[role=dialog]:visible').count();
          assert(visibleInputs > before || dialogs > 0, 'Stock Filters did not expose a filter editor');
          await page.keyboard.press('Escape');
        }
      }
    });
    await check('Markets exposes the selected full screener and opens its official destination', async () => {
      const destinations = { Stocks: 'https://www.tradingview.com/screener/', Crypto: 'https://www.tradingview.com/crypto-coins-screener/', Forex: 'https://www.tradingview.com/forex-screener/' };
      for (const [name, href] of Object.entries(destinations)) {
        await market(page, name);
        const link = page.getByRole('link', { name: 'Open full screener', exact: true });
        assert.equal(await link.getAttribute('href'), href);
        assert.equal(await link.getAttribute('target'), '_blank');
        assert.match(await link.getAttribute('rel'), /noopener/);
      }
      assert.equal(await page.locator('.explore-search').count(), 0);
      const pending = page.waitForEvent('popup');
      await page.getByRole('link', { name: 'Open full screener', exact: true }).click();
      const popup = await pending;
      await popup.waitForURL(url => url.origin === 'https://www.tradingview.com' && url.pathname === '/forex-screener/', { waitUntil: 'domcontentloaded' });
      assert.equal(await popup.evaluate(() => window.opener === null), true);
      await popup.close();
    });
    await check('Injected screener bootstrap failure exposes Retry and recovers with the actual provider', async () => {
      const pattern = 'https://s3.tradingview.com/external-embedding/embed-widget-screener.js';
      const block = route => route.abort('failed');
      await desktop.route(pattern, block);
      await market(page, 'Stocks');
      await page.getByRole('button', { name: 'Retry', exact: true }).waitFor({ timeout: 22000 });
      assert.equal(await page.locator('.explore-markets .leo-tv').getAttribute('data-widget-state'), 'unavailable');
      await desktop.unroute(pattern, block);
      await page.getByRole('button', { name: 'Retry', exact: true }).click();
      const { observation } = await provider(page, 'screener');
      receipt.injections.push({ kind: 'provider bootstrap outage', recoveredWith: observation });
    });
    await desktop.close();

    const mobile = await context({ width: 390, height: 844 });
    const phone = await mobile.newPage();
    await check('Mobile Picks exposes the dated shortlist; keyboard candidate selection reveals evidence and returns focus', async () => {
      await home(phone); await shortlist(phone); await observeMobileChart(phone);
      await capture(phone, 'mobile-home', 'Actual dated shortlist and hosted default chart presentation at 390px; quote availability recorded separately');
      const candidate = phone.getByRole('button', { name: 'Review ZM, rank 2', exact: true });
      await candidate.focus(); await phone.keyboard.press('Enter');
      await phone.waitForFunction(() => document.activeElement?.textContent === 'A closer look at ZM');
      const { observation } = await provider(phone, 'chart', 'NASDAQ:ZM');
      receipt.providerObservations.push({ device: 'mobile', ...observation });
      const heading = await phone.locator('.pick-detail h2').boundingBox();
      assert(heading && heading.y >= 0 && heading.y < 300, 'Selected mobile detail was not brought into view');
      await capture(phone, 'mobile-candidate', 'Actual ZM candidate selected by keyboard; viewport shows supporting detail', false);
      await phone.getByRole('button', { name: 'Back to shortlist', exact: true }).click();
      assert(await candidate.evaluate(element => document.activeElement === element));
      const bounds = await candidate.boundingBox(); assert(bounds && bounds.y >= 0 && bounds.y < 844);
      await phone.keyboard.press('Enter');
      await phone.waitForFunction(() => document.activeElement?.textContent === 'A closer look at ZM');
      const repeat = await phone.locator('.pick-detail h2').boundingBox();
      assert(repeat && repeat.y >= 0 && repeat.y < 300, 'Reselecting the same candidate did not reveal its detail');
      await phone.getByRole('button', { name: 'Back to shortlist', exact: true }).click();
      assert(await candidate.evaluate(element => document.activeElement === element));
      await noOverflow(phone);
    });
    await check('Mobile Markets keeps keyboard tabs and a settled screener within the viewport', async () => {
      await phone.goto(root + '/#/board');
      await market(phone, 'Stocks'); await provider(phone, 'screener');
      await capture(phone, 'mobile-markets', 'Actual hosted stock screener; provider handles its own table scrolling');
      await phone.getByRole('tab', { name: 'Stocks', exact: true }).focus();
      await phone.keyboard.press('ArrowRight');
      await phone.waitForFunction(() => document.activeElement?.textContent === 'Crypto' && document.activeElement?.getAttribute('aria-selected') === 'true');
      await provider(phone, 'screener');
      assert.equal(await phone.locator('.explore-markets .leo-tv-frame').count(), 1);
      await noOverflow(phone);
    });
    await check('Injected initial shortlist outage has no suggestions and Retry restores the evidence', async () => {
      const block = route => route.fulfill({ status: 503, body: 'Injected shortlist outage' });
      await mobile.route('**/data/shortlist.json', block);
      await home(phone);
      await phone.getByRole('heading', { name: 'The shortlist is unavailable.', exact: true }).waitFor();
      assert.equal(await phone.locator('.pick-select').count(), 0);
      await capture(phone, 'mobile-error', 'Deliberately injected initial shortlist 503; suggestions fail closed');
      await mobile.unroute('**/data/shortlist.json', block);
      await phone.getByRole('button', { name: 'Try again', exact: true }).click(); await shortlist(phone);
      receipt.injections.push({ kind: 'initial shortlist 503', recovery: 'Successful request for actual retained artifact' });
    });
    await check('Injected refresh failure retains the prior dated shortlist', async () => {
      const before = await selectedNames(phone);
      const block = route => route.fulfill({ status: 503, body: 'Injected refresh failure' });
      await mobile.route('**/data/shortlist.json', block);
      await phone.getByRole('button', { name: 'Refresh shortlist', exact: true }).click();
      await phone.getByRole('alert').filter({ hasText: 'The previous dated list remains below.' }).waitFor();
      assert.deepEqual(await selectedNames(phone), before);
      await phone.getByText('Snapshot · Sep 4, 2026', { exact: true }).waitFor();
      await mobile.unroute('**/data/shortlist.json', block);
      receipt.injections.push({ kind: 'shortlist refresh 503', priorValuesRetained: before });
    });
    await check('Other archived data outages do not block Picks or Markets', async () => {
      const block = async route => {
        if (new URL(route.request().url()).pathname.endsWith('/shortlist.json')) await route.continue();
        else await route.fulfill({ status: 503, body: 'Injected archived research outage' });
      };
      await mobile.route('**/app/research-desk/data/**', block);
      await home(phone); await shortlist(phone);
      assert.deepEqual(await selectedNames(phone), ['NVDA', 'ZM', 'AMZN']);
      await phone.goto(root + '/#/positions?symbol=NVDA');
      await phone.getByLabel('Symbol', { exact: true }).waitFor();
      assert.equal(await phone.getByLabel('Symbol', { exact: true }).inputValue(), 'NVDA');
      await phone.goto(root + '/#/board'); await provider(phone, 'screener');
      await mobile.unroute('**/app/research-desk/data/**', block);
      receipt.injections.push({ kind: 'archived JSON 503', exception: 'Actual shortlist still served', unaffected: ['Picks', 'My plans', 'Markets'] });
    });
    await check('An injected past review deadline labels the retained ranks Historical', async () => {
      const old = structuredClone(fixture); old.reviewAfter = '2000-01-01T00:00:00Z';
      const inject = route => route.fulfill({ json: old });
      await mobile.route('**/data/shortlist.json', inject);
      await home(phone); await shortlist(phone);
      assert.deepEqual(await phone.locator('.pick-verdict>span:first-child').allTextContents(), ['Historical', 'Historical', 'Historical']);
      await phone.getByText('This snapshot needs a refresh before a new buy decision. The historical ranking is retained below.', { exact: true }).waitFor();
      await observeMobileChart(phone);
      await capture(phone, 'mobile-stale', 'Injected past reviewAfter timestamp; prices and ranks remain the unchanged retained artifact');
      await mobile.unroute('**/data/shortlist.json', inject);
      receipt.injections.push({ kind: 'past reviewAfter', injectedValue: old.reviewAfter });
    });
    await check('A future-dated artifact fails closed rather than producing suggestions', async () => {
      const future = structuredClone(fixture); future.asOf = new Date(Date.now() + 86400000).toISOString().slice(0, 10);
      for (const row of [...future.stocks, ...future.funds]) row.asOf = future.asOf;
      const inject = route => route.fulfill({ json: future });
      await mobile.route('**/data/shortlist.json', inject);
      await home(phone);
      await phone.getByRole('heading', { name: 'The shortlist is unavailable.', exact: true }).waitFor();
      assert.equal(await phone.locator('.pick-select,.pick-detail').count(), 0);
      receipt.injections.push({ kind: 'future asOf', injectedValue: future.asOf, expectation: 'No suggestions' });
      await mobile.unroute('**/data/shortlist.json', inject);
    });
    await mobile.close();
    await check('No first-party mutating request was issued during the workflow', async () => { assert.deepEqual(receipt.firstPartyMutations, []); });
  } finally {
    await browser.close();
    receipt.firstPassEvidence = 'first-pass-browser-checks.json retains the original search redirect, mobile provider availability failures, and unattributed React errors.';
    receipt.corrections = ['Removed the symbol-query form that redirected and lost its query; selected full-screener destinations are explicit.', 'Repeated mobile selection now retriggers heading focus and scrolling after returning to the shortlist.', 'My plans opens independently of archived market JSON availability.', 'Mobile interaction checks observe provider presentation separately from unavailable OHLC; no blank provider values are claimed as quotes.', 'Errors now retain page URL and stack. External top-level-page errors are recorded separately, rather than discarded.'];
    await fs.writeFile(path.join(output, 'browser-checks.json'), JSON.stringify(receipt, null, 2) + '\n');
  }
  if (receipt.failures.length || receipt.pageErrors.length) process.exitCode = 1;
})().catch(error => { console.error(error); process.exitCode = 1; });
