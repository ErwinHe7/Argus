import type { Metadata } from 'next';
import Link from 'next/link';
import { LightPage } from '@/components/LightPage';

export const metadata: Metadata = {
  title: 'Support & Contact - Leo',
  description:
    'Get help with Leo quantitative research access, data-readiness messages, billing, refunds, and accounts.',
};

export default function SupportPage() {
  return (
    <LightPage>
      <div className="mx-auto max-w-3xl space-y-6">
        <section className="rounded-[24px] border p-6" style={{ background: 'var(--lt-surface)', borderColor: 'var(--lt-border)' }}>
          <p className="text-xs font-bold uppercase tracking-[0.2em]" style={{ color: 'var(--lt-muted)' }}>Leo help</p>
          <h1 className="mt-2 text-3xl font-black tracking-tight" style={{ color: 'var(--lt-text)' }}>Support &amp; Contact</h1>
          <p className="mt-3 text-sm leading-6" style={{ color: 'var(--lt-muted)' }}>
            Need help with billing, digital access, a research request, or your account? Email{' '}
            <a href="mailto:heguantao565@gmail.com" className="underline" style={{ color: 'var(--molt-shell)' }}>heguantao565@gmail.com</a>.
            Please allow up to two business days for an initial response.
          </p>
        </section>

        <div className="grid gap-4 sm:grid-cols-2">
          <SupportCard title="Research access">
            <p>Send the page, your membership level, and a brief description of the research workflow you expected to open.</p>
          </SupportCard>
          <SupportCard title="Data or model issue">
            <p>Send the symbol, request, displayed audit ID, observation cutoff, and exact readiness message. Never send API keys or other credentials.</p>
          </SupportCard>
          <SupportCard title="Billing & subscriptions">
            <p>
              Open the <Link href="/billing" className="underline" style={{ color: 'var(--molt-shell)' }}>billing page</Link> to
              access Paddle&apos;s customer portal, where available, for invoices, payment details, renewal status, and
              cancellation of future renewals.
            </p>
          </SupportCard>
          <SupportCard title="Refund requests">
            <p>
              Review the <Link href="/refund-policy" className="underline" style={{ color: 'var(--molt-shell)' }}>Refund Policy</Link>, then
              send your account email, charge date, and transaction or receipt ID. Never send full card details or passwords.
            </p>
          </SupportCard>
          <SupportCard title="Research boundary">
            <p>
              Support covers access, research-workflow errors, source and audit questions, accounts, and billing. Leo
              provides impersonal quantitative market research, not investment advice, personalized recommendations, or
              order-execution support.
            </p>
          </SupportCard>
          <SupportCard title="Account deletion">
            <p>Request deletion in the app at <Link href="/account/delete" className="underline" style={{ color: 'var(--molt-shell)' }}>/account/delete</Link>. We will confirm the request and process deletion or anonymization where possible.</p>
          </SupportCard>
        </div>

        <section className="rounded-[24px] border p-6 text-sm leading-6" style={{ background: 'var(--lt-surface)', borderColor: 'var(--lt-border)', color: 'var(--lt-muted)' }}>
          <h2 className="text-lg font-bold" style={{ color: 'var(--lt-text)' }}>Useful links</h2>
          <div className="mt-3 flex flex-wrap gap-3">
            <Link href="/pricing" className="r-btn-pink">Pricing</Link>
            <Link href="/billing" className="r-btn-ghost">Billing</Link>
            <Link href="/privacy" className="r-btn-ghost">Privacy Policy</Link>
            <Link href="/terms" className="r-btn-ghost">Terms of Service</Link>
            <Link href="/refund-policy" className="r-btn-ghost">Refund Policy</Link>
          </div>
        </section>
      </div>
    </LightPage>
  );
}

function SupportCard({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="rounded-[22px] border p-5 text-sm leading-6" style={{ background: 'var(--lt-surface)', borderColor: 'var(--lt-border)', color: 'var(--lt-muted)' }}>
      <h2 className="text-lg font-bold" style={{ color: 'var(--lt-text)' }}>{title}</h2>
      <div className="mt-2">{children}</div>
    </section>
  );
}
