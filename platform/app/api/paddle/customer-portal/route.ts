import { NextResponse } from 'next/server';
import { getCurrentUser } from '@/lib/auth';
import { getProviderBillingAccount } from '@/lib/billing';
import {
  getPaddlePortalIdentityForUser,
  syncPaddleSubscription,
} from '@/lib/paddle-billing';
import {
  createPaddleCustomerPortalUrl,
  isPaddleConfigured,
  isPaddleSandbox,
  retrievePaddleSubscription,
} from '@/lib/paddle';
import { hasTrustedPostOrigin, requestBaseUrl } from '@/lib/stripe';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

function unavailable(request: Request) {
  const url = new URL('/billing', requestBaseUrl(request));
  url.searchParams.set('portal', 'unavailable');
  return NextResponse.redirect(url, 303);
}

export async function POST(request: Request) {
  // Authentication is resolved before any customer/subscription identifier is
  // read. Client input is never used to select a Paddle customer.
  const user = await getCurrentUser();
  if (!user.authenticated) {
    const signIn = new URL('/auth/signin', requestBaseUrl(request));
    signIn.searchParams.set('next', '/billing');
    return NextResponse.redirect(signIn, 303);
  }
  if (!hasTrustedPostOrigin(request)) {
    return NextResponse.json({ error: 'Invalid request origin.' }, { status: 403 });
  }
  if (!isPaddleConfigured()) return unavailable(request);

  try {
    const testMode = isPaddleSandbox();
    const mirrored = await getPaddlePortalIdentityForUser(user.id, testMode);
    const account = await getProviderBillingAccount(user.id, 'paddle', testMode);
    const customerId = mirrored?.customerId ?? account?.provider_customer_id;
    const subscriptionId = mirrored?.subscriptionId ?? account?.provider_subscription_id;
    if (!customerId || !subscriptionId) {
      return unavailable(request);
    }

    const subscription = await retrievePaddleSubscription(subscriptionId);
    if (
      subscription.id !== subscriptionId ||
      subscription.customerId !== customerId
    ) {
      throw new Error('Paddle portal ownership check failed.');
    }

    // This validates the configured AXIO7 price and refreshes the local record
    // before a management session is issued for the authenticated owner.
    await syncPaddleSubscription(subscription, user.id);

    // Portal URLs are intentionally generated per request and never cached or
    // persisted because Paddle makes these links temporary.
    const portalUrl = await createPaddleCustomerPortalUrl({
      customerId,
      subscriptionId,
    });
    return NextResponse.redirect(portalUrl, 303);
  } catch (error) {
    console.error('[billing] Unable to open Paddle customer portal', error);
    return unavailable(request);
  }
}
