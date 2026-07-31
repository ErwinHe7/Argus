import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { currentPaddleCatalogPricesAreComplete } from '../lib/paddle-catalog-readiness.ts';

const repositoryRoot = new URL('../', import.meta.url);

async function source(relativePath) {
  return readFile(new URL(relativePath, repositoryRoot), 'utf8');
}

const expectedProvisionerAmounts = [
  'amount: 0',
  'amount: 6900',
  'amount: 69900',
];
const expectedRuntimeAmounts = [
  'baseUnitAmount: 0',
  'baseUnitAmount: 6900',
  'baseUnitAmount: 69900',
];

const currentPriceTiers = [
  { priceEnvName: 'PADDLE_PRICE_FREE_MONTH' },
  { priceEnvName: 'PADDLE_PRICE_PRO_MONTH' },
  { priceEnvName: 'PADDLE_PRICE_ANNUAL_YEAR' },
];
const currentPrices = {
  PADDLE_PRICE_FREE_MONTH: `pri_${'a'.repeat(25)}1`,
  PADDLE_PRICE_PRO_MONTH: `pri_${'b'.repeat(25)}2`,
  PADDLE_PRICE_ANNUAL_YEAR: `pri_${'c'.repeat(25)}3`,
};

test('Paddle provisioner creates the exact USD-only, no-trial catalog', async () => {
  const catalogScript = await source('scripts/provision-paddle-catalog.mjs');

  for (const amount of expectedProvisionerAmounts) assert.match(catalogScript, new RegExp(amount.replace(/[{}]/g, '\\$&')));
  assert.match(catalogScript, /axio7-research-pricing-2026-07-v5-usd-no-trial-0-69-699/);
  assert.match(catalogScript, /axio7-research/);
  assert.match(catalogScript, /impersonal quantitative market-research/);
  assert.doesNotMatch(catalogScript, /educational lessons|curriculum|source-reading/i);
  assert.match(catalogScript, /currencyCode: 'USD'/);
  assert.match(catalogScript, /price\.trialPeriod == null/);
  assert.match(catalogScript, /price\.unitPriceOverrides\?\.length \?\? 0\) === 0/);
  assert.doesNotMatch(catalogScript, /trialPeriod\s*:/);
  assert.doesNotMatch(catalogScript, /unitPriceOverrides\s*:/);
  assert.doesNotMatch(catalogScript, /currencyCode: '(?:GBP|EUR|AUD)'/);
  assert.match(catalogScript, /price\.billingCycle\?\.interval === tier\.cadence/);
  assert.match(catalogScript, /billingCycle: \{ interval: tier\.cadence, frequency: 1 \}/);
});

test('runtime catalog and validation reject trial or country-override prices', async () => {
  const [catalog, paddle] = await Promise.all([
    source('lib/paddle-catalog.ts'),
    source('lib/paddle.ts'),
  ]);

  for (const amount of expectedRuntimeAmounts) assert.match(catalog, new RegExp(amount.replace(/[{}]/g, '\\$&')));
  assert.doesNotMatch(catalog, /countryUnitAmount/);
  assert.doesNotMatch(catalog, /free trial/i);
  assert.match(paddle, /price\.trialPeriod == null/);
  assert.match(paddle, /price\.unitPriceOverrides\?\.length \?\? 0\) === 0/);
  assert.match(paddle, /price\.unitPrice\.currencyCode !== 'USD'/);
  assert.match(paddle, /price\.billingCycle\?\.interval === tier\.cadence/);
  assert.match(catalog, /getCurrentPaddlePriceIds/);
  assert.match(paddle, /Draft is the expected state until Paddle Checkout collects/);
  assert.match(
    paddle,
    /currentPaddleCatalogPricesAreComplete\(PADDLE_TIERS, process\.env\)/
  );
  assert.doesNotMatch(paddle, /getConfiguredPaddlePriceIds\(\)\.size\s*===/);
  assert.doesNotMatch(
    paddle,
    /transactions\.update\(existing\.id,\s*\{\s*status:\s*'ready'/
  );
  const localizedCheckoutRuntime = paddle.slice(
    paddle.indexOf('export async function resolvePaddleCheckoutCountryFromIp'),
    paddle.indexOf('export async function retrievePaddleSubscription')
  );
  assert.doesNotMatch(localizedCheckoutRuntime, /currencyCode: 'USD'/);
  assert.match(localizedCheckoutRuntime, /transaction\.currencyCode !== preview\.currencyCode/);
});

test('retired pre-payment checkout attempts rotate without weakening current selection locks', async () => {
  const [checkoutRoute, catalog, paddle] = await Promise.all([
    source('app/api/paddle/checkout/route.ts'),
    source('lib/paddle-catalog.ts'),
    source('lib/paddle.ts'),
  ]);

  assert.match(checkoutRoute, /retrievePaddleTransaction\(error\.transactionId\)/);
  assert.match(checkoutRoute, /!getCurrentPaddlePriceIds\(\)\.has\(lockedPriceId\)/);
  assert.match(checkoutRoute, /cancelRetiredPaddleCheckoutTransactionForUser/);
  assert.match(checkoutRoute, /retiredPriceId: lockedPriceId/);
  assert.match(checkoutRoute, /rotatePaddleReadyCheckoutAttempt/);
  assert.match(
    checkoutRoute,
    /Current-catalog[\s\S]*remain locked/
  );
  assert.match(catalog, /export function getCurrentPaddlePriceIds/);
  assert.match(catalog, /LEGACY_CONFIGURED_PRICE_ENV_NAMES/);
  assert.match(paddle, /cancelRetiredPaddleCheckoutTransactionForUser/);
  assert.match(paddle, /\['draft', 'ready'\]\.includes\(transaction\.status\)/);
  assert.match(paddle, /transaction\.items\[0\]\?\.price\?\.id !== input\.retiredPriceId/);
});

test('explicitly closed Paddle checkouts release draft and ready attempts', async () => {
  const paddle = await source('lib/paddle.ts');

  assert.match(paddle, /cancelPaddleCheckoutTransactionForUser/);
  assert.match(
    paddle,
    /Checkout explicitly closed before completion may still be draft/
  );
  assert.match(paddle, /\['draft', 'ready'\]\.includes\(transaction\.status\)/);
});

test('Paddle pricing UI requests and displays localized Paddle totals', async () => {
  const [pricingPage, pricingClient] = await Promise.all([
    source('app/pricing/page.tsx'),
    source('app/pricing/PaddlePricingClient.tsx'),
  ]);

  assert.doesNotMatch(pricingClient, /currencyCode: 'USD'/);
  assert.match(pricingClient, /item\.formattedTotals\.subtotal/);
  assert.doesNotMatch(pricingClient, /Intl\.NumberFormat|toLocaleString|Math\.(?:round|ceil|floor)/);
  assert.match(pricingClient, /address: \{ countryCode:/);
  assert.match(pricingClient, /Loading localized price/);
  assert.doesNotMatch(pricingClient, /customerEmail/);
  assert.match(pricingClient, /displayMode: 'overlay'/);
  assert.match(pricingClient, /variant: 'one-page'/);
  assert.match(pricingClient, /new URL\('\/welcome', window\.location\.origin\)/);
  assert.match(pricingClient, /paddle\.Checkout\.open\(\{/);
  assert.doesNotMatch(
    pricingClient,
    /transactionId: payload\.transactionId[\s\S]{0,300}customer:\s*\{\s*email/
  );
  assert.doesNotMatch(pricingClient, /PADDLE_API_KEY|pdl_live_apikey_|pdl_sdbx_apikey_/);
  assert.match(pricingPage, /headers\(\)\.get\('x-vercel-ip-country'\)/);
  assert.match(pricingPage, /\^\[A-Z\]\{2\}\$/);
  assert.doesNotMatch(pricingPage, /OTHERS/);
  assert.doesNotMatch(pricingClient, /free trial/i);
  assert.match(pricingClient, /Start free access/);
  assert.match(pricingClient, /Subscribe annually/);
  assert.match(pricingClient, /Original price US\$149\/month/);
  assert.match(pricingClient, /Original price US\$1,499\/year/);
  assert.match(pricingClient, /54% OFF/);
  assert.match(pricingClient, /53% OFF/);
  assert.match(pricingClient, /Contact enterprise sales/);
  assert.doesNotMatch(pricingClient, /Billing frequency/);
});

test('Free Paddle membership stays read-only across research surfaces', async () => {
  const protectedRoutes = [
    'app/api/ask/route.ts',
    'app/api/monitors/route.ts',
    'app/api/monitors/[id]/route.ts',
    'app/api/quant/backtest/route.ts',
    'app/api/quant/global-signals/route.ts',
    'app/api/quant/kdj-low-cross/route.ts',
    'app/api/quant/ml-ls/route.ts',
    'app/api/quant/price-anomalies/route.ts',
    'app/api/quant/reason/route.ts',
    'app/api/quant/research/route.ts',
    'app/api/quant/scan/route.ts',
    'app/api/quant/stat-arb/route.ts',
    'app/api/research/serenity/route.ts',
  ];
  const [billing, access, home, chat, ...routes] = await Promise.all([
    source('lib/billing.ts'),
    source('lib/research-access.ts'),
    source('app/page.tsx'),
    source('components/AxioChat.tsx'),
    ...protectedRoutes.map((route) => source(route)),
  ]);

  assert.match(billing, /PADDLE_PRICE_FREE_MONTH/);
  assert.match(access, /paid_research_required/);
  assert.match(access, /status: 402/);
  assert.match(home, /researchAccess/);
  assert.match(chat, /Free access is read-only/);
  for (const [index, route] of routes.entries()) {
    assert.match(
      route,
      /requirePaidResearchAccess\(\)/,
      `${protectedRoutes[index]} must enforce paid research access`
    );
  }

  const publicRuntimeStatus = await source(
    'app/api/quant/research/status/route.ts'
  );
  assert.match(publicRuntimeStatus, /probeQuantResearchBackend\(\)/);
  assert.doesNotMatch(publicRuntimeStatus, /requirePaidResearchAccess\(\)/);
});

test('Paddle automatic payment surfaces are a permanent repository contract', async () => {
  const [contract, pricingPage, pricingClient, checkoutRoute, webhookRoute] =
    await Promise.all([
      source('AGENTS.md'),
      source('app/pricing/page.tsx'),
      source('app/pricing/PaddlePricingClient.tsx'),
      source('app/api/paddle/checkout/route.ts'),
      source('app/api/paddle/webhook/route.ts'),
    ]);

  assert.match(contract, /Paddle Billing is permanent production infrastructure/);
  assert.match(contract, /Free and Pro use Paddle recurring monthly collection/);
  assert.match(contract, /Annual uses Paddle\s+recurring yearly collection/);
  assert.match(contract, /Do not delete or archive Paddle products, prices/);
  assert.match(pricingPage, /<PaddlePricingClient/);
  assert.match(pricingClient, /fetch\('\/api\/paddle\/checkout'/);
  assert.match(pricingClient, /paddle\.Checkout\.open\(\{/);
  assert.match(pricingClient, /transactionId: payload\.transactionId/);
  assert.match(checkoutRoute, /createPaddleTransactionCheckout/);
  assert.match(webhookRoute, /getPaddle\(\)\.webhooks\.unmarshal\(rawBody, secret, signature\)/);
  assert.match(webhookRoute, /EventName\.TransactionCompleted/);
});

test('Paddle environment is mandatory and never silently defaults', async () => {
  const paddle = await source('lib/paddle.ts');

  assert.match(
    paddle,
    /if \(value !== 'sandbox' && value !== 'live'\) \{\s*throw new Error\('PADDLE_ENVIRONMENT/
  );
  assert.doesNotMatch(paddle, /PADDLE_ENVIRONMENT[^;\n]*\|\|[^;\n]*sandbox/);
  assert.doesNotMatch(paddle, /PADDLE_ENVIRONMENT[^;\n]*\?\?[^;\n]*(?:sandbox|live)/);
});

test('Paddle webhook completeness accepts three valid, distinct current prices', () => {
  assert.equal(
    currentPaddleCatalogPricesAreComplete(currentPriceTiers, currentPrices),
    true
  );
});

test('Paddle webhook completeness fails closed when a current price is missing', () => {
  const { PADDLE_PRICE_ANNUAL_YEAR: _missing, ...missingAnnual } = currentPrices;
  assert.equal(
    currentPaddleCatalogPricesAreComplete(currentPriceTiers, missingAnnual),
    false
  );
});

test('legacy Paddle prices do not affect current catalog completeness', () => {
  assert.equal(
    currentPaddleCatalogPricesAreComplete(currentPriceTiers, currentPrices),
    true
  );
  assert.equal(
    currentPaddleCatalogPricesAreComplete(currentPriceTiers, {
      ...currentPrices,
      PADDLE_PRICE_STARTER_MONTH: `pri_${'g'.repeat(25)}8`,
      PADDLE_PRICE_LIFETIME: `pri_${'h'.repeat(25)}9`,
      PADDLE_PRICE_LEGACY_PRO_MONTH: `pri_${'i'.repeat(25)}0`,
      PADDLE_PRICE_STARTER_YEAR: `pri_${'d'.repeat(25)}4`,
      PADDLE_PRICE_PRO_YEAR: `pri_${'e'.repeat(25)}5`,
      PADDLE_PRICE_ADVANCED_MONTH: `pri_${'f'.repeat(25)}6`,
      PADDLE_PRICE_ADVANCED_YEAR: `pri_${'0'.repeat(25)}7`,
    }),
    true
  );
});

test('Paddle webhook completeness rejects duplicate or malformed current prices', () => {
  assert.equal(
    currentPaddleCatalogPricesAreComplete(currentPriceTiers, {
      ...currentPrices,
      PADDLE_PRICE_ANNUAL_YEAR: currentPrices.PADDLE_PRICE_PRO_MONTH,
    }),
    false
  );
  assert.equal(
    currentPaddleCatalogPricesAreComplete(currentPriceTiers, {
      ...currentPrices,
      PADDLE_PRICE_ANNUAL_YEAR: 'pri_not-a-real-price',
    }),
    false
  );
});

test('standalone runtime receives the browser-safe Paddle token after image build', async () => {
  const [paddle, compose, envExample] = await Promise.all([
    source('lib/paddle.ts'),
    source('infra/single-vm/compose.yaml'),
    source('.env.example'),
  ]);

  assert.match(
    paddle,
    /process\.env\.PADDLE_CLIENT_TOKEN\?\.trim\(\)[\s\S]*process\.env\.NEXT_PUBLIC_PADDLE_CLIENT_TOKEN/
  );
  assert.match(
    compose,
    /PADDLE_CLIENT_TOKEN: \$\{NEXT_PUBLIC_PADDLE_CLIENT_TOKEN:\?set NEXT_PUBLIC_PADDLE_CLIENT_TOKEN\}/
  );
  assert.match(envExample, /^PADDLE_CLIENT_TOKEN=$/m);
});

test('single-VM deployment preserves the permanent Paddle sales environment', async () => {
  const [serverEnvExample, prepareScript, runbook] = await Promise.all([
    source('infra/single-vm/.env.server.example'),
    source('scripts/prepare-single-vm-env.ps1'),
    source('docs/PADDLE_LIVE_RUNBOOK.md'),
  ]);
  const requiredSalesVariables = [
    'BILLING_PROVIDER',
    'AXIO7_SITE_URL',
    'PADDLE_ENVIRONMENT',
    'PADDLE_API_KEY',
    'PADDLE_NOTIFICATION_WEBHOOK_SECRET',
    'NEXT_PUBLIC_PADDLE_CLIENT_TOKEN',
    'PADDLE_CLIENT_TOKEN',
    'PADDLE_TRUST_X_FORWARDED_FOR',
    'PADDLE_ALLOW_SANDBOX_ACCESS',
    'PADDLE_PRODUCT_FREE',
    'PADDLE_PRICE_FREE_MONTH',
    'PADDLE_PRODUCT_PRO',
    'PADDLE_PRICE_PRO_MONTH',
    'PADDLE_PRODUCT_ANNUAL',
    'PADDLE_PRICE_ANNUAL_YEAR',
  ];

  for (const name of requiredSalesVariables) {
    assert.match(serverEnvExample, new RegExp(`^${name}=`, 'm'));
    assert.match(prepareScript, new RegExp(`"${name}"`));
  }
  assert.match(serverEnvExample, /^BILLING_PROVIDER=paddle$/m);
  assert.match(serverEnvExample, /^PADDLE_ENVIRONMENT=live$/m);
  assert.match(serverEnvExample, /^PADDLE_TRUST_X_FORWARDED_FOR=true$/m);
  assert.match(serverEnvExample, /^PADDLE_ALLOW_SANDBOX_ACCESS=false$/m);
  assert.match(prepareScript, /Existing output was not changed/);
  assert.match(prepareScript, /existing generated server file[\s\S]*never[\s\S]*erases/);
  assert.match(prepareScript, /Empty source values never replace/);
  assert.match(
    prepareScript,
    /PADDLE_CLIENT_TOKEN"\] = \$sourceValues\["NEXT_PUBLIC_PADDLE_CLIENT_TOKEN"\]/
  );
  assert.match(
    prepareScript,
    /Secret values were not printed\./
  );
  assert.match(runbook, /Free monthly, Pro monthly, and Annual yearly/);
  assert.match(runbook, /Historical Starter, Pro, Lifetime, annual, and Advanced Price IDs[\s\S]*legacy subscriptions/);
  assert.doesNotMatch(runbook, /monthly\/yearly toggling|all six Price IDs|six current prices/i);
});

test(
  'single-VM env generator preserves existing values and fails before destructive overwrite',
  { skip: process.platform !== 'win32' },
  async () => {
    const temporaryDirectory = await mkdtemp(join(tmpdir(), 'axio7-paddle-env-'));
    const sourcePath = join(temporaryDirectory, 'source.env');
    const outputPath = join(temporaryDirectory, 'server.env');
    const missingSourcePath = join(temporaryDirectory, 'missing.env');
    const protectedOutputPath = join(temporaryDirectory, 'protected.env');
    const scriptPath = fileURLToPath(
      new URL('../scripts/prepare-single-vm-env.ps1', import.meta.url)
    );
    const productIds = {
      free: `pro_${'a'.repeat(26)}`,
      pro: `pro_${'b'.repeat(26)}`,
      annual: `pro_${'c'.repeat(26)}`,
    };
    const priceIds = {
      free: `pri_${'d'.repeat(26)}`,
      pro: `pri_${'e'.repeat(26)}`,
      annual: `pri_${'f'.repeat(26)}`,
      legacy: `pri_${'0'.repeat(26)}`,
    };
    const sourceLines = [
      'NEXT_PUBLIC_SUPABASE_URL=https://example.supabase.co',
      'NEXT_PUBLIC_SUPABASE_ANON_KEY=fixture_anon_secret',
      'SUPABASE_SERVICE_ROLE_KEY=fixture_service_secret',
      'OPENAI_API_KEY=fixture_openai_secret',
      'BILLING_PROVIDER=paddle',
      'AXIO7_SITE_URL=https://axio7.com',
      'PADDLE_ENVIRONMENT=live',
      'PADDLE_API_KEY=pdl_live_apikey_fixture_secret',
      'PADDLE_NOTIFICATION_WEBHOOK_SECRET=fixture_webhook_secret',
      'NEXT_PUBLIC_PADDLE_CLIENT_TOKEN=live_fixture_public_token',
      'PADDLE_TRUST_X_FORWARDED_FOR=true',
      'PADDLE_ALLOW_SANDBOX_ACCESS=false',
      `PADDLE_PRODUCT_FREE=${productIds.free}`,
      `PADDLE_PRICE_FREE_MONTH=${priceIds.free}`,
      `PADDLE_PRODUCT_PRO=${productIds.pro}`,
      `PADDLE_PRICE_PRO_MONTH=${priceIds.pro}`,
      `PADDLE_PRODUCT_ANNUAL=${productIds.annual}`,
      `PADDLE_PRICE_ANNUAL_YEAR=${priceIds.annual}`,
    ];

    try {
      await writeFile(sourcePath, `${sourceLines.join('\n')}\n`, 'utf8');
      await writeFile(
        outputPath,
        `KEEP_ME=present\nINTRADAY_QUANT_TOKEN=existing_quant_secret\nPADDLE_PRICE_STARTER_YEAR=${priceIds.legacy}\n`,
        'utf8'
      );
      const success = spawnSync(
        'powershell.exe',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', scriptPath, '-Source', sourcePath, '-Output', outputPath],
        { encoding: 'utf8' }
      );
      assert.equal(success.status, 0, success.stderr);
      for (const secret of [
        'fixture_anon_secret',
        'fixture_service_secret',
        'fixture_openai_secret',
        'pdl_live_apikey_fixture_secret',
        'fixture_webhook_secret',
        'existing_quant_secret',
      ]) {
        assert.doesNotMatch(success.stdout, new RegExp(secret));
      }
      const generated = await readFile(outputPath, 'utf8');
      assert.match(generated, /^KEEP_ME=present$/m);
      assert.match(generated, /^INTRADAY_QUANT_TOKEN=existing_quant_secret$/m);
      assert.match(generated, new RegExp(`^PADDLE_PRICE_STARTER_YEAR=${priceIds.legacy}$`, 'm'));
      assert.match(generated, /^BILLING_PROVIDER=paddle$/m);
      assert.match(generated, /^PADDLE_CLIENT_TOKEN=live_fixture_public_token$/m);
      assert.match(generated, new RegExp(`^PADDLE_PRICE_ANNUAL_YEAR=${priceIds.annual}$`, 'm'));

      const missingLines = sourceLines.filter(
        (line) => !line.startsWith('PADDLE_PRICE_ANNUAL_YEAR=')
      );
      await writeFile(missingSourcePath, `${missingLines.join('\n')}\n`, 'utf8');
      await writeFile(protectedOutputPath, 'SENTINEL=unchanged\n', 'utf8');
      const failure = spawnSync(
        'powershell.exe',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', scriptPath, '-Source', missingSourcePath, '-Output', protectedOutputPath],
        { encoding: 'utf8' }
      );
      assert.notEqual(failure.status, 0);
      assert.equal(await readFile(protectedOutputPath, 'utf8'), 'SENTINEL=unchanged\n');
    } finally {
      await rm(temporaryDirectory, { recursive: true, force: true });
    }
  }
);

test('non-Vercel reverse-proxy country resolution is explicit and server-side', async () => {
  const [checkoutRoute, envExample] = await Promise.all([
    source('app/api/paddle/checkout/route.ts'),
    source('.env.example'),
  ]);

  assert.match(checkoutRoute, /PADDLE_TRUST_X_FORWARDED_FOR/);
  assert.match(checkoutRoute, /x-forwarded-for/);
  assert.match(checkoutRoute, /resolvePaddleCheckoutCountryFromIp/);
  assert.match(envExample, /PADDLE_TRUST_X_FORWARDED_FOR=false/);
});

test('reverse-proxy checkout URLs use the confirmed public site origin', async () => {
  const [checkoutRoute, sharedCheckout, compose, serverEnvExample] = await Promise.all([
    source('app/api/paddle/checkout/route.ts'),
    source('lib/stripe.ts'),
    source('infra/single-vm/compose.yaml'),
    source('infra/single-vm/.env.server.example'),
  ]);

  assert.match(checkoutRoute, /baseUrl: requestBaseUrl\(request\)/);
  assert.match(sharedCheckout, /process\.env\.AXIO7_SITE_URL/);
  assert.match(
    sharedCheckout,
    /NODE_ENV === 'production'[\s\S]*!runtimeSiteUrl && !vercelRuntime[\s\S]*AXIO7_SITE_URL is required in production/
  );
  assert.match(sharedCheckout, /process\.env\.VERCEL === '1'/);
  assert.match(sharedCheckout, /runtimeSiteUrl \|\| process\.env\.NEXT_PUBLIC_SITE_URL/);
  assert.match(sharedCheckout, /request\.headers\.get\('origin'\)/);
  assert.match(sharedCheckout, /x-forwarded-host/);
  assert.match(sharedCheckout, /x-forwarded-proto/);
  assert.match(
    sharedCheckout,
    /suppliedOrigin === configuredOrigin[\s\S]*forwardedRequestOrigin\(request\) === configuredOrigin/
  );
  assert.match(compose, /AXIO7_SITE_URL: \$\{AXIO7_SITE_URL:\?set AXIO7_SITE_URL\}/);
  assert.match(serverEnvExample, /AXIO7_SITE_URL=https:\/\/axio7\.com/);
});
