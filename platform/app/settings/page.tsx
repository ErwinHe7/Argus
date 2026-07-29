import type { Metadata } from 'next';
import Link from 'next/link';
import { LightPage } from '@/components/LightPage';
import { getCurrentUser } from '@/lib/auth';
import { CreditCard, FileText, ShieldCheck, LifeBuoy, ReceiptText, UserX, LogOut, LogIn } from 'lucide-react';

export const metadata: Metadata = {
  title: 'Settings - AXIO7',
  description: 'Manage your AXIO7 account, review legal policies, and contact support.',
};

const ITEMS = [
  { href: '/billing', title: 'Billing', description: 'View invoices, renewal status, payment settings, and cancel future renewals.', icon: CreditCard },
  { href: '/privacy', title: 'Privacy Policy', description: 'How AXIO7 collects, uses, and protects your data.', icon: ShieldCheck },
  { href: '/terms', title: 'Terms of Service', description: 'Subscription terms and the rules for using AXIO7.', icon: FileText },
  { href: '/refund-policy', title: 'Refund Policy', description: 'Cancellation, refund eligibility, and how to submit a request.', icon: ReceiptText },
  { href: '/support', title: 'Help & Support', description: 'Get help with billing, refunds, lesson access, or your account.', icon: LifeBuoy },
  { href: '/account/delete', title: 'Delete Account', description: 'Permanently remove your AXIO7 account and data.', icon: UserX },
];

export default async function SettingsPage() {
  const user = await getCurrentUser();

  return (
    <LightPage>
      <div className="mx-auto max-w-3xl space-y-6">
        <section
          className="rounded-[24px] border p-6"
          style={{ background: 'var(--lt-surface)', borderColor: 'var(--lt-border)' }}
        >
          <p className="text-xs font-bold uppercase tracking-[0.2em]" style={{ color: 'var(--lt-muted)' }}>
            AXIO7 account
          </p>
          <h1 className="mt-2 text-3xl font-black tracking-tight" style={{ color: 'var(--lt-text)' }}>
            Settings
          </h1>
          {user.authenticated ? (
            <p className="mt-3 text-sm leading-6" style={{ color: 'var(--lt-muted)' }}>
              Signed in as <span style={{ color: 'var(--lt-text)' }}>{user.name}</span>
              {user.email ? <> ({user.email})</> : null}
            </p>
          ) : (
            <p className="mt-3 text-sm leading-6" style={{ color: 'var(--lt-muted)' }}>
              You are not signed in. Some actions like account deletion require sign in.
            </p>
          )}
        </section>

        <div className="grid gap-3 sm:grid-cols-2">
          {ITEMS.map(({ href, title, description, icon: Icon }) => (
            <Link
              key={href}
              href={href}
              className="group flex items-start gap-3 rounded-[22px] border p-5 transition hover:-translate-y-0.5"
              style={{ background: 'var(--lt-surface)', borderColor: 'var(--lt-border)', color: 'var(--lt-text)' }}
            >
              <span
                className="mt-0.5 inline-flex h-9 w-9 flex-none items-center justify-center rounded-full"
                style={{ background: 'rgba(255,128,180,0.12)', color: 'var(--molt-shell)' }}
              >
                <Icon className="h-4 w-4" />
              </span>
              <span className="min-w-0">
                <span className="block text-base font-bold">{title}</span>
                <span className="mt-1 block text-sm leading-6" style={{ color: 'var(--lt-muted)' }}>
                  {description}
                </span>
              </span>
            </Link>
          ))}
        </div>

        <section
          className="flex flex-wrap items-center justify-between gap-3 rounded-[24px] border p-5"
          style={{ background: 'var(--lt-surface)', borderColor: 'var(--lt-border)' }}
        >
          <div className="text-sm leading-6" style={{ color: 'var(--lt-muted)' }}>
            {user.authenticated
              ? 'Sign out of AXIO7 on this device.'
              : 'Sign in to access lesson progress, saved notes, and your profile.'}
          </div>
          {user.authenticated ? (
            <a href="/auth/signout" className="r-btn-ghost inline-flex items-center gap-2">
              <LogOut className="h-4 w-4" /> Sign out
            </a>
          ) : (
            <Link href="/auth/signin" className="r-btn-pink inline-flex items-center gap-2">
              <LogIn className="h-4 w-4" /> Sign in
            </Link>
          )}
        </section>
      </div>
    </LightPage>
  );
}
