import { Environment, Paddle } from '@paddle/paddle-node-sdk';

// Product identity is stable across price changes. Prices are immutable once
// published, so every commercial revision gets a new price catalog version.
const productCatalogKey = 'axio7-research';
const priceCatalogVersion = 'axio7-research-pricing-2026-07-v5-usd-no-trial-0-69-699';
const legacyProductCatalogVersion = 'axio7-education-2026-07-v1';
const environment = process.env.PADDLE_ENVIRONMENT?.trim().toLowerCase();
const apiKey = process.env.PADDLE_API_KEY?.trim();

if (environment !== 'sandbox' && environment !== 'live') {
  throw new Error('PADDLE_ENVIRONMENT must be explicitly set to sandbox or live.');
}
if (!apiKey) throw new Error('PADDLE_API_KEY is required.');
if (environment === 'live' && !apiKey.startsWith('pdl_live_apikey_')) {
  throw new Error('Live catalog provisioning requires a live Paddle API key.');
}
if (environment === 'sandbox' && !apiKey.startsWith('pdl_sdbx_apikey_')) {
  throw new Error('Sandbox catalog provisioning requires a sandbox Paddle API key.');
}
if (
  environment === 'live' &&
  process.env.PADDLE_CATALOG_CREATE_CONFIRM !== 'CREATE_AXIO7_LIVE_CATALOG'
) {
  throw new Error(
    'Set PADDLE_CATALOG_CREATE_CONFIRM=CREATE_AXIO7_LIVE_CATALOG after Paddle approves the real AXIO7 product.'
  );
}

const tiers = [
  {
    key: 'free',
    name: 'Free',
    description:
      'Free read-only access to AXIO7 public pages for the impersonal quantitative market-research service.',
    billingMode: 'recurring',
    cadence: 'month',
    amount: 0,
    productEnvName: 'PADDLE_PRODUCT_FREE',
    priceEnvName: 'PADDLE_PRICE_FREE_MONTH',
  },
  {
    key: 'pro',
    name: 'Pro',
    description: 'Monthly Pro access to the same evidence-first quantitative research service.',
    billingMode: 'recurring',
    cadence: 'month',
    amount: 6900,
    productEnvName: 'PADDLE_PRODUCT_PRO',
    priceEnvName: 'PADDLE_PRICE_PRO_MONTH',
  },
  {
    key: 'annual',
    name: 'Annual',
    description:
      'Annual Pro access to the impersonal, evidence-first quantitative market-research service.',
    billingMode: 'recurring',
    cadence: 'year',
    amount: 69900,
    productEnvName: 'PADDLE_PRODUCT_ANNUAL',
    priceEnvName: 'PADDLE_PRICE_ANNUAL_YEAR',
  },
];

const paddle = new Paddle(apiKey, {
  environment: environment === 'live' ? Environment.production : Environment.sandbox,
});

function customValue(entity, key) {
  const customData = entity.customData;
  return customData && typeof customData === 'object' ? customData[key] : undefined;
}

function customDataWith(entity, values) {
  const existing =
    entity.customData && typeof entity.customData === 'object' ? entity.customData : {};
  return { ...existing, ...values };
}

async function listAll(collection) {
  const values = [];
  for await (const value of collection) values.push(value);
  return values;
}

function envName(value) {
  return value.toUpperCase();
}

function priceMatches(price, tier, productId) {
  const billingCycleMatches =
    tier.billingMode === 'one_time'
      ? price.billingCycle == null
      : price.billingCycle?.interval === tier.cadence && price.billingCycle?.frequency === 1;
  return (
    price.productId === productId &&
    price.status === 'active' &&
    billingCycleMatches &&
    price.trialPeriod == null &&
    price.unitPrice.currencyCode === 'USD' &&
    price.unitPrice.amount === String(tier.amount) &&
    (price.unitPriceOverrides?.length ?? 0) === 0
  );
}

function assertExistingPrice(price, tier, productId) {
  if (!priceMatches(price, tier, productId)) {
    throw new Error(
      `Existing ${tier.key}/${tier.cadence} price ${price.id} does not match the requested USD-only, no-trial catalog.`
    );
  }
}

const existingProducts = await listAll(
  paddle.products.list({ status: ['active'], perPage: 200 })
);
const mapping = {};

for (const tier of tiers) {
  const configuredProductId = process.env[tier.productEnvName]?.trim();
  let product = existingProducts.find(
    (candidate) => candidate.id === configuredProductId
  );
  product ??= existingProducts.find(
    (candidate) =>
      customValue(candidate, 'axio7_product_key') === productCatalogKey &&
      customValue(candidate, 'axio7_tier') === tier.key
  );
  // Reuse products from the original catalog script. Only the attached price
  // entities are versioned, so existing product IDs remain stable.
  product ??= existingProducts.find(
    (candidate) =>
      customValue(candidate, 'axio7_catalog_version') === legacyProductCatalogVersion &&
      customValue(candidate, 'axio7_tier') === tier.key
  );
  // Also adopt an exact product created in the dashboard or through another
  // trusted provisioning path, then stamp AXIO7's stable metadata below.
  product ??= existingProducts.find(
    (candidate) =>
      candidate.name === tier.name &&
      candidate.description === tier.description
  );
  if (!product) {
    product = await paddle.products.create({
      name: tier.name,
      taxCategory: 'saas',
      description: tier.description,
      customData: {
        axio7_product_key: productCatalogKey,
        axio7_tier: tier.key,
      },
    });
  } else {
    product = await paddle.products.update(product.id, {
      name: tier.name,
      description: tier.description,
      customData: customDataWith(product, {
        axio7_product_key: productCatalogKey,
        axio7_tier: tier.key,
      }),
    });
  }

  mapping[tier.key] = { productId: product.id, priceId: null };
  const existingPrices = await listAll(
    paddle.prices.list({ productId: [product.id], status: ['active'], perPage: 200 })
  );

  const configuredPriceId = process.env[tier.priceEnvName]?.trim();
  let price = existingPrices.find(
    (candidate) =>
      candidate.id === configuredPriceId &&
      priceMatches(candidate, tier, product.id)
  );
  price ??= existingPrices.find(
    (candidate) =>
      customValue(candidate, 'axio7_price_catalog_version') === priceCatalogVersion &&
      customValue(candidate, 'axio7_tier') === tier.key &&
      customValue(candidate, 'axio7_cadence') === tier.cadence
  );
  price ??= existingPrices.find((candidate) =>
    priceMatches(candidate, tier, product.id)
  );
  if (price) {
    assertExistingPrice(price, tier, product.id);
  } else {
    price = await paddle.prices.create({
      name:
        tier.billingMode === 'one_time'
          ? tier.name
          : tier.cadence === 'year'
            ? 'Annual'
            : 'Monthly',
      description:
        tier.billingMode === 'one_time'
          ? `${tier.name} - one-time permanent access`
          : `${tier.name} - ${tier.cadence === 'year' ? 'annual' : 'monthly'} subscription`,
      productId: product.id,
      unitPrice: { amount: String(tier.amount), currencyCode: 'USD' },
      ...(tier.billingMode === 'recurring'
        ? { billingCycle: { interval: tier.cadence, frequency: 1 } }
        : {}),
      taxMode: 'account_setting',
      quantity: { minimum: 1, maximum: 1 },
      customData: {
        axio7_product_key: productCatalogKey,
        axio7_price_catalog_version: priceCatalogVersion,
        axio7_tier: tier.key,
        axio7_cadence: tier.cadence,
      },
    });
  }
  mapping[tier.key].priceId = price.id;
}

for (const tier of tiers) {
  const ids = mapping[tier.key];
  process.stdout.write(`${tier.productEnvName}=${ids.productId}\n`);
  process.stdout.write(`${tier.priceEnvName}=${ids.priceId}\n`);
}
