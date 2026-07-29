'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { Heart, Loader2 } from 'lucide-react';
import type { Listing } from '@/lib/types';
import { formatCents } from '@/lib/format';

type BidPanelUser = {
  id: string;
  name: string;
  authenticated: boolean;
};

const inputCls = 'w-full rounded-lg px-3 py-2 text-sm focus:outline-none';
const inputStyle = {
  background: 'rgba(0,0,0,0.04)',
  border: '1px solid var(--lt-border)',
  color: 'var(--lt-text)',
  caretColor: 'var(--molt-shell)',
};
const card = {
  background: 'var(--lt-surface)',
  border: '1px solid var(--lt-border)',
};

function startingName(user: BidPanelUser) {
  return user.name && user.name !== 'Guest' ? user.name : '';
}

export function BidPanel({ listing, user }: { listing: Listing; bids?: unknown[]; user: BidPanelUser }) {
  const isSeller = listing.seller_id === user.id;
  const [form, setForm] = useState({
    name: startingName(user),
    message: '',
  });
  const [buying, setBuying] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const router = useRouter();

  async function wantThis() {
    setError(null);
    setNotice(null);
    if (!form.name.trim()) { setError('Please enter your name.'); return; }

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
      if (!res.ok) {
        setError(data.error ?? 'Connection failed. Try again.');
        return;
      }
      // Redirect to the private thread
      if (data.threadUrl) {
        router.push(data.threadUrl);
        return;
      }
      setNotice("You're connected! Check your inbox for the email introduction.");
      router.refresh();
    } finally {
      setBuying(false);
    }
  }

  if (notice) {
    return (
      <div className="rounded-[22px] p-5 text-center space-y-3" style={{ ...card, background: 'rgba(74,124,89,0.08)', border: '1px solid rgba(74,124,89,0.25)' }}>
        <div className="text-2xl">🎉</div>
        <p className="text-sm font-medium" style={{ color: '#2f6842' }}>{notice}</p>
        <p className="text-xs" style={{ color: 'var(--lt-muted)' }}>
          You and the seller can take it from here — reach out directly to arrange the exchange.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {listing.status === 'open' && !isSeller && (
        <div className="space-y-3 rounded-[22px] p-5" style={card}>
          <div className="flex items-center justify-between gap-3">
            <h3 className="text-base font-semibold" style={{ color: 'var(--lt-text)' }}>I want this</h3>
            <span className="text-sm font-mono font-bold" style={{ color: 'var(--molt-shell)' }}>
              {formatCents(listing.asking_price_cents, listing.currency)}
            </span>
          </div>

          {!user.authenticated ? (
            <div className="rounded-lg px-3 py-3 text-sm" style={{ background: 'rgba(216,71,39,0.08)', border: '1px solid rgba(216,71,39,0.18)', color: 'var(--lt-muted)' }}>
              <p>Sign in with Google to connect. AXIO7 will email both sides privately.</p>
              <Link
                href={`/auth/signin?next=/trade/${listing.id}`}
                className="mt-3 inline-flex rounded-full px-4 py-2 text-xs font-semibold text-white"
                style={{ background: 'var(--molt-shell)' }}
              >
                Continue with Google
              </Link>
            </div>
          ) : (
            <>
          <div className="grid gap-2">
            <input
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder="Your name"
              required
              className={inputCls}
              style={inputStyle}
            />
          </div>

          <textarea
            rows={2}
            value={form.message}
            onChange={(e) => setForm({ ...form, message: e.target.value })}
            placeholder="Any questions or pickup notes? (optional)"
            className={inputCls}
            style={inputStyle}
          />

          {error && (
            <div className="rounded-lg px-3 py-2 text-xs" style={{ background: 'rgba(220,38,38,0.08)', border: '1px solid rgba(220,38,38,0.2)', color: '#dc2626' }}>
              {error}
            </div>
          )}

          <button
            type="button"
            onClick={wantThis}
            disabled={buying}
            className="inline-flex w-full items-center justify-center gap-2 rounded-xl px-4 py-3 text-sm font-semibold text-white shadow-sm transition hover:opacity-90 disabled:opacity-50"
            style={{ background: 'var(--molt-shell)' }}
          >
            {buying ? <Loader2 className="h-4 w-4 animate-spin" /> : <Heart className="h-4 w-4" />}
            Connect me to the seller
          </button>

          <p className="text-center text-[11px]" style={{ color: 'var(--lt-subtle)' }}>
            AXIO7 uses your account email privately and emails both sides.
          </p>
            </>
          )}
        </div>
      )}

      {listing.status === 'open' && isSeller && (
        <div className="rounded-[22px] p-4 text-sm" style={{ ...card, color: 'var(--lt-muted)' }}>
          This is your listing. Share the link so interested buyers can reach out.
        </div>
      )}

      {listing.status !== 'open' && (
        <div className="rounded-[22px] p-4 text-sm" style={{ ...card, color: 'var(--lt-muted)' }}>
          This listing is <strong>{listing.status}</strong>. No new inquiries accepted.
        </div>
      )}
    </div>
  );
}
