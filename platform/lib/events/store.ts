import { isSupabaseConfigured, supabaseAdmin } from '../supabase';
import type { Event, EventStatus } from './types';

function mapEvent(row: unknown): Event {
  const r = row as Record<string, unknown>;
  return {
    id: r.id as string,
    source_id: (r.source_id as string) ?? null,
    external_id: (r.external_id as string) ?? null,
    title: r.title as string,
    description: (r.description as string) ?? null,
    start_time: (r.start_time as string) ?? null,
    end_time: (r.end_time as string) ?? null,
    location: (r.location as string) ?? null,
    borough: (r.borough as string) ?? null,
    lat: (r.lat as number) ?? null,
    lng: (r.lng as number) ?? null,
    url: (r.url as string) ?? null,
    poster_url: (r.poster_url as string) ?? null,
    tags: Array.isArray(r.tags) ? (r.tags as string[]) : [],
    category: (r.category as string) ?? null,
    price_text: (r.price_text as string) ?? null,
    is_free: (r.is_free as boolean) ?? null,
    submitted_by_author_id: (r.submitted_by_author_id as string) ?? null,
    status: (r.status as EventStatus) ?? 'published',
    freshness_score: (r.freshness_score as number) ?? 100,
    created_at: r.created_at as string,
    updated_at: r.updated_at as string,
  };
}

export async function getEvent(id: string): Promise<Event | null> {
  if (!isSupabaseConfigured()) return null;
  const { data } = await supabaseAdmin()
    .from('events')
    .select('*')
    .eq('id', id)
    .maybeSingle();
  return data ? mapEvent(data) : null;
}

export async function listUpcomingEvents(opts: {
  limit?: number;
  category?: string;
  borough?: string;
  isFree?: boolean;
  from?: Date;
  to?: Date;
  status?: EventStatus;
} = {}): Promise<Event[]> {
  if (!isSupabaseConfigured()) return [];
  const { limit = 30, category, borough, isFree, from, to, status = 'published' } = opts;

  let q = supabaseAdmin()
    .from('events')
    .select('*')
    .eq('status', status)
    .gte('start_time', (from ?? new Date()).toISOString())
    .order('start_time', { ascending: true })
    .limit(limit);

  if (to) q = q.lte('start_time', to.toISOString());
  if (category) q = q.eq('category', category);
  if (borough) q = q.eq('borough', borough);
  if (isFree === true) q = q.eq('is_free', true);

  const { data } = await q;
  return (data ?? []).map(mapEvent);
}

export async function searchEventsByText(
  query: string,
  opts: { limit?: number; from?: Date; to?: Date } = {}
): Promise<Event[]> {
  if (!isSupabaseConfigured()) return [];
  const limit = opts.limit ?? 8;

  let q = supabaseAdmin()
    .from('events')
    .select('*')
    .eq('status', 'published')
    .gte('start_time', (opts.from ?? new Date()).toISOString())
    .order('start_time', { ascending: true })
    .limit(limit * 4); // fetch more for JS scoring

  if (opts.to) q = q.lte('start_time', opts.to.toISOString());

  const { data } = await q;
  if (!data) return [];

  const lower = query.toLowerCase();
  const words = lower.split(/\s+/).filter((w) => w.length > 2);

  const scored = (data as unknown[]).map(mapEvent).map((ev) => {
    const hay = `${ev.title} ${ev.description ?? ''} ${ev.category ?? ''} ${ev.tags.join(' ')} ${ev.location ?? ''}`.toLowerCase();
    const score = words.reduce((s, w) => s + (hay.includes(w) ? 1 : 0), 0);
    return { ev, score };
  });

  return scored
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .map((x) => x.ev);
}
