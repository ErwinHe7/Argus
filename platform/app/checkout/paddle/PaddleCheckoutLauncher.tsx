'use client';

import { useEffect, useRef, useState } from 'react';
import {
  CheckoutEventNames,
  initializePaddle,
  type Environments,
  type PaddleEventData,
} from '@paddle/paddle-js';

type Props = {
  clientToken: string;
  environment: Environments;
  transactionId: string;
};

async function abandonServerCheckout(
  transactionId: string
): Promise<'released' | 'processing'> {
  const response = await fetch('/api/paddle/checkout/abandon', {
    method: 'POST',
    credentials: 'same-origin',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ transactionId }),
    keepalive: true,
  });
  if (response.status === 409) {
    const payload = (await response.json().catch(() => null)) as { error?: unknown } | null;
    if (payload?.error === 'checkout_processing') return 'processing';
    return 'released';
  }
  if (!response.ok) {
    throw new Error(`Paddle checkout abandonment returned ${response.status}.`);
  }
  return 'released';
}

export function PaddleCheckoutLauncher({
  clientToken,
  environment,
  transactionId,
}: Props) {
  const completed = useRef(false);
  const closing = useRef(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;

    const successUrl = new URL('/welcome', window.location.origin).toString();
    const abandonAndReturn = async () => {
      if (closing.current) return;
      closing.current = true;
      try {
        const result = await abandonServerCheckout(transactionId);
        if (result === 'processing') {
          window.location.assign('/welcome');
          return;
        }
        window.location.assign('/pricing?checkout=cancelled');
      } catch (abandonError) {
        console.error('[billing] Unable to abandon Paddle checkout', abandonError);
        closing.current = false;
        if (active) {
          setError('Checkout closed, but its secure session could not be released. Please try again.');
        }
      }
    };
    const handleEvent = (event: PaddleEventData) => {
      if (!active) return;

      if (event.name === CheckoutEventNames.CHECKOUT_COMPLETED) {
        completed.current = true;
        // This page never grants access. It only navigates to a status page;
        // the verified webhook and server-side billing record remain decisive.
        window.location.assign(successUrl);
      } else if (event.name === CheckoutEventNames.CHECKOUT_CLOSED && !completed.current) {
        void abandonAndReturn();
      } else if (
        event.name === CheckoutEventNames.CHECKOUT_ERROR ||
        event.name === CheckoutEventNames.CHECKOUT_FAILED ||
        event.name === CheckoutEventNames.CHECKOUT_PAYMENT_ERROR
      ) {
        setError('Secure checkout could not continue. Please return to pricing and try again.');
      }
    };

    void initializePaddle({
      token: clientToken,
      environment,
      eventCallback: handleEvent,
      checkout: {
        settings: {
          displayMode: 'overlay',
          variant: 'one-page',
          theme: 'dark',
          locale: 'en',
          successUrl,
        },
      },
    })
      .then((paddle) => {
        if (!active) return;
        if (!paddle) {
          setError('Secure checkout is temporarily unavailable.');
          void abandonAndReturn();
          return;
        }
        paddle.Checkout.open({
          transactionId,
          settings: {
            displayMode: 'overlay',
            variant: 'one-page',
            theme: 'dark',
            locale: 'en',
            successUrl,
          },
        });
      })
      .catch((checkoutError) => {
        console.error('[billing] Unable to initialize Paddle.js', checkoutError);
        if (active) {
          setError('Secure checkout is temporarily unavailable. Releasing this checkout session...');
          void abandonAndReturn();
        }
      });

    return () => {
      active = false;
    };
  }, [clientToken, environment, transactionId]);

  async function retryReleaseCheckout() {
    setError(null);
    closing.current = false;
    try {
      const result = await abandonServerCheckout(transactionId);
      window.location.assign(result === 'processing' ? '/welcome' : '/pricing?checkout=cancelled');
    } catch (releaseError) {
      console.error('[billing] Unable to release Paddle checkout', releaseError);
      setError('This checkout session is still being released. Please try again.');
    }
  }

  return (
    <div className="mx-auto flex min-h-[62vh] max-w-xl items-center px-4 py-12 text-center">
      <section className="w-full rounded-[28px] border border-white/10 bg-white/[0.05] p-8">
        <div className="mx-auto h-10 w-10 animate-spin rounded-full border-2 border-white/15 border-t-violet-300" />
        <h1 className="mt-6 text-2xl font-black tracking-tight">Opening secure checkout</h1>
        <p className="mt-3 text-sm leading-6 text-white/55">
          Paddle will open the payment form in a secure overlay. Keep this page open.
        </p>
        {error ? (
          <div className="mt-6 rounded-xl border border-amber-300/25 bg-amber-300/10 px-4 py-3 text-sm text-amber-100">
            {error}{' '}
            <button
              type="button"
              onClick={() => void retryReleaseCheckout()}
              className="font-bold underline underline-offset-4"
            >
              Return to pricing
            </button>
          </div>
        ) : null}
      </section>
    </div>
  );
}
