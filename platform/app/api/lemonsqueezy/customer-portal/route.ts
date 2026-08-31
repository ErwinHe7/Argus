import { NextResponse } from 'next/server';
import { getCurrentUser } from '@/lib/auth';
import { getProviderBillingAccount } from '@/lib/billing';
import {
  syncLemonSqueezySubscription,
  validateLemonSqueezySubscription,
} from '@/lib/lemon-billing';
import {
  isLemonSqueezyConfigured,
  isLemonSqueezyTestMode,
  retrieveLemonSqueezySubscription,
} from '@/lib/lemon-squeezy';
import { hasTrustedPostOrigin, requestBaseUrl } from '@/lib/stripe';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

function unavailable(request: Request) {
  const url = new URL('/billing', requestBaseUrl(request));
  url.searchParams.set('portal', 'unavailable');
  return NextResponse.redirect(url, 303);
}

export async function POST(request: Request) {
  if (!hasTrustedPostOrigin(request)) {
    return NextResponse.json({ error: 'Invalid request origin.' }, { status: 403 });
  }

  const user = await getCurrentUser();
  if (!user.authenticated) {
    const signIn = new URL('/auth/signin', requestBaseUrl(request));
    signIn.searchParams.set('next', '/billing');
    return NextResponse.redirect(signIn, 303);
  }
  if (!isLemonSqueezyConfigured()) return unavailable(request);

  try {
    const account = await getProviderBillingAccount(
      user.id,
      'lemon_squeezy',
      isLemonSqueezyTestMode()
    );
    if (!account?.provider_subscription_id) return unavailable(request);

    const subscription = await retrieveLemonSqueezySubscription(account.provider_subscription_id);
    const normalized = validateLemonSqueezySubscription(subscription);
    if (
      normalized.id !== account.provider_subscription_id ||
      normalized.customerId !== account.provider_customer_id
    ) {
      throw new Error('Lemon Squeezy portal ownership check failed.');
    }

    await syncLemonSqueezySubscription(subscription, user.id);
    if (!normalized.customerPortalUrl) return unavailable(request);
    return NextResponse.redirect(normalized.customerPortalUrl, 303);
  } catch (error) {
    console.error('[billing] Unable to open Lemon Squeezy customer portal', error);
    return unavailable(request);
  }
}
