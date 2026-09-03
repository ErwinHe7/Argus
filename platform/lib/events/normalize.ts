import type { NormalizedEvent } from './types';

export function normalizeborough(location: string | null | undefined): string | null {
  if (!location) return null;
  const l = location.toLowerCase();
  if (l.includes('brooklyn')) return 'Brooklyn';
  if (l.includes('queens')) return 'Queens';
  if (l.includes('bronx')) return 'Bronx';
  if (l.includes('staten island')) return 'Staten Island';
  if (l.includes('manhattan') || l.includes('midtown') || l.includes('downtown') ||
      l.includes('upper west') || l.includes('upper east') || l.includes('harlem') ||
      l.includes('morningside') || l.includes('columbia') || l.includes('new york, ny')) {
    return 'Manhattan';
  }
  return null;
}

export function inferCategory(title: string, description: string | null, tags: string[]): string {
  const text = `${title} ${description ?? ''} ${tags.join(' ')}`.toLowerCase();
  if (/party|parties|mixer|social|rooftop|nightlife|club/.test(text)) return 'social';
  if (/concert|music|jazz|band|dj|live music|performance/.test(text)) return 'music';
  if (/art|gallery|museum|exhibit|moma|met|brooklyn museum/.test(text)) return 'culture';
  if (/hackathon|coding|tech|startup|demo day|product/.test(text)) return 'tech';
  if (/lecture|talk|panel|symposium|workshop|seminar|class/.test(text)) return 'talk';
  if (/film|movie|screening|cinema/.test(text)) return 'culture';
  if (/food|market|restaurant|dining|smorgasburg/.test(text)) return 'food';
  if (/yoga|fitness|run|workout|wellness/.test(text)) return 'wellness';
  if (/networking|meetup|career|professional/.test(text)) return 'networking';
  if (/academic|research|thesis|dissertation|gala|graduation/.test(text)) return 'academic';
  return 'other';
}

export function inferIsFree(priceText: string | null | undefined): boolean | null {
  if (!priceText) return null;
  const t = priceText.toLowerCase();
  if (t.includes('free') || t === '0' || t === '$0') return true;
  if (/\$[1-9]/.test(t)) return false;
  return null;
}

// iCal VEVENT → NormalizedEvent
export function normalizeIcalEvent(vevent: Record<string, unknown>): NormalizedEvent | null {
  const uid = String(vevent.uid ?? vevent.UID ?? '').trim();
  const summary = String(vevent.summary ?? vevent.SUMMARY ?? '').trim();
  if (!uid || !summary) return null;

  const location = String(vevent.location ?? vevent.LOCATION ?? '').trim() || null;
  const description = String(vevent.description ?? vevent.DESCRIPTION ?? '').trim() || null;
  const url = String(vevent.url ?? vevent.URL ?? '').trim() || null;

  let start_time: string | null = null;
  let end_time: string | null = null;
  try {
    const dtstart = vevent.dtstart ?? vevent.DTSTART;
    const dtend = vevent.dtend ?? vevent.DTEND;
    if (dtstart) start_time = new Date(dtstart as string).toISOString();
    if (dtend) end_time = new Date(dtend as string).toISOString();
  } catch {
    // ignore malformed dates
  }

  const tags: string[] = [];
  const category = inferCategory(summary, description, tags);
  const borough = normalizeborough(location);

  return {
    external_id: uid,
    title: summary,
    description,
    start_time,
    end_time,
    location,
    borough,
    lat: null,
    lng: null,
    url,
    poster_url: null,
    tags,
    category,
    price_text: null,
    is_free: null,
    raw_payload: vevent as Record<string, unknown>,
  };
}

// NYC Open Data permitted-events row → NormalizedEvent
export function normalizeNycOpenDataRow(row: Record<string, unknown>): NormalizedEvent | null {
  const eventId = String(row.event_id ?? row.id ?? '').trim();
  const title = String(row.event_name ?? row.title ?? '').trim();
  if (!title) return null;

  const location = [row.event_location, row.street_address, row.borough]
    .filter(Boolean).join(', ') || null;
  const borough = normalizeborough(String(row.borough ?? ''));
  const description = String(row.event_type ?? '').trim() || null;
  const url = null;

  let start_time: string | null = null;
  let end_time: string | null = null;
  try {
    if (row.start_date_time) start_time = new Date(String(row.start_date_time)).toISOString();
    else if (row.start_date) start_time = new Date(String(row.start_date)).toISOString();
    if (row.end_date_time) end_time = new Date(String(row.end_date_time)).toISOString();
    else if (row.end_date) end_time = new Date(String(row.end_date)).toISOString();
  } catch {}

  const tags: string[] = [];
  if (row.event_type) tags.push(String(row.event_type).toLowerCase());
  const category = inferCategory(title, description, tags);

  return {
    external_id: eventId || `nycopendata-${title.slice(0, 40).replace(/\s+/g, '-')}`,
    title,
    description,
    start_time,
    end_time,
    location,
    borough,
    lat: row.latitude ? Number(row.latitude) : null,
    lng: row.longitude ? Number(row.longitude) : null,
    url,
    poster_url: null,
    tags,
    category,
    price_text: 'Free (permit)',
    is_free: true,
    raw_payload: row,
  };
}

// Ticketmaster Discovery API event → NormalizedEvent
export function normalizeTicketmasterEvent(event: Record<string, unknown>): NormalizedEvent | null {
  const id = String(event.id ?? '').trim();
  const name = String(event.name ?? '').trim();
  if (!id || !name) return null;

  const url = String((event.url as string) ?? '').trim() || null;

  // Best poster: highest-width image
  const images = Array.isArray(event.images) ? event.images as Array<Record<string, unknown>> : [];
  const poster = images
    .filter((img) => img.url)
    .sort((a, b) => Number(b.width ?? 0) - Number(a.width ?? 0))[0];
  const poster_url = poster ? String(poster.url) : null;

  // Venue
  const venues = (event._embedded as Record<string, unknown>)?.venues;
  const venue = Array.isArray(venues) ? (venues[0] as Record<string, unknown>) : null;
  const venueName = venue ? String(venue.name ?? '') : null;
  const city = venue ? String((venue.city as Record<string, unknown>)?.name ?? '') : '';
  const location = [venueName, city].filter(Boolean).join(', ') || null;
  const borough = normalizeborough(location ?? city);

  const lat = venue?.location ? Number((venue.location as Record<string, unknown>).latitude) : null;
  const lng = venue?.location ? Number((venue.location as Record<string, unknown>).longitude) : null;

  // Dates
  let start_time: string | null = null;
  let end_time: string | null = null;
  try {
    const dates = event.dates as Record<string, unknown>;
    const start = (dates?.start as Record<string, unknown>);
    if (start?.dateTime) start_time = new Date(String(start.dateTime)).toISOString();
    else if (start?.localDate) start_time = new Date(String(start.localDate)).toISOString();
  } catch {}

  // Price
  const priceRanges = Array.isArray(event.priceRanges)
    ? (event.priceRanges as Array<Record<string, unknown>>)
    : [];
  let price_text: string | null = null;
  let is_free: boolean | null = null;
  if (priceRanges.length > 0) {
    const min = priceRanges[0].min;
    const max = priceRanges[0].max;
    if (min !== undefined) {
      price_text = max && max !== min ? `$${min}–$${max}` : `$${min}`;
      is_free = Number(min) === 0;
    }
  }

  // Tags from classifications
  const classifications = Array.isArray(event.classifications)
    ? (event.classifications as Array<Record<string, unknown>>)
    : [];
  const tags: string[] = [];
  for (const c of classifications) {
    for (const key of ['segment', 'genre', 'subGenre']) {
      const obj = c[key] as Record<string, unknown> | undefined;
      if (obj?.name && String(obj.name) !== 'Undefined') tags.push(String(obj.name).toLowerCase());
    }
  }

  const category = inferCategory(name, null, tags);

  // Description from info/pleaseNote
  const description = String(event.info ?? event.pleaseNote ?? '').trim() || null;

  return {
    external_id: id,
    title: name,
    description,
    start_time,
    end_time,
    location,
    borough,
    lat: isNaN(lat ?? NaN) ? null : lat,
    lng: isNaN(lng ?? NaN) ? null : lng,
    url,
    poster_url,
    tags,
    category,
    price_text,
    is_free,
    raw_payload: event,
  };
}
