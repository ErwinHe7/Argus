import { NextRequest, NextResponse } from 'next/server';
import { listUpcomingEvents, searchEventsByText } from '@/lib/events/store';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

// Keyword → category mapping for intent detection
const CATEGORY_KEYWORDS: Record<string, string[]> = {
  social:     ['party', 'parties', 'mixer', 'social', 'rooftop', 'nightlife', '派对'],
  music:      ['concert', 'music', 'band', 'dj', 'jazz', 'live music', '音乐'],
  culture:    ['art', 'gallery', 'museum', 'exhibit', 'film', 'movie', 'screening'],
  tech:       ['startup', 'founder', 'investor', 'tech', 'hackathon', 'demo', 'product'],
  talk:       ['lecture', 'talk', 'panel', 'seminar', 'workshop', 'conference'],
  food:       ['food', 'market', 'dining', 'tasting', 'brunch'],
  wellness:   ['yoga', 'fitness', 'run', 'workout', 'meditation'],
  networking: ['networking', 'meetup', 'career', 'professional'],
  academic:   ['columbia', 'research', 'thesis', 'academic', 'graduation'],
};

function detectCategory(q: string): string | undefined {
  const lower = q.toLowerCase();
  for (const [cat, kws] of Object.entries(CATEGORY_KEYWORDS)) {
    if (kws.some((kw) => lower.includes(kw))) return cat;
  }
  return undefined;
}

function detectFree(q: string): boolean | undefined {
  const lower = q.toLowerCase();
  if (lower.includes('free')) return true;
  return undefined;
}

function detectDateWindow(when: string | null): { from: Date; to: Date } | null {
  if (!when) return null;
  const now = new Date();
  switch (when) {
    case 'today': {
      const end = new Date(now); end.setHours(23, 59, 59, 999);
      return { from: now, to: end };
    }
    case 'tomorrow': {
      const start = new Date(now); start.setDate(start.getDate() + 1); start.setHours(0, 0, 0, 0);
      const end = new Date(start); end.setHours(23, 59, 59, 999);
      return { from: start, to: end };
    }
    case 'weekend': {
      const day = now.getDay();
      const toSat = (6 - day + 7) % 7 || 7;
      const sat = new Date(now.getTime() + toSat * 86_400_000); sat.setHours(0, 0, 0, 0);
      const sun = new Date(sat.getTime() + 86_400_000); sun.setHours(23, 59, 59, 999);
      return { from: sat, to: sun };
    }
    case 'week':
      return { from: now, to: new Date(now.getTime() + 7 * 86_400_000) };
    case 'month':
      return { from: now, to: new Date(now.getTime() + 30 * 86_400_000) };
    default:
      return null;
  }
}

export async function GET(req: NextRequest) {
  const sp = req.nextUrl.searchParams;
  const q          = sp.get('q') ?? '';
  const when       = sp.get('when');
  const category   = sp.get('category') ?? detectCategory(q);
  const borough    = sp.get('borough') ?? undefined;
  const isFree     = sp.get('free') === '1' ? true : detectFree(q);
  const limit      = Math.min(Number(sp.get('limit') ?? '10'), 30);

  const dateWindow = detectDateWindow(when);

  try {
    let events;
    if (q.trim()) {
      events = await searchEventsByText(q, {
        limit,
        from: dateWindow?.from,
        to: dateWindow?.to,
      });
    } else {
      events = await listUpcomingEvents({
        limit,
        category,
        borough,
        isFree: isFree ?? undefined,
        from: dateWindow?.from,
        to: dateWindow?.to,
      });
    }

    return NextResponse.json({ events, total: events.length });
  } catch (err: unknown) {
    console.error('[events/search]', err);
    return NextResponse.json({ events: [], error: String(err) }, { status: 500 });
  }
}
