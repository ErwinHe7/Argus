import type { NormalizedEvent } from '../types';
import { normalizeIcalEvent } from '../normalize';

// Configurable via COLUMBIA_EVENTS_JSON_URLS (comma-separated JSON feed URLs)
// or falls back to the official iCal endpoint.
const COLUMBIA_ICAL_FALLBACK =
  'https://events.columbia.edu/feeder/main/eventsFeed.do?f=y&sort=dtstart.utc:asc&skinName=ical';

function getColumbiaUrls(): string[] {
  const envUrls = process.env.COLUMBIA_EVENTS_JSON_URLS;
  if (envUrls) return envUrls.split(',').map((u) => u.trim()).filter(Boolean);
  return [COLUMBIA_ICAL_FALLBACK];
}

// Minimal iCal parser — avoids a heavy dep, handles Columbia's specific format.
function parseIcal(text: string): Record<string, unknown>[] {
  const events: Record<string, unknown>[] = [];
  let current: Record<string, unknown> | null = null;
  let lastKey = '';

  const lines = text
    .replace(/\r\n /g, '') // unfold
    .replace(/\r\n\t/g, '')
    .split(/\r\n|\n/);

  for (const line of lines) {
    if (line === 'BEGIN:VEVENT') {
      current = {};
      lastKey = '';
    } else if (line === 'END:VEVENT') {
      if (current) events.push(current);
      current = null;
      lastKey = '';
    } else if (current) {
      const semi = line.indexOf(';');
      const colon = line.indexOf(':');
      if (colon === -1) continue;
      const sep = semi !== -1 && semi < colon ? semi : colon;
      const key = line.slice(0, sep).toLowerCase().replace(/;[^:]+/, '');
      const value = line.slice(colon + 1).trim();
      if (key) {
        current[key] = value;
        lastKey = key;
      } else if (lastKey) {
        // continuation line
        current[lastKey] = String(current[lastKey]) + line.trim();
      }
    }
  }
  return events;
}

async function fetchOneUrl(url: string): Promise<NormalizedEvent[]> {
  const res = await fetch(url, {
    headers: { 'User-Agent': 'AXIO7-Events-Bot/1.0' },
    signal: AbortSignal.timeout(15_000),
  });
  if (!res.ok) throw new Error(`Columbia feed fetch failed (${url}): ${res.status}`);
  const text = await res.text();

  // If it looks like JSON, try to parse as a JSON events array
  if (text.trimStart().startsWith('[') || text.trimStart().startsWith('{')) {
    try {
      const json = JSON.parse(text);
      const rows: Record<string, unknown>[] = Array.isArray(json) ? json : json.events ?? json.data ?? [];
      const normalized: NormalizedEvent[] = [];
      for (const row of rows) {
        // Map common JSON fields to iCal shape then normalize
        const vcal: Record<string, unknown> = {
          uid: row.id ?? row.uid ?? row.event_id ?? String(Math.random()),
          summary: row.title ?? row.name ?? row.summary ?? '',
          description: row.description ?? row.summary_text ?? null,
          dtstart: row.start ?? row.starts_at ?? row.start_time ?? row.dtstart ?? null,
          dtend: row.end ?? row.ends_at ?? row.end_time ?? row.dtend ?? null,
          location: row.location ?? row.venue ?? row.address ?? null,
          url: row.url ?? row.link ?? row.rsvp_url ?? null,
        };
        const n = normalizeIcalEvent(vcal);
        if (n) normalized.push(n);
      }
      return normalized;
    } catch {
      // fall through to iCal parser
    }
  }

  // Parse as iCal
  const vevents = parseIcal(text);
  const normalized: NormalizedEvent[] = [];
  for (const v of vevents) {
    const n = normalizeIcalEvent(v);
    if (n) normalized.push(n);
  }
  return normalized;
}

export async function fetchColumbiaEvents(): Promise<NormalizedEvent[]> {
  const urls = getColumbiaUrls();
  const allResults = await Promise.allSettled(urls.map(fetchOneUrl));
  const merged: NormalizedEvent[] = [];
  for (const r of allResults) {
    if (r.status === 'fulfilled') merged.push(...r.value);
    else console.warn('[columbia] feed error:', r.reason);
  }
  return merged;
}
