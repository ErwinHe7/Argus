import 'server-only';

export type BillingProvider = 'stripe' | 'lemonsqueezy' | 'paddle';

export function getActiveBillingProvider(): BillingProvider {
  const configured = process.env.BILLING_PROVIDER?.trim().toLowerCase();
  if (
    configured === 'lemonsqueezy' ||
    configured === 'lemon-squeezy' ||
    configured === 'lemon_squeezy'
  ) {
    return 'lemonsqueezy';
  }
  if (configured === 'paddle') return 'paddle';
  return 'stripe';
}

export function billingProviderLabel(provider = getActiveBillingProvider()): string {
  if (provider === 'lemonsqueezy') return 'Lemon Squeezy';
  if (provider === 'paddle') return 'Paddle';
  return 'Stripe';
}

export function billingCheckoutPath(provider = getActiveBillingProvider()): string {
  if (provider === 'lemonsqueezy') return '/api/lemonsqueezy/checkout';
  if (provider === 'paddle') return '/api/paddle/checkout';
  return '/api/stripe/checkout';
}
