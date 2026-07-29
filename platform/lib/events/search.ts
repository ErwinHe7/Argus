import { isSupabaseConfigured, supabaseAdmin } from '../supabase';
import type { Event } from './types';

const EVENT_KEYWORDS = [
  'party', 'parties', 'event', 'events', 'concert', 'show', 'tonight',
  'this weekend', 'this week', 'happening', 'activity', 'activities',
  '活动', '派对', '演出', '音乐会', 'club night', 'mixer', 'meetup',
  'lecture', 'talk', 'screening', 'festival', 'gala', 'exhibit',
  'museum', 'gallery', 'music', 'nightlife',
];

export function detectEventIntent(text: string): boolean {
  const lower = text.toLowerCase();
  return EVENT_KEYWORDS.some((kw) => lower.includes(kw));
}

function getDateWindow(text: string): { from: Date; to: Date } | null {
  const lower = text.toLowerCase();
  const now = new Date();
  if (lower.includes('tonight') || lower.includes('today')) {
    const end = new Date(now);
    end.setHours(23, 59, 59, 999);
    return { from: now, to: end };
  }
  if (lower.includes('this weekend')) {
    // next Saturday–Sunday
    const day = now.getDay();
    const toSat = (6 - day + 7) % 7 || 7;
    const sat = new Date(now.getTime() + toSat * 86_400_000);
    sat.setHours(0, 0, 0, 0);
    const sun = new Date(sat.getTime() + 86_400_000);
    sun.setHours(23, 59, 59, 999);
    return { from: sat, to: sun };
  }
  if (lower.includes('this week')) {
    const end = new Date(now.getTime() + 7 * 86_400_000);
    return { from: now, to: end };
  }
  // Default: next 30 days
  return { from: now, to: new Date(now.getTime() + 30 * 86_400_000) };
}

export async function searchEvents(
  query: string,
  opts: { limit?: number } = {}
): Promise<Event[]> {
  const limit = opts.limit ?? 5;

  // In-memory fallback: return empty (no seeded events in memory mode)
  if (!isSupabaseConfigured()) return [];

  const window = getDateWindow(query);
  const lower = query.toLowerCase();

  let q = supabaseAdmin()
    .from('events')
    .select('*')
    .eq('status', 'published')
    .order('start_time', { ascending: true })
    .limit(limit * 3); // fetch more for JS-side filtering

  if (window) {
    q = q
      .gte('start_time', window.from.toISOString())
      .lte('start_time', window.to.toISOString());
  } else {
    q = q.gte('start_time', new Date().toISOString());
  }

  const { data, error } = await q;
  if (error || !data) return [];

  // JS-side text filter if the query has specific content words
  const stopwords = new Set(['any', 'what', 'is', 'are', 'there', 'happening', 'tonight', 'this', 'weekend', 'week', 'today', 'find', 'show', 'me']);
  const keywords = lower
    .split(/\s+/)
    .filter((w) => w.length > 2 && !stopwords.has(w));

  if (keywords.length === 0) return (data as Event[]).slice(0, limit);

  const scored = (data as Event[]).map((ev) => {
    const haystack = `${ev.title} ${ev.description ?? ''} ${ev.tags.join(' ')} ${ev.category ?? ''} ${ev.location ?? ''}`.toLowerCase();
    const score = keywords.reduce((s, kw) => s + (haystack.includes(kw) ? 1 : 0), 0);
    return { ev, score };
  });

  return scored
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .map((x) => x.ev);
}

export function formatEventsForAgentContext(events: Event[]): string {
  if (events.length === 0) return '';
  const lines = events.map((ev, i) => {
    const when = ev.start_time
      ? new Date(ev.start_time).toLocaleDateString('en-US', {
          weekday: 'short', month: 'short', day: 'numeric',
          hour: 'numeric', minute: '2-digit',
        })
      : 'Date TBD';
    const where = ev.location ?? 'NYC';
    const price = ev.price_text ? ` · ${ev.price_text}` : ev.is_free ? ' · Free' : '';
    return `${i + 1}. "${ev.title}" — ${when} — ${where}${price} — /events/${ev.id}`;
  });
  return `[Upcoming events on AXIO7]\n${lines.join('\n')}\nCite events by number. Do not invent events.`;
}
