const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const { chromium } = require(process.env.LEO_PLAYWRIGHT_MODULE || 'C:/Users/Hj/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const origin = 'https://leo.axio7.workers.dev';
const stage = path.resolve(__dirname, '../../../../../release-work/leo-auto-picks-20260908');
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
async function feed() { const response = await fetch(origin + '/app/research-desk/data/shortlist-feed/current.json'); assert.equal(response.status, 200); assert.equal(response.headers.get('cache-control'), 'no-store'); return response.json(); }
(async () => {
  const first = await feed();
  const started = Date.now();
  const routes = await Promise.all(['/', '/original/', '/app/', '/pricing', '/strategy-auth/callback'].map(async route => { const response = await fetch(origin + route, { redirect: 'follow' }); assert.equal(response.status, 200); return { route, status: response.status }; }));
  const assets = await Promise.all(['desk.js', 'desk.css'].map(async name => { const response = await fetch(origin + '/app/research-desk/' + name); assert.equal(response.status, 200); const remote = hash(Buffer.from(await response.arrayBuffer())); const local = hash(await fs.readFile(path.join(stage, '.open-next/assets/app/research-desk', name))); assert.equal(remote, local); return { name, sha256: remote }; }));
  const browser = await chromium.launch({ headless: true });
  let visible;
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    await page.goto(origin + '/#/home');
    await page.getByText('Automatic screening is running', { exact: true }).waitFor();
    await page.getByRole('heading', { name: 'Start your research with NVDA.', exact: true }).waitFor();
    visible = { heading: await page.locator('.picks-answer h2').innerText(), stocks: await page.locator('.pick-title strong').allTextContents(), observationLabel: await page.locator('.picks-date').innerText() };
    assert.deepEqual(visible.stocks, ['NVDA', 'ZM', 'AMZN']);
  } finally { await browser.close(); }
  await new Promise(resolve => setTimeout(resolve, Math.max(0, 35000 - (Date.now() - started))));
  const second = await feed();
  assert(Date.parse(second.publisher.heartbeatAt) > Date.parse(first.publisher.heartbeatAt));
  assert.equal(second.publisher.revision, first.publisher.revision);
  assert.equal(second.publisher.publishedAt, first.publisher.publishedAt);
  assert.equal(second.shortlist.asOf, first.shortlist.asOf);
  assert.equal(second.publisher.llmCalls, 0); assert.equal(second.publisher.executionEnabled, false);
  const receipt = { checkedAt: new Date().toISOString(), scope: 'Actual deployed website and authenticated local publisher. Read-only live checks; no broker operation.', routes, assets, visible, firstHeartbeat: first.publisher.heartbeatAt, secondHeartbeat: second.publisher.heartbeatAt, revision: second.publisher.revision, publishedAt: second.publisher.publishedAt, sourceCutoff: second.shortlist.asOf, llmCalls: 0, executionEnabled: false, publisherLocation: 'Current Windows computer; VPS not provisioned', result: 'pass' };
  await fs.writeFile(path.join(stage, 'live-verification.json'), JSON.stringify(receipt, null, 2));
  console.log(JSON.stringify(receipt, null, 2));
})().catch(error => { console.error(error); process.exitCode = 1; });
