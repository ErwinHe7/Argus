import type { NormalizedEvent } from '../types';
import { normalizeTicketmasterEvent } from '../normalize';

// Columbia area: lat/lng for Morningside Heights, 10-mile radius
const LAT = '40.8075';
const LNG = '-73.9626';
const RADIUS = '10';

export async function fetchTicketmasterEvents(): Promise<NormalizedEvent[]> {
  const apiKey = process.env.TICKETMASTER_API_KEY;
  if (!apiKey) {
    console.log('[events/ticketmaster] TICKETMASTER_API_KEY not set — skipping');
    return [];
  }

  const params = new URLSearchParams({
    apikey: apiKey,
    latlong: `${LAT},${LNG}`,
    radius: RADIUS,
    unit: 'miles',
    size: '50',
    sort: 'date,asc',
    countryCode: 'US',
  });

  const url = `https://app.ticketmaster.com/discovery/v2/events.json?${params}`;
  const res = await fetch(url, {
    headers: { 'User-Agent': 'AXIO7-Events-Bot/1.0', Accept: 'application/json' },
    signal: AbortSignal.timeout(20_000),
  });
  if (!res.ok) throw new Error(`Ticketmaster fetch failed: ${res.status}`);
  const data = await res.json() as Record<string, unknown>;
  const embedded = data._embedded as Record<string, unknown> | undefined;
  const rawEvents = Array.isArray(embedded?.events) ? embedded.events as Record<string, unknown>[] : [];

  const normalized: NormalizedEvent[] = [];
  for (const e of rawEvents) {
    const n = normalizeTicketmasterEvent(e);
    if (n) normalized.push(n);
  }
  return normalized;
}
