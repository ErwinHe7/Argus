'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { MapPin, Heart, Loader2, X } from 'lucide-react';
import type { Listing } from '@/lib/types';
import { formatCents, timeAgo } from '@/lib/format';

const CAT_LABEL: Record<Listing['category'], string> = {
  furniture: 'Furniture',
  electronics: 'Electronics',
  books: 'Books',
  services: 'Services',
  tickets: 'Tickets',
  tutoring: 'Tutoring',
  other: 'Other',
};

const STATUS_STYLE: Record<Listing['status'], { bg: string; text: string }> = {
  open:      { bg: 'rgba(74,124,89,0.2)',   text: '#4A7C59' },
  pending:   { bg: 'rgba(245,158,11,0.2)',  text: '#B45309' },
  sold:      { bg: 'rgba(0,0,0,0.06)',      text: 'var(--lt-muted)' },
  withdrawn: { bg: 'rgba(216,71,39,0.15)', text: 'var(--molt-shell)' },
};

function WantModal({
  listing,
  user,
  onClose,
}: {
  listing: Listing;
  user: TradeCardUser;
  onClose: () => void;
}) {
  const [form, setForm] = useState({ name: startingName(user), message: '' });
  const [buying, setBuying] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const router = useRouter();

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!form.name.trim()) { setError('Please enter your name.'); return; }
    setError(null);
    setBuying(true);
    try {
      const res = await fetch(`/api/listings/${listing.id}/buy`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          buyer_name: form.name.trim(),
          message: form.message.trim() || undefined,
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) { setError(data.error ?? 'Failed. Try again.'); return; }
      // Redirect to private thread
      if (data.threadUrl) {
        router.push(data.threadUrl);
        return;
      }
      setDone(true);
    } finally {
      setBuying(false);
    }
  }

  const inputCls = 'w-full rounded-lg px-3 py-2 text-sm focus:outline-none';
  const inputStyle = {
    background: 'rgba(0,0,0,0.04)',
    border: '1px solid var(--lt-border)',
    color: 'var(--lt-text)',
    caretColor: 'var(--molt-shell)',
  } as React.CSSProperties;

  return (
    /* backdrop */
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      style={{ background: 'rgba(0,0,0,0.55)', backdropFilter: 'blur(4px)' }}
      onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      <div
        className="relative w-full max-w-sm rounded-[22px] p-5 shadow-2xl"
        style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)' }}
      >
        <button
          onClick={onClose}
          className="absolute right-4 top-4 rounded-full p-1 opacity-40 hover:opacity-80 transition"
          style={{ color: 'var(--lt-text)' }}
        >
          <X className="h-4 w-4" />
        </button>

        {done ? (
          <div className="space-y-3 py-4 text-center">
            <div className="text-3xl">🎉</div>
            <p className="text-sm font-semibold" style={{ color: 'var(--lt-text)' }}>
              You&apos;re connected!
            </p>
            <p className="text-xs" style={{ color: 'var(--lt-muted)' }}>
              Both you and the seller have been emailed. Check your inbox.
            </p>
            <button
              onClick={onClose}
              className="mt-2 rounded-xl px-4 py-2 text-xs font-medium text-white"
              style={{ background: 'var(--molt-shell)' }}
            >
              Done
            </button>
          </div>
        ) : !user.authenticated ? (
          <div className="space-y-3 py-4">
            <div>
              <p className="text-sm font-semibold" style={{ color: 'var(--lt-text)' }}>
                Sign in to connect
              </p>
              <p className="mt-1 text-xs leading-relaxed" style={{ color: 'var(--lt-muted)' }}>
                AXIO7 uses your Google account email privately and sends an introduction to both sides.
              </p>
            </div>
            <Link
              href={`/auth/signin?next=/trade/${listing.id}`}
              className="inline-flex w-full items-center justify-center rounded-xl px-4 py-2.5 text-sm font-semibold text-white transition hover:opacity-90"
              style={{ background: 'var(--molt-shell)' }}
            >
              Continue with Google
            </Link>
          </div>
        ) : (
          <form onSubmit={submit} className="space-y-3">
            <div>
              <p className="text-sm font-semibold" style={{ color: 'var(--lt-text)' }}>
                I want this ♥
              </p>
              <p className="mt-0.5 text-xs" style={{ color: 'var(--lt-muted)' }}>
                {listing.title} — {formatCents(listing.asking_price_cents, listing.currency)}
              </p>
            </div>

            <input
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder="Your name"
              required
              className={inputCls}
              style={inputStyle}
            />
            <textarea
              rows={2}
              value={form.message}
              onChange={(e) => setForm({ ...form, message: e.target.value })}
              placeholder="Any questions? (optional)"
              className={inputCls}
              style={inputStyle}
            />

            {error && (
              <p className="text-xs" style={{ color: '#dc2626' }}>{error}</p>
            )}

            <button
              type="submit"
              disabled={buying}
              className="inline-flex w-full items-center justify-center gap-2 rounded-xl px-4 py-2.5 text-sm font-semibold text-white transition hover:opacity-90 disabled:opacity-50"
              style={{ background: 'var(--molt-shell)' }}
            >
              {buying ? <Loader2 className="h-4 w-4 animate-spin" /> : <Heart className="h-4 w-4" />}
              Connect me to the seller
            </button>
            <p className="text-center text-[10px]" style={{ color: 'var(--lt-subtle)' }}>
              Your account email stays private in AXIO7 and is only used for the intro.
            </p>
          </form>
        )}
      </div>
    </div>
  );
}

type TradeCardUser = {
  id: string;
  name: string;
  authenticated: boolean;
};

function startingName(user: TradeCardUser) {
  return user.name && user.name !== 'Guest' ? user.name : '';
}

export function ListingCard({ listing, user }: { listing: Listing; user: TradeCardUser }) {
  const [showModal, setShowModal] = useState(false);
  const categoryLabel = CAT_LABEL[listing.category] ?? listing.category;
  const hasImage = listing.images.length > 0;
  const status = STATUS_STYLE[listing.status];
  const isOpen = listing.status === 'open';
  const isSeller = listing.seller_id === user.id;

  return (
    <>
      {showModal && (
        <WantModal listing={listing} user={user} onClose={() => setShowModal(false)} />
      )}

      <div
        className="listing-card group flex flex-col overflow-hidden rounded-[20px] transition-all duration-200"
        style={{
          background: 'var(--lt-surface)',
          border: '1px solid var(--lt-border)',
          backdropFilter: 'blur(12px) saturate(1.4)',
          WebkitBackdropFilter: 'blur(12px) saturate(1.4)',
        }}
      >
        <style>{`
          .listing-card:hover {
            border-color: rgba(216,71,39,0.35);
            box-shadow: 0 8px 32px var(--glow-shell);
            transform: translateY(-2px);
          }
        `}</style>

        {/* Image — clicking navigates to detail */}
        <Link href={`/trade/${listing.id}`} className="block" tabIndex={-1}>
          {hasImage ? (
            <div className="relative h-44 overflow-hidden" style={{ background: 'rgba(0,0,0,0.04)' }}>
              <img
                src={listing.images[0]}
                alt={listing.title}
                className="h-full w-full object-cover transition duration-500 group-hover:scale-105"
              />
              {listing.images.length > 1 && (
                <span className="absolute bottom-2 right-2 rounded-full bg-black/70 px-2 py-0.5 text-[10px] font-medium text-white backdrop-blur">
                  +{listing.images.length - 1}
                </span>
              )}
              <span
                className="absolute left-3 top-3 rounded-full px-2.5 py-1 text-[11px] font-medium backdrop-blur"
                style={{ background: 'rgba(10,21,32,0.72)', color: 'white', border: '1px solid rgba(255,255,255,0.16)' }}
              >
                {categoryLabel}
              </span>
            </div>
          ) : (
            <div
              className="flex h-28 items-center justify-center text-xs font-semibold uppercase tracking-widest"
              style={{ background: 'rgba(0,0,0,0.03)', color: 'var(--lt-subtle)' }}
            >
              {categoryLabel}
            </div>
          )}
        </Link>

        {/* Body */}
        <div className="flex flex-1 flex-col p-4">
          <div className="flex items-center gap-2">
            {!hasImage && <span className="text-[11px]" style={{ color: 'var(--lt-muted)' }}>{categoryLabel}</span>}
            {listing.status !== 'open' && (
              <span
                className="rounded px-1.5 py-0.5 text-[10px] font-semibold uppercase"
                style={{ background: status.bg, color: status.text }}
              >
                {listing.status}
              </span>
            )}
            <span className="ml-auto text-[11px]" style={{ color: 'var(--lt-muted)' }}>{timeAgo(listing.created_at)}</span>
          </div>

          <Link href={`/trade/${listing.id}`}>
            <h3 className="mt-2 line-clamp-2 text-[15px] font-semibold leading-snug hover:underline" style={{ color: 'var(--lt-text)' }}>
              {listing.title}
            </h3>
          </Link>
          <p className="mt-1 line-clamp-2 text-xs leading-relaxed" style={{ color: 'var(--lt-muted)' }}>
            {listing.description}
          </p>

          <div className="mt-auto">
            <div className="mt-3 flex items-end justify-between border-t pt-3" style={{ borderColor: 'var(--lt-border)' }}>
              <div>
                <div className="text-xl font-bold font-mono" style={{ color: 'var(--molt-shell)' }}>
                  {formatCents(listing.asking_price_cents, listing.currency)}
                </div>
                {listing.location && (
                  <span className="inline-flex items-center gap-1 text-[11px]" style={{ color: 'var(--lt-muted)' }}>
                    <MapPin className="h-3 w-3" />{listing.location}
                  </span>
                )}
              </div>
              {isOpen && !isSeller ? (
                <button
                  onClick={() => setShowModal(true)}
                  className="inline-flex items-center gap-1.5 rounded-xl px-3 py-2 text-xs font-semibold text-white transition hover:opacity-90 active:scale-95"
                  style={{ background: 'var(--molt-shell)' }}
                >
                  <Heart className="h-3.5 w-3.5" />
                  I want this
                </button>
              ) : isOpen && isSeller ? (
                <span
                  className="rounded px-2 py-1 text-[10px] font-semibold uppercase"
                  style={{ background: 'rgba(216,71,39,0.12)', color: 'var(--molt-shell)' }}
                >
                  Your listing
                </span>
              ) : (
                <span
                  className="rounded px-2 py-1 text-[10px] font-semibold uppercase"
                  style={{ background: status.bg, color: status.text }}
                >
                  {listing.status}
                </span>
              )}
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
