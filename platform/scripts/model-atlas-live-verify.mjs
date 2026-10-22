/** Read-only verification of the released atlas and retained Leo application. */
import { readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';
import { parseArgs } from 'node:util';

const { values } = parseArgs({ options: {
  stage: { type: 'string' }, output: { type: 'string' },
} });
if (!values.stage) throw new Error('--stage must name the finalized release directory');
const stage = resolve(values.stage);
const output = resolve(values.output ?? `${stage}/model-atlas-live-verification.json`);
const manifest = JSON.parse(await readFile(`${stage}/assets-manifest.json`, 'utf8'));
const receipt = JSON.parse(await readFile(`${stage}/stage-receipt.json`, 'utf8'));
if (receipt.schema !== 'leo-model-atlas-stage/v1' || receipt.status === 'prepared-baseline') {
  throw new Error('Finalize the atlas overlay before verifying the deployed release');
}
const selected = [
  'app/research-desk/desk.js', 'app/research-desk/desk.css',
  'app/research-desk/data/model-atlas.json', 'app/research-desk/index.html',
  'app/research-desk/strategy-config.json', 'app/jev/jev.js', 'app/jev/jev.css', 'logo.png',
];
for (const path of selected) {
  if (!/^[a-f0-9]{64}$/.test(manifest[path] ?? '')) throw new Error(`Missing final manifest asset: ${path}`);
}
const origins = ['https://leo.axio7.workers.dev', 'https://axio7.com', 'https://www.axio7.com'];
const routeCases = [
  ['/', 200], ['/app/research-desk/', 200], ['/original/', 200],
  ['/app/?preview=1', 200], ['/pricing', 200], ['/api/health', 200], ['/jev', 200],
  ['/api/quant/intraday/research/market-assessment?with_jev=true', 401],
  ['/api/quant/intraday/research/market-assessment?url=https%3A%2F%2Fexample.com', 400],
];

function contentHash(body) {
  let normalized = 0;
  // The retained custom-domain verifier allows only this exact Cloudflare tag.
  // No other markup, whitespace, metadata, or script is removed before hashing.
  if (body.subarray(0, 15).toString('utf8').toLowerCase() === '<!doctype html>') {
    const text = body.toString('utf8').replace(
      /<script type="module" src="https:\/\/static\.cloudflareinsights\.com\/beacon\.min\.js\/[^"\s]+" integrity="[^"\s]+" data-cf-beacon='[^']+' crossorigin="anonymous"><\/script>\n/g,
      () => { normalized += 1; return ''; },
    );
    if (normalized > 1) throw new Error('Unexpected multiple Cloudflare analytics tags');
    body = Buffer.from(text);
  }
  return { sha256: createHash('sha256').update(body).digest('hex'), analyticsTagsRemoved: normalized };
}

async function request(origin, path) {
  const response = await fetch(`${origin}${path}`, {
    redirect: 'manual', cache: 'no-store', signal: AbortSignal.timeout(30_000),
    headers: { 'Cache-Control': 'no-cache' },
  });
  return { response, body: Buffer.from(await response.arrayBuffer()) };
}

async function checkAsset(origin, path) {
  try {
    let { response, body } = await request(origin, `/${path}`);
    let canonicalRedirect;
    if (path === 'app/research-desk/index.html' && [307, 308].includes(response.status)) {
      const location = new URL(response.headers.get('location'), origin);
      if (location.origin !== origin || location.pathname !== '/app/research-desk/' || location.search) {
        throw new Error('Unexpected HTML canonical redirect');
      }
      canonicalRedirect = { status: response.status, path: location.pathname };
      ({ response, body } = await request(origin, location.pathname));
    }
    const hash = contentHash(body);
    let atlas;
    if (path.endsWith('/model-atlas.json') && response.status === 200) {
      const data = JSON.parse(body.toString('utf8'));
      atlas = {
        schemaVersion: data.schemaVersion, dataMode: data.dataMode,
        executionEnabled: data.executionEnabled, predictionEnabled: data.predictionEnabled,
        candidateModelCount: data.models?.length,
        pass: data.schemaVersion === 'astra-model-atlas.v1'
          && data.dataMode === 'frozen_candidate_parameters_not_live'
          && data.executionEnabled === false && data.predictionEnabled === false
          && Array.isArray(data.models) && data.models.length > 0
          && data.models.every(model => model.promotionStatus === 'CANDIDATE_NOT_PROMOTED'
            && model.calibrationVersion === 'UNAVAILABLE_FAIL_CLOSED'),
      };
    }
    return { path, status: response.status, expected: manifest[path], actual: hash.sha256,
      analyticsTagsRemoved: hash.analyticsTagsRemoved, ...(canonicalRedirect ? { canonicalRedirect } : {}),
      ...(atlas ? { atlas } : {}),
      pass: response.status === 200 && hash.sha256 === manifest[path] && (!atlas || atlas.pass) };
  } catch (error) {
    return { path, pass: false, error: error.message };
  }
}

async function checkRoute(origin, [path, expected]) {
  try {
    const { response, body } = await request(origin, path);
    const hash = contentHash(body);
    const privateRoute = path.startsWith('/api/quant/');
    const privateHeaders = !privateRoute || response.headers.get('cache-control') === 'private, no-store';
    const noCandidates = !privateRoute || !body.toString('utf8').includes('candidates');
    return { path, status: response.status, expected, cacheControl: response.headers.get('cache-control'),
      ...(privateRoute ? { privateHeaders, noCandidates } : {}),
      pass: response.status === expected && privateHeaders && noCandidates
        && (!['/', '/app/research-desk/'].includes(path) || hash.sha256 === manifest['app/research-desk/index.html']) };
  } catch (error) {
    return { path, expected, pass: false, error: error.message };
  }
}

const domains = [];
for (const origin of origins) {
  const [assets, routes] = await Promise.all([
    Promise.all(selected.map(path => checkAsset(origin, path))),
    Promise.all(routeCases.map(route => checkRoute(origin, route))),
  ]);
  domains.push({ origin, assets, routes, pass: [...assets, ...routes].every(check => check.pass) });
}
const result = { schema: 'leo-model-atlas-live-verification/v1', checkedAt: new Date().toISOString(),
  stage, tlsVerified: true, requestMethods: ['GET'], executionEnabled: false,
  domains, pass: domains.every(domain => domain.pass) };
await writeFile(output, `${JSON.stringify(result, null, 2)}\n`);
console.log(JSON.stringify({ pass: result.pass, evidence: output, domains: domains.map(domain => ({
  origin: domain.origin, assets: domain.assets.length, routes: domain.routes.length,
  failures: [...domain.assets, ...domain.routes].filter(check => !check.pass),
})) }, null, 2));
if (!result.pass) process.exitCode = 1;
