import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ArrowLeft, Tag, MapPin } from 'lucide-react';
import { getListing, getTransaction, listMessages } from '@/lib/store';
import { getCurrentUser, isAdmin } from '@/lib/auth';
import { formatCents, timeAgo } from '@/lib/format';
import { MessageThread } from '@/components/MessageThread';
import { LightPage } from '@/components/LightPage';

export const dynamic = 'force-dynamic';

export default async function ThreadPage({
  params,
  searchParams,
}: {
  params: { id: string };
  searchParams: { tx?: string };
}) {
  const listing = await getListing(params.id);
  if (!listing) return notFound();
  if (!searchParams.tx) return notFound();
  const [transaction, user] = await Promise.all([
    getTransaction(searchParams.tx),
    getCurrentUser(),
  ]);
  if (!transaction) return notFound();
  if (!user.authenticated || !user.id) return notFound();
  if (!isAdmin(user) && transaction.seller_id !== user.id && transaction.buyer_id !== user.id) return notFound();
  const messages = await listMessages(searchParams.tx);

  return (
    <LightPage>
      <div className="space-y-4">
        <Link
          href={`/trade/${listing.id}`}
          className="inline-flex items-center gap-1 text-sm hover:opacity-80"
          style={{ color: 'var(--lt-muted)' }}
        >
          <ArrowLeft className="h-4 w-4" /> Back to listing
        </Link>

        {/* Listing summary card */}
        <div
          className="rounded-[22px] p-4"
          style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)' }}
        >
          <div className="flex items-start justify-between gap-3">
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2 text-xs" style={{ color: 'var(--lt-muted)' }}>
                <span
                  className="inline-flex items-center gap-1 rounded px-2 py-0.5 font-medium capitalize"
                  style={{ background: 'rgba(0,0,0,0.06)', color: 'var(--lt-text)' }}
                >
                  <Tag className="h-3 w-3" /> {listing.category}
                </span>
                {listing.location && (
                  <span className="inline-flex items-center gap-1">
                    <MapPin className="h-3 w-3" /> {listing.location}
                  </span>
                )}
                <span>{timeAgo(listing.created_at)}</span>
              </div>
              <h1 className="mt-1.5 text-lg font-semibold tracking-tight" style={{ color: 'var(--lt-text)' }}>
                {listing.title}
              </h1>
              <p className="mt-0.5 text-sm" style={{ color: 'var(--lt-muted)' }}>
                Seller: <span className="font-medium" style={{ color: 'var(--lt-text)' }}>{transaction.seller_name}</span>
              </p>
            </div>
            <div className="text-right flex-shrink-0">
              <div className="text-xl font-bold font-mono" style={{ color: 'var(--molt-shell)' }}>
                {formatCents(transaction.amount_cents, 'USD')}
              </div>
              <span
                className={`inline-block rounded px-2 py-0.5 text-[10px] font-semibold uppercase mt-1 ${
                  transaction.status === 'pending' ? 'bg-amber-100 text-amber-800' :
                  transaction.status === 'confirmed' ? 'bg-emerald-100 text-emerald-800' :
                  'bg-gray-100 text-gray-600'
                }`}
              >
                {transaction.status}
              </span>
            </div>
          </div>
        </div>

        <MessageThread
          transactionId={transaction.id}
          currentUserId={user.id}
          currentUserName={user.name}
          sellerName={transaction.seller_name}
          buyerName={transaction.buyer_name}
          initialMessages={messages}
        />
      </div>
    </LightPage>
  );
}
