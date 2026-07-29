import 'server-only';

export type PaddleTierKey = 'free' | 'pro' | 'annual' | 'starter' | 'lifetime';
export type PaddleBillingCadence = 'month' | 'year' | 'lifetime';
export type PaddleBillingMode = 'recurring' | 'one_time';

export interface PaddleTierDefinition {
  key: PaddleTierKey;
  name: 'Free' | 'Pro' | 'Annual' | 'Starter' | 'Lifetime';
  description: string;
  features: string[];
  billingMode: PaddleBillingMode;
  cadence: PaddleBillingCadence;
  baseUnitAmount: number;
  productEnvName:
    | 'PADDLE_PRODUCT_FREE'
    | 'PADDLE_PRODUCT_PRO'
    | 'PADDLE_PRODUCT_ANNUAL'
    | 'PADDLE_PRODUCT_STARTER'
    | 'PADDLE_PRODUCT_LIFETIME';
  priceEnvName:
    | 'PADDLE_PRICE_FREE_MONTH'
    | 'PADDLE_PRICE_PRO_MONTH'
    | 'PADDLE_PRICE_ANNUAL_YEAR'
    | 'PADDLE_PRICE_STARTER_MONTH'
    | 'PADDLE_PRICE_LEGACY_PRO_MONTH'
    | 'PADDLE_PRICE_LIFETIME';
}

export interface PaddlePublicTier {
  key: PaddleTierKey;
  name: PaddleTierDefinition['name'];
  description: string;
  features: string[];
  billingMode: PaddleBillingMode;
  cadence: PaddleBillingCadence;
  priceId: string;
}

export const PADDLE_TIERS: readonly PaddleTierDefinition[] = [
  {
    key: 'free',
    name: 'Free',
    description: 'Free read-only access to AXIO7 public market-research pages.',
    features: [
      'View public AXIO7 research pages',
      'Review the research boundary and methodology',
      'Research runs, scans, backtests, and monitors are locked',
    ],
    billingMode: 'recurring',
    cadence: 'month',
    baseUnitAmount: 0,
    productEnvName: 'PADDLE_PRODUCT_FREE',
    priceEnvName: 'PADDLE_PRICE_FREE_MONTH',
  },
  {
    key: 'pro',
    name: 'Pro',
    description: 'Monthly Pro access to the same evidence-first quantitative research service.',
    features: [
      'Impersonal quantitative research workspace',
      'Source, cutoff, coverage, and caveat disclosure',
      'Reproducibility and model-version receipts',
    ],
    billingMode: 'recurring',
    cadence: 'month',
    baseUnitAmount: 6900,
    productEnvName: 'PADDLE_PRODUCT_PRO',
    priceEnvName: 'PADDLE_PRICE_PRO_MONTH',
  },
  {
    key: 'annual',
    name: 'Annual',
    description: 'Annual Pro access to the same evidence-first quantitative research service.',
    features: [
      'Annual AXIO7 membership access',
      'Automatic yearly renewal',
      'The same evidence-first research boundary and disclosures',
    ],
    billingMode: 'recurring',
    cadence: 'year',
    baseUnitAmount: 69900,
    productEnvName: 'PADDLE_PRODUCT_ANNUAL',
    priceEnvName: 'PADDLE_PRICE_ANNUAL_YEAR',
  },
] as const;

const LEGACY_CONFIGURED_PRICE_ENV_NAMES = [
  'PADDLE_PRICE_STARTER_MONTH',
  'PADDLE_PRICE_LIFETIME',
  'PADDLE_PRICE_LEGACY_PRO_MONTH',
  'PADDLE_PRICE_STARTER_YEAR',
  'PADDLE_PRICE_PRO_YEAR',
  'PADDLE_PRICE_ADVANCED_MONTH',
  'PADDLE_PRICE_ADVANCED_YEAR',
] as const;

const LEGACY_PRICE_TIERS: readonly Pick<
  PaddleTierDefinition,
  'key' | 'billingMode' | 'cadence' | 'priceEnvName'
>[] = [
  {
    key: 'starter',
    billingMode: 'recurring',
    cadence: 'month',
    priceEnvName: 'PADDLE_PRICE_STARTER_MONTH',
  },
  {
    key: 'pro',
    billingMode: 'recurring',
    cadence: 'month',
    priceEnvName: 'PADDLE_PRICE_LEGACY_PRO_MONTH',
  },
  {
    key: 'lifetime',
    billingMode: 'one_time',
    cadence: 'lifetime',
    priceEnvName: 'PADDLE_PRICE_LIFETIME',
  },
] as const;

const PADDLE_ID_PATTERN = /^(?:pro|pri)_[a-z0-9]{26}$/;

function requiredCatalogId(envName: string, prefix: 'pro' | 'pri'): string {
  const value = process.env[envName]?.trim();
  if (!value) throw new Error(`${envName} is not configured.`);
  if (!PADDLE_ID_PATTERN.test(value) || !value.startsWith(`${prefix}_`)) {
    throw new Error(`${envName} is not a valid Paddle ${prefix === 'pro' ? 'product' : 'price'} ID.`);
  }
  return value;
}

export function getPaddleTier(value: string): PaddleTierDefinition | null {
  return PADDLE_TIERS.find((tier) => tier.key === value) ?? null;
}

export function getPaddleProductId(tier: PaddleTierDefinition): string {
  return requiredCatalogId(tier.productEnvName, 'pro');
}

export function getPaddlePriceId(
  tier: PaddleTierDefinition,
  cadence: PaddleBillingCadence = tier.cadence
): string {
  if (cadence !== tier.cadence) {
    throw new Error(`${tier.key} is not available with ${cadence} billing.`);
  }
  return requiredCatalogId(tier.priceEnvName, 'pri');
}

export function getPublicPaddleTiers(): PaddlePublicTier[] {
  return PADDLE_TIERS.map((tier) => ({
    key: tier.key,
    name: tier.name,
    description: tier.description,
    features: [...tier.features],
    billingMode: tier.billingMode,
    cadence: tier.cadence,
    priceId: getPaddlePriceId(tier),
  }));
}

export function getConfiguredPaddlePriceIds(): Set<string> {
  const ids = getCurrentPaddlePriceIds();
  const envNames = [
    ...PADDLE_TIERS.map((tier) => tier.priceEnvName),
    ...LEGACY_CONFIGURED_PRICE_ENV_NAMES,
  ];
  for (const envName of envNames) {
    const value = process.env[envName]?.trim();
    if (value && /^pri_[a-z0-9]{26}$/.test(value)) ids.add(value);
  }
  return ids;
}

export function getCurrentPaddlePriceIds(): Set<string> {
  const ids = new Set<string>();
  for (const tier of PADDLE_TIERS) {
    const value = process.env[tier.priceEnvName]?.trim();
    if (value && /^pri_[a-z0-9]{26}$/.test(value)) ids.add(value);
  }
  return ids;
}

export function getPaddleTierForPriceId(priceId: string): {
  tier: Pick<PaddleTierDefinition, 'key' | 'billingMode' | 'cadence'>;
  cadence: PaddleBillingCadence;
} | null {
  for (const tier of PADDLE_TIERS) {
    if (process.env[tier.priceEnvName]?.trim() === priceId) {
      return { tier, cadence: tier.cadence };
    }
  }
  for (const tier of LEGACY_PRICE_TIERS) {
    if (process.env[tier.priceEnvName]?.trim() === priceId) {
      return { tier, cadence: tier.cadence };
    }
  }
  return null;
}
