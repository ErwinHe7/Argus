import Link from 'next/link';
import type { Event } from '@/lib/events/types';

function formatEventDate(iso: string | null): string {
  if (!iso) return 'Date TBD';
  return new Date(iso).toLocaleDateString('en-US', {
    weekday: 'short', month: 'short', day: 'numeric',
    hour: 'numeric', minute: '2-digit',
  });
}

const CATEGORY_GRADIENT: Record<string, string> = {
  social:     'linear-gradient(135deg, #D84727 0%, #F5A623 100%)',
  music:      'linear-gradient(135deg, #4A0080 0%, #9B59B6 100%)',
  culture:    'linear-gradient(135deg, #0A3D62 0%, #3498DB 100%)',
  tech:       'linear-gradient(135deg, #1A1A2E 0%, #16213E 100%)',
  talk:       'linear-gradient(135deg, #2C5F2E 0%, #97BC62 100%)',
  food:       'linear-gradient(135deg, #B7410E 0%, #E8A045 100%)',
  wellness:   'linear-gradient(135deg, #1B4D3E 0%, #52B788 100%)',
  networking: 'linear-gradient(135deg, #2D2D2D 0%, #555 100%)',
  academic:   'linear-gradient(135deg, #003087 0%, #4A90E2 100%)',
  nightlife:  'linear-gradient(135deg, #0D0D0D 0%, #1a1a2e 100%)',
  other:      'linear-gradient(135deg, #525861 0%, #8892A0 100%)',
};

function posterGradient(category: string | null) {
  return CATEGORY_GRADIENT[category ?? 'other'] ?? CATEGORY_GRADIENT.other;
}

export function EventCard({ event }: { event: Event }) {
  const hasPoster = Boolean(event.poster_url);

  return (
    <Link
      href={`/events/${event.id}`}
      className="event-card group flex flex-col overflow-hidden rounded-[20px] transition-all duration-200"
      style={{
        background: 'var(--lt-surface)',
        border: '1px solid var(--lt-border)',
        backdropFilter: 'blur(12px)',
      }}
    >
      <style>{`
        .event-card:hover {
          border-color: rgba(216,71,39,0.4);
          box-shadow: 0 8px 32px var(--glow-shell);
          transform: translateY(-2px);
        }
      `}</style>

      {/* Poster / gradient header */}
      <div className="relative h-44 overflow-hidden flex-shrink-0" style={{ background: posterGradient(event.category) }}>
        {hasPoster && (
          <img
            src={event.poster_url!}
            alt={event.title}
            className="h-full w-full object-cover transition duration-500 group-hover:scale-105"
            onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
          />
        )}

        {/* Category badge */}
        {event.category && (
          <span
            className="absolute left-3 top-3 rounded-full px-2.5 py-1 text-[11px] font-semibold uppercase tracking-wide backdrop-blur"
            style={{ background: 'rgba(10,21,32,0.75)', color: 'white', border: '1px solid rgba(255,255,255,0.18)' }}
          >
            {event.category}
          </span>
        )}

        {/* Free badge */}
        {event.is_free && (
          <span
            className="absolute right-3 top-3 rounded-full px-2 py-0.5 text-[10px] font-bold backdrop-blur"
            style={{ background: 'rgba(74,124,89,0.85)', color: 'white' }}
          >
            FREE
          </span>
        )}
      </div>

      {/* Body */}
      <div className="flex flex-1 flex-col p-4">
        <h3 className="line-clamp-2 text-[15px] font-semibold leading-snug" style={{ color: 'var(--lt-text)' }}>
          {event.title}
        </h3>

        <div className="mt-2 space-y-1">
          {event.start_time && (
            <p className="text-xs font-medium" style={{ color: 'var(--molt-shell)' }}>
              {formatEventDate(event.start_time)}
            </p>
          )}
          {event.location && (
            <p className="line-clamp-1 text-xs" style={{ color: 'var(--lt-muted)' }}>
              📍 {event.location}
            </p>
          )}
        </div>

        {/* Tags */}
        {event.tags.length > 0 && (
          <div className="mt-auto pt-3 flex flex-wrap gap-1">
            {event.tags.slice(0, 3).map((tag) => (
              <span
                key={tag}
                className="rounded-full px-2 py-0.5 text-[10px]"
                style={{ background: 'rgba(0,0,0,0.06)', color: 'var(--lt-subtle)' }}
              >
                {tag}
              </span>
            ))}
          </div>
        )}

        {/* Price */}
        {event.price_text && !event.is_free && (
          <p className="mt-2 text-xs font-semibold font-mono" style={{ color: 'var(--lt-text)' }}>
            {event.price_text}
          </p>
        )}
      </div>
    </Link>
  );
}
