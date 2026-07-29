import type { Metadata } from 'next';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { CalendarClock, CheckCircle2, CreditCard, Crown, ReceiptText } from 'lucide-react';
import { LightPage } from '@/components/LightPage';
import { getCurrentUser } from '@/lib/auth';
import {
  billingAccountHasAccess,
  getBillingAccount,
  providerBillingAccountHasAccess,
} from '@/lib/billing';
import {
  billingProviderLabel,
  getActiveBillingProvider,
  type BillingProvider as PublicBillingProvider,
} from '@/lib/payment-provider';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Billing - AXIO7',
  description: 'View and manage your AXIO7 payment and subscription status.',
};

function formatDate(value: string | null) {
  if (!value) return 'Not available';
  return new Intl.DateTimeFormat('en-US', { dateStyle: 'medium' }).format(new Date(value));
}

export default async function BillingPage({
  searchParams,
}: {
  searchParams?: { portal?: string; renewal?: string };
}) {
  const user = await getCurrentUser();
  if (!user.authenticated) redirect('/auth/signin?next=/billing');

  const account = await getBillingAccount(user.id).catch(() => null);
  const hasAccess = billingAccountHasAccess(account);
  const activeProvider = getActiveBillingProvider();
  const activeDatabaseProvider =
    activeProvider === 'lemonsqueezy'
      ? 'lemon_squeezy'
      : activeProvider === 'paddle'
        ? 'paddle'
        : 'stripe';
  const managedAccount =
    account?.provider_accounts?.find((entry) => providerBillingAccountHasAccess(entry)) ??
    account?.provider_accounts?.find((entry) => entry.provider === activeDatabaseProvider) ??
    null;
  const managedPublicProvider: PublicBillingProvider =
    managedAccount?.provider === 'lemon_squeezy'
      ? 'lemonsqueezy'
      : managedAccount?.provider === 'paddle'
        ? 'paddle'
        : managedAccount?.provider === 'stripe' || account?.stripe_customer_id
          ? 'stripe'
          : activeProvider;
  const providerLabel = billingProviderLabel(managedPublicProvider);
  const isLifetime = hasAccess && Boolean(managedAccount?.lifetime_access ?? account?.lifetime_access);
  const subscriptionId = managedAccount?.provider_subscription_id ?? account?.stripe_subscription_id;
  const customerId = managedAccount?.provider_customer_id ?? account?.stripe_customer_id;
  const subscriptionStatus = managedAccount?.subscription_status ?? account?.subscription_status;
  const currentPeriodEnd = managedAccount?.current_period_end ?? account?.current_period_end ?? null;
  const cancelAtPeriodEnd =
    managedAccount?.cancel_at_period_end ?? account?.cancel_at_period_end ?? false;
  const portalAction =
    managedPublicProvider === 'lemonsqueezy'
      ? '/api/lemonsqueezy/customer-portal'
      : managedPublicProvider === 'paddle'
        ? '/api/paddle/customer-portal'
        : '/api/stripe/customer-portal';
  const canOpenPortal =
    managedPublicProvider === 'lemonsqueezy'
      ? Boolean(subscriptionId)
      : managedPublicProvider === 'paddle'
        ? Boolean(
            managedAccount?.provider === 'paddle' &&
              managedAccount.provider_customer_id &&
              managedAccount.provider_subscription_id
          )
        : Boolean(customerId);
  const portalUnavailable = searchParams?.portal === 'unavailable';
  const renewalCancelled = searchParams?.renewal === 'cancelled';
  const renewalUnavailable = searchParams?.renewal === 'unavailable';
  const isManagedPaddle = managedAccount?.provider === 'paddle';
  const canCancelPaddleRenewal = Boolean(
    isManagedPaddle &&
      !isLifetime &&
      subscriptionId &&
      ['active', 'trialing'].includes(subscriptionStatus ?? '') &&
      !cancelAtPeriodEnd
  );
  const periodEndLabel = formatDate(currentPeriodEnd);

  return (
    <LightPage>
      <div className="axio-account-page mx-auto max-w-3xl py-4 sm:py-10">
        <div>
          <p className="text-xs font-bold uppercase tracking-[0.2em] text-[var(--ax-accent)]">Account</p>
          <h1 className="mt-3 font-[var(--font-instrument-serif)] text-4xl font-normal tracking-tight">Membership</h1>
          <p className="mt-2 text-sm text-[var(--ax-muted)]">Signed in as {user.email ?? user.name}</p>
        </div>

        {portalUnavailable ? (
          <div role="alert" className="mt-6 rounded-xl border border-amber-300/60 bg-amber-50 px-4 py-3 text-sm text-amber-900">
            The {providerLabel} billing portal is temporarily unavailable. Please try again later.
          </div>
        ) : null}

        {renewalCancelled ? (
          <div role="status" className="mt-6 rounded-xl border border-emerald-300/60 bg-emerald-50 px-4 py-3 text-sm text-emerald-900">
            Your renewal has been canceled. Access remains available until {periodEndLabel}. No refund has been issued.
          </div>
        ) : null}

        {renewalUnavailable ? (
          <div role="alert" className="mt-6 rounded-xl border border-amber-300/60 bg-amber-50 px-4 py-3 text-sm text-amber-900">
            Renewal cancellation could not be confirmed. No subscription change or refund was assumed. Please try again or contact support.
          </div>
        ) : null}

        <section className="axio-account-card mt-8 rounded-2xl p-6 sm:p-8">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div>
              <p className="text-xs font-bold uppercase tracking-[0.18em] text-[var(--ax-quiet)]">Current access</p>
              <div className="mt-3 flex items-center gap-3">
                {hasAccess ? (
                  <CheckCircle2 className="h-7 w-7 text-emerald-300" />
                ) : (
                  <CreditCard className="h-7 w-7 text-[var(--ax-quiet)]" />
                )}
                <h2 className="text-2xl font-black">
                  {isLifetime
                    ? 'AXIO7 Lifetime'
                    : hasAccess
                      ? 'AXIO7 Subscription'
                      : 'Free access'}
                </h2>
              </div>
            </div>
            <span
              className={`rounded-full px-3 py-1.5 text-xs font-black uppercase tracking-[0.14em] ${
                hasAccess
                  ? 'bg-emerald-300/15 text-emerald-200'
                  : 'bg-stone-100 text-[var(--ax-muted)]'
              }`}
            >
              {isLifetime ? 'Lifetime' : hasAccess ? subscriptionStatus ?? 'Active' : 'Free'}
            </span>
          </div>

          {hasAccess && subscriptionId ? (
            <div className="mt-7 grid gap-4 border-t border-[var(--ax-line-soft)] pt-6 sm:grid-cols-2">
              <div className="flex gap-3">
                <CalendarClock className="mt-0.5 h-5 w-5 text-[var(--ax-accent)]" />
                <div>
                  <p className="text-xs text-[var(--ax-quiet)]">
                    {cancelAtPeriodEnd ? 'Access ends' : 'Current period ends'}
                  </p>
                  <p className="mt-1 text-sm font-bold text-[var(--ax-ink)]">{formatDate(currentPeriodEnd)}</p>
                </div>
              </div>
              <div className="flex gap-3">
                <ReceiptText className="mt-0.5 h-5 w-5 text-[var(--ax-accent)]" />
                <div>
                  <p className="text-xs text-[var(--ax-quiet)]">Billing</p>
                  <p className="mt-1 text-sm font-bold text-[var(--ax-ink)]">
                    {cancelAtPeriodEnd ? 'Cancellation scheduled' : 'Renews automatically'}
                  </p>
                </div>
              </div>
            </div>
          ) : isLifetime ? (
            <div className="mt-7 flex gap-3 border-t border-[var(--ax-line-soft)] pt-6">
              <Crown className="mt-0.5 h-5 w-5 text-amber-300" />
              <p className="text-sm leading-6 text-[var(--ax-muted)]">No recurring renewal is attached to lifetime access.</p>
            </div>
          ) : null}

          <div className="mt-7 flex flex-wrap gap-3">
            {canOpenPortal ? (
              <form action={portalAction} method="post">
                <button
                  type="submit"
                  className="inline-flex min-h-11 items-center gap-2 rounded-lg bg-[var(--ax-accent)] px-4 py-2.5 text-sm font-black text-white transition hover:opacity-90 focus:outline-none focus:ring-2 focus:ring-[var(--ax-accent)]"
                >
                  <CreditCard className="h-4 w-4" /> Open {providerLabel} billing portal
                </button>
              </form>
            ) : (
              <Link
                href="/pricing"
                className="inline-flex min-h-11 items-center gap-2 rounded-lg bg-[var(--ax-accent)] px-4 py-2.5 text-sm font-black text-white transition hover:opacity-90"
              >
                View paid plans
              </Link>
            )}
            <Link
              href="/support"
              className="inline-flex min-h-11 items-center rounded-lg border border-[var(--ax-line)] px-4 py-2.5 text-sm font-bold text-[var(--ax-muted)] transition hover:bg-white"
            >
              Billing support
            </Link>
            <Link
              href="/"
              className="inline-flex min-h-11 items-center rounded-lg px-4 py-2.5 text-sm font-bold text-[var(--ax-muted)] transition hover:bg-white"
            >
              Back to research
            </Link>
          </div>
        </section>

        {isManagedPaddle && subscriptionId && currentPeriodEnd && !isLifetime ? (
          <section className="axio-account-card mt-6 rounded-2xl p-6 sm:p-8">
            <h2 className="text-xl font-black text-[var(--ax-ink)]">Renewal</h2>
            {cancelAtPeriodEnd ? (
              <p className="mt-3 text-sm leading-6 text-[var(--ax-muted)]">
                Your renewal has been canceled. Access remains available until {periodEndLabel}. No refund has been issued.
              </p>
            ) : canCancelPaddleRenewal ? (
              <details className="mt-4 rounded-xl border border-[var(--ax-line)] bg-white p-4">
                <summary className="cursor-pointer text-sm font-black text-[var(--ax-ink)]">Cancel renewal</summary>
                <div className="mt-4 space-y-4">
                  <p className="text-sm leading-6 text-[var(--ax-muted)]">
                    Your subscription will remain active until {periodEndLabel}. You will not be charged again. Canceling does not refund the current billing period, except where required by law or Paddle&apos;s Refund Policy.
                  </p>
                  <form action="/api/paddle/subscription/cancel-renewal" method="post">
                    <button
                      type="submit"
                      className="inline-flex min-h-11 items-center rounded-lg border border-red-300 px-4 py-2.5 text-sm font-black text-red-700 transition hover:bg-red-50"
                    >
                      Confirm cancellation
                    </button>
                  </form>
                </div>
              </details>
            ) : (
              <p className="mt-3 text-sm leading-6 text-[var(--ax-muted)]">
                This subscription cannot be scheduled for cancellation from AXIO7 in its current state. Open the Paddle billing portal or contact support.
              </p>
            )}
          </section>
        ) : null}

        <p className="mt-5 text-xs leading-5 text-[var(--ax-quiet)]">
          Subscription changes can take a few seconds to appear after {providerLabel} confirms the payment event.
        </p>
      </div>
    </LightPage>
  );
}
