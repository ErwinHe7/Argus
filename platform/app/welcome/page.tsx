import type { Metadata } from 'next';
import Link from 'next/link';
import { CheckCircle2, Clock3, ShieldCheck } from 'lucide-react';
import { LightPage } from '@/components/LightPage';
import { getCurrentUser } from '@/lib/auth';
import {
  getProviderBillingAccount,
  providerBillingAccountHasAccess,
} from '@/lib/billing';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Membership status - AXIO7',
  robots: { index: false, follow: false },
};

export default async function WelcomePage() {
  const user = await getCurrentUser();
  const account = user.authenticated
    ? await getProviderBillingAccount(user.id, 'paddle').catch((error) => {
        console.error('[billing] Unable to read Paddle entitlement on welcome page', error);
        return null;
      })
    : null;
  const active = providerBillingAccountHasAccess(account);

  return (
    <LightPage>
      <div className="axio-account-page mx-auto flex min-h-[58vh] max-w-xl items-center py-8">
        <section className="axio-account-card w-full rounded-2xl p-7 text-center sm:p-10">
          <div
            className={`mx-auto flex h-16 w-16 items-center justify-center rounded-full ${
              active ? 'bg-emerald-300/15' : 'bg-amber-300/15'
            }`}
          >
            {active ? (
              <CheckCircle2 className="h-8 w-8 text-emerald-600" />
            ) : (
              <Clock3 className="h-8 w-8 text-amber-600" />
            )}
          </div>

          <h1 className="mt-6 font-[var(--font-instrument-serif)] text-4xl font-normal tracking-tight">
            {active ? 'Your membership is ready' : 'Confirming your membership'}
          </h1>
          <p className="mt-3 text-sm leading-6 text-[var(--ax-muted)]">
            {active
              ? 'Paddle has confirmed your subscription and AXIO7 has granted paid access.'
              : user.authenticated
                ? 'Checkout has returned to AXIO7, but a verified Paddle event has not granted access yet. Refresh this page after a moment.'
                : 'Sign in with the same AXIO7 account used for checkout so we can read your server-verified membership status.'}
          </p>

          {account?.subscription_status ? (
            <p className="mt-4 text-xs text-[var(--ax-quiet)]">
              Paddle subscription status: <strong>{account.subscription_status}</strong>
            </p>
          ) : null}

          <div className="mt-7 flex flex-wrap justify-center gap-3">
            {user.authenticated ? (
              <>
                <Link
                  href="/welcome"
                  className="min-h-11 rounded-lg bg-[var(--ax-accent)] px-4 py-2.5 text-sm font-black text-white"
                >
                  Refresh status
                </Link>
                <Link
                  href="/billing"
                  className="min-h-11 rounded-lg border border-[var(--ax-line)] px-4 py-2.5 text-sm font-bold text-[var(--ax-muted)]"
                >
                  Manage billing
                </Link>
                <Link
                  href="/"
                  className="min-h-11 rounded-lg border border-[var(--ax-line)] px-4 py-2.5 text-sm font-bold text-[var(--ax-muted)]"
                >
                  Open research
                </Link>
              </>
            ) : (
              <Link
                href="/auth/signin?next=/welcome"
                className="min-h-11 rounded-lg bg-[var(--ax-accent)] px-4 py-2.5 text-sm font-black text-white"
              >
                Sign in to check status
              </Link>
            )}
          </div>

          <p className="mt-7 flex items-center justify-center gap-2 text-xs text-[var(--ax-quiet)]">
            <ShieldCheck className="h-3.5 w-3.5" /> Access is based only on verified server-side events
          </p>
        </section>
      </div>
    </LightPage>
  );
}
