import assert from 'node:assert/strict';
import { after, before, beforeEach, test } from 'node:test';
import { openDatabase } from '../src/db.js';
import { createSealer } from '../src/secrets.js';
import { createApp, loadConfig } from '../src/server.js';
import { charge, startFakeStripe, sub } from './fake-stripe.js';

const KEY = 'rk_live_good';
let stripe, db, app, base, clock;

before(async () => {
  stripe = await startFakeStripe({ subscriptions: [sub('s1', [[4900, 'month', 3]])], charges: [charge('c1', 14700)] });
});
after(() => stripe.close());

beforeEach(async () => {
  if (app) await new Promise((resolve) => app.server.close(resolve));
  clock = Date.parse('2026-10-01T12:00:00Z');
  db = openDatabase(':memory:');
  const config = { ...loadConfig({}), stripeApiBase: stripe.apiBase, sponsorCheckoutUrl: 'https://buy.stripe.com/test' };
  app = createApp({ db, config, sealer: createSealer('x'.repeat(32)), now: () => clock });
  await new Promise((resolve) => app.server.listen(0, '127.0.0.1', resolve));
  base = `http://127.0.0.1:${app.server.address().port}`;
});
after(() => app.server.close());

const submit = (fields) =>
  fetch(`${base}/add`, { method: 'POST', body: new URLSearchParams(fields), redirect: 'manual' });

test('verifies a startup, lists it, and never exposes the key', async () => {
  const res = await submit({ name: 'Acme <script>', website: 'https://www.acme.dev', description: 'Rockets', stripeKey: KEY });
  assert.equal(res.status, 303);
  assert.equal(res.headers.get('location'), '/s/acme-script');

  const home = await (await fetch(base)).text();
  assert.match(home, /Acme &#60;script&#62;/);
  assert.doesNotMatch(home, /<script>/);
  assert.match(home, /\$147/);
  assert.match(home, /Your product here/);

  const api = await (await fetch(`${base}/api/startups`)).json();
  assert.equal(api.startups[0].mrr, 14700);
  assert.equal(api.startups[0].revenue_30d, 14700);

  for (const body of [home, JSON.stringify(api), await (await fetch(`${base}/s/acme-script`)).text()]) {
    assert.ok(!body.includes(KEY));
  }
});

test('rejects bad keys and duplicate hosts without saving anything', async () => {
  let res = await submit({ name: 'A', website: 'https://a.dev', stripeKey: 'sk_live_full' });
  assert.equal(res.status, 422);
  assert.match(await res.text(), /restricted key/);

  res = await submit({ name: 'A', website: 'https://a.dev', stripeKey: 'rk_live_wrong' });
  assert.equal(res.status, 422);
  const page = await res.text();
  assert.match(page, /Invalid API Key/);
  assert.doesNotMatch(page, /rk_live_wrong/);
  assert.equal(db.ranked('').length, 0);

  assert.equal((await submit({ name: 'A', website: 'https://a.dev', stripeKey: KEY })).status, 303);
  res = await submit({ name: 'B', website: 'http://www.A.dev/pricing', stripeKey: KEY });
  assert.equal(res.status, 422);
  assert.match(await res.text(), /already listed/);
});

test('hourly refresh updates numbers; lapsed verification drops off the board', async () => {
  await submit({ name: 'Acme', website: 'https://acme.dev', stripeKey: KEY });

  stripe.state.subscriptions = [sub('s1', [[4900, 'month', 5]])];
  clock += 3_600_000;
  await app.refreshAll();
  assert.equal(db.get('acme').mrr, 24500);

  stripe.state.validKey = 'rk_live_rotated'; // founder revoked the key
  clock += 49 * 3_600_000;
  await app.refreshAll();
  stripe.state.validKey = KEY;
  assert.match(db.get('acme').refresh_error, /Invalid API Key/);
  assert.equal(db.ranked(new Date(clock - 48 * 3_600_000).toISOString()).length, 0);
  assert.doesNotMatch(await (await fetch(base)).text(), /acme\.dev/);
  assert.match(await (await fetch(`${base}/s/acme`)).text(), /Verification lapsed/);
});

test('rate-limits submissions per client', async () => {
  for (let i = 0; i < 10; i++) await submit({ name: '', website: '', stripeKey: '' });
  const res = await submit({ name: 'A', website: 'https://a.dev', stripeKey: KEY });
  assert.match(await res.text(), /Too many submissions/);
});

test('sealer refuses short secrets and round-trips keys', () => {
  assert.throws(() => createSealer('short'), /APP_SECRET/);
  const sealer = createSealer('y'.repeat(40));
  const sealed = sealer.seal(KEY);
  assert.ok(!sealed.includes(KEY));
  assert.equal(sealer.open(sealed), KEY);
});
