import type { Metadata } from 'next';
import { AxioChat } from '@/components/AxioChat';
import { getCurrentUser, isAdmin } from '@/lib/auth';
import { billingAccountHasAccess, getBillingAccount } from '@/lib/billing';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'AXIO7 — Research market conditions with evidence',
  description:
    'Ask AXIO7 to scan, backtest, or monitor an impersonal market condition with source coverage, model limits, and a reproducible audit trail.',
  openGraph: {
    title: 'AXIO7 — Research market conditions with evidence',
    description:
      'Impersonal quantitative market research with point-in-time data, deterministic Rust inference, and explicit caveats.',
    images: [
      {
        url: '/og-formal.png',
        width: 1776,
        height: 887,
        alt: 'AXIO7 quantitative market-research workspace',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'AXIO7 — Research market conditions with evidence',
    description:
      'Impersonal quantitative market research with point-in-time data, deterministic Rust inference, and explicit caveats.',
    images: ['/og-formal.png'],
  },
};

export default async function HomePage({
  searchParams,
}: {
  searchParams?: { mock?: string | string[] };
}) {
  const user = await getCurrentUser();
  const administrator = isAdmin(user);
  const researchAccess =
    administrator ||
    (user.authenticated &&
      billingAccountHasAccess(await getBillingAccount(user.id).catch(() => null)));
  const developmentReplay =
    process.env.NODE_ENV !== 'production' && searchParams?.mock === '1';
  const localLiveResearch =
    process.env.NODE_ENV !== 'production' &&
    process.env.AXIO_ENABLE_LOCAL_UNCALIBRATED_LIVE_RESEARCH === '1' &&
    user.authenticated &&
    researchAccess;
  return (
    <AxioChat
      developmentReplay={developmentReplay}
      localLiveResearch={localLiveResearch}
      initialUser={{
        authenticated: user.authenticated,
        name: user.name,
        email: user.email,
        privateMarketDataAccess: administrator,
        researchAccess,
      }}
    />
  );
}
