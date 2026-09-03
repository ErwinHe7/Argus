import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);

async function source(path) {
  return readFile(new URL(path, root), 'utf8');
}

test('pricing keeps Paddle canonical while exposing the verified Whop checkout', async () => {
  const [pricingPage, whopCheckout] = await Promise.all([
    source('app/pricing/page.tsx'),
    source('app/pricing/whop-checkout.ts'),
  ]);

  assert.match(pricingPage, /<PaddlePricingClient/);
  assert.match(pricingPage, /PADDLE_TIERS\.map/);
  assert.match(pricingPage, /WHOP_LIVE_TRADING_CHECKOUT/);
  assert.match(pricingPage, /target="_blank"/);
  assert.match(pricingPage, /rel="noopener noreferrer"/);
  assert.match(
    pricingPage,
    /does\s+not automatically unlock the Leo app/
  );
  assert.match(pricingPage, /contact support with the receipt/);
  assert.match(pricingPage, /Manual account matching is required/);
  assert.match(pricingPage, /!hasAccess \? <section className="axio-whop-checkout"/);
  assert.match(pricingPage, /verified Paddle event/);

  assert.match(whopCheckout, /plan_lx8Xc92y4i1Mg/);
  assert.match(
    whopCheckout,
    /https:\/\/whop\.com\/checkout\/plan_lx8Xc92y4i1Mg/
  );
  assert.match(whopCheckout, /AXIO7 Live Trading/);
  assert.match(whopCheckout, /\$99\.99/);
  assert.match(whopCheckout, /September 1, 2026/);
  assert.doesNotMatch(whopCheckout, /plan_(?:GSNAlvdouiQ2U|fdFSyH6iNybPr|Y5safdQJ59vlo)/);
});
