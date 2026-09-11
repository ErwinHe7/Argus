import { test } from 'node:test';
import assert from 'node:assert/strict';
import type { SupabaseClient } from '@supabase/supabase-js';
import { BROKER_LINK_API, MOOMOO_START, directLinkFresh, directLinkSchema, requestDirectLink } from './direct-link';

const now = Date.parse('2026-09-11T12:00:00Z');
const connected = { schemaVersion: 'broker-link/v1', provider: 'moomoo', configured: true, state: 'connected', checkedAt: new Date(now).toISOString(), accounts: [{ label: '••••1234', securityFirm: 'moomoo', accountType: 'cash', markets: [1, 2] }], readonly: true, executionEnabled: false, message: 'Verified' } as const;
const auth = (id = 'fixture-owner', anonymous = false) => ({ auth: { getSession: async () => ({ data: { session: { user: { id, is_anonymous: anonymous }, access_token: 'fixture-token' } }, error: null }) } }) as unknown as SupabaseClient;

test('account links require a verified read-only response and masked account identifiers', () => {
  assert.equal(directLinkSchema.parse(connected).state, 'connected');
  for (const value of [{ ...connected, checkedAt: null }, { ...connected, configured: false }, { ...connected, readonly: false }, { ...connected, executionEnabled: true }, { ...connected, provider: 'ibkr' }, { ...connected, access_token: 'private' }, { ...connected, accounts: [{ ...connected.accounts[0], label: '123456789' }] }, { ...connected, accounts: [{ ...connected.accounts[0], accountId: '123456789' }] }]) assert.equal(directLinkSchema.safeParse(value).success, false);
});
test('retained, stale, future and unavailable account evidence cannot claim a current connection', () => {
  const value = directLinkSchema.parse(connected);
  assert.equal(directLinkFresh(value, now), true);
  assert.equal(directLinkFresh(value, now + 300_000), false);
  assert.equal(directLinkFresh({ ...value, checkedAt: new Date(now + 61_000).toISOString() }, now), false);
  assert.equal(directLinkFresh({ ...value, state: 'unavailable' }, now), false);
  assert.equal(directLinkFresh({ ...value, state: 'reauthorization_required' }, now), false);
});
test('status and disconnect verify the current owner and keep tokens out of URLs', async () => {
  const original = globalThis.fetch; const calls: { url: string; init?: RequestInit }[] = [];
  globalThis.fetch = async (url, init) => { calls.push({ url: String(url), init }); return Response.json(connected); };
  try {
    const signal = new AbortController().signal;
    await assert.rejects(requestDirectLink(auth('other-owner'), 'fixture-owner', '/status', signal), /sign-in/);
    await assert.rejects(requestDirectLink(auth('fixture-owner', true), 'fixture-owner', '/status', signal), /sign-in/);
    assert.equal(calls.length, 0);
    await requestDirectLink(auth(), 'fixture-owner', '/status', signal);
    await requestDirectLink(auth(), 'fixture-owner', '/disconnect', signal);
    assert.equal(calls[0].url, `${BROKER_LINK_API}/status`);
    assert.equal(calls[0].init?.method, 'GET');
    assert.equal(calls[0].init?.body, undefined);
    assert.equal(calls[1].url, `${BROKER_LINK_API}/disconnect`);
    assert.equal(calls[1].init?.method, 'POST');
    assert.equal(calls[1].init?.body, '{}');
    for (const call of calls) { assert.equal(new Headers(call.init?.headers).get('Authorization'), 'Bearer fixture-token'); assert.equal(call.init?.credentials, 'omit'); assert.equal(call.init?.redirect, 'error'); assert.equal(call.init?.cache, 'no-store'); }
    assert.equal(MOOMOO_START, `${BROKER_LINK_API}/oauth/moomoo/start`);
  } finally { globalThis.fetch = original; }
});
test('interrupted and failed calls never return account access', async () => {
  const original = globalThis.fetch; let calls = 0, status = 503;
  globalThis.fetch = async () => { calls++; return Response.json(connected, { status }); };
  try {
    const controller = new AbortController(); controller.abort();
    await assert.rejects(requestDirectLink(auth(), 'fixture-owner', '/status', controller.signal)); assert.equal(calls, 0);
    await assert.rejects(requestDirectLink(auth(), 'fixture-owner', '/status', new AbortController().signal), /Try again/);
    status = 401; await assert.rejects(requestDirectLink(auth(), 'fixture-owner', '/status', new AbortController().signal), /sign-in/);
  } finally { globalThis.fetch = original; }
});
