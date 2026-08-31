import { EventName } from '@paddle/paddle-node-sdk';
import { randomUUID } from 'node:crypto';
import { NextResponse } from 'next/server';
import {
  claimPaddleWebhookEvent,
  completePaddleWebhookEvent,
  failPaddleWebhookEvent,
} from '@/lib/billing';
import {
  paddleCatalogDisposition,
  syncPaddleCustomer,
  syncPaddleSubscription,
  syncPaddleTransaction,
} from '@/lib/paddle-billing';
import { syncPaddleRefundAdjustment } from '@/lib/refund-requests';
import {
  configuredPaddlePricesAreComplete,
  getPaddle,
  isPaddleSandbox,
  paddleWebhookSecret,
} from '@/lib/paddle';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const MAX_WEBHOOK_BYTES = 1_000_000;

function messageFor(error: unknown): string {
  return error instanceof Error ? error.message : 'Unknown Paddle webhook processing error';
}

export async function POST(request: Request) {
  const signature = request.headers.get('paddle-signature')?.trim();
  const secret = paddleWebhookSecret();
  if (!signature || !secret) {
    return NextResponse.json({ error: 'Paddle webhook is not configured.' }, { status: 400 });
  }

  const contentLength = Number(request.headers.get('content-length') ?? '0');
  if (Number.isFinite(contentLength) && contentLength > MAX_WEBHOOK_BYTES) {
    return NextResponse.json({ error: 'Webhook payload is too large.' }, { status: 413 });
  }

  // Paddle signs these exact bytes. Never JSON.parse before unmarshal.
  const rawBody = await request.text();
  if (!rawBody || new TextEncoder().encode(rawBody).byteLength > MAX_WEBHOOK_BYTES) {
    return NextResponse.json(
      { error: rawBody ? 'Webhook payload is too large.' : 'Webhook payload is empty.' },
      { status: rawBody ? 413 : 400 }
    );
  }

  let event;
  try {
    event = await getPaddle().webhooks.unmarshal(rawBody, secret, signature);
  } catch (error) {
    console.warn('[billing] Rejected Paddle webhook signature', error);
    // A non-2xx response is intentional so Paddle does not treat an invalid or
    // temporarily misconfigured delivery as successfully fulfilled.
    return NextResponse.json({ error: 'Invalid signature.' }, { status: 400 });
  }

  if (!configuredPaddlePricesAreComplete()) {
    return NextResponse.json(
      { error: 'Paddle catalog configuration is incomplete.' },
      { status: 500 }
    );
  }

  const testMode = isPaddleSandbox();
  const environment = testMode ? 'sandbox' : 'live';
  const claimToken = randomUUID();
  let claim;
  try {
    claim = await claimPaddleWebhookEvent({
      environment,
      testMode,
      eventId: event.eventId,
      notificationId: event.notificationId,
      eventType: event.eventType,
      claimToken,
      occurredAt: event.occurredAt,
    });
  } catch (error) {
    console.error('[billing] Unable to claim Paddle webhook', error);
    return NextResponse.json({ error: 'Webhook claim failed.' }, { status: 500 });
  }

  if (claim === 'processed') {
    return NextResponse.json({ received: true, duplicate: true });
  }
  if (claim === 'busy') {
    // Do not acknowledge a concurrently-processing/stale delivery until one
    // worker has durably committed fulfillment.
    return NextResponse.json({ error: 'Webhook is already processing.' }, { status: 409 });
  }

  try {
    switch (event.eventType) {
      case EventName.AdjustmentCreated:
      case EventName.AdjustmentUpdated:
        await syncPaddleRefundAdjustment(event.data);
        break;
      case EventName.CustomerCreated:
      case EventName.CustomerUpdated:
        await syncPaddleCustomer(event.data, event.occurredAt);
        break;
      case EventName.SubscriptionCreated:
      case EventName.SubscriptionActivated:
      case EventName.SubscriptionUpdated:
      case EventName.SubscriptionTrialing:
      case EventName.SubscriptionPastDue:
      case EventName.SubscriptionPaused:
      case EventName.SubscriptionResumed:
      case EventName.SubscriptionCanceled: {
        const disposition = paddleCatalogDisposition(event.data);
        if (disposition === 'unrelated') break;
        if (disposition === 'invalid') {
          throw new Error('Paddle subscription mixes AXIO7 and unrelated catalog items.');
        }
        await syncPaddleSubscription(event.data, null, null, event.occurredAt);
        break;
      }
      case EventName.TransactionCompleted: {
        const disposition = paddleCatalogDisposition(event.data);
        if (disposition === 'unrelated') break;
        if (disposition === 'invalid') {
          throw new Error('Paddle transaction mixes AXIO7 and unrelated catalog items.');
        }
        await syncPaddleTransaction(event.data, event.occurredAt);
        break;
      }
      default:
        // Verified but irrelevant events are intentionally acknowledged after
        // recording their event ID, so repeated delivery is harmless.
        break;
    }

    await completePaddleWebhookEvent(environment, event.eventId, claimToken);
    return NextResponse.json({ received: true });
  } catch (error) {
    console.error(`[billing] Paddle webhook ${event.eventType} failed`, error);
    try {
      await failPaddleWebhookEvent(
        environment,
        event.eventId,
        claimToken,
        messageFor(error)
      );
    } catch (recordError) {
      // The original non-2xx still causes Paddle to retry. A processing claim is
      // also recoverable after its five-minute stale-claim timeout.
      console.error('[billing] Unable to mark Paddle webhook failed', recordError);
    }
    return NextResponse.json({ error: 'Webhook processing failed.' }, { status: 500 });
  }
}
