import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ArrowLeft, ExternalLink, MapPin, Tag, Calendar } from 'lucide-react';
import { LightPage } from '@/components/LightPage';
import { isSupabaseConfigured, supabaseAdmin } from '@/lib/supabase';
import type { Event } from '@/lib/events/types';

export const dynamic = 'force-dynamic';

function formatFullDate(iso: string | null): string {
  if (!iso) return 'Date TBD';
  return new Date(iso).toLocaleDateString('en-US', {
    weekday: 'long', month: 'long', day: 'numeric',
    year: 'numeric', hour: 'numeric', minute: '2-digit',
  });
}

function icsContent(event: Event): string {
  const fmt = (d: string | null) =>
    d ? new Date(d).toISOString().replace(/[-:]/g, '').split('.')[0] + 'Z' : '';
  return [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//AXIO7//Events//EN',
    'BEGIN:VEVENT',
    `UID:axio7-${event.id}@axio7.com`,
    `DTSTART:${fmt(event.start_time)}`,
    event.end_time ? `DTEND:${fmt(event.end_time)}` : '',
    `SUMMARY:${event.title}`,
    event.location ? `LOCATION:${event.location}` : '',
    event.description ? `DESCRIPTION:${event.description.replace(/\n/g, '\\n')}` : '',
    event.url ? `URL:${event.url}` : '',
    'END:VEVENT',
    'END:VCALENDAR',
  ].filter(Boolean).join('\r\n');
}

async function getEvent(id: string): Promise<Event | null> {
  if (!isSupabaseConfigured()) return null;
  try {
    const { data, error } = await supabaseAdmin()
      .from('events')
      .select('*')
      .eq('id', id)
      .eq('status', 'published')
      .maybeSingle();
    if (error) { console.error('[EventDetail]', error.message); return null; }
    return data as Event | null;
  } catch (err) {
    console.error('[EventDetail] fetch failed:', err);
    return null;
  }
}

export default async function EventDetailPage({ params }: { params: { id: string } }) {
  const event = await getEvent(params.id);
  if (!event) return notFound();

  const ics = Buffer.from(icsContent(event)).toString('base64');

  return (
    <LightPage>
      <div className="space-y-6">
        <Link
          href="/events"
          className="inline-flex items-center gap-1 text-sm hover:opacity-80"
          style={{ color: 'var(--lt-muted)' }}
        >
          <ArrowLeft className="h-4 w-4" /> Back to Events
        </Link>

        {/* Poster */}
        {event.poster_url && (
          <div className="overflow-hidden rounded-[22px]" style={{ maxHeight: 400 }}>
            <img
              src={event.poster_url}
              alt={event.title}
              className="w-full object-cover"
              style={{ maxHeight: 400 }}
            />
          </div>
        )}

        <article
          className="rounded-[22px] p-6 space-y-4"
          style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)' }}
        >
          {/* Category + free badge */}
          <div className="flex flex-wrap items-center gap-2 text-xs">
            {event.category && (
              <span className="inline-flex items-center gap-1 rounded px-2 py-0.5 font-medium capitalize"
                style={{ background: 'rgba(0,0,0,0.06)', color: 'var(--lt-text)' }}>
                <Tag className="h-3 w-3" /> {event.category}
              </span>
            )}
            {event.borough && (
              <span className="rounded px-2 py-0.5" style={{ background: 'rgba(0,0,0,0.04)', color: 'var(--lt-muted)' }}>
                {event.borough}
              </span>
            )}
            {event.is_free && (
              <span className="rounded px-2 py-0.5 font-bold" style={{ background: 'rgba(74,124,89,0.15)', color: '#4A7C59' }}>
                FREE
              </span>
            )}
          </div>

          <h1 className="text-2xl font-semibold tracking-tight" style={{ color: 'var(--lt-text)' }}>
            {event.title}
          </h1>

          {/* Date/time */}
          {event.start_time && (
            <div className="flex items-start gap-2 text-sm">
              <Calendar className="mt-0.5 h-4 w-4 flex-shrink-0" style={{ color: 'var(--molt-shell)' }} />
              <div>
                <div style={{ color: 'var(--lt-text)' }}>{formatFullDate(event.start_time)}</div>
                {event.end_time && (
                  <div className="text-xs mt-0.5" style={{ color: 'var(--lt-muted)' }}>
                    Ends {formatFullDate(event.end_time)}
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Location */}
          {event.location && (
            <div className="flex items-start gap-2 text-sm">
              <MapPin className="mt-0.5 h-4 w-4 flex-shrink-0" style={{ color: 'var(--molt-shell)' }} />
              <span style={{ color: 'var(--lt-text)' }}>
                {event.location}{' '}
                <a
                  href={`https://maps.google.com/?q=${encodeURIComponent(event.location)}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-xs underline opacity-60 hover:opacity-100"
                >
                  map
                </a>
              </span>
            </div>
          )}

          {/* Price */}
          {(event.price_text || event.is_free != null) && (
            <div className="text-sm font-medium" style={{ color: event.is_free ? '#4A7C59' : 'var(--lt-text)' }}>
              {event.is_free ? 'Free admission' : event.price_text ?? ''}
            </div>
          )}

          {/* Description */}
          {event.description && (
            <p className="whitespace-pre-wrap text-[15px] leading-relaxed" style={{ color: 'var(--lt-muted)' }}>
              {event.description}
            </p>
          )}

          {/* Tags */}
          {event.tags.length > 0 && (
            <div className="flex flex-wrap gap-1.5 pt-1">
              {event.tags.map((t) => (
                <span
                  key={t}
                  className="rounded-full px-2.5 py-0.5 text-xs"
                  style={{ background: 'rgba(0,0,0,0.06)', color: 'var(--lt-subtle)' }}
                >
                  {t}
                </span>
              ))}
            </div>
          )}

          {/* Actions */}
          <div className="flex flex-wrap gap-3 border-t pt-4" style={{ borderColor: 'var(--lt-border)' }}>
            {event.url && (
              <a
                href={event.url}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-2 rounded-xl px-4 py-2 text-sm font-semibold text-white transition hover:opacity-90"
                style={{ background: 'var(--molt-shell)' }}
              >
                <ExternalLink className="h-4 w-4" /> Source / Tickets
              </a>
            )}
            <a
              href={`data:text/calendar;base64,${ics}`}
              download={`${event.title.slice(0, 40).replace(/\s+/g, '-')}.ics`}
              className="inline-flex items-center gap-2 rounded-xl px-4 py-2 text-sm font-medium transition hover:opacity-80"
              style={{ background: 'var(--lt-surface)', border: '1px solid var(--lt-border)', color: 'var(--lt-text)' }}
            >
              <Calendar className="h-4 w-4" /> Add to calendar
            </a>
          </div>
        </article>
      </div>
    </LightPage>
  );
}
