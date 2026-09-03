import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

test('owner IBKR routes require an authenticated administrator', () => {
  for (const route of [
    'app/api/market/databento/health/route.ts',
    'app/api/market/ibkr/health/route.ts',
    'app/api/market/options/route.ts',
    'app/api/market/order-flow/route.ts',
  ]) {
    const source = read(route);
    assert.match(source, /getCurrentUser/);
    assert.match(source, /isAdmin\(user\)/);
    assert.match(source, /authentication_required/);
  }
  assert.match(
    read('app/api/market/order-flow/route.ts'),
    /allowRetailFallback:\s*false/
  );

  const protection = read('lib/api-protection.ts');
  assert.doesNotMatch(
    protection,
    /PUBLIC_MARKET_READ_PATHS\s*=\s*\[[^\]]*(?:options|order-flow)/s
  );
  assert.match(
    read('middleware.ts'),
    /['"]\/api\/market\/databento\/health['"]/
  );
});

test('Databento control plane fails closed without adding owner diagnostics to the chat shell', () => {
  const client = read('lib/quant/research-client.ts');
  const chat = read('components/AxioChat.tsx');
  assert.match(client, /\/api\/v1\/system\/readiness/);
  assert.match(client, /public_use_rights/);
  assert.match(client, /READY_MARKET_DATA_RIGHTS_REASONS/);
  assert.match(client, /OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT/);
  assert.match(client, /provider_entitlement/);
  assert.match(client, /stream_freshness/);
  assert.match(client, /feed_freshness/);
  assert.doesNotMatch(client, /\/api\/v1\/live\/bars/);
  assert.doesNotMatch(client, /latestObservation/);
  assert.doesNotMatch(chat, /\/api\/market\/databento\/health/);
  assert.doesNotMatch(chat, /\/api\/market\/ibkr\/health/);
  assert.doesNotMatch(chat, /\/api\/market\/order-flow/);
  assert.doesNotMatch(chat, /Owner market data/);
  assert.doesNotMatch(chat, /Owner model preview/);
  assert.doesNotMatch(chat, /IBKR verification/);
});

test('IBKR gateway is loopback-only and execution remains disabled', () => {
  const compose = read('infra/single-vm/compose.yaml');
  assert.match(compose, /127\.0\.0\.1:5000:5000/);
  assert.match(compose, /vertx\.cacheDirBase=\/tmp\/vertx-cache/);
  assert.match(compose, /\/opt\/ibkr\/logs:size=16m,uid=999,gid=999,mode=0750/);
  assert.match(compose, /IBKR_BASE_URL:/);
  assert.match(compose, /IBKR_MARKET_DATA_ENABLED:/);
  assert.match(compose, /LIVE_EXECUTION_ENABLED:\s*"false"/);
  assert.match(compose, /BROKER_LIVE_ENABLED:\s*"false"/);
  assert.match(compose, /ANOMALY_LIVE_ORDER_ENABLED:\s*"false"/);

  const gatewayConfig = read('infra/single-vm/ibkr-gateway/conf.yaml');
  assert.match(gatewayConfig, /-\s+127\.0\.0\.1/);
  assert.match(gatewayConfig, /-\s+172\.\*/);
  assert.doesNotMatch(gatewayConfig, /origin\.allowed:\s*"\*"/);
});

test('Databento credential is passed server-side without a committed value', () => {
  const compose = read('infra/single-vm/compose.yaml');
  const example = read('infra/single-vm/.env.server.example');
  assert.match(compose, /DATABENTO_API_KEY:\s*\$\{DATABENTO_API_KEY:-\}/);
  assert.match(example, /^DATABENTO_API_KEY=$/m);
  assert.doesNotMatch(example, /db-[A-Za-z0-9]+/);
});

test('quantd image embeds an explicit source commit during compilation', () => {
  const dockerfile = read('infra/single-vm/quantd.Dockerfile');
  assert.match(dockerfile, /ARG GIT_COMMIT=WORKTREE_UNCOMMITTED/);
  assert.match(dockerfile, /ENV GIT_COMMIT=\$GIT_COMMIT/);
  assert.match(dockerfile, /cargo build --locked --release --bin quantd --bin quantctl/);
});
