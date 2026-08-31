import type { Metadata } from 'next';
import Link from 'next/link';
import { LightPage } from '@/components/LightPage';

export const metadata: Metadata = {
  title: 'Terms of Service - Leo',
  description:
    'Terms governing Leo quantitative market-research software, accounts, digital subscriptions, and billing.',
};

const updatedAt = 'July 26, 2026';

export default function TermsPage() {
  return (
    <LightPage>
      <article className="mx-auto max-w-3xl space-y-6 rounded-[24px] border p-6" style={{ background: 'var(--lt-surface)', borderColor: 'var(--lt-border)' }}>
        <div>
          <p className="text-xs font-bold uppercase tracking-[0.2em]" style={{ color: 'var(--lt-muted)' }}>Leo terms</p>
          <h1 className="mt-2 text-3xl font-black tracking-tight" style={{ color: 'var(--lt-text)' }}>Terms of Service</h1>
          <p className="mt-2 text-sm" style={{ color: 'var(--lt-muted)' }}>Last updated: {updatedAt}</p>
        </div>

        <TermsSection title="Service and provider information">
          <p>
            Leo is an account-based, impersonal quantitative market-research software service. It can translate an
            allow-listed research question into deterministic scan, historical-evaluation, and monitoring workflows, then
            present source coverage, observation cutoffs, model lineage, evidence, and material caveats. The legal provider
            or merchant of record for a purchase, together with the applicable billing descriptor, is identified at
            checkout and on the transaction receipt. When Paddle is shown at checkout, Paddle acts as the merchant of
            record. The paid service is delivered digitally; no physical product is shipped.
          </p>
        </TermsSection>

        <TermsSection title="Research scope and boundaries">
          <p>
            Leo provides impersonal research about market conditions. It is not a broker, investment adviser, fiduciary,
            portfolio manager, or order-execution service. Leo does not consider a user&apos;s financial situation, risk
            tolerance, holdings, goals, tax position, or other personal circumstances, and it does not recommend that any
            person buy, sell, hold, or trade a financial product.
          </p>
        </TermsSection>

        <TermsSection title="Data, models, and availability">
          <p>
            Market data may be delayed, incomplete, stale, revised, unavailable, or restricted by a third-party license.
            Model artifacts and research methods may also be unavailable or withheld until required validation and
            production-promotion checks pass. Leo is designed to fail closed when freshness, coverage, entitlement,
            causality, or model-readiness requirements are not met. Outputs are estimates or research observations, not
            guarantees, and no plan guarantees that a requested result will be available.
          </p>
        </TermsSection>

        <TermsSection title="Accounts, access, and acceptable use">
          <ul className="list-disc space-y-2 pl-5">
            <li>You must provide accurate account information and protect your sign-in credentials.</li>
            <li>Paid access is licensed to the purchasing account and may not be resold, shared outside an authorized team, or used to circumvent plan limits.</li>
            <li>You may not use Leo for fraud, manipulation, unlawful activity, infringement, service disruption, or unauthorized access.</li>
            <li>You may not submit material non-public information, private credentials, or data you do not have the right to process.</li>
            <li>You may not ask Leo to bypass logins, paywalls, CAPTCHAs, rate limits, API terms, private groups, direct messages, or other access controls.</li>
            <li>You may not represent Leo output as personalized advice, a guaranteed outcome, or an instruction generated for automatic order execution.</li>
          </ul>
        </TermsSection>

        <TermsSection title="Subscriptions, prices, and digital delivery">
          <p>
            Plan prices are displayed in U.S. dollars unless checkout states otherwise. Taxes may be calculated and added
            at checkout. Starter, Pro, and Advanced are available as monthly or annual subscriptions and do not include a
            free trial. The selected plan renews automatically at the billing frequency and price shown during checkout
            until cancelled. After payment is verified, digital access is applied to the purchasing Leo account. Access
            timing can be affected by payment review, authentication, or service availability.
          </p>
        </TermsSection>

        <TermsSection title="Payment processing">
          <p>
            Paddle, when identified at checkout, processes payment credentials as merchant of record and handles the
            transaction receipt, invoice, eligible payment methods, renewals, and applicable tax calculation, collection,
            and remittance. Leo does not receive or store full card numbers. Paddle&apos;s terms and privacy notice also
            apply to payment processing.
          </p>
        </TermsSection>

        <TermsSection title="Cancellation and refunds">
          <p>
            You may cancel a subscription from the <Link href="/billing" className="underline" style={{ color: 'var(--molt-shell)' }}>billing page</Link> or
            through the Paddle subscription-management link supplied on your receipt. Cancellation stops future renewals and normally takes
            effect at the end of the current paid period. Cancellation does not itself create a refund. Refund eligibility,
            request instructions, and billing-error handling are explained in the <Link href="/refund-policy" className="underline" style={{ color: 'var(--molt-shell)' }}>Refund Policy</Link>.
            Mandatory consumer rights continue to apply.
          </p>
        </TermsSection>

        <TermsSection title="Availability and intellectual property">
          <p>
            Leo and its software, interface, and original content are protected by applicable intellectual-property laws.
            Third-party market data and content remain subject to their owners&apos; licenses. Features, data sources,
            models, and research methods may change, be suspended, or become unavailable. To the maximum extent permitted
            by law, the service is provided without a guarantee that every output, source, or feature will always be
            accurate, complete, timely, or uninterrupted.
          </p>
        </TermsSection>

        <TermsSection title="Account deletion">
          <p>
            You can request account deletion at <Link href="/account/delete" className="underline" style={{ color: 'var(--molt-shell)' }}>/account/delete</Link>.
            Deleting an account does not automatically cancel an externally managed subscription; cancel it first from the
            billing page or receipt link. Leo may retain limited records for legal, tax, fraud-prevention, security, or
            dispute purposes.
          </p>
        </TermsSection>

        <TermsSection title="Changes and contact">
          <p>
            Leo may update these terms as the service evolves. Material changes will be posted on this page. Questions
            can be sent to <a href="mailto:heguantao565@gmail.com" className="underline" style={{ color: 'var(--molt-shell)' }}>heguantao565@gmail.com</a> or
            submitted through <Link href="/support" className="underline" style={{ color: 'var(--molt-shell)' }}>Support</Link>.
          </p>
        </TermsSection>
      </article>
    </LightPage>
  );
}

function TermsSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="space-y-2 text-sm leading-6" style={{ color: 'var(--lt-muted)' }}>
      <h2 className="text-lg font-bold" style={{ color: 'var(--lt-text)' }}>{title}</h2>
      {children}
    </section>
  );
}
