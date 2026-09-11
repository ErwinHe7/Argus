import { z } from 'zod';

const stamp = z.string().datetime({ offset: true }).refine(value => value.endsWith('Z'), 'UTC timestamp required');
const day = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(value => { const date = new Date(`${value}T00:00:00Z`); return Number.isFinite(date.valueOf()) && date.toISOString().slice(0, 10) === value; });
const text = z.string().min(1).max(2000);
const id = z.string().min(1).max(180).regex(/^[a-zA-Z0-9_.:-]+$/);
const url = z.string().url().max(1500).refine(value => { const parsed = new URL(value); return parsed.protocol === 'https:' && !parsed.username && !parsed.password; });
const hash = z.string().regex(/^[a-f0-9]{64}$/);
function easternMidnight(day: string): number {
  for (const offset of ['04', '05']) {
    const candidate = Date.parse(`${day}T00:00:00-${offset}:00`);
    const parts = Object.fromEntries(new Intl.DateTimeFormat('en-US', { timeZone: 'America/New_York', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', hourCycle: 'h23' }).formatToParts(new Date(candidate)).map(part => [part.type, part.value]));
    if (`${parts.year}-${parts.month}-${parts.day}` === day && parts.hour === '00') return candidate;
  }
  return NaN;
}
export const radarSourceSchema = z.object({
  id, title: text, url, mode: z.enum(['automatic', 'manual_verified']), state: z.enum(['success', 'error']),
  lastAttemptAt: stamp, retrievedAt: stamp.nullable(), reviewAfter: stamp.nullable(), contentSha256: hash.nullable(), error: text.nullable(),
}).strict();
export const radarEventSchema = z.object({
  id, kind: z.enum(['macro', 'earnings']), title: text, symbols: z.array(z.string().regex(/^[A-Z0-9.^/-]{1,24}$/)).max(50),
  startDate: day, endDate: day, scheduledAt: stamp.nullable(), timing: z.enum(['exact', 'date_only']),
  sourceId: id, sourceUrl: url, availableAt: stamp, referencePeriod: text.nullable(), summary: text, watchFor: text, limitation: text,
  scenarios: z.array(z.object({ condition: text, implication: text }).strict()).max(10),
}).strict();
export const eventRadarSchema = z.object({
  schemaVersion: z.literal('astra-event-radar.v1'), generatedAt: stamp, reviewAfter: stamp,
  sources: z.array(radarSourceSchema).max(40), events: z.array(radarEventSchema).max(500),
  records: z.array(z.object({ id, sequence: z.number().int().positive(), kind: z.enum(['hypothesis', 'outcome']), eventId: id,
    registeredAt: stamp, statement: text, sourceUrl: url.nullable(), sourceAvailableAt: stamp.nullable(), hypothesisId: id.nullable(),
    previousSha256: hash.nullable(), contentSha256: hash }).strict()).max(1000),
  coverage: z.object({ from: day, through: day, eventCount: z.number().int().nonnegative(), sourceCount: z.number().int().nonnegative(),
    failedSourceCount: z.number().int().nonnegative(), scope: text }).strict(),
  limitations: z.array(text).min(1).max(30), llmCalls: z.literal(0), executionEnabled: z.literal(false), predictionEnabled: z.literal(false),
}).strict().superRefine((value, ctx) => {
  const fail = (message: string) => ctx.addIssue({ code: z.ZodIssueCode.custom, message });
  const sourceIds = new Set(value.sources.map(source => source.id));
  if (sourceIds.size !== value.sources.length || new Set(value.events.map(event => event.id)).size !== value.events.length) fail('Duplicate evidence identity');
  if (value.coverage.eventCount !== value.events.length || value.coverage.sourceCount !== value.sources.length
    || value.coverage.failedSourceCount !== value.sources.filter(source => source.state === 'error').length) fail('Coverage counts differ from records');
  if (value.coverage.from > value.coverage.through) fail('Invalid coverage window');
  const deadlines = value.sources.flatMap(source => source.reviewAfter ? [Date.parse(source.reviewAfter)] : []);
  if (deadlines.length && Date.parse(value.reviewAfter) !== Math.min(...deadlines)) fail('Review deadline must preserve earliest source deadline');
  for (const source of value.sources) {
    if (Date.parse(source.lastAttemptAt) > Date.parse(value.generatedAt) || (source.retrievedAt && Date.parse(source.retrievedAt) > Date.parse(source.lastAttemptAt))) fail('Source chronology invalid');
    if ((source.state === 'success') !== (source.error === null)) fail('Source error state inconsistent');
    if (source.state === 'success' && (!source.retrievedAt || !source.reviewAfter || !source.contentSha256)) fail('Successful source evidence missing');
    if (source.retrievedAt && source.reviewAfter && Date.parse(source.reviewAfter) < Date.parse(source.retrievedAt)) fail('Source deadline precedes verification');
  }
  for (const event of value.events) {
    const source = value.sources.find(item => item.id === event.sourceId);
    if (!source || !source.retrievedAt || Date.parse(event.availableAt) > Date.parse(source.retrievedAt)) fail('Event source unavailable');
    if (event.startDate > event.endDate || event.endDate < value.coverage.from || event.startDate > value.coverage.through) fail('Event outside coverage window');
    if ((event.timing === 'exact') !== (event.scheduledAt !== null)) fail('Event timing inconsistent');
    if (event.scheduledAt) {
      const parts = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/New_York', year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(new Date(event.scheduledAt));
      const part = (key: string) => parts.find(item => item.type === key)?.value;
      const scheduledDay = `${part('year')}-${part('month')}-${part('day')}`;
      if (scheduledDay < event.startDate || scheduledDay > event.endDate) fail('Exact timestamp outside Eastern event date');
    }
  }
  const records = new Map(value.records.map(record => [record.id, record]));
  if (records.size !== value.records.length) fail('Duplicate journal identity');
  const outcomes = new Set<string>();
  for (const [index, record] of value.records.entries()) {
    const event = value.events.find(item => item.id === record.eventId);
    if (!event || record.sequence !== index + 1 || record.previousSha256 !== (value.records[index - 1]?.contentSha256 ?? null)) fail('Journal event, sequence or hash-chain link invalid');
    if (Date.parse(record.registeredAt) > Date.parse(value.generatedAt)) fail('Future journal record');
    if (index > 0 && Date.parse(record.registeredAt) < Date.parse(value.records[index - 1].registeredAt)) fail('Journal registration regressed');
    if (record.kind === 'hypothesis') {
      if (record.hypothesisId || record.sourceUrl || record.sourceAvailableAt) fail('Hypothesis has outcome-only fields');
      if (event) {
        const cutoff = event.scheduledAt ? Date.parse(event.scheduledAt) : easternMidnight(event.startDate);
        if (Date.parse(record.registeredAt) >= cutoff || Date.parse(record.registeredAt) < Date.parse(event.availableAt)) fail('Hypothesis was not registered after evidence and before event');
      }
    } else {
      const hypothesis = record.hypothesisId ? records.get(record.hypothesisId) : undefined;
      if (!hypothesis || hypothesis.kind !== 'hypothesis' || hypothesis.eventId !== record.eventId || hypothesis.sequence >= record.sequence) fail('Outcome lacks earlier same-event hypothesis');
      if (record.hypothesisId && outcomes.has(record.hypothesisId)) fail('Hypothesis has duplicate outcomes');
      if (record.hypothesisId) outcomes.add(record.hypothesisId);
      if (!record.sourceUrl || !record.sourceAvailableAt || Date.parse(record.sourceAvailableAt) > Date.parse(record.registeredAt)) fail('Outcome source unavailable when registered');
      if (event) {
        const cutoff = event.scheduledAt ? Date.parse(event.scheduledAt) : easternMidnight(event.startDate);
        if (record.sourceAvailableAt && Date.parse(record.sourceAvailableAt) < cutoff) fail('Outcome source precedes completed event');
      }
    }
  }
});

export type EventRadar = z.infer<typeof eventRadarSchema>;
export type RadarEvent = z.infer<typeof radarEventSchema>;
export type RadarSource = z.infer<typeof radarSourceSchema>;

export function validateRadar(value: unknown, now = Date.now()): EventRadar {
  const radar = eventRadarSchema.parse(value);
  if (Date.parse(radar.generatedAt) > now + 5000 || radar.sources.some(source => Date.parse(source.lastAttemptAt) > now + 5000
    || (source.retrievedAt && Date.parse(source.retrievedAt) > now + 5000))) throw new Error('Future evidence timestamp');
  return radar;
}

export function assertRadarMonotonic(previous: EventRadar, next: EventRadar): void {
  if (Date.parse(next.generatedAt) < Date.parse(previous.generatedAt)) throw new Error('Radar generation regressed');
  for (const source of previous.sources) {
    const newer = next.sources.find(item => item.id === source.id);
    if (!newer || (source.retrievedAt && (!newer.retrievedAt || Date.parse(newer.retrievedAt) < Date.parse(source.retrievedAt)))
      || Date.parse(newer.lastAttemptAt) < Date.parse(source.lastAttemptAt)) throw new Error('Radar source regressed');
    if (newer.retrievedAt === source.retrievedAt && newer.contentSha256 !== source.contentSha256) throw new Error('Source identity changed without new verification');
  }
  for (const record of previous.records) if (JSON.stringify(next.records.find(item => item.id === record.id)) !== JSON.stringify(record)) throw new Error('Journal record changed');
}

function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value !== null && typeof value === 'object') return `{${Object.entries(value).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0).map(([key, item]) => `${JSON.stringify(key)}:${canonical(item)}`).join(',')}}`;
  return JSON.stringify(value);
}

/** Hash integrity detects local edits; it does not establish a trusted publication time. */
export async function validateRadarIntegrity(value: unknown, now = Date.now()): Promise<EventRadar> {
  const radar = validateRadar(value, now);
  for (const record of radar.records) {
    const { contentSha256, ...fields } = record;
    const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(canonical(fields)));
    const digest = Array.from(new Uint8Array(bytes), byte => byte.toString(16).padStart(2, '0')).join('');
    if (digest !== contentSha256) throw new Error('Journal content hash mismatch');
  }
  return radar;
}
