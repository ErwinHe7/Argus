import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import {
  normalizeAcquisitionAttribution,
  parseAcquisitionAttributionCookie,
} from '../lib/observability/acquisition-attribution';

test('first-touch attribution keeps only bounded allow-listed fields', () => {
  assert.deepEqual(
    normalizeAcquisitionAttribution({
      utm_source: '  product-hunt  ',
      utm_campaign: 'launch\u0000-week',
      landing_path: '/?utm_source=product-hunt',
      email: 'must-not-be-captured@example.com',
    }),
    {
      utm_source: 'product-hunt',
      utm_campaign: 'launch-week',
      landing_path: '/?utm_source=product-hunt',
    }
  );
});

test('cookie parsing fails closed and never accepts arrays', () => {
  assert.deepEqual(parseAcquisitionAttributionCookie(undefined), {});
  assert.deepEqual(parseAcquisitionAttributionCookie('%7Bnot-json'), {});
  assert.deepEqual(parseAcquisitionAttributionCookie(encodeURIComponent('[]')), {});
  assert.deepEqual(
    parseAcquisitionAttributionCookie(
      encodeURIComponent(JSON.stringify({ utm_medium: 'community' }))
    ),
    { utm_medium: 'community' }
  );
});

test('the public runtime probe is read-only while paid research remains gated', async () => {
  const [statusRoute, researchRoute, protection] = await Promise.all([
    readFile('app/api/quant/research/status/route.ts', 'utf8'),
    readFile('app/api/quant/research/route.ts', 'utf8'),
    readFile('lib/api-protection.ts', 'utf8'),
  ]);
  assert.match(statusRoute, /probeQuantResearchBackend\(\)/);
  assert.doesNotMatch(statusRoute, /requirePaidResearchAccess/);
  assert.match(researchRoute, /requirePaidResearchAccess\(\)/);
  assert.match(protection, /['"]\/api\/quant\/research\/status['"]/);
});

test('sector-rotation acquisition page is public, indexed, and makes no current signal claim', async () => {
  const [page, sitemap, robots, middleware] = await Promise.all([
    readFile('app/research/sector-rotation/page.tsx', 'utf8'),
    readFile('app/sitemap.ts', 'utf8'),
    readFile('app/robots.ts', 'utf8'),
    readFile('middleware.ts', 'utf8'),
  ]);
  assert.match(page, /This page explains methodology/);
  assert.match(page, /not a current market signal/);
  assert.match(sitemap, /\/research\/sector-rotation/);
  assert.match(robots, /\/research\/sector-rotation/);
  assert.match(middleware, /ACTIVE_IMPERSONAL_RESEARCH_PAGE_PREFIXES[\s\S]*['"]\/research\/sector-rotation['"]/);
  assert.match(middleware, /ACTIVE_API_PREFIXES[\s\S]*['"]\/api\/health['"]/);
});
