import type { Metadata } from 'next';
import Link from 'next/link';
import { LightPage } from '@/components/LightPage';

export const metadata: Metadata = {
  title: 'Refund Policy - AXIO7',
  description: 'AXIO7 subscription cancellation, refund request, duplicate-charge, and billing-error policy.',
  alternates: { canonical: '/refund-policy' },
};

const updatedAt = 'July 26, 2026';

export default function RefundPolicyPage() {
  return (
    <LightPage>
      <article className="mx-auto max-w-3xl space-y-6 rounded-[24px] border p-6" style={{ background: 'var(--lt-surface)', borderColor: 'var(--lt-border)' }}>
        <div>
          <p className="text-xs font-bold uppercase tracking-[0.2em]" style={{ color: 'var(--lt-muted)' }}>AXIO7 billing policy</p>
          <h1 className="mt-2 text-3xl font-black tracking-tight" style={{ color: 'var(--lt-text)' }}>Refund Policy</h1>
          <p className="mt-2 text-sm" style={{ color: 'var(--lt-muted)' }}>Last updated: {updatedAt}</p>
        </div>

        <RefundSection title="Scope">
          <p>
            This policy covers paid AXIO7 digital-software subscriptions. Access is delivered to the purchasing AXIO7
            account after payment verification. Starter, Pro, and Advanced are paid subscriptions with no free trial. No
            physical goods are shipped.
          </p>
        </RefundSection>

        <RefundSection title="Cancellation is different from a refund">
          <p>
            You may cancel from the <Link href="/billing" className="underline" style={{ color: 'var(--molt-shell)' }}>billing page</Link> or
            the Paddle subscription-management link on your receipt. Cancellation prevents future renewal and normally leaves
            access active through the current paid period. It does not automatically refund the current period.
          </p>
        </RefundSection>

        <RefundSection title="Final-sale default and mandatory rights">
          <p>
            All sales are final and non-refundable except where required by applicable law or Paddle&apos;s Refund Policy.
            Customers may cancel at any time to prevent future renewal. Cancellation does not result in a refund or credit
            for the current billing period.
          </p>
          <p>
            This final-sale default does not limit non-waivable consumer rights, remedies for duplicate or unauthorized
            charges, materially defective service, or Paddle&apos;s case-by-case review. Paddle may approve, partially approve,
            or reject a request under its policy.
          </p>
        </RefundSection>

        <RefundSection title="Billing errors and service problems">
          <p>
            Contact support promptly for a duplicate charge, an amount that differs from checkout, suspected unauthorized
            use, or a material failure that prevents paid access. Include the account email, charge date, amount, receipt or
            transaction ID, and a brief description. Do not send a full card number or bank credentials.
          </p>
        </RefundSection>

        <RefundSection title="How to request a refund review">
          <ol className="list-decimal space-y-2 pl-5">
            <li>Sign in and submit the internal review form on the <Link href="/billing" className="underline" style={{ color: 'var(--molt-shell)' }}>billing page</Link>, or email <a href="mailto:heguantao565@gmail.com" className="underline" style={{ color: 'var(--molt-shell)' }}>heguantao565@gmail.com</a> from the purchasing account.</li>
            <li>Provide the charge date, transaction or receipt ID, and a truthful description of the request. Never send full card details or passwords.</li>
            <li>You may also use the link on your Paddle receipt or <a href="https://paddle.net" className="underline" style={{ color: 'var(--molt-shell)' }}>Paddle Buyer Support</a>. AXIO7 cannot remove that review channel.</li>
          </ol>
          <p>
            Submitting an AXIO7 request creates an internal ticket with status <strong>under review</strong>. It never calls a refund API automatically.
          </p>
        </RefundSection>

        <RefundSection title="Approved refunds">
          <p>
            When Paddle is the merchant of record, Paddle issues an approved refund to the original payment method.
            Processing time depends on Paddle, the payment method, and the customer&apos;s bank. Refunded access may end when
            the refund is approved. Partial or prorated refunds are not normally offered for unused time unless required by
            law or expressly approved.
          </p>
        </RefundSection>

        <RefundSection title="Contact">
          <p>
            For billing or refund help, email <a href="mailto:heguantao565@gmail.com" className="underline" style={{ color: 'var(--molt-shell)' }}>heguantao565@gmail.com</a> or
            visit <Link href="/support" className="underline" style={{ color: 'var(--molt-shell)' }}>Support</Link>.
          </p>
        </RefundSection>
      </article>
    </LightPage>
  );
}

function RefundSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="space-y-2 text-sm leading-6" style={{ color: 'var(--lt-muted)' }}>
      <h2 className="text-lg font-bold" style={{ color: 'var(--lt-text)' }}>{title}</h2>
      {children}
    </section>
  );
}
