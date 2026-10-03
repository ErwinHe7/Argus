import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { assertRestrictedKey, fetchRevenueMetrics, VerificationError } from '../src/stripe.js';
import { charge, startFakeStripe, sub } from './fake-stripe.js';

let stripe;
before(async () => { stripe = await startFakeStripe({ pageSize: 2 }); });
after(() => stripe.close());

const verify = (key = 'rk_live_good') => fetchRevenueMetrics(key, { apiBase: stripe.apiBase });

test('normalizes every billing interval to monthly and applies percent discounts', async () => {
  stripe.state.subscriptions = [
    sub('s1', [[1000, 'month', 2]]), // $20/mo
    sub('s2', [[12000, 'year']]), // $10/mo
    sub('s3', [[3000, 'month', 1, 3]]), // $10/mo billed quarterly
    sub('s4', [[5000, 'month']], { discount: { coupon: { percent_off: 50 } } }), // $25/mo
  ];
  stripe.state.charges = [
    charge('c1', 5000),
    charge('c2', 2000, { amount_refunded: 500 }),
    charge('c3', 9999, { status: 'failed', paid: false }),
  ];
  const metrics = await verify();
  assert.deepEqual(metrics, { currency: 'usd', mrr: 6500, revenue30d: 6500, activeSubscriptions: 4 });
});

test('follows pagination cursors and only asks for active subscriptions', async () => {
  stripe.requests.length = 0;
  stripe.state.subscriptions = Array.from({ length: 5 }, (_, i) => sub(`s${i}`, [[100, 'month']]));
  stripe.state.charges = [];
  const metrics = await verify();
  assert.equal(metrics.activeSubscriptions, 5);
  assert.equal(metrics.mrr, 500);
  const subRequests = stripe.requests.filter((u) => u.pathname === '/v1/subscriptions');
  assert.equal(subRequests.length, 3);
  assert.ok(subRequests.every((u) => u.searchParams.get('status') === 'active'));
});

test('fails closed on non-USD revenue and unpriceable subscriptions', async () => {
  stripe.state.subscriptions = [sub('s1', [[1000, 'month']], { currency: 'eur' })];
  stripe.state.charges = [];
  await assert.rejects(verify(), /Only USD/);

  stripe.state.subscriptions = [sub('s1', [[null, 'month']])];
  await assert.rejects(verify(), /cannot be verified/);
});

test('surfaces Stripe auth errors as verification errors', async () => {
  await assert.rejects(verify('rk_live_wrong'), (err) => err instanceof VerificationError && /Invalid API Key/.test(err.message));
});

test('accepts only restricted live keys unless test keys are allowed', () => {
  assert.throws(() => assertRestrictedKey('sk_live_abc'), /restricted key/);
  assert.throws(() => assertRestrictedKey('rk_test_abc'), /Test-mode/);
  assert.throws(() => assertRestrictedKey('rk_live_abc def'), /restricted key/);
  assert.doesNotThrow(() => assertRestrictedKey('rk_live_abc123'));
  assert.doesNotThrow(() => assertRestrictedKey('rk_test_abc', { allowTestKeys: true }));
});

test('weekly and daily plans scale up to a month', async () => {
  stripe.state.subscriptions = [sub('w', [[1000, 'week']]), sub('d', [[100, 'day']])];
  stripe.state.charges = [];
  const { mrr } = await verify();
  assert.equal(mrr, Math.round((1000 * 52.1775) / 12 + (100 * 365.25) / 12));
});
