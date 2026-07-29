'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import { Check, CreditCard, Loader2 } from 'lucide-react';
import {
  CheckoutEventNames,
  initializePaddle,
  type CountryCode,
  type Environments,
  type Paddle,
} from '@paddle/paddle-js';
import type { PaddlePublicTier, PaddleTierKey } from '@/lib/paddle-catalog';

type Props = {
  authenticated: boolean;
  clientToken: string;
  countryCode?: string;
  environment: Environments;
  tiers: PaddlePublicTier[];
};

type PriceMap = Partial<Record<PaddleTierKey, string>>;
type PreviewState = 'loading' | 'ready' | 'error';

function billingLabel(tier: PaddlePublicTier): string {
  if (tier.billingMode === 'one_time') return 'One-time payment';
  if (tier.key === 'free') return 'Free access';
  return tier.cadence === 'year' ? 'Annual subscription' : 'Monthly subscription';
}

function priceSuffix(tier: PaddlePublicTier): string {
  if (tier.billingMode === 'one_time') return 'one time';
  return tier.cadence === 'year' ? '/year' : '/month';
}

function subscribeLabel(tier: PaddlePublicTier): string {
  if (tier.key === 'free') return 'Start free access';
  if (tier.cadence === 'year') return 'Subscribe annually';
  return 'Subscribe';
}

function discountDetails(tier: PaddlePublicTier): {
  badge: string;
  original: string | null;
} {
  if (tier.key === 'free') {
    return { badge: '100% FREE · READ-ONLY', original: null };
  }
  if (tier.key === 'pro') {
    return { badge: '54% OFF', original: 'Original price US$149/month' };
  }
  if (tier.key === 'annual') {
    return { badge: '53% OFF', original: 'Original price US$1,499/year' };
  }
  return { badge: 'LEGACY', original: null };
}

async function abandonPaddleCheckout(transactionId: string): Promise<void> {
  const response = await fetch('/api/paddle/checkout/abandon', {
    method: 'POST',
    credentials: 'same-origin',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ transactionId }),
    keepalive: true,
  });
  if (!response.ok && response.status !== 409) {
    throw new Error(`Paddle checkout abandonment returned ${response.status}.`);
  }
}

export function PaddlePricingClient({
  authenticated,
  clientToken,
  countryCode,
  environment,
  tiers,
}: Props) {
  const [paddle, setPaddle] = useState<Paddle | null>(null);
  const [prices, setPrices] = useState<PriceMap>({});
  const [previewState, setPreviewState] = useState<PreviewState>('loading');
  const [previewCountryCode, setPreviewCountryCode] = useState<string | null>(null);
  const [checkoutTier, setCheckoutTier] = useState<PaddleTierKey | null>(null);
  const [error, setError] = useState<string | null>(null);
  const activeTransactionId = useRef<string | null>(null);
  const checkoutCompleted = useRef(false);

  const priceSignature = useMemo(
    () => tiers.map((tier) => tier.priceId).join(':'),
    [tiers]
  );

  useEffect(() => {
    let active = true;

    if (!clientToken || !environment || tiers.length !== 3) {
      setPreviewState('error');
      setError('Paddle checkout is not configured. Please contact AXIO7 support.');
      return () => {
        active = false;
      };
    }

    async function initializeAndPreview() {
      try {
        const instance = await initializePaddle({
          token: clientToken,
          environment,
          eventCallback: (event) => {
            if (event.name === CheckoutEventNames.CHECKOUT_COMPLETED) {
              checkoutCompleted.current = true;
              const completedTransactionId = event.data?.transaction_id;
              if (
                typeof completedTransactionId !== 'string' ||
                completedTransactionId === activeTransactionId.current
              ) {
                activeTransactionId.current = null;
              }
              setCheckoutTier(null);
              window.location.assign('/welcome');
            } else if (event.name === CheckoutEventNames.CHECKOUT_CLOSED) {
              const eventTransactionId = event.data?.transaction_id;
              const closedTransactionId =
                typeof eventTransactionId === 'string'
                  ? eventTransactionId
                  : activeTransactionId.current;
              if (
                !checkoutCompleted.current &&
                typeof closedTransactionId === 'string' &&
                /^txn_[a-z0-9]{26}$/.test(closedTransactionId)
              ) {
                if (activeTransactionId.current === closedTransactionId) {
                  activeTransactionId.current = null;
                  setCheckoutTier(null);
                }
                void abandonPaddleCheckout(closedTransactionId).catch((abandonError) => {
                  console.error('[billing] Unable to abandon closed Paddle checkout', abandonError);
                });
              }
            } else if (
              event.name === CheckoutEventNames.CHECKOUT_ERROR ||
              event.name === CheckoutEventNames.CHECKOUT_FAILED ||
              event.name === CheckoutEventNames.CHECKOUT_PAYMENT_ERROR
            ) {
              setCheckoutTier(null);
              setError('Paddle could not complete checkout. Please review the payment form and try again.');
            }
          },
        });

        if (!active) return;
        if (!instance) throw new Error('Paddle.js did not initialize.');
        setPaddle(instance);

        const preview = await instance.PricePreview({
          items: tiers.map((tier) => ({ priceId: tier.priceId, quantity: 1 })),
          ...(countryCode
            ? { address: { countryCode: countryCode as CountryCode } }
            : {}),
        });
        const formattedByPrice = new Map(
          preview.data.details.lineItems.map((item) => [
            item.price.id,
            item.formattedTotals.subtotal,
          ])
        );
        const nextPrices: PriceMap = {};
        for (const tier of tiers) {
          const formattedTotal = formattedByPrice.get(tier.priceId);
          if (!formattedTotal) throw new Error(`Paddle did not return a total for ${tier.key}.`);
          nextPrices[tier.key] = formattedTotal;
        }

        if (!active) return;
        setPrices(nextPrices);
        setPreviewCountryCode(preview.data.address?.countryCode ?? null);
        setPreviewState('ready');
      } catch (previewError) {
        console.error('[billing] Unable to initialize Paddle pricing', previewError);
        if (!active) return;
        setPreviewState('error');
        setError('Localized prices are temporarily unavailable. Please try again later.');
      }
    }

    void initializeAndPreview();
    return () => {
      active = false;
    };
  }, [clientToken, countryCode, environment, priceSignature, tiers]);

  async function subscribe(tier: PaddlePublicTier) {
    setError(null);

    if (!authenticated) {
      window.location.assign('/auth/signin?next=%2Fpricing');
      return;
    }
    if (!paddle || previewState !== 'ready') {
      setError('Secure checkout is still loading. Please try again in a moment.');
      return;
    }

    setCheckoutTier(tier.key);
    checkoutCompleted.current = false;
    try {
      const response = await fetch('/api/paddle/checkout', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          tier: tier.key,
          countryCode: countryCode ?? previewCountryCode,
        }),
      });
      const payload = (await response.json().catch(() => null)) as
        | { transactionId?: unknown; error?: unknown }
        | null;

      if (!response.ok || typeof payload?.transactionId !== 'string') {
        if (payload?.error === 'authentication_required') {
          window.location.assign('/auth/signin?next=%2Fpricing');
          return;
        }
        if (payload?.error === 'already_subscribed') {
          window.location.assign('/billing');
          return;
        }
        if (payload?.error === 'checkout_processing') {
          window.location.assign('/welcome');
          return;
        }
        if (payload?.error === 'checkout_selection_locked') {
          throw new Error(
            'An earlier checkout is still open for a different option. Finish that checkout or contact support before changing plans.'
          );
        }
        if (payload?.error === 'checkout_in_progress') {
          throw new Error('Secure checkout is already starting. Please wait a moment and try again.');
        }
        if (payload?.error === 'invalid_plan') {
          throw new Error('That billing option is not available.');
        }
        if (payload?.error === 'checkout_country_unavailable') {
          throw new Error(
            'Paddle could not determine the checkout country. Refresh the page or contact support.'
          );
        }
        if (payload?.error === 'invalid_origin') {
          throw new Error('Secure checkout rejected this site origin. Please contact AXIO7 support.');
        }
        if (payload?.error === 'paddle_not_active') {
          throw new Error('Paddle checkout is temporarily unavailable. Please contact AXIO7 support.');
        }
        if (payload?.error === 'checkout_unavailable') {
          throw new Error('Paddle could not create a secure checkout. Please try again later.');
        }
        throw new Error('Unable to start secure checkout. Please try again later.');
      }
      if (!/^txn_[a-z0-9]{26}$/.test(payload.transactionId)) {
        throw new Error('Paddle returned an invalid transaction.');
      }

      activeTransactionId.current = payload.transactionId;
      const successUrl = new URL('/welcome', window.location.origin).toString();
      // The server-created transaction already has the authenticated Paddle
      // customer attached. Transaction checkout must inherit that customer;
      // passing customer.email here tries to alter it and can block the hosted
      // checkout from opening.
      paddle.Checkout.open({
        transactionId: payload.transactionId,
        settings: {
          displayMode: 'overlay',
          variant: 'one-page',
          successUrl,
        },
      });
    } catch (checkoutError) {
      if (activeTransactionId.current) {
        const transactionId = activeTransactionId.current;
        activeTransactionId.current = null;
        try {
          await abandonPaddleCheckout(transactionId);
        } catch (abandonError) {
          console.error('[billing] Unable to abandon unopened Paddle checkout', abandonError);
        }
      }
      console.error('[billing] Unable to open Paddle checkout', checkoutError);
      setError(
        checkoutError instanceof Error
          ? checkoutError.message
          : 'Unable to start secure checkout.'
      );
      setCheckoutTier(null);
    }
  }

  return (
    <>
      <p className="axio-pricing-localization-note">
        <span aria-hidden="true" />
        Live localized pricing · Paddle shows the checkout total and any applicable tax.
      </p>

      {error ? (
        <div
          role="alert"
          className="axio-pricing-notice"
        >
          {error}
        </div>
      ) : null}

      <div className="axio-plan-grid">
        {tiers.map((tier) => {
          const highlighted = tier.key === 'pro';
          const formattedTotal = prices[tier.key];
          const busy = checkoutTier === tier.key;
          const checkoutLocked = checkoutTier !== null;
          const unavailable = previewState !== 'ready' || !formattedTotal;
          const discount = discountDetails(tier);

          return (
            <article
              key={tier.key}
              className={`axio-plan-card ${highlighted ? 'axio-plan-card--featured' : ''}`}
            >
              {highlighted ? (
                <span className="axio-plan-popular">
                  Most popular
                </span>
              ) : null}
              <p className="axio-plan-kicker">
                {billingLabel(tier)}
              </p>
              <h2 className="axio-plan-title">{tier.name}</h2>
              <p className="axio-plan-description">{tier.description}</p>

              <div
                className="axio-plan-price"
                role="status"
                aria-live="polite"
                aria-busy={previewState === 'loading'}
              >
                {formattedTotal ? (
                  <>
                    <span className="axio-pricing-total">
                      {formattedTotal}
                    </span>
                    <span className="axio-price-suffix">
                      {priceSuffix(tier)}
                    </span>
                  </>
                ) : (
                  <span className="axio-price-loading">
                    {previewState === 'loading' ? <Loader2 className="h-4 w-4 animate-spin" /> : null}
                    {previewState === 'loading' ? 'Loading localized price' : 'Price unavailable'}
                  </span>
                )}
              </div>

              <div className="axio-plan-discount">
                <strong>{discount.badge}</strong>
                {discount.original ? <span>{discount.original}</span> : null}
              </div>

              <button
                type="button"
                disabled={checkoutLocked || (authenticated && unavailable)}
                onClick={() => void subscribe(tier)}
                className={`axio-subscribe-action ${
                  highlighted ? 'axio-subscribe-action--featured' : ''
                }`}
              >
                {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <CreditCard className="h-4 w-4" />}
                {authenticated
                  ? subscribeLabel(tier)
                  : 'Sign in to subscribe'}
              </button>

              <ul className="axio-plan-features">
                {tier.features.map((feature) => (
                  <li key={feature}>
                    <Check />
                    <span>{feature}</span>
                  </li>
                ))}
              </ul>
            </article>
          );
        })}

        <article className="axio-plan-card axio-plan-card--enterprise">
          <p className="axio-plan-kicker">Enterprise</p>
          <h2 className="axio-plan-title">Enterprise</h2>
          <p className="axio-plan-description">
            Multi-seat research access, procurement support, and an enterprise
            agreement sized to your organization.
          </p>

          <div className="axio-plan-price">
            <span className="axio-pricing-total">Custom</span>
            <span className="axio-price-suffix">volume pricing</span>
          </div>

          <div className="axio-plan-discount">
            <strong>CUSTOM DISCOUNT</strong>
            <span>Written quote based on seats and deployment scope</span>
          </div>

          <Link className="axio-subscribe-action" href="/support">
            <CreditCard className="h-4 w-4" />
            Contact enterprise sales
          </Link>

          <ul className="axio-plan-features">
            {[
              'Multi-seat team access',
              'Procurement and onboarding support',
              'Volume discount documented in the enterprise quote',
            ].map((feature) => (
              <li key={feature}>
                <Check />
                <span>{feature}</span>
              </li>
            ))}
          </ul>
        </article>
      </div>

      {!authenticated ? (
        <p className="axio-pricing-signin-note">
          Already have an account?{' '}
          <Link href="/auth/signin?next=/pricing" className="font-bold underline underline-offset-4">
            Sign in before subscribing
          </Link>
          .
        </p>
      ) : null}
    </>
  );
}
