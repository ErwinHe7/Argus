import type { Metadata } from 'next';
import Link from 'next/link';
import { LightPage } from '@/components/LightPage';
import { AccountDeletionRequestForm } from '@/components/AccountDeletionRequestForm';
import { getCurrentUser } from '@/lib/auth';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Delete Account — AXIO7',
  description: 'Request deletion or anonymization of your AXIO7 account and private account data.',
};

export default async function DeleteAccountPage() {
  const user = await getCurrentUser();

  return (
    <LightPage>
      <div className="mx-auto max-w-3xl space-y-6">
        <section className="rounded-[24px] border p-6" style={{ background: 'var(--lt-surface)', borderColor: 'var(--lt-border)' }}>
          <p className="text-xs font-bold uppercase tracking-[0.2em]" style={{ color: 'var(--lt-muted)' }}>Account settings</p>
          <h1 className="mt-2 text-3xl font-black tracking-tight" style={{ color: 'var(--lt-text)' }}>Delete account</h1>
          <p className="mt-3 text-sm leading-6" style={{ color: 'var(--lt-muted)' }}>
            Request deletion or anonymization of your AXIO7 account, profile data, research history, saved monitors, and
            private account data where possible. Some billing and audit records may be retained when needed for safety,
            fraud prevention, legal compliance, tax, or dispute handling.
          </p>
        </section>

        {user.authenticated ? (
          <>
            <section className="rounded-[22px] border p-5 text-sm leading-6" style={{ background: 'var(--lt-surface)', borderColor: 'var(--lt-border)', color: 'var(--lt-muted)' }}>
              <h2 className="text-lg font-bold" style={{ color: 'var(--lt-text)' }}>Signed in account</h2>
              <p className="mt-2">{user.email ?? user.name}</p>
              <p className="mt-2">Deletion requests are usually reviewed within 7 days. Support may contact you if more information is needed.</p>
            </section>
            <AccountDeletionRequestForm />
          </>
        ) : (
          <section className="rounded-[22px] border p-5 text-sm leading-6" style={{ background: 'var(--lt-surface)', borderColor: 'var(--lt-border)', color: 'var(--lt-muted)' }}>
            <h2 className="text-lg font-bold" style={{ color: 'var(--lt-text)' }}>Sign in required</h2>
            <p className="mt-2">Please sign in to request deletion for your account.</p>
            <Link href="/auth/signin?next=/account/delete" className="r-btn-pink mt-4">Sign in to continue</Link>
          </section>
        )}
      </div>
    </LightPage>
  );
}
