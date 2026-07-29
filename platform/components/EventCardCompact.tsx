import Link from 'next/link';
import type { Event } from '@/lib/events/types';

function formatShortDate(iso: string | null): string {
  if (!iso) return 'TBD';
  return new Date(iso).toLocaleDateString('en-US', {
    month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit',
  });
}

export function EventCardCompact({ event }: { event: Event }) {
  return (
    <Link
      href={`/events/${event.id}`}
      className="group flex items-start gap-3 rounded-xl p-3 transition hover:opacity-90"
      style={{
        background: 'rgba(216,71,39,0.06)',
        border: '1px solid rgba(216,71,39,0.18)',
      }}
    >
      {/* Poster thumbnail */}
      <div
        className="h-14 w-14 flex-shrink-0 overflow-hidden rounded-lg"
        style={{ background: 'rgba(0,0,0,0.1)' }}
      >
        {event.poster_url ? (
          <img
            src={event.poster_url}
            alt=""
            className="h-full w-full object-cover"
            onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
          />
        ) : (
          <div
            className="flex h-full w-full items-center justify-center text-lg"
          >
            🎉
          </div>
        )}
      </div>

      <div className="min-w-0 flex-1">
        <p className="line-clamp-1 text-[13px] font-semibold" style={{ color: 'var(--lt-text)' }}>
          {event.title}
        </p>
        {event.start_time && (
          <p className="mt-0.5 text-[11px]" style={{ color: 'var(--molt-shell)' }}>
            {formatShortDate(event.start_time)}
          </p>
        )}
        {event.location && (
          <p className="mt-0.5 line-clamp-1 text-[11px]" style={{ color: 'var(--lt-muted)' }}>
            {event.location}
          </p>
        )}
        {(event.price_text || event.is_free) && (
          <p className="mt-0.5 text-[11px] font-medium" style={{ color: event.is_free ? '#4A7C59' : 'var(--lt-muted)' }}>
            {event.is_free ? 'Free' : event.price_text}
          </p>
        )}
      </div>

      <span className="text-xs opacity-40 group-hover:opacity-70 transition">→</span>
    </Link>
  );
}
