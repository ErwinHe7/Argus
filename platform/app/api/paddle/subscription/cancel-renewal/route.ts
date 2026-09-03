import { NextResponse } from 'next/server';
import { getCurrentUser } from '@/lib/auth';
import { getProviderBillingAccount } from '@/lib/billing';
import { recordBillingUsageEventBestEffort } from '@/lib/refund-requests';
import { syncPaddleSubscription } from '@/lib/paddle-billing';
import {
  cancelPaddleSubscriptionAtPeriodEnd,
  isPaddleConfigured,
  isPaddleSandbox,
  retrievePaddleSubscription,
} from '@/lib/paddle';
import { hasTrustedPostOrigin, requestBaseUrl } from '@/lib/stripe';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

function billingRedirect(request: Request, renewal: 'cancelled' | 'unavailable') {
  const url = new URL('/billing', requestBaseUrl(request));
  url.searchParams.set('renewal', renewal);
  return NextResponse.redirect(url, 303);
}

export async function POST(request: Request) {
  const user = await getCurrentUser();
  if (!user.authenticated) {
    const signIn = new URL('/auth/signin', requestBaseUrl(request));
    signIn.searchParams.set('next', '/billing');
    return NextResponse.redirect(signIn, 303);
  }
  if (!hasTrustedPostOrigin(request)) {
    return NextResponse.json({ error: 'Invalid request origin.' }, { status: 403 });
  }
  if (!isPaddleConfigured()) return billingRedirect(request, 'unavailable');

  try {
    const testMode = isPaddleSandbox();
    const account = await getProviderBillingAccount(user.id, 'paddle', testMode);
    const subscriptionId = account?.provider_subscription_id;
    const customerId = account?.provider_customer_id;
    if (!subscriptionId || !customerId) {
      return billingRedirect(request, 'unavailable');
    }

    const current = await retrievePaddleSubscription(subscriptionId);
    if (current.customerId !== customerId) {
      throw new Error('Paddle cancellation ownership check failed.');
    }
    const updated =
      current.scheduledChange?.action === 'cancel'
        ? current
        : await cancelPaddleSubscriptionAtPeriodEnd(subscriptionId);
    await syncPaddleSubscription(updated, user.id);
    await recordBillingUsageEventBestEffort({
      userId: user.id,
      eventType: 'renewal_cancelled',
      metadata: {
        subscription_id: subscriptionId,
        effective_at: updated.scheduledChange?.effectiveAt ?? null,
      },
    });
    return billingRedirect(request, 'cancelled');
  } catch (error) {
    console.error('[billing] Unable to cancel Paddle renewal', error);
    return billingRedirect(request, 'unavailable');
  }
}
