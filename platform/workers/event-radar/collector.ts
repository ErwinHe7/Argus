import { assertRadarMonotonic, validateRadar, type EventRadar, type RadarEvent, type RadarSource } from '../../features/research-desk/radar/contract';

export const MAX_SOURCE_BYTES = 1024 * 1024;
export const sources = [
  { id: 'fed-fomc', title: 'Federal Reserve FOMC calendar', url: 'https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm' },
  { id: 'bls-calendar', title: 'Bureau of Labor Statistics release calendar', url: 'https://www.bls.gov/schedule/news_release/bls.ics' },
] as const;

export async function readBounded(response: Response): Promise<string> {
  if (Number(response.headers.get('content-length')) > MAX_SOURCE_BYTES) { await response.body?.cancel(); throw new Error('source_too_large'); }
  if (!response.body) throw new Error('source_empty');
  const reader = response.body.getReader(); const chunks: Uint8Array[] = []; let length = 0;
  try {
    for (;;) { const { done, value } = await reader.read(); if (done) break;
      length += value.byteLength; if (length > MAX_SOURCE_BYTES) throw new Error('source_too_large'); chunks.push(value); }
  } catch (error) { await reader.cancel().catch(() => undefined); throw error; } finally { reader.releaseLock(); }
  const bytes = new Uint8Array(length); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  return new TextDecoder('utf-8', { fatal: true, ignoreBOM: false }).decode(bytes);
}

export async function sha256(value: string): Promise<string> {
  return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value))), byte => byte.toString(16).padStart(2, '0')).join('');
}
const plain = (value: string) => value.replace(/<[^>]*>/g, '').replace(/&nbsp;|&#160;/g, ' ').replace(/&amp;/g, '&').trim();
const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const isoDay = (year: number, month: number, day: number) => {
  const value = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
  const date = new Date(`${value}T00:00:00Z`);
  if (!Number.isFinite(date.valueOf()) || date.toISOString().slice(0, 10) !== value) throw new Error('source_invalid_date');
  return value;
};

/** A deployment is the only operator publication channel for reviewed issuer dates. */
export function mergeManualSeed(previous: EventRadar, bundled: EventRadar, now = Date.now()): EventRadar {
  validateRadar(bundled, now);
  if (bundled.records.length !== 0) throw new Error('Hosted journal requires separate trusted timestamp anchoring');
  const next = structuredClone(previous);
  let changed = false;
  for (const source of bundled.sources) {
    if (source.mode !== 'manual_verified' || source.state !== 'success' || !source.retrievedAt) continue;
    const existing = next.sources.find(item => item.id === source.id);
    if (existing && (existing.mode !== 'manual_verified' || (existing.retrievedAt && Date.parse(source.retrievedAt) <= Date.parse(existing.retrievedAt)))) continue;
    const incoming = bundled.events.filter(event => event.sourceId === source.id);
    if (next.records.some(record => next.events.some(event => event.id === record.eventId && event.sourceId === source.id))) throw new Error('Reviewed source update would rewrite journal evidence');
    const otherIds = new Set(next.events.filter(event => event.sourceId !== source.id).map(event => event.id));
    if (incoming.some(event => otherIds.has(event.id))) throw new Error('Reviewed source update conflicts with another source event');
    next.sources = [...next.sources.filter(item => item.id !== source.id), source];
    next.events = [...next.events.filter(event => event.sourceId !== source.id), ...incoming];
    changed = true;
  }
  if (!changed) return previous;
  next.generatedAt = new Date(Math.max(now, Date.parse(previous.generatedAt), Date.parse(bundled.generatedAt))).toISOString();
  next.reviewAfter = next.sources.flatMap(source => source.reviewAfter ? [source.reviewAfter] : []).sort()[0] ?? next.generatedAt;
  const dates = next.events.flatMap(event => [event.startDate, event.endDate]).sort();
  next.coverage = { ...next.coverage, from: dates[0] ?? next.coverage.from, through: dates.at(-1) ?? next.coverage.through,
    eventCount: next.events.length, sourceCount: next.sources.length, failedSourceCount: next.sources.filter(source => source.state === 'error').length };
  validateRadar(next, now); assertRadarMonotonic(previous, next); return next;
}

export function parseFed(html: string, availableAt: string, year: number): RadarEvent[] {
  const heading = new RegExp(`${year} FOMC Meetings<\\/a><\\/h4>`).exec(html);
  if (!heading) throw new Error('source_layout_changed');
  const section = html.slice(heading.index + heading[0].length).split(/<div class="panel-heading"/)[0];
  const pattern = /class="[^"]*fomc-meeting__month[^"]*">([\s\S]*?)<\/div>[\s\S]*?class="[^"]*fomc-meeting__date[^"]*">([\s\S]*?)<\/div>/g;
  const events: RadarEvent[] = [];
  for (const match of section.matchAll(pattern)) {
    const monthText = plain(match[1]); const dates = plain(match[2]).replace(/\*/g, '');
    const monthNames = monthText.split('/');
    const range = /^(\d{1,2})(?:-(\d{1,2}))?$/.exec(dates);
    if (!range || monthNames.some(month => !months.includes(month))) throw new Error('source_layout_changed');
    const startDate = isoDay(year, months.indexOf(monthNames[0]) + 1, Number(range[1]));
    const endDate = isoDay(year, months.indexOf(monthNames.at(-1)!) + 1, Number(range[2] ?? range[1]));
    events.push({ id: `fed-fomc-${endDate}`, kind: 'macro', title: 'FOMC meeting', symbols: [], startDate, endDate,
      scheduledAt: null, timing: 'date_only', sourceId: sources[0].id, sourceUrl: sources[0].url, availableAt, referencePeriod: null,
      summary: 'Scheduled Federal Open Market Committee meeting.', watchFor: 'Read the published policy statement, projections when issued, and press conference.',
      limitation: 'Meeting dates do not verify a decision hour or predict the policy decision or market direction.', scenarios: [] });
  }
  if (events.length !== 8 || new Set(events.map(event => event.id)).size !== events.length) throw new Error('source_layout_changed');
  return events;
}

function easternInstant(date: string, hour: number, minute: number): string {
  // Calendar conversion only. Check the result in the named IANA zone, including DST.
  for (const offset of [4, 5]) {
    const candidate = new Date(Date.parse(`${date}T00:00:00Z`) + (hour + offset) * 3600_000 + minute * 60_000);
    const parts = Object.fromEntries(new Intl.DateTimeFormat('en-US', { timeZone: 'America/New_York', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).formatToParts(candidate).map(part => [part.type, part.value]));
    if (`${parts.year}-${parts.month}-${parts.day}` === date && Number(parts.hour) === hour && Number(parts.minute) === minute) return candidate.toISOString();
  }
  throw new Error('source_invalid_time');
}

export function parseBls(ics: string, availableAt: string): RadarEvent[] {
  if (!ics.startsWith('BEGIN:VCALENDAR')) throw new Error('source_layout_changed');
  const events: RadarEvent[] = [];
  for (const block of ics.replace(/\r?\n[ \t]/g, '').split('BEGIN:VEVENT').slice(1)) {
    const summary = /^SUMMARY:(.+)$/m.exec(block)?.[1].trim();
    if (!summary || !/Consumer Price Index|Producer Price Index|Employment Situation|Job Openings and Labor Turnover/i.test(summary)) continue;
    const start = /^DTSTART(?:;TZID=(America\/New_York|US\/Eastern|US-Eastern))?:(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z)?\r?$/m.exec(block);
    if (!start || (!start[1] && !start[8])) throw new Error('source_timezone_missing');
    const date = isoDay(Number(start[2]), Number(start[3]), Number(start[4]));
    const at = start[8] ? `${date}T${start[5]}:${start[6]}:${start[7]}Z` : easternInstant(date, Number(start[5]), Number(start[6]));
    const title = summary.replace(/\\[,;]/g, char => char.slice(1)).slice(0, 300);
    const slug = /Consumer Price Index/i.test(title) ? 'cpi' : /Producer Price Index/i.test(title) ? 'ppi' : /Employment Situation/i.test(title) ? 'jobs' : 'jolts';
    events.push({ id: `bls-${slug}-${date}`, kind: 'macro', title, symbols: [], startDate: date, endDate: date,
      scheduledAt: at, timing: 'exact', sourceId: sources[1].id, sourceUrl: sources[1].url, availableAt, referencePeriod: null,
      summary: 'Scheduled official U.S. economic release.', watchFor: 'Read the published result, revisions, and methodology before assessing a market reaction.',
      limitation: 'The schedule provides no consensus forecast, release result, or directional trading edge.', scenarios: [] });
  }
  if (events.length < 4 || events.length > 500 || new Set(events.map(event => event.id)).size !== events.length) throw new Error('source_layout_changed');
  return events;
}

export async function refreshRadar(previous: EventRadar, now = Date.now(), fetcher: typeof fetch = fetch): Promise<EventRadar> {
  const attemptedAt = new Date(now).toISOString();
  const updates = await Promise.all(sources.map(async definition => {
    const old = previous.sources.find(source => source.id === definition.id);
    try {
      const response = await fetcher(definition.url, { redirect: 'manual', signal: AbortSignal.timeout(12_000), headers: { 'User-Agent': 'LeoEventRadar/1.0', Accept: definition.id === 'fed-fomc' ? 'text/html' : 'text/calendar' } });
      if (!response.ok) { await response.body?.cancel(); throw new Error(`source_http_${response.status}`); }
      const content = await readBounded(response); const digest = await sha256(content);
      const observedAt = new Date(Math.max(now, Date.now())).toISOString();
      const events = definition.id === 'fed-fomc' ? parseFed(content, observedAt, new Date(now).getUTCFullYear()) : parseBls(content, observedAt);
      const source: RadarSource = { ...definition, mode: 'automatic', state: 'success', lastAttemptAt: observedAt, retrievedAt: observedAt,
        reviewAfter: new Date(Date.parse(observedAt) + 24 * 3600_000).toISOString(), contentSha256: digest, error: null };
      for (const event of events) {
        const prior = previous.events.find(item => item.id === event.id && item.sourceId === event.sourceId);
        if (prior && JSON.stringify({ ...prior, availableAt: '' }) === JSON.stringify({ ...event, availableAt: '' })) event.availableAt = prior.availableAt;
      }
      return { source, events };
    } catch (error) {
      const code = error instanceof Error && /^source_[a-z0-9_]+$/.test(error.message) ? error.message : 'source_fetch_failed';
      const source: RadarSource = { ...definition, mode: 'automatic', state: 'error', lastAttemptAt: new Date(Math.max(now, Date.now())).toISOString(),
        retrievedAt: old?.retrievedAt ?? null, reviewAfter: old?.reviewAfter ?? null, contentSha256: old?.contentSha256 ?? null,
        error: `Official calendar refresh failed (${code}); previous observations are retained.` };
      return { source, events: previous.events.filter(event => event.sourceId === definition.id) };
    }
  }));
  const automaticIds = new Set(sources.map(source => source.id));
  const nextSources = [...previous.sources.filter(source => !automaticIds.has(source.id as typeof sources[number]['id'])), ...updates.map(update => update.source)];
  const from = new Date(now - 7 * 86400_000).toISOString().slice(0, 10);
  const through = new Date(now + 120 * 86400_000).toISOString().slice(0, 10);
  const eventMap = new Map(previous.events.filter(event => !automaticIds.has(event.sourceId as typeof sources[number]['id'])).map(event => [event.id, event]));
  for (const event of updates.flatMap(update => update.events)) {
    const precise = eventMap.get(event.id);
    // A verified decision hour remains attached to its manual source. Confirming
    // only a matching meeting date range cannot renew or invent that hour.
    if (event.sourceId === 'fed-fomc' && precise?.timing === 'exact' && precise.startDate === event.startDate && precise.endDate === event.endDate) continue;
    eventMap.set(event.id, event);
  }
  const events = [...eventMap.values()].filter(event => event.endDate >= from && event.startDate <= through)
    .sort((a, b) => a.startDate.localeCompare(b.startDate) || a.id.localeCompare(b.id));
  const generatedAt = new Date(Math.max(now, Date.now())).toISOString();
  const deadlines = nextSources.map(source => source.reviewAfter).filter((value): value is string => value !== null).sort();
  const next: EventRadar = { ...previous, generatedAt, reviewAfter: deadlines[0] ?? attemptedAt, sources: nextSources, events,
    coverage: { from, through, eventCount: events.length, sourceCount: nextSources.length, failedSourceCount: nextSources.filter(source => source.state === 'error').length,
      scope: 'Official FOMC and selected BLS release calendars, plus explicitly labeled manually verified company events. This is not a complete market calendar.' } };
  validateRadar(next); assertRadarMonotonic(previous, next); return next;
}
