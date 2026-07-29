import type Stripe from 'stripe';
import { NextResponse } from 'next/server';
import { getCurrentUser } from '@/lib/auth';
import { billingAccountHasAccess, ensureStripeCustomer, getBillingAccount } from '@/lib/billing';
import { getActiveBillingProvider } from '@/lib/payment-provider';
import {
  getBillingPlanDefinition,
  getBillingPriceId,
  getStripe,
  hasTrustedPostOrigin,
  isStripeConfigured,
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

  if (getActiveBillingProvider() !== 'stripe' || !isStripeConfigured()) {
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
    const requestedPlan = String(form.get('plan') ?? '');
    const plan = getBillingPlanDefinition(requestedPlan);
    if (!plan) return pricingRedirect(request, 'invalid-plan');

    const account = await getBillingAccount(user.id);
    if (billingAccountHasAccess(account)) {
      return NextResponse.redirect(new URL('/billing', requestBaseUrl(request)), 303);
    }

    const priceId = getBillingPriceId(plan);
    if (!priceId) return pricingRedirect(request, 'unavailable');

    const stripe = getStripe();
    const price = await stripe.prices.retrieve(priceId);
    const recurringMatches = plan.mode === 'subscription' ? Boolean(price.recurring) : !price.recurring;
    if (!price.active || !recurringMatches) return pricingRedirect(request, 'unavailable');

    const customer = await ensureStripeCustomer(user);
    const baseUrl = requestBaseUrl(request);
    const metadata = {
      axio7_user_id: user.id,
      axio7_plan: plan.key,
      stripe_price_id: priceId,
    };

    const params: Stripe.Checkout.SessionCreateParams = {
      mode: plan.mode,
      integration_identifier: 'axio7_web_checkout_gsjmklzl',
      customer,
      client_reference_id: user.id,
      line_items: [{ price: priceId, quantity: 1 }],
      allow_promotion_codes: true,
      billing_address_collection: 'auto',
      customer_update: { address: 'auto', name: 'auto' },
      success_url: `${baseUrl}/billing/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${baseUrl}/pricing?checkout=cancelled`,
      metadata,
    };

    if (plan.mode === 'subscription') {
      params.subscription_data = { metadata };
    } else {
      params.payment_intent_data = { metadata };
    }

    if (process.env.STRIPE_AUTOMATIC_TAX === 'true') {
      params.automatic_tax = { enabled: true };
    }

    const idempotencyWindow = Math.floor(Date.now() / (5 * 60_000));
    const session = await stripe.checkout.sessions.create(params, {
      idempotencyKey: `axio7_checkout_${user.id}_${plan.key}_${idempotencyWindow}`,
    });
    if (!session.url) throw new Error('Stripe did not return a Checkout URL.');
    return NextResponse.redirect(session.url, 303);
  } catch (error) {
    console.error('[billing] Unable to create Stripe Checkout Session', error);
    return pricingRedirect(request, 'unavailable');
  }
}
