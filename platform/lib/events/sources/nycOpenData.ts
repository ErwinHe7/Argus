import type { NormalizedEvent } from '../types';
import { normalizeNycOpenDataRow } from '../normalize';

// NYC Open Data — Permitted events (public, no API key needed).
const NYC_OPEN_DATA_URL =
  'https://data.cityofnewyork.us/resource/tvpp-9vvx.json?$limit=100&$order=start_date_time+DESC';

export async function fetchNycOpenDataEvents(): Promise<NormalizedEvent[]> {
  const res = await fetch(NYC_OPEN_DATA_URL, {
    headers: { 'User-Agent': 'AXIO7-Events-Bot/1.0', Accept: 'application/json' },
    signal: AbortSignal.timeout(15_000),
  });
  if (!res.ok) throw new Error(`NYC Open Data fetch failed: ${res.status}`);
  const rows = (await res.json()) as Record<string, unknown>[];
  if (!Array.isArray(rows)) throw new Error('Unexpected response shape');

  const now = Date.now();
  const normalized: NormalizedEvent[] = [];
  for (const row of rows) {
    // Skip past events
    try {
      const start = row.start_date_time ?? row.start_date;
      if (start && new Date(String(start)).getTime() < now) continue;
    } catch {}
    const n = normalizeNycOpenDataRow(row);
    if (n) normalized.push(n);
  }
  return normalized;
}
