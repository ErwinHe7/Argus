import { NextResponse } from 'next/server';
import {
  hasProcessedPaymentEvent,
  recordProcessedPaymentEvent,
} from '@/lib/billing';
import {
  lemonSqueezyCustomUserId,
  syncLemonSqueezySubscription,
} from '@/lib/lemon-billing';
import {
  asLemonSqueezySubscription,
  getLemonSqueezyStoreId,
  isLemonSqueezyTestMode,
  lemonSqueezyWebhookEventId,
  parseLemonSqueezyWebhook,
  retrieveLemonSqueezySubscription,
  verifyLemonSqueezyWebhook,
} from '@/lib/lemon-squeezy';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function POST(request: Request) {
  const signature = request.headers.get('x-signature')?.trim();
  const eventHeader = request.headers.get('x-event-name')?.trim();
  if (!signature || !eventHeader || !process.env.LEMONSQUEEZY_WEBHOOK_SECRET?.trim()) {
    return NextResponse.json({ error: 'Lemon Squeezy webhook is not configured.' }, { status: 400 });
  }

  const contentLength = Number(request.headers.get('content-length') ?? '0');
  if (Number.isFinite(contentLength) && contentLength > 1_000_000) {
    return NextResponse.json({ error: 'Webhook payload is too large.' }, { status: 413 });
  }

  const rawBody = await request.text();
  if (!verifyLemonSqueezyWebhook(rawBody, signature)) {
    return NextResponse.json({ error: 'Invalid signature.' }, { status: 400 });
  }

  try {
    const payload = parseLemonSqueezyWebhook(rawBody);
    if (payload.meta.event_name !== eventHeader) {
      return NextResponse.json({ error: 'Webhook event name mismatch.' }, { status: 400 });
    }
    const eventTestMode = payload.data.attributes.test_mode;
    if (
      typeof eventTestMode !== 'boolean' ||
      eventTestMode !== isLemonSqueezyTestMode()
    ) {
      return NextResponse.json({ error: 'Webhook mode mismatch.' }, { status: 400 });
    }
    const eventStoreId = String(payload.data.attributes.store_id ?? '').trim();
    if (!/^\d+$/.test(eventStoreId) || eventStoreId !== getLemonSqueezyStoreId()) {
      return NextResponse.json({ error: 'Webhook store mismatch.' }, { status: 400 });
    }

    const eventId = lemonSqueezyWebhookEventId(rawBody);
    if (await hasProcessedPaymentEvent('lemon_squeezy', eventId)) {
      return NextResponse.json({ received: true, duplicate: true });
    }

    const webhookSubscription = asLemonSqueezySubscription(payload);
    if (webhookSubscription) {
      // Retrieve current provider state rather than trusting event delivery
      // order. Lemon Squeezy can retry or deliver lifecycle events later.
      const currentSubscription = await retrieveLemonSqueezySubscription(webhookSubscription.id);
      await syncLemonSqueezySubscription(
        currentSubscription,
        lemonSqueezyCustomUserId(payload.meta.custom_data)
      );
    }

    await recordProcessedPaymentEvent('lemon_squeezy', {
      id: eventId,
      type: eventHeader,
      test_mode: eventTestMode,
    });
    return NextResponse.json({ received: true });
  } catch (error) {
    console.error(`[billing] Lemon Squeezy webhook ${eventHeader} failed`, error);
    return NextResponse.json({ error: 'Webhook processing failed.' }, { status: 500 });
  }
}
