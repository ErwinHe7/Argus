import Link from 'next/link';
import { Plus, Sofa, Smartphone, BookOpen, Hammer, Package, Ticket, GraduationCap } from 'lucide-react';
import { LightPage } from '@/components/LightPage';
import { listListings } from '@/lib/store';
import { ListingCard } from '@/components/ListingCard';
import { getCurrentUser } from '@/lib/auth';

export const dynamic = 'force-dynamic';

const CATEGORIES = [
  { id: 'furniture',   label: 'Furniture',    icon: Sofa },
  { id: 'electronics', label: 'Electronics',  icon: Smartphone },
  { id: 'books',       label: 'Books',        icon: BookOpen },
  { id: 'tickets',     label: 'Tickets',      icon: Ticket },
  { id: 'tutoring',    label: 'Tutoring',     icon: GraduationCap },
  { id: 'services',    label: 'Services',     icon: Hammer },
  { id: 'other',       label: 'Other',        icon: Package },
] as const;

export default async function TradePage({
  searchParams,
}: {
  searchParams?: { category?: string };
}) {
  const category = searchParams?.category;

  let listings: Awaited<ReturnType<typeof listListings>> = [];
  const user = await getCurrentUser();
  const publicUser = { id: user.id, name: user.name, authenticated: user.authenticated };
  try {
    listings = await listListings({ category: category || undefined });
  } catch (err) {
    console.error('[TradePage] listListings failed:', err);
  }

  return (
    <LightPage>
      <div className="space-y-6">
        <div className="flex items-start justify-between pt-2">
          <h1
            className="font-fraunces text-6xl font-black italic leading-none sm:text-7xl lg:text-8xl"
            style={{
              background: 'linear-gradient(135deg, var(--molt-shell) 0%, var(--molt-coral) 48%, var(--lt-text) 100%)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              backgroundClip: 'text',
            }}
          >
            Trade
          </h1>
          <Link
            href="/trade/new"
            className="mt-3 inline-flex items-center gap-1.5 rounded-full px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:opacity-90"
            style={{ background: 'var(--molt-shell)' }}
          >
            <Plus className="h-4 w-4" /> Post
          </Link>
        </div>

        <div className="flex flex-wrap gap-2">
          <Link
            href="/trade"
            className="inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium transition"
            style={!category ? {
              background: 'var(--molt-shell)',
              color: 'white',
              boxShadow: '0 0 8px var(--glow-shell)',
            } : {
              background: 'var(--lt-surface)',
              border: '1px solid var(--lt-border)',
              color: 'var(--lt-muted)',
            }}
          >
            All
          </Link>
          {CATEGORIES.map((c) => (
            <Link
              key={c.id}
              href={`/trade?category=${c.id}`}
              className="inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium transition"
              style={category === c.id ? {
                background: 'var(--molt-shell)',
                color: 'white',
                boxShadow: '0 0 8px var(--glow-shell)',
              } : {
                background: 'var(--lt-surface)',
                border: '1px solid var(--lt-border)',
                color: 'var(--lt-muted)',
              }}
            >
              <c.icon className="h-3.5 w-3.5" />
              {c.label}
            </Link>
          ))}
        </div>

        {listings.length === 0 ? (
          <div
            className="rounded-[20px] border-dashed p-14 text-center"
            style={{ border: '1px dashed var(--lt-border)', background: 'var(--lt-surface)' }}
          >
            <p className="text-sm font-medium" style={{ color: 'var(--lt-text)' }}>
              No listings yet{category ? ` in ${category}` : ''}
            </p>
            <Link
              href="/trade/new"
              className="mt-4 inline-flex items-center gap-1.5 rounded-full px-4 py-2 text-sm font-semibold text-white hover:opacity-90"
              style={{ background: 'var(--molt-shell)' }}
            >
              <Plus className="h-4 w-4" /> Post a listing
            </Link>
          </div>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {listings.map((listing) => (
              <ListingCard
                key={listing.id}
                listing={{ ...listing, seller_email: null, seller_contact: null }}
                user={publicUser}
              />
            ))}
          </div>
        )}
      </div>
    </LightPage>
  );
}
