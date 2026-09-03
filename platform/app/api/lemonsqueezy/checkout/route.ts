import { NextResponse } from 'next/server';
import { getCurrentUser } from '@/lib/auth';
import {
  assertProviderBillingStorageReady,
  billingAccountHasAccess,
  getBillingAccount,
} from '@/lib/billing';
import {
  createLemonSqueezyCheckout,
  isLemonSqueezyCheckoutConfigured,
  isLemonSqueezyConfigured,
} from '@/lib/lemon-squeezy';
import { getActiveBillingProvider } from '@/lib/payment-provider';
import {
  getBillingPlanDefinition,
  hasTrustedPostOrigin,
  requestBaseUrl,
} from '@/lib/stripe';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

function pricingRedirect(request: Request, state: string) {
  const url = new URL('/pricing', requestBaseUrl(request));
  url.searchParams.set('checkout', state);
  return NextResponse.redirect(url, 303);
}

export async function POST(request: Request) {
  if (!hasTrustedPostOrigin(request)) {
    return NextResponse.json({ error: 'Invalid request origin.' }, { status: 403 });
  }

  if (getActiveBillingProvider() !== 'lemonsqueezy' || !isLemonSqueezyConfigured()) {
    return pricingRedirect(request, 'unavailable');
  }

  const user = await getCurrentUser();
  if (!user.authenticated) {
    const signIn = new URL('/auth/signin', requestBaseUrl(request));
    signIn.searchParams.set('next', '/pricing');
    return NextResponse.redirect(signIn, 303);
  }

  try {
    const form = await request.formData();
    const plan = getBillingPlanDefinition(String(form.get('plan') ?? ''));
    if (!plan) return pricingRedirect(request, 'invalid-plan');
    if (!isLemonSqueezyCheckoutConfigured(plan)) {
      return pricingRedirect(request, 'unavailable');
    }

    // Fail before creating a chargeable hosted checkout if the database
    // migration or webhook-event storage is not ready.
    await assertProviderBillingStorageReady();

    const account = await getBillingAccount(user.id);
    if (billingAccountHasAccess(account)) {
      return NextResponse.redirect(new URL('/billing', requestBaseUrl(request)), 303);
    }

    const checkoutUrl = await createLemonSqueezyCheckout({
      plan,
      user,
      baseUrl: requestBaseUrl(request),
    });
    return NextResponse.redirect(checkoutUrl, 303);
  } catch (error) {
    console.error('[billing] Unable to create Lemon Squeezy Checkout', error);
    return pricingRedirect(request, 'unavailable');
  }
}
