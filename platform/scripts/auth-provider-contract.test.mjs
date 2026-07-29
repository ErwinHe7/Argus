import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const repositoryRoot = new URL('../', import.meta.url);

async function source(relativePath) {
  return readFile(new URL(relativePath, repositoryRoot), 'utf8');
}

test('sign-in UI fails closed when an OAuth provider is disabled', async () => {
  const [signin, providersRoute] = await Promise.all([
    source('app/auth/signin/page.tsx'),
    source('app/api/auth/providers/route.ts'),
  ]);

  assert.match(signin, /fetch\('\/api\/auth\/providers'/);
  assert.match(signin, /appleAvailable \? \(/);
  assert.match(signin, /Apple sign-in is temporarily unavailable/);
  assert.match(signin, /unsupported provider/);
  assert.match(providersRoute, /settings\.external\?\.apple === true/);
  assert.match(providersRoute, /apple: false/);
  assert.match(providersRoute, /cache-control': 'no-store'/);
});

test('guest subscription returns through sign-in to the pricing page', async () => {
  const [pricingClient, checkoutRoute] = await Promise.all([
    source('app/pricing/PaddlePricingClient.tsx'),
    source('app/api/paddle/checkout/route.ts'),
  ]);

  assert.match(
    pricingClient,
    /if \(!authenticated\) \{\s*window\.location\.assign\('\/auth\/signin\?next=%2Fpricing'\)/
  );
  assert.match(
    checkoutRoute,
    /authentication_required[\s\S]*signInUrl: '\/auth\/signin\?next=%2Fpricing'/
  );
});

test('public billing and support contacts use the requested Gmail address', async () => {
  const pages = await Promise.all(
    [
      'app/refunds/page.tsx',
      'app/privacy/page.tsx',
      'app/terms/page.tsx',
      'app/support/page.tsx',
    ].map(source)
  );

  for (const page of pages) {
    assert.match(page, /mailto:heguantao565@gmail\.com/);
    assert.doesNotMatch(page, /gh2722@columbia\.edu/);
  }
});
