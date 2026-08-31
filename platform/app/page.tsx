import type { Metadata } from 'next';
import { AxioChat } from '@/components/AxioChat';
import { CosmicHero } from '@/components/home/CosmicHero';
import { getCurrentUser, isAdmin } from '@/lib/auth';
import { billingAccountHasAccess, getBillingAccount } from '@/lib/billing';
import cosmicStyles from '@/components/home/CosmicHero.module.css';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'AXIO7 — Navigate uncertainty',
  description:
    'Explore evidence-first market research and a private celestial reflection practice in one English-first product.',
  openGraph: {
    title: 'AXIO7 — Navigate uncertainty',
    description:
      'Evidence-first market research and private celestial reflection, held in one coherent product.',
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
    title: 'AXIO7 — Navigate uncertainty',
    description:
      'Evidence-first market research and private celestial reflection, held in one coherent product.',
    images: ['/og-formal.png'],
  },
};

export default async function HomePage() {
  const user = await getCurrentUser();
  const administrator = isAdmin(user);
  const researchAccess =
    administrator ||
    (user.authenticated &&
      billingAccountHasAccess(await getBillingAccount(user.id).catch(() => null)));
  return (
    <>
      <CosmicHero />
      <div id="research-workspace" className={cosmicStyles.researchStage}>
        <AxioChat
          initialUser={{
            authenticated: user.authenticated,
            name: user.name,
            email: user.email,
            privateMarketDataAccess: administrator,
            researchAccess,
          }}
        />
      </div>
    </>
  );
}
