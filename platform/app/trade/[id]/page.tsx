import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ArrowLeft, MapPin, MessageSquare, Tag } from 'lucide-react';
import { LightPage } from '@/components/LightPage';
import { BidPanel } from '@/components/BidPanel';
import { ListingAskAI } from '@/components/ListingAskAI';
import { getCurrentUser } from '@/lib/auth';
import { formatCents, timeAgo } from '@/lib/format';
import { getListing, getTransactionByListing } from '@/lib/store';

export const dynamic = 'force-dynamic';

export default async function ListingDetail({ params }: { params: { id: string } }) {
  const listing = await getListing(params.id);
  if (!listing) return notFound();

  const [transaction, user] = await Promise.all([
    getTransactionByListing(listing.id),
    getCurrentUser(),
  ]);
  const publicListing = { ...listing, seller_email: null, seller_contact: null };
  const publicUser = { id: user.id, name: user.name, authenticated: user.authenticated };

  return (
    <LightPage>
      <div className="space-y-6">
        <Link href="/trade" className="inline-flex items-center gap-1 text-sm hover:opacity-80" style={{ color: 'var(--lt-muted)' }}>
          <ArrowLeft className="h-4 w-4" /> Back to Trade
        </Link>

        <article className="rounded-[22px] p-5" style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)', backdropFilter: 'blur(12px)' }}>
          <div className="flex items-center gap-2 text-xs" style={{ color: 'var(--lt-muted)' }}>
            <span className="inline-flex items-center gap-1 rounded px-2 py-0.5 font-medium" style={{ background: 'rgba(0,0,0,0.06)', color: 'var(--lt-text)' }}>
              <Tag className="h-3 w-3" /> {listing.category}
            </span>
            <span>{timeAgo(listing.created_at)}</span>
            {listing.location && (
              <span className="inline-flex items-center gap-1">
                <MapPin className="h-3 w-3" /> {listing.location}
              </span>
            )}
            <span className={`ml-auto inline-flex items-center gap-1 rounded px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide ${
              listing.status === 'open' ? 'bg-emerald-100 text-emerald-800' :
              listing.status === 'pending' ? 'bg-amber-100 text-amber-800' :
              listing.status === 'sold' ? 'bg-gray-100 text-gray-600' : 'bg-red-100 text-red-700'
            }`}>
              {listing.status}
            </span>
          </div>

          <h1 className="mt-3 text-2xl font-semibold tracking-tight" style={{ color: 'var(--lt-text)' }}>{listing.title}</h1>
          <p className="mt-1 text-sm" style={{ color: 'var(--lt-muted)' }}>
            by <span className="font-medium" style={{ color: 'var(--lt-text)' }}>{listing.seller_name}</span>
          </p>

          {listing.images.length > 0 && (
            <div className="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-3">
              {listing.images.map((src) => (
                <img key={src} src={src} alt="" className="aspect-square w-full rounded-lg object-cover" style={{ border: '1px solid var(--lt-border)' }} />
              ))}
            </div>
          )}

          <p className="mt-4 whitespace-pre-wrap text-[15px] leading-relaxed" style={{ color: 'var(--lt-muted)' }}>
            {listing.description}
          </p>

          <div className="mt-5 flex items-end justify-between border-t pt-4" style={{ borderColor: 'var(--lt-border)' }}>
            <div>
              <div className="text-xs" style={{ color: 'var(--lt-muted)' }}>Asking price</div>
              <div className="text-2xl font-bold font-mono" style={{ color: 'var(--molt-shell)' }}>
                {formatCents(listing.asking_price_cents, listing.currency)}
              </div>
            </div>
            <div className="text-right">
              <div className="text-xs" style={{ color: 'var(--lt-muted)' }}>Top offer</div>
              <div className="text-xl font-semibold" style={{ color: 'var(--lt-text)' }}>
                {listing.top_bid_cents != null ? formatCents(listing.top_bid_cents, listing.currency) : '-'}
              </div>
            </div>
          </div>
        </article>

        {transaction && (
          <Link
            href={`/trade/${listing.id}/thread?tx=${transaction.id}`}
            className="flex items-center justify-between rounded-[22px] px-4 py-3 text-sm transition hover:opacity-90"
            style={{ background: 'rgba(216,71,39,0.12)', border: '1px solid rgba(216,71,39,0.3)', color: 'var(--molt-shell)' }}
          >
            <span className="inline-flex items-center gap-2 font-medium">
              <MessageSquare className="h-4 w-4" />
              Active deal with {transaction.buyer_name} ({formatCents(transaction.amount_cents, 'USD')})
            </span>
            <span className="text-xs opacity-70">Open thread -&gt;</span>
          </Link>
        )}

        <BidPanel listing={publicListing} user={publicUser} />

        <ListingAskAI listing={publicListing} />
      </div>
    </LightPage>
  );
}
