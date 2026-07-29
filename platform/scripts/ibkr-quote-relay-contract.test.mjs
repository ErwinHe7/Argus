import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const read = (path) => fs.readFileSync(path, 'utf8');

test('IBKR relay route is separately authenticated and proxies only to Rust quote ingress', () => {
  const route = read('app/api/market/ibkr/relay/route.ts');
  assert.match(route, /IBKR_QUOTE_RELAY_TOKEN/);
  assert.match(route, /crypto\.timingSafeEqual/);
  assert.match(route, /MAX_BODY_BYTES = 65_536/);
  assert.match(route, /\/api\/v1\/live\/ibkr\/quotes/);
  assert.match(route, /X-Research-Token/);
  assert.doesNotMatch(route, /order|trade|account|cookie/i);
});

test('IBKR relay receipt read is owner-only and read-only', () => {
  const route = read('app/api/market/ibkr/relay/route.ts');
  const client = read('lib/quant/research-client.ts');
  const middleware = read('middleware.ts');
  assert.match(route, /export async function GET/);
  assert.match(route, /getCurrentUser/);
  assert.match(route, /isAdmin/);
  assert.match(route, /readIbkrQuoteRelayReceipt/);
  assert.match(client, /fetchQuantJson\('\/api\/v1\/live\/ibkr\/quotes'\)/);
  assert.match(middleware, /'\/api\/market\/ibkr\/relay'/);
  assert.doesNotMatch(route, /export async function (?:PUT|PATCH|DELETE)/);
});

test('local IBKR bridge enforces loopback Gateway and outbound HTTPS', () => {
  const bridge = read('scripts/ibkr_quote_relay.py');
  assert.match(bridge, /address\.is_loopback/);
  assert.match(bridge, /Gateway URL must be loopback HTTPS/);
  assert.match(bridge, /AXIO7 ingest URL must use HTTPS/);
  assert.match(bridge, /IBKR_QUOTE_RELAY_TOKEN/);
  assert.match(bridge, /SNAPSHOT_FIELDS = "31,84,85,86,88,6509"/);
  assert.doesNotMatch(bridge, /iserver\/account\/orders|iserver\/account\/trades|iserver\/account\/order/);
});
