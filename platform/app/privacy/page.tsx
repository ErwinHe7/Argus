import type { Metadata } from 'next';
import Link from 'next/link';
import { LightPage } from '@/components/LightPage';

export const metadata: Metadata = {
  title: 'Privacy Policy - AXIO7',
  description:
    'How AXIO7 collects, uses, shares, retains, and protects account, billing, and quantitative market-research data.',
};

const updatedAt = 'July 26, 2026';

export default function PrivacyPage() {
  return (
    <LightPage>
      <article className="mx-auto max-w-3xl space-y-6 rounded-[24px] border p-6" style={{ background: 'var(--lt-surface)', borderColor: 'var(--lt-border)' }}>
        <div>
          <p className="text-xs font-bold uppercase tracking-[0.2em]" style={{ color: 'var(--lt-muted)' }}>AXIO7 policy</p>
          <h1 className="mt-2 text-3xl font-black tracking-tight" style={{ color: 'var(--lt-text)' }}>Privacy Policy</h1>
          <p className="mt-2 text-sm" style={{ color: 'var(--lt-muted)' }}>Last updated: {updatedAt}</p>
        </div>

        <PolicySection title="What AXIO7 collects">
          <ul className="list-disc space-y-2 pl-5">
            <li>Account data such as email address, display name, avatar, authentication provider, and session metadata.</li>
            <li>Subscription and transaction data such as selected plan, payment status, customer and transaction identifiers, renewal date, invoice or receipt references, and billing country.</li>
            <li>Research inputs such as prompts, symbols, allow-listed query parameters, requested horizons, and monitor conditions.</li>
            <li>Research records such as saved requests, model responses, backtest parameters and results, source references, data-readiness checks, audit identifiers, and reproducibility metadata.</li>
            <li>Device and usage data such as pages viewed, approximate region, referrer, browser, operating system, diagnostic events, and feature usage.</li>
          </ul>
        </PolicySection>

        <PolicySection title="Payments">
          <p>
            When Paddle is identified at checkout, Paddle collects and processes payment credentials as merchant of record.
            AXIO7 does not receive or store full card numbers or bank-account credentials. AXIO7 receives limited billing
            records such as customer, transaction, subscription, product, price, status, billing-country, invoice, and
            receipt references to activate access, reconcile transactions, manage subscriptions, prevent fraud, answer
            support requests, and meet legal or tax obligations. Paddle&apos;s own privacy terms also apply to that processing.
          </p>
        </PolicySection>

        <PolicySection title="How AXIO7 uses data">
          <ul className="list-disc space-y-2 pl-5">
            <li>To authenticate users, secure accounts, deliver paid digital access, and manage subscriptions.</li>
            <li>To run quantitative research workflows, save request history and monitors, present evidence and caveats, and improve service reliability.</li>
            <li>To block prohibited requests involving material non-public information, unauthorized collection, manipulation, or unlawful activity.</li>
            <li>To provide support, process billing questions and refund requests, prevent fraud, and improve reliability.</li>
            <li>To comply with legal, accounting, tax, safety, security, and platform obligations.</li>
          </ul>
        </PolicySection>

        <PolicySection title="AI processing">
          <p>
            AXIO7 may use AI systems to translate a question into an allow-listed research contract and explain output from
            the quantitative engine. AI systems are not the source of market observations and are not permitted to invent
            data or replace the production quantitative calculation. AI-assisted explanations may be incomplete or wrong
            and are not investment advice, personalized recommendations, or order instructions. Do not submit confidential
            information, private credentials, or data you are not authorized to process.
          </p>
        </PolicySection>

        <PolicySection title="Service providers and sharing">
          <p>
            AXIO7 may share only the data needed with authentication, cloud hosting, database, storage, analytics,
            monitoring, market-data, model-inference, payment, customer-support, and AI providers. AXIO7 does not monetize personal data.
            Data may also be disclosed when required by law, to protect users or the service, or as part of a business
            transfer subject to appropriate safeguards.
          </p>
        </PolicySection>

        <PolicySection title="Retention, security, and international processing">
          <p>
            AXIO7 retains data for as long as needed to provide the service and for legitimate security, fraud-prevention,
            accounting, tax, dispute, and legal purposes. Reasonable technical and organizational safeguards are used, but
            no online service can guarantee absolute security. Providers may process data in countries other than your own,
            subject to their applicable safeguards and law.
          </p>
        </PolicySection>

        <PolicySection title="Your choices">
          <p>
            Depending on your location, you may have rights to access, correct, delete, restrict, or obtain a copy of certain
            personal data. You can request account deletion at <Link href="/account/delete" className="underline" style={{ color: 'var(--molt-shell)' }}>/account/delete</Link>.
            AXIO7 may retain limited records where law or legitimate fraud, tax, security, or dispute needs require it.
          </p>
        </PolicySection>

        <PolicySection title="Contact">
          <p>
            For privacy or deletion questions, email <a href="mailto:heguantao565@gmail.com" className="underline" style={{ color: 'var(--molt-shell)' }}>heguantao565@gmail.com</a> or
            visit <Link href="/support" className="underline" style={{ color: 'var(--molt-shell)' }}>/support</Link>.
          </p>
          <p>
            Also review the <Link href="/terms" className="underline" style={{ color: 'var(--molt-shell)' }}>Terms of Service</Link> and{' '}
            <Link href="/refund-policy" className="underline" style={{ color: 'var(--molt-shell)' }}>Refund Policy</Link>.
          </p>
        </PolicySection>
      </article>
    </LightPage>
  );
}

function PolicySection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="space-y-2 text-sm leading-6" style={{ color: 'var(--lt-muted)' }}>
      <h2 className="text-lg font-bold" style={{ color: 'var(--lt-text)' }}>{title}</h2>
      {children}
    </section>
  );
}
