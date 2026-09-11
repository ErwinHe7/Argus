import { test } from 'node:test';
import assert from 'node:assert/strict';
import type { SupabaseClient } from '@supabase/supabase-js';
import { BILLING_API, checkoutUrl, createCheckout, loadMembership, membershipSchema, STATUS_MAX_AGE_MS, statusIsFresh } from './api';

const now = Date.parse('2026-09-11T12:00:00Z');
const active = { provider: 'whop', status: 'active', checkedAt: new Date(now).toISOString(), cancelAtPeriodEnd: false, renewalPeriodEnd: '2026-10-11T12:00:00Z' } as const;
const auth = (id = 'fixture-owner', anonymous = false) => ({ auth: { getSession: async () => ({ data: { session: { user: { id, is_anonymous: anonymous }, access_token: 'fixture-token' } }, error: null }) } }) as unknown as SupabaseClient;

test('membership response rejects missing verification, wrong providers and client authority fields', () => {
  assert.equal(membershipSchema.parse(active).status, 'active');
  for (const value of [{ ...active, checkedAt: null }, { ...active, checkedAt: 'unknown' }, { ...active, provider: 'paddle' }, { ...active, granted: true }, { ...active, status: 'paid' }]) {
    assert.equal(membershipSchema.safeParse(value).success, false);
  }
});
test('old, future, unavailable and long-retained observations are never current active status', () => {
  assert.equal(statusIsFresh(active, now, now), true);
  assert.equal(statusIsFresh(active, now, now + STATUS_MAX_AGE_MS), false);
  assert.equal(statusIsFresh({ ...active, checkedAt: new Date(now + 61_000).toISOString() }, now, now), false);
  assert.equal(statusIsFresh({ ...active, status: 'unavailable' }, now, now), false);
  assert.equal(statusIsFresh({ ...active, status: 'none', checkedAt: null }, now, now), true);
  assert.equal(statusIsFresh(active, now - STATUS_MAX_AGE_MS, now), false);
});
test('checkout requires an exact HTTPS Whop checkout URL and rejects redirects to other surfaces', () => {
  const expected = 'https://whop.com/checkout/plan_fixture/';
  assert.equal(checkoutUrl({ url: expected }), expected);
  for (const url of ['http://whop.com/checkout/plan_fixture/', 'https://whop.com.evil.invalid/checkout/a', 'https://evil.invalid/checkout/a', 'https://whop.com@evil.invalid/checkout/a', 'https://user:password@whop.com/checkout/a', 'https://whop.com/home/', '/checkout/plan_fixture/', 'javascript:alert(1)', 'https://whop.com/checkout/']) {
    assert.throws(() => checkoutUrl({ url }));
  }
  assert.throws(() => checkoutUrl({ url: expected, active: true }));
});
test('private calls require the current non-anonymous account and send its token only to the fixed service', async () => {
  const original = globalThis.fetch; const calls: { url: string; init?: RequestInit }[] = [];
  globalThis.fetch = async (url, init) => { calls.push({ url: String(url), init }); return Response.json(active); };
  try {
    await assert.rejects(loadMembership(auth('other-owner'), 'fixture-owner'), /sign-in/);
    await assert.rejects(loadMembership(auth('fixture-owner', true), 'fixture-owner'), /sign-in/);
    assert.equal(calls.length, 0);
    assert.deepEqual(await loadMembership(auth(), 'fixture-owner'), active);
    assert.equal(calls[0].url, `${BILLING_API}/status`);
    assert.equal(calls[0].init?.method, 'GET');
    assert.deepEqual(calls[0].init?.headers, { Authorization: 'Bearer fixture-token' });
    assert.equal(calls[0].init?.redirect, 'error');
    assert.equal(calls[0].init?.cache, 'no-store');
    assert.equal(calls[0].init?.credentials, 'omit');
  } finally { globalThis.fetch = original; }
});
test('checkout is server-created with POST; failure responses never produce access or a fallback URL', async () => {
  const original = globalThis.fetch; let mode = 'success';
  globalThis.fetch = async (url, init) => {
    assert.equal(String(url), `${BILLING_API}/checkout`); assert.equal(init?.method, 'POST');
    return mode === 'success' ? Response.json({ url: 'https://whop.com/checkout/plan_fixture/' }) : Response.json({ active: true, url: 'https://whop.com/checkout/plan_fixture/' }, { status: 503 });
  };
  try {
    assert.equal(await createCheckout(auth(), 'fixture-owner'), 'https://whop.com/checkout/plan_fixture/');
    mode = 'failure'; await assert.rejects(createCheckout(auth(), 'fixture-owner'), /unavailable/);
  } finally { globalThis.fetch = original; }
});
test('an already-canceled request never sends a token or begins checkout', async () => {
  const original = globalThis.fetch; let calls = 0;
  globalThis.fetch = async () => { calls++; return Response.json(active); };
  try { const controller = new AbortController(); controller.abort(); await assert.rejects(createCheckout(auth(), 'fixture-owner', controller.signal)); assert.equal(calls, 0); }
  finally { globalThis.fetch = original; }
});
