import { NextResponse } from 'next/server';
import { randomUUID } from 'node:crypto';
import { getCurrentUser } from '@/lib/auth';
import {
  assertPaddleBillingStorageReady,
  billingAccountHasAccess,
  claimPaddleCheckoutAttempt,
  finalizePaddleCheckoutAttempt,
  getBillingAccount,
  resetPaddleCheckoutAttempt,
  rotatePaddleReadyCheckoutAttempt,
} from '@/lib/billing';
import {
  getCurrentPaddlePriceIds,
  getPaddlePriceId,
  getPaddleTier,
} from '@/lib/paddle-catalog';
import {
  cancelPaddleFreeSubscriptionForUpgrade,
  cancelRetiredPaddleCheckoutTransactionForUser,
  createPaddleTransactionCheckout,
  getPaddleEnvironment,
  isPaddleCheckoutConfigured,
  isPaddleConfigured,
  PaddleCheckoutTransactionProcessingError,
  PaddleCheckoutTransactionSelectionLockedError,
  PaddleCheckoutTransactionUnavailableError,
  retrievePaddleTransaction,
  resolvePaddleCheckoutCountryFromIp,
} from '@/lib/paddle';
import { syncPaddleSubscription } from '@/lib/paddle-billing';
import {
  ensurePaddleCheckoutIdentity,
  findPaddleTransactionByAttemptToken,
} from '@/lib/paddle-checkout';
import { getActiveBillingProvider } from '@/lib/payment-provider';
import { hasTrustedPostOrigin, requestBaseUrl } from '@/lib/stripe';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

type CheckoutBody = {
  tier?: unknown;
  countryCode?: unknown;
};

async function readBody(request: Request): Promise<CheckoutBody> {
  const contentType = request.headers.get('content-type')?.toLowerCase() ?? '';
  if (contentType.includes('application/json')) {
    const value = (await request.json()) as unknown;
    return value && typeof value === 'object' ? (value as CheckoutBody) : {};
  }

  const form = await request.formData();
  return {
    tier: form.get('tier') ?? form.get('plan'),
    countryCode: form.get('countryCode'),
  };
}

function validCountry(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const normalized = value.trim().toUpperCase();
  return /^[A-Z]{2}$/.test(normalized) ? normalized : null;
}

function trustedClientIp(request: Request): string | null {
  const vercelRequest = Boolean(request.headers.get('x-vercel-id'));
  const trustedReverseProxy =
    process.env.PADDLE_TRUST_X_FORWARDED_FOR?.trim().toLowerCase() === 'true';
  if (!vercelRequest && !trustedReverseProxy) return null;

  const value =
    (vercelRequest ? request.headers.get('x-vercel-forwarded-for') : null) ??
    request.headers.get('x-forwarded-for') ??
    request.headers.get('x-real-ip');
  return value?.split(',')[0]?.trim() || null;
}

export async function POST(request: Request) {
  if (!hasTrustedPostOrigin(request)) {
    return NextResponse.json({ error: 'invalid_origin' }, { status: 403 });
  }

  if (getActiveBillingProvider() !== 'paddle') {
    return NextResponse.json({ error: 'paddle_not_active' }, { status: 503 });
  }

  const user = await getCurrentUser();
  if (!user.authenticated) {
    return NextResponse.json(
      { error: 'authentication_required', signInUrl: '/auth/signin?next=%2Fpricing' },
      { status: 401 }
    );
  }

  try {
    // Reading the environment is deliberately mandatory. An unset or invalid
    // value must never silently choose the wrong Paddle account.
    const paddleEnvironment = getPaddleEnvironment();
    if (!isPaddleConfigured()) {
      throw new Error('PADDLE_API_KEY is missing or does not match the configured environment.');
    }

    const body = await readBody(request);
    const tier = getPaddleTier(typeof body.tier === 'string' ? body.tier : '');
    if (!tier) {
      return NextResponse.json({ error: 'invalid_plan' }, { status: 400 });
    }
    const cadence = tier.cadence;
    if (!isPaddleCheckoutConfigured(tier, cadence)) {
      throw new Error(`Paddle checkout is not fully configured for ${tier.key}/${cadence}.`);
    }

    // No chargeable transaction is created until the durable entitlement and
    // idempotency storage is available.
    await assertPaddleBillingStorageReady();

    const environment = paddleEnvironment;
    const testMode = environment === 'sandbox';
    const account = await getBillingAccount(user.id);
    if (billingAccountHasAccess(account)) {
      return NextResponse.json(
        { error: 'already_subscribed', billingUrl: '/billing' },
        { status: 409 }
      );
    }
    const paddleAccount = account?.provider_accounts?.find(
      (entry) => entry.provider === 'paddle' && entry.test_mode === testMode
    );
    const freeTier = getPaddleTier('free');
    if (!freeTier) throw new Error('The Paddle Free tier is missing.');
    const freePriceId = getPaddlePriceId(freeTier);
    const hasActiveFreeSubscription =
      paddleAccount?.provider_price_id === freePriceId &&
      Boolean(paddleAccount.provider_subscription_id) &&
      ['active', 'trialing'].includes(paddleAccount.subscription_status ?? '');
    if (tier.key === 'free' && hasActiveFreeSubscription) {
      return NextResponse.json(
        { error: 'already_subscribed', billingUrl: '/billing' },
        { status: 409 }
      );
    }
    if (tier.key !== 'free' && hasActiveFreeSubscription) {
      if (!paddleAccount?.provider_subscription_id || !paddleAccount.provider_customer_id) {
        throw new Error('The Paddle Free subscription identity is incomplete.');
      }
      const canceledFree = await cancelPaddleFreeSubscriptionForUpgrade({
        subscriptionId: paddleAccount.provider_subscription_id,
        customerId: paddleAccount.provider_customer_id,
        freePriceId,
      });
      await syncPaddleSubscription(canceledFree, user.id);
    }

    const headerCountry = validCountry(request.headers.get('x-vercel-ip-country'));
    const previewCountry = validCountry(body.countryCode);
    const serverIp = headerCountry ? null : trustedClientIp(request);
    const countryCode = headerCountry ?? (
      serverIp
        ? await resolvePaddleCheckoutCountryFromIp({
            tier,
            cadence,
            customerIpAddress: serverIp,
          })
        : paddleEnvironment === 'sandbox'
          ? previewCountry
          : null
    );
    if (!countryCode) {
      return NextResponse.json(
        { error: 'checkout_country_unavailable' },
        { status: 400, headers: { 'cache-control': 'no-store' } }
      );
    }

    const requestedAttemptToken = randomUUID();
    const claim = await claimPaddleCheckoutAttempt({
      environment,
      testMode,
      userId: user.id,
      attemptToken: requestedAttemptToken,
    });
    if (claim.state === 'busy') {
      return NextResponse.json({ error: 'checkout_in_progress' }, { status: 409 });
    }
    if (claim.state === 'completed') {
      return NextResponse.json(
        { error: 'already_subscribed', billingUrl: '/billing' },
        { status: 409 }
      );
    }

    let attemptToken = claim.attemptToken;
    let existingTransactionId = claim.transactionId;
    let mustFinalize = claim.state === 'claimed';
    if (claim.state === 'recover') {
      const recoveredTransactionId = await findPaddleTransactionByAttemptToken(
        claim.attemptToken
      );
      if (recoveredTransactionId) {
        await finalizePaddleCheckoutAttempt({
          environment,
          userId: user.id,
          attemptToken: claim.attemptToken,
          transactionId: recoveredTransactionId,
        });
        existingTransactionId = recoveredTransactionId;
      } else {
        const replacementToken = randomUUID();
        const reset = await resetPaddleCheckoutAttempt({
          environment,
          userId: user.id,
          previousToken: claim.attemptToken,
          attemptToken: replacementToken,
        });
        if (!reset) {
          return NextResponse.json({ error: 'checkout_in_progress' }, { status: 409 });
        }
        attemptToken = replacementToken;
        mustFinalize = true;
      }
    }

    const identity = await ensurePaddleCheckoutIdentity({ user });

    const createTransaction = () => createPaddleTransactionCheckout({
        tier,
        cadence,
        user,
        baseUrl: requestBaseUrl(request),
        countryCode,
        customerId: identity.customerId,
        attemptToken,
        existingTransactionId,
      });
    let transactionId: string;
    try {
      transactionId = await createTransaction();
    } catch (error) {
      if (error instanceof PaddleCheckoutTransactionProcessingError) {
        return NextResponse.json(
          { error: 'checkout_processing', welcomeUrl: '/welcome' },
          { status: 409, headers: { 'cache-control': 'no-store' } }
        );
      }
      if (error instanceof PaddleCheckoutTransactionSelectionLockedError) {
        const lockedTransaction = await retrievePaddleTransaction(error.transactionId);
        const lockedPriceId = lockedTransaction.items[0]?.price?.id;
        if (
          existingTransactionId &&
          lockedPriceId &&
          !getCurrentPaddlePriceIds().has(lockedPriceId)
        ) {
          // A ready checkout from a retired public catalog must not strand the
          // customer after a catalog migration. Ownership and the durable
          // attempt token are revalidated before cancellation. Current-catalog
          // selections remain locked so another open tab is never overwritten.
          await cancelRetiredPaddleCheckoutTransactionForUser({
            transactionId: existingTransactionId,
            userId: user.id,
            attemptToken,
            retiredPriceId: lockedPriceId,
          });
          const replacementToken = randomUUID();
          const rotated = await rotatePaddleReadyCheckoutAttempt({
            environment,
            userId: user.id,
            expectedToken: attemptToken,
            expectedTransactionId: existingTransactionId,
            attemptToken: replacementToken,
          });
          if (!rotated) {
            return NextResponse.json({ error: 'checkout_in_progress' }, { status: 409 });
          }
          attemptToken = replacementToken;
          existingTransactionId = null;
          mustFinalize = true;
          transactionId = await createTransaction();
          if (mustFinalize) {
            await finalizePaddleCheckoutAttempt({
              environment,
              userId: user.id,
              attemptToken,
              transactionId,
            });
          }
          return NextResponse.json(
            { transactionId },
            { status: 201, headers: { 'cache-control': 'no-store' } }
          );
        }
        return NextResponse.json(
          { error: 'checkout_selection_locked' },
          { status: 409, headers: { 'cache-control': 'no-store' } }
        );
      }
      if (!(error instanceof PaddleCheckoutTransactionUnavailableError) || !existingTransactionId) {
        throw error;
      }

      const replacementToken = randomUUID();
      const rotated = await rotatePaddleReadyCheckoutAttempt({
        environment,
        userId: user.id,
        expectedToken: attemptToken,
        expectedTransactionId: existingTransactionId,
        attemptToken: replacementToken,
      });
      if (!rotated) {
        return NextResponse.json({ error: 'checkout_in_progress' }, { status: 409 });
      }
      attemptToken = replacementToken;
      existingTransactionId = null;
      mustFinalize = true;
      transactionId = await createTransaction();
    }
    if (mustFinalize) {
      await finalizePaddleCheckoutAttempt({
        environment,
        userId: user.id,
        attemptToken,
        transactionId,
      });
    }
    return NextResponse.json(
      { transactionId },
      { status: 201, headers: { 'cache-control': 'no-store' } }
    );
  } catch (error) {
    console.error('[billing] Unable to create Paddle transaction checkout', error);
    return NextResponse.json(
      { error: 'checkout_unavailable' },
      { status: 503, headers: { 'cache-control': 'no-store' } }
    );
  }
}
