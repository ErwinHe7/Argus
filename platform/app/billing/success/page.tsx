import type { Metadata } from 'next';
import Link from 'next/link';
import { CheckCircle2, Clock3, ShieldCheck } from 'lucide-react';
import { LightPage } from '@/components/LightPage';
import { getCurrentUser } from '@/lib/auth';
import {
  getProviderBillingAccount,
  providerBillingAccountHasAccess,
  syncStripeCheckoutSession,
} from '@/lib/billing';
import { isLemonSqueezyTestMode } from '@/lib/lemon-squeezy';
import { isPaddleSandbox } from '@/lib/paddle';
import { getStripe, isStripeConfigured } from '@/lib/stripe';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Payment status - AXIO7',
  robots: { index: false, follow: false },
};

export default async function BillingSuccessPage({
  searchParams,
}: {
  searchParams?: { session_id?: string; provider?: string };
}) {
  const user = await getCurrentUser();
  const sessionId = searchParams?.session_id;
  const isLemonSqueezy = searchParams?.provider === 'lemonsqueezy';
  const isPaddle = searchParams?.provider === 'paddle';
  const providerLabel = isLemonSqueezy ? 'Lemon Squeezy' : isPaddle ? 'Paddle' : 'Stripe';
  let confirmed = false;

  if (user.authenticated && (isLemonSqueezy || isPaddle)) {
    const account = await getProviderBillingAccount(
      user.id,
      isPaddle ? 'paddle' : 'lemon_squeezy',
      isPaddle ? isPaddleSandbox() : isLemonSqueezyTestMode()
    ).catch(() => null);
    confirmed = providerBillingAccountHasAccess(account);
  } else if (
    user.authenticated &&
    !isPaddle &&
    sessionId?.startsWith('cs_') &&
    isStripeConfigured()
  ) {
    try {
      const session = await getStripe().checkout.sessions.retrieve(sessionId);
      const belongsToUser =
        session.client_reference_id === user.id || session.metadata?.axio7_user_id === user.id;
      if (belongsToUser && session.status === 'complete') {
        confirmed =
          session.payment_status === 'paid' || session.payment_status === 'no_payment_required';
        if (confirmed) {
          await syncStripeCheckoutSession(session).catch((error) => {
            console.error('[billing] Success-page sync failed; webhook will retry', error);
          });
        }
      }
    } catch (error) {
      console.error('[billing] Unable to verify Checkout Session on success page', error);
    }
  }

  return (
    <LightPage>
      <div className="mx-auto flex min-h-[58vh] max-w-xl items-center py-8">
        <section className="w-full rounded-[28px] border border-white/10 bg-white/[0.05] p-7 text-center sm:p-10">
          <div
            className={`mx-auto flex h-16 w-16 items-center justify-center rounded-full ${
              confirmed ? 'bg-emerald-300/15' : 'bg-amber-300/15'
            }`}
          >
            {confirmed ? (
              <CheckCircle2 className="h-8 w-8 text-emerald-300" />
            ) : (
              <Clock3 className="h-8 w-8 text-amber-300" />
            )}
          </div>
          <h1 className="mt-6 text-3xl font-black tracking-tight">
            {confirmed ? 'Payment confirmed' : 'Payment confirmation pending'}
          </h1>
          <p className="mt-3 text-sm leading-6 text-white/58">
            {confirmed
              ? `Thank you. ${providerLabel} has confirmed your checkout and AXIO7 has updated your access.`
              : `We could not confirm this checkout yet. You will not receive paid access until AXIO7 receives a verified ${providerLabel} payment event.`}
          </p>
          <div className="mt-7 flex flex-wrap justify-center gap-3">
            <Link href="/billing" className="rounded-xl bg-white px-4 py-2.5 text-sm font-black text-slate-950">
              View billing status
            </Link>
            <Link href="/" className="rounded-xl border border-white/12 px-4 py-2.5 text-sm font-bold text-white/70">
              Return to AXIO7
            </Link>
          </div>
          <p className="mt-7 flex items-center justify-center gap-2 text-xs text-white/38">
            <ShieldCheck className="h-3.5 w-3.5" /> Verified server-side with {providerLabel}
          </p>
        </section>
      </div>
    </LightPage>
  );
}
