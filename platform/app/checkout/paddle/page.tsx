import type { Metadata } from 'next';
import Link from 'next/link';
import { CreditCard, LockKeyhole, ShieldCheck } from 'lucide-react';
import { LightPage } from '@/components/LightPage';
import { getPaddleBrowserConfig } from '@/lib/paddle';
import { PaddleCheckoutLauncher } from './PaddleCheckoutLauncher';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Secure checkout - AXIO7',
  robots: { index: false, follow: false },
};

export default async function PaddleCheckoutPage({
  searchParams,
}: {
  searchParams?: { _ptxn?: string; transaction_id?: string };
}) {
  const transactionId =
    searchParams?._ptxn?.trim() ?? searchParams?.transaction_id?.trim() ?? '';
  let browserConfig: ReturnType<typeof getPaddleBrowserConfig> | null = null;
  try {
    browserConfig = getPaddleBrowserConfig();
  } catch (error) {
    console.error('[billing] Paddle payment-link page is not configured', error);
  }
  const validTransaction = /^txn_[a-z0-9]{26}$/.test(transactionId);

  return (
    <LightPage>
      {browserConfig && validTransaction ? (
        <PaddleCheckoutLauncher
          clientToken={browserConfig.clientToken}
          environment={browserConfig.environment}
          transactionId={transactionId}
        />
      ) : !browserConfig ? (
        <div className="mx-auto flex min-h-[62vh] max-w-xl items-center px-4 py-12 text-center">
          <section className="w-full rounded-[28px] border border-amber-300/25 bg-amber-300/10 p-8">
            <h1 className="text-2xl font-black tracking-tight">Checkout temporarily unavailable</h1>
            <p className="mt-3 text-sm leading-6 text-white/60">
              The secure payment service is not configured for this deployment. No payment has
              been started and no card information has been collected.
            </p>
            <Link
              href="/pricing"
              className="mt-6 inline-flex rounded-xl bg-white px-4 py-2.5 text-sm font-black text-slate-950"
            >
              Return to memberships
            </Link>
          </section>
        </div>
      ) : (
        <div className="mx-auto flex min-h-[62vh] max-w-3xl items-center px-4 py-12 text-center">
          <section className="w-full rounded-[32px] border border-white/10 bg-white/[0.05] p-7 shadow-[0_30px_100px_rgba(76,29,149,0.16)] sm:p-10">
            <div className="mx-auto inline-flex items-center gap-2 rounded-full border border-emerald-300/25 bg-emerald-300/10 px-3 py-1.5 text-xs font-bold uppercase tracking-[0.16em] text-emerald-200">
              <ShieldCheck className="h-4 w-4" /> Official payment link
            </div>
            <h1 className="mt-6 text-3xl font-black tracking-[-0.04em] sm:text-4xl">
              Secure AXIO7 checkout
            </h1>
            <p className="mx-auto mt-4 max-w-xl text-sm leading-6 text-white/60 sm:text-base">
              This is AXIO7&apos;s official Paddle payment page. Select a membership first and
              Paddle will open a secure one-page checkout here with the exact localized total.
            </p>
            <Link
              href="/pricing"
              className="mt-7 inline-flex items-center gap-2 rounded-xl bg-white px-5 py-3 text-sm font-black text-slate-950 transition hover:bg-violet-100"
            >
              <CreditCard className="h-4 w-4" /> Choose a membership
            </Link>

            <div className="mt-8 grid gap-3 text-left sm:grid-cols-3">
              <div className="rounded-2xl border border-white/10 bg-black/10 p-4">
                <CreditCard className="h-5 w-5 text-violet-300" />
                <h2 className="mt-3 text-sm font-bold">Paddle-hosted payment</h2>
                <p className="mt-1 text-xs leading-5 text-white/48">
                  AXIO7 never receives or stores your complete card number.
                </p>
              </div>
              <div className="rounded-2xl border border-white/10 bg-black/10 p-4">
                <LockKeyhole className="h-5 w-5 text-violet-300" />
                <h2 className="mt-3 text-sm font-bold">Exact checkout total</h2>
                <p className="mt-1 text-xs leading-5 text-white/48">
                  The total shown is returned directly by Paddle for your location.
                </p>
              </div>
              <div className="rounded-2xl border border-white/10 bg-black/10 p-4">
                <ShieldCheck className="h-5 w-5 text-violet-300" />
                <h2 className="mt-3 text-sm font-bold">Verified access</h2>
                <p className="mt-1 text-xs leading-5 text-white/48">
                  Membership access changes only after a verified payment event.
                </p>
              </div>
            </div>
          </section>
        </div>
      )}
    </LightPage>
  );
}
