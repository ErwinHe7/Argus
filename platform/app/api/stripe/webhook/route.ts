import type Stripe from 'stripe';
import { NextResponse } from 'next/server';
import {
  hasProcessedStripeEvent,
  recordProcessedStripeEvent,
  revokeLifetimeAccessForPaymentIntent,
  syncStripeCheckoutSession,
  syncStripeInvoice,
  syncStripeSubscription,
} from '@/lib/billing';
import { getStripe, isStripeLiveMode } from '@/lib/stripe';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function POST(request: Request) {
  const signature = request.headers.get('stripe-signature');
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET?.trim();
  if (!signature || !webhookSecret) {
    return NextResponse.json({ error: 'Stripe webhook is not configured.' }, { status: 400 });
  }

  let event: Stripe.Event;
  try {
    event = getStripe().webhooks.constructEvent(await request.text(), signature, webhookSecret);
  } catch (error) {
    console.error('[billing] Stripe webhook signature verification failed', error);
    return NextResponse.json({ error: 'Invalid signature.' }, { status: 400 });
  }

  try {
    if (event.livemode !== isStripeLiveMode()) {
      return NextResponse.json({ error: 'Stripe event mode mismatch.' }, { status: 400 });
    }

    if (await hasProcessedStripeEvent(event.id)) {
      return NextResponse.json({ received: true, duplicate: true });
    }

    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object;
        if (session.payment_status === 'paid' || session.payment_status === 'no_payment_required') {
          await syncStripeCheckoutSession(session);
        }
        break;
      }
      case 'checkout.session.async_payment_succeeded':
        await syncStripeCheckoutSession(event.data.object);
        break;
      case 'checkout.session.async_payment_failed':
        break;
      case 'customer.subscription.created':
      case 'customer.subscription.updated':
      case 'customer.subscription.deleted':
        await syncStripeSubscription(event.data.object);
        break;
      case 'invoice.paid':
      case 'invoice.payment_failed':
        await syncStripeInvoice(event.data.object);
        break;
      case 'invoice.finalization_failed':
        break;
      case 'charge.refunded': {
        const charge = event.data.object;
        const paymentIntent =
          typeof charge.payment_intent === 'string'
            ? charge.payment_intent
            : charge.payment_intent?.id;
        if (paymentIntent && charge.refunded) {
          await revokeLifetimeAccessForPaymentIntent(paymentIntent);
        }
        break;
      }
      default:
        break;
    }

    await recordProcessedStripeEvent(event);
    return NextResponse.json({ received: true });
  } catch (error) {
    console.error(`[billing] Stripe webhook ${event.id} failed`, error);
    return NextResponse.json({ error: 'Webhook processing failed.' }, { status: 500 });
  }
}
