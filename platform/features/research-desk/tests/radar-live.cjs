const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { chromium } = require(process.env.LEO_PLAYWRIGHT_MODULE || 'C:/Users/Hj/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const base = 'https://leo.axio7.workers.dev';
const output = path.resolve(__dirname, '../../../.impeccable/review/event-radar/live-verification.json');
const receipt = { checkedAt: new Date().toISOString(), base, scope: 'Read-only production verification. No injected data, orders or authentication changes.', checks: [], errors: [] };
async function check(name, fn) { try { receipt.checks.push({ name, result: 'pass', evidence: await fn() }); } catch (error) { receipt.checks.push({ name, result: 'fail', error: String(error) }); } }
(async () => {
  await check('Public root, original app, billing, auth callback and guide preserved', async () => {
    const statuses = await Promise.all(['/', '/original/', '/app/', '/pricing', '/strategy-auth/callback', '/app/research-desk/earnings-research-guide.md'].map(async route => { const response = await fetch(base + route); await response.arrayBuffer(); assert.equal(response.status, 200, route); return { route, status: response.status }; })); return statuses;
  });
  await check('Deployed JavaScript and CSS match the reviewed local build', async () => {
    const hashes = [];
    for (const name of ['desk.js', 'desk.css']) {
      const response = await fetch(`${base}/app/research-desk/${name}`); assert.equal(response.status, 200);
      const actual = createHash('sha256').update(Buffer.from(await response.arrayBuffer())).digest('hex');
      const expected = createHash('sha256').update(await fs.readFile(path.resolve(__dirname, '../../../public/app/research-desk', name))).digest('hex');
      assert.equal(actual, expected); hashes.push({ name, sha256: actual });
    } return hashes;
  });
  await check('Same-origin calendar feed supplies source facts without predictions', async () => {
    const value = await (await fetch(base + '/app/research-desk/data/event-radar.json')).json();
    assert.equal(value.schemaVersion, 'astra-event-radar.v1'); assert.equal(value.predictionEnabled, false); assert.equal(value.executionEnabled, false); assert.equal(value.llmCalls, 0);
    assert(value.events.some(event => event.symbols.includes('MU')));
    return { generatedAt: value.generatedAt, eventCount: value.events.length, sources: value.sources.map(source => ({ id: source.id, mode: source.mode, state: source.state, lastAttemptAt: source.lastAttemptAt, retrievedAt: source.retrievedAt })) };
  });
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 960 }, reducedMotion: 'reduce' });
    page.on('pageerror', error => receipt.errors.push(error.message));
    await check('Production radar, named-company explanation and chart destinations render', async () => {
      await page.goto(base + '/#/radar'); await page.locator('.radar-event').first().waitFor();
      await page.getByLabel('Ask about this event, its source, or the trading workflow').fill('Explain Micron');
      await page.getByRole('button', { name: 'Ask Astra', exact: true }).click();
      assert.match(await page.locator('.radar-answer h3').innerText(), /Micron/);
      for (const symbol of ['MU', 'ADBE']) {
        await page.goto(`${base}/#/structure?symbol=${symbol}`);
        await page.locator('.leo-tv[data-widget-state="embedded"]').waitFor({ timeout: 30000 });
        assert.equal(await page.locator('.leo-tv-unmapped').count(), 0);
        assert.match(await page.locator('.market-chart-heading').innerText(), symbol === 'MU' ? /Micron/ : /Adobe/);
      }
      return { charts: ['NASDAQ:MU', 'NASDAQ:ADBE'], widgetScope: 'Official embed loaded; no raw quote or execution claim.' };
    });
    await check('Homepage retains dated stock ranking and links to radar', async () => {
      await page.goto(base + '/#/home'); await page.locator('.picks-answer h2').waitFor();
      assert.match(await page.locator('.picks-answer h2').innerText(), /last recorded screen/);
      assert(await page.getByRole('link', { name: 'Radar', exact: true }).isVisible());
      return { heading: await page.locator('.picks-answer h2').innerText() };
    });
  } finally { await browser.close(); }
  await fs.writeFile(output, JSON.stringify(receipt, null, 2)); console.log(JSON.stringify(receipt, null, 2));
  if (receipt.checks.some(check => check.result === 'fail') || receipt.errors.length) process.exitCode = 1;
})().catch(error => { console.error(error); process.exitCode = 1; });
