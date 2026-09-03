import Link from 'next/link';
import { ArrowLeft } from 'lucide-react';
import { ListingComposer } from '@/components/ListingComposer';
import { LightPage } from '@/components/LightPage';
import { getCurrentUser } from '@/lib/auth';

export default async function NewListingPage() {
  const user = await getCurrentUser();

  if (!user.authenticated || !user.email) {
    return (
      <LightPage>
        <div className="space-y-4">
          <Link href="/trade" className="inline-flex items-center gap-1 text-sm hover:opacity-80" style={{ color: 'var(--lt-muted)' }}>
            <ArrowLeft className="h-4 w-4" /> Back to Trade
          </Link>
          <div className="rounded-[22px] p-6" style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)' }}>
            <h1 className="text-2xl font-semibold tracking-tight" style={{ color: 'var(--lt-text)' }}>Sign in to post</h1>
            <p className="mt-2 max-w-md text-sm" style={{ color: 'var(--lt-muted)' }}>
              Trade uses your Google account email privately so buyers can be connected by email when they click I want this.
            </p>
            <Link
              href="/auth/signin?next=/trade/new"
              className="mt-4 inline-flex rounded-full px-4 py-2 text-sm font-semibold text-white transition hover:opacity-90"
              style={{ background: 'var(--molt-shell)' }}
            >
              Continue with Google
            </Link>
          </div>
        </div>
      </LightPage>
    );
  }

  return (
    <LightPage>
      <div className="space-y-4">
        <Link href="/trade" className="inline-flex items-center gap-1 text-sm hover:opacity-80" style={{ color: 'var(--lt-muted)' }}>
          <ArrowLeft className="h-4 w-4" /> Back to Trade
        </Link>
        <h1 className="text-2xl font-semibold tracking-tight" style={{ color: 'var(--lt-text)' }}>New listing</h1>
        <p className="text-sm" style={{ color: 'var(--lt-muted)' }}>
          Your account email stays private until a buyer asks to connect.
        </p>
        <ListingComposer initialSellerName={user.name} />
      </div>
    </LightPage>
  );
}
