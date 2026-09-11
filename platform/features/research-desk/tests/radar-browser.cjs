const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { chromium } = require(process.env.LEO_PLAYWRIGHT_MODULE || 'C:/Users/Hj/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base = process.env.LEO_PREVIEW_URL || 'http://127.0.0.1:3117';
const dir = path.resolve(__dirname, '../../../.impeccable/review/event-radar');
const receipt = { checkedAt: new Date().toISOString(), base, checks: [], errors: [], scope: 'Real compiled official-calendar artifact; injected HTTP faults and fictional imported reports are explicitly labeled. No broker or market-performance test.' };
async function check(name, action) { try { await action(); receipt.checks.push({ name, result: 'pass' }); } catch (error) { receipt.checks.push({ name, result: 'fail', error: String(error) }); } }
(async () => {
  await fs.mkdir(dir, { recursive: true });
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 960 }, reducedMotion: 'reduce' });
    page.on('pageerror', error => receipt.errors.push(error.message));
    const requests = [];
    page.on('request', request => requests.push({ method: request.method(), url: request.url() }));
    await page.goto(base + '/#/radar');
    await check('Official calendar loads independently of archived chart data', async () => {
      await page.getByRole('heading', { name: 'What could move the market?' }).waitFor();
      await page.locator('.radar-event').first().waitFor();
      assert((await page.locator('.radar-event').count()) > 0);
      await page.route('**/data/desk-data.json', route => route.fulfill({ status: 503, body: 'Injected archive outage' }));
      await page.reload(); await page.locator('.radar-event').first().waitFor();
      assert(await page.locator('.radar-detail .radar-detail-title h2').isVisible());
    });
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: path.join(dir, 'desktop.png'), fullPage: false });
    await check('Earnings call keeps issuer time, link and symbol into a saved plan', async () => {
      await page.getByRole('button', { name: 'Earnings', exact: true }).click();
      await page.getByRole('button').filter({ hasText: /Micron/ }).click();
      assert((await page.locator('.radar-detail').innerText()).includes('call'));
      assert((await page.locator('.radar-detail').innerText()).includes('4:30 PM ET'));
      await page.getByRole('link', { name: 'Make a trade plan', exact: true }).click();
      await page.getByLabel('Symbol', { exact: true }).waitFor();
      assert.equal(await page.getByLabel('Symbol', { exact: true }).inputValue(), 'MU');
      assert.match(await page.getByLabel('Thesis and invalidation conditions').inputValue(), /Micron/);
      assert.match(await page.getByLabel('Primary source (HTTPS, optional)').inputValue().catch(() => page.getByLabel('Primary source').inputValue()).catch(() => page.locator('input[type=url]').inputValue()), /investors\.micron\.com/);
      await page.getByRole('button', { name: 'Save in this browser' }).click();
      assert((await page.locator('.journal-list').innerText()).includes('MU'));
    });
    await page.goto(base + '/#/radar'); await page.locator('.radar-event').first().waitFor();
    await check('Decision day uses exact timestamp and earnings import stays local', async () => {
      assert.match(await page.locator('.radar-event').filter({ hasText: 'FOMC policy decision' }).innerText(), /Sep 16, 2026/);
      await page.locator('.earnings-comparison > summary').click();
      const report = { schema_version: 'leo-earnings-comparison.v1', feature_version: 'earnings-comparison-1.0.0', status: 'unavailable', symbol: 'TEST', as_of: '2026-09-09T19:59:00Z', event_at: '2026-09-10T21:00:00Z', reason_codes: ['option_quotes_unavailable'], comparison: null, sources: [], input_sha256: 'a'.repeat(64), prediction_enabled: false, execution_enabled: false, limitations: ['FICTIONAL browser test; not market evidence.'] };
      await page.getByLabel('Import earnings research report').setInputFiles({ name: 'fictional-test.json', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify(report)) });
      await page.getByRole('heading', { name: 'TEST · imported research' }).waitFor();
      assert(await page.getByRole('heading', { name: 'Comparison unavailable' }).isVisible());
      await page.getByLabel('Import earnings research report').setInputFiles({ name: 'invalid.json', mimeType: 'application/json', buffer: Buffer.from('{}') });
      assert(await page.getByRole('heading', { name: 'TEST · imported research' }).isVisible());
      await page.getByRole('button', { name: 'Clear report' }).click();
      await page.locator('.earnings-comparison > summary').click();
    });
    await check('Evidence assistant explains limitations and refuses unsupported questions without paid calls', async () => {
      await page.getByRole('button', { name: 'Can you predict this?', exact: true }).click();
      assert((await page.locator('.radar-answer').innerText()).includes('unvalidated'));
      await page.getByLabel('Ask about this event, its source, or the trading workflow').fill('Write a poem about the moon');
      await page.getByRole('button', { name: 'Ask Astra', exact: true }).click();
      assert((await page.locator('.radar-answer').innerText()).includes('not in this evidence'));
      assert.equal(requests.filter(request => request.method !== 'GET').length, 0);
    });
    await check('Failed calendar refresh retains visible last good dates', async () => {
      const before = await page.locator('.radar-event').allTextContents();
      await page.route('**/data/event-radar.json', route => route.fulfill({ status: 503, body: 'Injected calendar outage' }));
      await page.getByRole('button', { name: 'Refresh calendar', exact: true }).click();
      await page.getByRole('alert').waitFor();
      assert.deepEqual(await page.locator('.radar-event').allTextContents(), before);
      await page.unroute('**/data/event-radar.json');
    });
    await check('Evidence download is the displayed calendar, without quotes or execution', async () => {
      await page.locator('.radar-sources').filter({ hasText: 'Sources, coverage & research record' }).locator('summary').click();
      const [file] = await Promise.all([page.waitForEvent('download'), page.getByRole('button', { name: 'Download the evidence', exact: true }).click()]);
      const value = JSON.parse(await fs.readFile(await file.path(), 'utf8'));
      assert.equal(value.schemaVersion, 'astra-event-radar.v1'); assert.equal(value.executionEnabled, false); assert.equal(value.llmCalls, 0);
    });
    await check('Forecast record works during archive outage and publishes no invented wins', async () => {
      await page.goto(base + '/#/forecast');
      await page.getByRole('heading', { name: 'No published hypotheses or scored outcomes yet.' }).waitFor();
      assert(await page.getByRole('heading', { name: 'No validated direction model is published.' }).isVisible());
    });
    const mobile = await browser.newPage({ viewport: { width: 390, height: 844 }, reducedMotion: 'reduce' });
    mobile.on('pageerror', error => receipt.errors.push(error.message));
    await mobile.goto(base + '/#/radar'); await mobile.locator('.radar-event').first().waitFor(); await mobile.evaluate(() => document.fonts.ready);
    await mobile.screenshot({ path: path.join(dir, 'mobile.png'), fullPage: false });
    await check('Mobile calendar and keyboard detail selection stay within viewport', async () => {
      assert(await mobile.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
      await mobile.locator('.radar-event').first().focus(); await mobile.keyboard.press('Enter');
      assert(await mobile.locator('.radar-detail h2').evaluate(element => document.activeElement === element));
      assert(await mobile.getByRole('button', { name: 'Back to calendar' }).evaluate(element => element.getBoundingClientRect().top >= 0));
      await mobile.screenshot({ path: path.join(dir, 'mobile-detail.png'), fullPage: false });
      await mobile.getByRole('button', { name: 'Back to calendar' }).click();
      assert(await mobile.locator('.radar-event[aria-pressed=true]').evaluate(element => document.activeElement === element));
    });
    await mobile.close();
  } finally {
    await browser.close(); await fs.writeFile(path.join(dir, 'browser-checks.json'), JSON.stringify(receipt, null, 2));
    console.log(JSON.stringify(receipt, null, 2));
    if (receipt.checks.some(check => check.result === 'fail') || receipt.errors.length) process.exitCode = 1;
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
