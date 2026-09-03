import Link from 'next/link';
import { Plus, Calendar } from 'lucide-react';
import { LightPage } from '@/components/LightPage';
import { EventCard } from '@/components/EventCard';
import { isSupabaseConfigured, supabaseAdmin } from '@/lib/supabase';
import type { Event } from '@/lib/events/types';

export const dynamic = 'force-dynamic';

const DATE_FILTERS = [
  { id: 'all',     label: 'All upcoming' },
  { id: 'today',   label: 'Today' },
  { id: 'weekend', label: 'This weekend' },
  { id: 'week',    label: 'This week' },
];

const CATEGORY_FILTERS = [
  'social', 'music', 'culture', 'tech', 'talk', 'food', 'wellness', 'networking', 'academic', 'nightlife',
];

const BOROUGH_FILTERS = ['Manhattan', 'Brooklyn', 'Queens', 'Bronx', 'Staten Island'];

function getDateRange(dateFilter: string): { from: string; to: string } | null {
  const now = new Date();
  if (dateFilter === 'today') {
    const end = new Date(now);
    end.setHours(23, 59, 59, 999);
    return { from: now.toISOString(), to: end.toISOString() };
  }
  if (dateFilter === 'weekend') {
    const day = now.getDay();
    const toSat = (6 - day + 7) % 7 || 7;
    const sat = new Date(now.getTime() + toSat * 86_400_000);
    sat.setHours(0, 0, 0, 0);
    const sun = new Date(sat.getTime() + 86_400_000);
    sun.setHours(23, 59, 59, 999);
    return { from: sat.toISOString(), to: sun.toISOString() };
  }
  if (dateFilter === 'week') {
    const end = new Date(now.getTime() + 7 * 86_400_000);
    return { from: now.toISOString(), to: end.toISOString() };
  }
  return null; // all: from now
}

async function getEvents(params: {
  dateFilter: string;
  category?: string;
  borough?: string;
  free?: boolean;
}): Promise<Event[]> {
  if (!isSupabaseConfigured()) return [];

  let q = supabaseAdmin()
    .from('events')
    .select('*')
    .eq('status', 'published')
    .gte('start_time', new Date().toISOString())
    .order('start_time', { ascending: true })
    .limit(60);

  const range = getDateRange(params.dateFilter);
  if (range) {
    q = q.lte('start_time', range.to);
  }
  if (params.category) q = q.eq('category', params.category);
  if (params.borough) q = q.eq('borough', params.borough);
  if (params.free) q = q.eq('is_free', true);

  try {
    const { data, error } = await q;
    if (error) {
      console.error('[EventsPage] query error:', error.message);
      return [];
    }
    return (data ?? []) as Event[];
  } catch (err) {
    console.error('[EventsPage] fetch failed:', err);
    return [];
  }
}

export default async function EventsPage({
  searchParams,
}: {
  searchParams?: { date?: string; category?: string; borough?: string; free?: string };
}) {
  const dateFilter = searchParams?.date ?? 'all';
  const category = searchParams?.category;
  const borough = searchParams?.borough;
  const free = searchParams?.free === '1';

  const events = await getEvents({ dateFilter, category, borough, free }).catch(() => []);

  function buildHref(updates: Record<string, string | undefined>) {
    const params = new URLSearchParams();
    const merged = { date: dateFilter, category, borough, free: free ? '1' : undefined, ...updates };
    for (const [k, v] of Object.entries(merged)) {
      if (v) params.set(k, v);
    }
    return `/events?${params.toString()}`;
  }

  const pillActive = {
    background: 'var(--molt-shell)',
    color: 'white',
    boxShadow: '0 0 8px var(--glow-shell)',
  };
  const pillInactive = {
    background: 'var(--lt-surface)',
    border: '1px solid var(--lt-border)',
    color: 'var(--lt-muted)',
  };

  return (
    <LightPage>
      <div className="space-y-6">
        {/* Header */}
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
            Events
          </h1>
          <Link
            href="/events/submit"
            className="mt-3 inline-flex items-center gap-1.5 rounded-full px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:opacity-90"
            style={{ background: 'var(--molt-shell)' }}
          >
            <Plus className="h-4 w-4" /> Submit
          </Link>
        </div>

        {/* Date filters */}
        <div className="flex flex-wrap gap-2">
          {DATE_FILTERS.map((f) => (
            <Link
              key={f.id}
              href={buildHref({ date: f.id })}
              className="inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium transition"
              style={dateFilter === f.id ? pillActive : pillInactive}
            >
              <Calendar className="h-3.5 w-3.5" />
              {f.label}
            </Link>
          ))}
        </div>

        {/* Category filters */}
        <div className="flex flex-wrap gap-2">
          <Link
            href={buildHref({ category: undefined })}
            className="inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium transition"
            style={!category ? pillActive : pillInactive}
          >
            All categories
          </Link>
          {CATEGORY_FILTERS.map((c) => (
            <Link
              key={c}
              href={buildHref({ category: c })}
              className="inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium capitalize transition"
              style={category === c ? pillActive : pillInactive}
            >
              {c}
            </Link>
          ))}
        </div>

        {/* Borough + free filters */}
        <div className="flex flex-wrap gap-2">
          {BOROUGH_FILTERS.map((b) => (
            <Link
              key={b}
              href={buildHref({ borough: borough === b ? undefined : b })}
              className="inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium transition"
              style={borough === b ? pillActive : pillInactive}
            >
              {b}
            </Link>
          ))}
          <Link
            href={buildHref({ free: free ? undefined : '1' })}
            className="inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium transition"
            style={free ? pillActive : pillInactive}
          >
            Free only
          </Link>
        </div>

        {/* Grid */}
        {events.length === 0 ? (
          <div
            className="rounded-[20px] border-dashed p-16 text-center"
            style={{ border: '1px dashed var(--lt-border)', background: 'var(--lt-surface)' }}
          >
            <p className="text-sm font-medium" style={{ color: 'var(--lt-text)' }}>
              No events found for these filters.
            </p>
            <Link
              href="/events/submit"
              className="mt-4 inline-flex items-center gap-1.5 rounded-full px-4 py-2 text-sm font-semibold text-white hover:opacity-90"
              style={{ background: 'var(--molt-shell)' }}
            >
              <Plus className="h-4 w-4" /> Submit an event
            </Link>
          </div>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {events.map((ev) => (
              <EventCard key={ev.id} event={ev} />
            ))}
          </div>
        )}
      </div>
    </LightPage>
  );
}
