import 'server-only';

import Stripe from 'stripe';

export type BillingPlanKey = 'starter' | 'pro' | 'premium' | 'enterprise';

export type BillingPlanDefinition = {
  key: BillingPlanKey;
  envName:
    | 'STRIPE_PRICE_STARTER'
    | 'STRIPE_PRICE_PRO'
    | 'STRIPE_PRICE_PREMIUM'
    | 'STRIPE_PRICE_ENTERPRISE';
  fallbackName: string;
  fallbackDescription: string;
  fallbackUnitAmount: number;
  mode: 'subscription' | 'payment';
};

export type PublicBillingPlan = BillingPlanDefinition & {
  configured: boolean;
  priceId: string | null;
  name: string;
  description: string;
  unitAmount: number | null;
  currency: string | null;
  recurringInterval: string | null;
};

type StripeMode = 'test' | 'live';

const BILLING_PLANS: readonly BillingPlanDefinition[] = [
  {
    key: 'starter',
    envName: 'STRIPE_PRICE_STARTER',
    fallbackName: 'AXIO7 Starter',
    fallbackDescription: 'Core educational lessons, source-reading exercises, and review notes for one learner.',
    fallbackUnitAmount: 5990,
    mode: 'subscription',
  },
  {
    key: 'pro',
    envName: 'STRIPE_PRICE_PRO',
    fallbackName: 'AXIO7 Pro',
    fallbackDescription: 'Guided learning workspaces, historical case reviews, and source-comparison exercises.',
    fallbackUnitAmount: 15990,
    mode: 'subscription',
  },
  {
    key: 'premium',
    envName: 'STRIPE_PRICE_PREMIUM',
    fallbackName: 'AXIO7 Premium',
    fallbackDescription: 'The complete AXIO7 learning library with advanced source-reading and review modules.',
    fallbackUnitAmount: 29990,
    mode: 'subscription',
  },
  {
    key: 'enterprise',
    envName: 'STRIPE_PRICE_ENTERPRISE',
    fallbackName: 'AXIO7 Enterprise',
    fallbackDescription: 'Team-scale access, priority onboarding, and enterprise billing.',
    fallbackUnitAmount: 299990,
    mode: 'subscription',
  },
] as const;

let stripeInstance: Stripe | null = null;

function stripeKeyMode(key: string | undefined): StripeMode | null {
  const value = key?.trim();
  const match = value?.match(/^[sr]k_(test|live)_/);
  return (match?.[1] as StripeMode | undefined) ?? null;
}

export function isStripeConfigured(): boolean {
  return stripeKeyMode(process.env.STRIPE_SECRET_KEY) !== null;
}

export function isStripeLiveMode(): boolean {
  return stripeKeyMode(process.env.STRIPE_SECRET_KEY) === 'live';
}

export function getStripe(): Stripe {
  const key = process.env.STRIPE_SECRET_KEY?.trim();
  if (!key) throw new Error('STRIPE_SECRET_KEY is not configured.');

  stripeInstance ??= new Stripe(key, {
    apiVersion: '2026-06-24.dahlia',
    appInfo: {
      name: 'AXIO7',
      version: '1.0.0',
      url: 'https://axio7.com',
    },
  });
  return stripeInstance;
}

export function getBillingPlanDefinition(key: string): BillingPlanDefinition | null {
  return BILLING_PLANS.find((plan) => plan.key === key) ?? null;
}

export function getBillingPriceId(plan: BillingPlanDefinition): string | null {
  const value = process.env[plan.envName]?.trim();
  return value && value.startsWith('price_') ? value : null;
}

function fallbackPlan(plan: BillingPlanDefinition): PublicBillingPlan {
  return {
    ...plan,
    configured: false,
    priceId: getBillingPriceId(plan),
    name: plan.fallbackName,
    description: plan.fallbackDescription,
    unitAmount: plan.fallbackUnitAmount,
    currency: 'usd',
    recurringInterval: 'month',
  };
}

export async function getPublicBillingPlans(loadStripe = true): Promise<PublicBillingPlan[]> {
  if (!loadStripe || !isStripeConfigured()) return BILLING_PLANS.map(fallbackPlan);

  const stripe = getStripe();
  return Promise.all(
    BILLING_PLANS.map(async (plan): Promise<PublicBillingPlan> => {
      const priceId = getBillingPriceId(plan);
      if (!priceId) return fallbackPlan(plan);

      try {
        const price = await stripe.prices.retrieve(priceId, { expand: ['product'] });
        const recurringMatches = plan.mode === 'subscription' ? Boolean(price.recurring) : !price.recurring;
        if (!price.active || !recurringMatches) return fallbackPlan(plan);

        const product = typeof price.product === 'string' ? null : price.product;
        const liveProduct = product && !('deleted' in product && product.deleted) ? product : null;

        return {
          ...plan,
          configured: true,
          priceId,
          name: liveProduct?.name || plan.fallbackName,
          description: liveProduct?.description || plan.fallbackDescription,
          unitAmount: price.unit_amount,
          currency: price.currency,
          recurringInterval: price.recurring?.interval ?? null,
        };
      } catch (error) {
        console.error(`[billing] Unable to load ${plan.key} Stripe price`, error);
        return fallbackPlan(plan);
      }
    })
  );
}

function canonicalOrigin(value: string | null | undefined): string | null {
  if (!value) return null;
  try {
    const origin = new URL(value).origin;
    return origin === 'null' ? null : origin;
  } catch {
    return null;
  }
}

function configuredSiteOrigin(): string | null {
  const runtimeSiteUrl = process.env.AXIO7_SITE_URL?.trim();
  const vercelRuntime = process.env.VERCEL === '1';
  if (process.env.NODE_ENV === 'production' && !runtimeSiteUrl && !vercelRuntime) {
    throw new Error('AXIO7_SITE_URL is required in production.');
  }

  const configured = runtimeSiteUrl || process.env.NEXT_PUBLIC_SITE_URL?.trim();
  if (!configured) return null;
  const origin = canonicalOrigin(configured);
  if (!origin) throw new Error('AXIO7_SITE_URL must be a valid HTTP(S) URL.');
  return origin;
}

function forwardedRequestOrigin(request: Request): string | null {
  const forwardedHost = request.headers.get('x-forwarded-host')?.split(',')[0]?.trim();
  const forwardedProto = request.headers.get('x-forwarded-proto')?.split(',')[0]?.trim();
  if (!forwardedHost || (forwardedProto !== 'http' && forwardedProto !== 'https')) {
    return null;
  }
  return canonicalOrigin(`${forwardedProto}://${forwardedHost}`);
}

export function requestBaseUrl(request: Request): string {
  const requestOrigin = new URL(request.url).origin;
  const configuredOrigin = configuredSiteOrigin();
  if (!configuredOrigin) return requestOrigin;

  // A TLS-terminating reverse proxy may expose its internal HTTP origin through
  // request.url. Use the configured public origin only when the browser Origin
  // or the proxy's forwarded origin independently confirms it.
  const suppliedOrigin = canonicalOrigin(request.headers.get('origin'));
  if (
    suppliedOrigin === configuredOrigin ||
    forwardedRequestOrigin(request) === configuredOrigin
  ) {
    return configuredOrigin;
  }
  return requestOrigin;
}

export function hasTrustedPostOrigin(request: Request): boolean {
  const origin = canonicalOrigin(request.headers.get('origin'));
  if (!origin) return false;

  const allowed = new Set([new URL(request.url).origin]);
  const configured = configuredSiteOrigin();
  if (configured) allowed.add(configured);
  return allowed.has(origin);
}
