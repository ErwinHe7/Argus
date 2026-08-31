import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const source = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8');

test('Paddle renewal cancellation is always scheduled for the next billing period', async () => {
  const [paddle, route] = await Promise.all([
    source('lib/paddle.ts'),
    source('app/api/paddle/subscription/cancel-renewal/route.ts'),
  ]);
  assert.match(paddle, /effectiveFrom:\s*'next_billing_period'/);
  assert.doesNotMatch(route, /effectiveFrom:\s*'immediately'/);
  assert.match(route, /syncPaddleSubscription/);
  assert.match(route, /Paddle cancellation ownership check failed/);
});

test('billing UI distinguishes cancellation from refund and requires confirmation', async () => {
  const billing = await source('app/billing/page.tsx');
  assert.match(billing, /Cancel renewal/);
  assert.match(billing, /Confirm cancellation/);
  assert.match(billing, /No refund has been issued/);
  assert.match(billing, /does not refund the current billing period/);
  assert.doesNotMatch(billing, /Submit refund request for review/);
  assert.doesNotMatch(billing, /\/api\/paddle\/refund-requests/);
});

test('website creates only internal refund requests and never Paddle adjustments', async () => {
  const [route, storage, paddle] = await Promise.all([
    source('app/api/paddle/refund-requests/route.ts'),
    source('lib/refund-requests.ts'),
    source('lib/paddle.ts'),
  ]);
  const combined = `${route}\n${storage}\n${paddle}`;
  assert.match(combined, /billing_refund_requests/);
  assert.doesNotMatch(combined, /adjustments\.create/);
  assert.doesNotMatch(combined, /action:\s*['"]refund['"]/);
});

test('refund webhooks preserve access during review and revoke only approved access', async () => {
  const [webhook, storage, billing, provisioner] = await Promise.all([
    source('app/api/paddle/webhook/route.ts'),
    source('lib/refund-requests.ts'),
    source('lib/billing.ts'),
    source('scripts/provision-paddle-live-infrastructure.mjs'),
  ]);
  assert.match(provisioner, /'adjustment\.created'/);
  assert.match(provisioner, /'adjustment\.updated'/);
  assert.match(webhook, /syncPaddleRefundAdjustment/);
  assert.match(storage, /pending_approval[\s\S]*under_review/);
  assert.match(storage, /approved/);
  assert.match(storage, /rejected/);
  assert.match(billing, /refund_status === 'approved'/);
  assert.match(storage, /select\('provider_subscription_id,lifetime_access'\)/);
  assert.match(storage, /resolvedSubscriptionId/);
  assert.match(storage, /not attached to a known subscription/);
});

test('public refund policy states final-sale default without limiting mandatory rights', async () => {
  const policy = await source('app/refunds/page.tsx');
  assert.match(policy, /All sales are final and non-refundable/);
  assert.match(policy, /required by applicable law or Paddle/);
  assert.match(policy, /cancel at any time to prevent future renewal/);
});

test('runtime key guidance excludes adjustment write while retaining checkout permissions', async () => {
  const env = await source('.env.example');
  assert.match(env, /transaction\.write/);
  assert.match(env, /customer\.write/);
  assert.match(env, /subscription\.write/);
  assert.match(env, /customer_portal_session\.write/);
  assert.match(env, /must not have `adjustment\.write`/);
});
