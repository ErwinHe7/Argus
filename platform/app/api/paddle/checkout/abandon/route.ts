import { NextResponse } from 'next/server';
import { getCurrentUser } from '@/lib/auth';
import {
  abandonPaddleCheckoutAttempt,
  assertPaddleBillingStorageReady,
  getPaddleCheckoutAttemptForUser,
} from '@/lib/billing';
import {
  cancelPaddleCheckoutTransactionForUser,
  getPaddleEnvironment,
  isPaddleConfigured,
  PaddleCheckoutTransactionProcessingError,
} from '@/lib/paddle';
import { getActiveBillingProvider } from '@/lib/payment-provider';
import { hasTrustedPostOrigin } from '@/lib/stripe';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

type AbandonBody = { transactionId?: unknown };

async function expectedTransactionId(request: Request): Promise<string | null> {
  const contentType = request.headers.get('content-type')?.toLowerCase() ?? '';
  if (!contentType.includes('application/json')) return null;
  const value = (await request.json().catch(() => null)) as AbandonBody | null;
  return typeof value?.transactionId === 'string' && /^txn_[a-z0-9]{26}$/.test(value.transactionId)
    ? value.transactionId
    : null;
}

export async function POST(request: Request) {
  const user = await getCurrentUser();
  if (!user.authenticated) {
    return NextResponse.json({ error: 'authentication_required' }, { status: 401 });
  }
  if (!hasTrustedPostOrigin(request)) {
    return NextResponse.json({ error: 'invalid_origin' }, { status: 403 });
  }
  if (getActiveBillingProvider() !== 'paddle') {
    return NextResponse.json({ error: 'paddle_not_active' }, { status: 503 });
  }

  try {
    const expectedId = await expectedTransactionId(request);
    if (!expectedId) {
      return NextResponse.json({ error: 'invalid_transaction' }, { status: 400 });
    }
    const environment = getPaddleEnvironment();
    if (!isPaddleConfigured()) {
      throw new Error('PADDLE_API_KEY is missing or does not match the configured environment.');
    }
    await assertPaddleBillingStorageReady();

    // Resolve ownership from the authenticated user. The browser ID is only an
    // expected-value CAS guard against a stale CLOSED event; it is never used
    // to look up or cancel a transaction by itself.
    const attempt = await getPaddleCheckoutAttemptForUser({
      environment,
      userId: user.id,
    });
    if (
      !attempt ||
      attempt.state !== 'ready' ||
      !attempt.transactionId ||
      attempt.transactionId !== expectedId
    ) {
      return new NextResponse(null, { status: 204 });
    }

    await cancelPaddleCheckoutTransactionForUser({
      transactionId: attempt.transactionId,
      userId: user.id,
      attemptToken: attempt.attemptToken,
    });
    const abandoned = await abandonPaddleCheckoutAttempt({
      environment,
      userId: user.id,
      attemptToken: attempt.attemptToken,
      transactionId: attempt.transactionId,
    });
    if (!abandoned) {
      return NextResponse.json(
        { error: 'checkout_state_changed' },
        { status: 409, headers: { 'cache-control': 'no-store' } }
      );
    }
    return new NextResponse(null, {
      status: 204,
      headers: { 'cache-control': 'no-store' },
    });
  } catch (error) {
    if (error instanceof PaddleCheckoutTransactionProcessingError) {
      return NextResponse.json(
        { error: 'checkout_processing' },
        { status: 409, headers: { 'cache-control': 'no-store' } }
      );
    }
    console.error('[billing] Unable to abandon Paddle checkout', error);
    return NextResponse.json(
      { error: 'checkout_abandon_unavailable' },
      { status: 503, headers: { 'cache-control': 'no-store' } }
    );
  }
}
