// Read-only production checks. The runtime calendar is never compared with a stale static seed.
const assert = require('node:assert/strict');
const { readFile, writeFile } = require('node:fs/promises');
const { resolve, join } = require('node:path');
const { createHash } = require('node:crypto');
const { validateRadarIntegrity } = require('../radar/contract.ts');
const base = 'https://leo.axio7.workers.dev';

(async () => {
  const stage = resolve(process.argv[2]);
  const manifest = JSON.parse(await readFile(join(stage, 'assets-manifest.json'), 'utf8'));
  const routes = await Promise.all(['/', '/original/', '/app/', '/pricing', '/strategy-auth/callback'].map(async path => {
    const response = await fetch(`${base}${path}`, { redirect: 'follow' });
    const body = await response.text(); assert.equal(response.status, 200, path);
    assert.ok(body.length > 100, path); return { path, status: response.status, bytes: Buffer.byteLength(body) };
  }));
  const assets = await Promise.all(['desk.js', 'desk.css', 'earnings-research-guide.md'].map(async file => {
    const key = `app/research-desk/${file}`; const response = await fetch(`${base}/${key}`); assert.equal(response.status, 200);
    const digest = createHash('sha256').update(Buffer.from(await response.arrayBuffer())).digest('hex');
    assert.equal(digest, manifest[key], file); return { path: key, sha256: digest };
  }));
  const response = await fetch(`${base}/app/research-desk/data/event-radar.json`);
  assert.equal(response.status, 200); assert.equal(response.headers.get('cache-control'), 'no-store');
  const artifact = await validateRadarIntegrity(await response.json());
  const automatic = artifact.sources.filter(source => source.mode === 'automatic');
  const receipt = { checkedAt: new Date().toISOString(), routes, assets, radar: { status: response.status, generatedAt: artifact.generatedAt,
    coverage: artifact.coverage, sources: artifact.sources, records: artifact.records.length, executionEnabled: artifact.executionEnabled,
    predictionEnabled: artifact.predictionEnabled, llmCalls: artifact.llmCalls, actualCronObserved: automatic.length === 2 },
    note: 'Read-only HTTP checks. A successful calendar poll does not establish predictive performance.' };
  await writeFile(join(stage, 'live-verification.json'), JSON.stringify(receipt, null, 2));
  console.log(JSON.stringify({ routes: routes.length, assetHashes: assets.length, events: artifact.events.length,
    automaticSources: automatic.length, failedSources: artifact.coverage.failedSourceCount, actualCronObserved: receipt.radar.actualCronObserved }, null, 2));
})().catch(error => { console.error(error); process.exitCode = 1; });
