import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const read = (path) => fs.readFileSync(path, 'utf8');

test('Moomoo forecast relay has a separate bearer secret and narrow Rust target', () => {
  const route = read('app/api/market/moomoo/relay/route.ts');
  assert.match(route, /MOOMOO_FORECAST_RELAY_TOKEN/);
  assert.match(route, /crypto\.timingSafeEqual/);
  assert.match(route, /MAX_BODY_BYTES = 1_048_576/);
  assert.match(route, /\/api\/v1\/live\/moomoo\/forecasts/);
  assert.match(route, /ROUTE}:publish/);
  assert.match(route, /120, 60_000/);
  assert.match(route, /X-Research-Token/);
  assert.doesNotMatch(route, /order|position|account|cookie/i);
});

test('Moomoo receipt and model preview remain administrator-only', () => {
  const relay = read('app/api/market/moomoo/relay/route.ts');
  const gateway = read('app/api/quant/intraday/[...path]/route.ts');
  const page = read('app/quant/intraday/page.tsx');
  const middleware = read('middleware.ts');
  assert.match(relay, /getCurrentUser/);
  assert.match(relay, /isAdmin/);
  assert.match(gateway, /'predictor\/owner-preview'/);
  assert.match(page, /isAdmin\(user\)/);
  assert.match(middleware, /'\/api\/market\/moomoo\/relay'/);
  assert.doesNotMatch(relay, /export async function (?:PUT|PATCH|DELETE)/);
});

test('owner preview visibly withholds public rights, probabilities, and execution', () => {
  const rustRelay = read('quant_engine_rs/src/data/moomoo_forecast_relay.rs');
  const rustApi = read('quant_engine_rs/src/api.rs');
  const ui = read('components/AxioChat.tsx');
  assert.match(rustRelay, /public_redistribution_authorized: false/);
  assert.match(rustRelay, /WITHHELD_UNPROMOTED_OOS_CALIBRATION/);
  assert.match(rustRelay, /row\.decision\.eligible/);
  assert.match(rustRelay, /row\.calibrated_probability_up\.is_some\(\)/);
  assert.match(rustApi, /customer_publication_authorized/);
  assert.match(ui, /Calibrated up\/down probability, ranking,/);
  assert.match(ui, /advice, and execution are withheld/);
});

test('local Rust publisher requires HTTPS except for loopback development', () => {
  const cli = read('quant_engine_rs/src/bin/quantctl.rs');
  assert.match(cli, /Moomoo owner forecast relay must use HTTPS/);
  assert.match(cli, /HTTP is allowed only on loopback/);
  assert.match(cli, /MOOMOO_FORECAST_RELAY_TOKEN/);
  assert.doesNotMatch(cli, /publish_token:\s*String/);
});

test('production and UI symbols remain inside the exact frozen universe', () => {
  const registry = JSON.parse(read('quant_engine_rs/data/models/universe/registry.json'));
  const registrySymbols = new Set(registry.entries.map((entry) => entry.model_symbol));
  const production = read('quant_engine_rs/configs/production.yaml');
  const configuredRow = production.match(/^\s*forecast_symbols:\s*\[([^\]]+)\]/m);
  assert.ok(configuredRow, 'production forecast_symbols must be explicit');
  const configuredSymbols = new Set(
    configuredRow[1].split(',').map((symbol) => symbol.trim().replace(/^US\./, '')),
  );
  assert.deepEqual([...configuredSymbols].sort(), [...registrySymbols].sort());

  const ui = read('components/quant/QuantOperatingSystem.tsx');
  const requestedSymbols = new Set([
    'SPY',
    ...[...ui.matchAll(/\/predictor\/(?:owner-preview|forecast)\?symbol=([A-Z]+)/g)]
      .map((match) => match[1]),
  ]);
  for (const symbol of requestedSymbols) {
    assert.ok(registrySymbols.has(symbol), `UI requested unsupported frozen symbol ${symbol}`);
  }
});

test('single-VM configuration carries and validates the owner relay secret', () => {
  const quantdDockerfile = read('infra/single-vm/quantd.Dockerfile');
  const serverExample = read('infra/single-vm/.env.server.example');
  const prepare = read('scripts/prepare-single-vm-env.ps1');
  assert.match(quantdDockerfile, /sed -i 's\/\\r\$\/\/' \/usr\/local\/bin\/axio-entrypoint/);
  assert.match(serverExample, /MOOMOO_FORECAST_RELAY_ENABLED=false/);
  assert.match(serverExample, /MOOMOO_FORECAST_RELAY_TOKEN=/);
  assert.match(prepare, /"MOOMOO_FORECAST_RELAY_ENABLED"/);
  assert.match(prepare, /"MOOMOO_FORECAST_RELAY_TOKEN"/);
  assert.match(prepare, /MOOMOO_FORECAST_RELAY_TOKEN.*at least 32 characters/);
  assert.match(prepare, /\.Length -lt 32/);
});
