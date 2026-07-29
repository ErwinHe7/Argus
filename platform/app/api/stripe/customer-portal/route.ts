import { NextResponse } from 'next/server';
import { getCurrentUser } from '@/lib/auth';
import { ensureStripeCustomer } from '@/lib/billing';
import { getStripe, hasTrustedPostOrigin, requestBaseUrl } from '@/lib/stripe';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

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

  try {
    const customer = await ensureStripeCustomer(user);
    const portal = await getStripe().billingPortal.sessions.create({
      customer,
      configuration: process.env.STRIPE_PORTAL_CONFIGURATION_ID?.trim() || undefined,
      return_url: `${requestBaseUrl(request)}/billing`,
    });
    return NextResponse.redirect(portal.url, 303);
  } catch (error) {
    console.error('[billing] Unable to create Stripe customer portal session', error);
    const url = new URL('/billing', requestBaseUrl(request));
    url.searchParams.set('portal', 'unavailable');
    return NextResponse.redirect(url, 303);
  }
}
