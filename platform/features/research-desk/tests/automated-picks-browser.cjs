const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { chromium } = require(process.env.LEO_PLAYWRIGHT_MODULE || 'C:/Users/Hj/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base = process.env.LEO_PREVIEW_URL || 'http://127.0.0.1:3117';
const directory = path.resolve(__dirname, '../../../.impeccable/review/automated-picks');
const feedPath = '/app/research-desk/data/shortlist-feed/current.json';
const receipt = { checkedAt: new Date().toISOString(), base, checks: [], screenshots: [], errors: [], injections: [], scope: 'Actual local Python publication and website integration; injected HTTP/time cases are labeled, no broker or performance claim.' };
async function check(name, action) { try { await action(); receipt.checks.push({ name, result: 'pass' }); } catch (error) { receipt.checks.push({ name, result: 'fail', error: String(error) }); } }
(async () => {
  await fs.mkdir(directory, { recursive: true });
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 }, reducedMotion: 'reduce' });
    page.on('pageerror', e => receipt.errors.push(e.message));
    const current = await (await fetch(base + feedPath)).json();
    await page.goto(base + '/#/home');
    await check('Actual publisher feeds dated NVDA shortlist and explicit reasons', async () => {
      await page.getByText('Automatic screening is running', { exact: true }).waitFor();
      await page.getByRole('heading', { name: 'Start your research with NVDA.', exact: true }).waitFor();
      assert.equal(current.shortlist.stocks[0].symbol, 'NVDA');
      assert.equal(current.publisher.llmCalls, 0);
      assert.equal(current.shortlist.asOf, '2026-09-04');
      assert.deepEqual(await page.locator('.pick-title strong').allTextContents(), ['NVDA', 'ZM', 'AMZN']);
      assert(await page.locator('.picks-date').innerText().then(t => t.includes('Sep 4, 2026')));
    });
    await check('Evidence download contains the displayed shortlist', async () => {
      await page.locator('#picks-method > summary').click();
      const [download] = await Promise.all([page.waitForEvent('download'), page.getByRole('button', { name: 'Download the ranked evidence', exact: true }).click()]);
      const data = JSON.parse(await fs.readFile(await download.path(), 'utf8'));
      assert.equal(data.inputSha256, current.shortlist.inputSha256);
      await page.locator('#picks-method > summary').click();
      await page.evaluate(() => scrollTo(0, 0));
    });
    await page.evaluate(() => document.fonts.ready);
    await page.locator('.pick-detail .leo-tv[data-widget-state="embedded"]').waitFor({ timeout: 25000 });
    await page.waitForTimeout(2000);
    await page.screenshot({ path: path.join(directory, 'desktop.png'), fullPage: false });
    receipt.screenshots.push({ file: 'desktop.png', viewport: { width: 1440, height: 900 }, scope: 'First viewport: decision and automation state' });
    const mobile = await browser.newPage({ viewport: { width: 390, height: 844 }, reducedMotion: 'reduce' });
    await mobile.goto(base + '/#/home');
    await check('Mobile opening and keyboard selection show what to research and why', async () => {
      await mobile.getByRole('heading', { name: 'Start your research with NVDA.', exact: true }).waitFor();
      assert(await mobile.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
      await mobile.evaluate(() => document.fonts.ready);
      await mobile.screenshot({ path: path.join(directory, 'mobile.png') });
      await mobile.getByRole('button', { name: 'Why NVDA', exact: true }).focus();
      await mobile.keyboard.press('Enter');
      assert.equal(await mobile.locator('.pick-detail h2').evaluate(e => e === document.activeElement), true);
      await mobile.locator('.pick-detail .leo-tv[data-widget-state="embedded"]').waitFor({ timeout: 25000 });
      await mobile.waitForTimeout(1500);
      await mobile.screenshot({ path: path.join(directory, 'mobile-detail.png') });
      await mobile.getByRole('button', { name: 'Back to shortlist', exact: true }).click();
      assert(await mobile.locator('.pick-select[aria-pressed="true"]').evaluate(e => e === document.activeElement));
    });
    receipt.screenshots.push({ file: 'mobile.png', viewport: { width: 390, height: 844 }, scope: 'Actual mobile first viewport' }, { file: 'mobile-detail.png', viewport: { width: 390, height: 844 }, scope: 'Supporting chart after keyboard selection; provider quote accuracy not asserted' });
    await check('Lost publisher preserves previous dated values and clears running claim', async () => {
      await page.route('**' + feedPath, route => route.abort());
      await page.getByRole('button', { name: 'Refresh shortlist', exact: true }).click();
      await page.getByText('Saved shortlist', { exact: true }).waitFor();
      assert.equal(await page.locator('.pick-title strong').first().innerText(), 'NVDA');
      await page.unroute('**' + feedPath);
    });
    receipt.injections.push('Browser-only publication request abort; actual worker unchanged.');
    await check('Old publisher heartbeat is visibly interrupted without losing evidence', async () => {
      const stale = structuredClone(current); stale.publisher.heartbeatAt = new Date(Date.now() - 180000).toISOString(); stale.publisher.lastCheckedAt = stale.publisher.heartbeatAt; stale.publisher.publishedAt = new Date(Date.parse(stale.publisher.heartbeatAt) - 1000).toISOString();
      await page.route('**' + feedPath, route => route.fulfill({ json: stale }));
      // A later response cannot rewind an already accepted publisher heartbeat.
      // Load stale evidence as the initial state to test a genuinely old feed.
      await page.reload();
      await page.getByText('Updates interrupted', { exact: true }).waitFor();
      assert.equal(await page.locator('.pick-title strong').first().innerText(), 'NVDA');
      await page.unroute('**' + feedPath);
    });
    receipt.injections.push('Browser-only old heartbeat on retained data.');
    await check('Background refresh runs without a user click', async () => {
      const probe = await browser.newPage({ viewport: { width: 1440, height: 900 } });
      let requests = 0;
      await probe.route('**' + feedPath, route => { requests++; return route.fulfill({ json: current }); });
      await probe.clock.install();
      await probe.goto(base + '/#/home');
      await probe.getByRole('button', { name: 'Review NVDA, rank 1', exact: true }).waitFor();
      await probe.clock.runFor(61000);
      assert(requests >= 2);
      await probe.close();
    });
    receipt.injections.push('Browser clock advanced61seconds with fixed publication response to verifypolltimer, not source freshness.');
  } finally { await browser.close(); await fs.writeFile(path.join(directory, 'browser-checks.json'), JSON.stringify(receipt, null, 2)); }
  console.log(JSON.stringify(receipt, null, 2));
  if (receipt.checks.some(c => c.result !== 'pass') || receipt.errors.length) process.exitCode = 1;
})().catch(error => { console.error(error); process.exitCode = 1; });
