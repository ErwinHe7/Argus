import { z } from 'zod';
import { shortlistAge, shortlistSchema } from './contract';

const timestamp = z.string().datetime({ offset: true });
const digest = z.string().regex(/^[a-f0-9]{64}$/);
const coverageSchema = z.object({
  state: z.string().max(120), observedSessions: z.number().int().nonnegative(),
  sourceSessions: z.number().int().nonnegative(), validationExcludedPrefixSessions: z.number().int().nonnegative(),
  startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/), endDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  expectedSessions: z.number().int().nonnegative().nullable(),
  invalidDates: z.array(z.string().regex(/^\d{4}-\d{2}-\d{2}$/)).max(20000),
  validationNote: z.string().max(1000), adjustmentPolicy: z.string().max(200),
}).strict();
export const publisherSchema = z.object({
  schemaVersion: z.literal('astra-shortlist-publisher-status.v1'),
  state: z.enum(['waiting', 'paused', 'error', 'stopped']),
  heartbeatAt: timestamp, lastCheckedAt: timestamp.nullable(), publishedAt: timestamp.nullable(),
  inputSha256: digest.nullable(), artifactSha256: digest.nullable(), revision: digest.nullable(),
  lastError: z.object({
    code: z.enum(['source_unavailable', 'source_invalid', 'source_regressed', 'source_future', 'cache_invalid', 'generator_changed', 'publication_failed']),
    message: z.string().min(1).max(500),
  }).strict().nullable(),
  intervalSeconds: z.number().int().min(5).max(3600),
  llmCalls: z.literal(0), executionEnabled: z.literal(false), predictionEnabled: z.literal(false),
}).strict();

/** Presentation/transport contract only. Ranking stays in the Python generator. */
export const publicationSchema = z.object({
  schemaVersion: z.literal('astra-shortlist-publication.v1'),
  shortlist: shortlistSchema.nullable(), publisher: publisherSchema,
}).strict().superRefine((value, context) => {
  const { shortlist, publisher } = value;
  if (shortlist && [...shortlist.stocks, ...shortlist.funds].some(row => !coverageSchema.safeParse(row.coverage).success)) {
    context.addIssue({ code: z.ZodIssueCode.custom, message: 'Only declared coverage metadata can be published' });
  }
  const bound = [publisher.inputSha256, publisher.artifactSha256, publisher.revision, publisher.publishedAt];
  if (shortlist ? bound.some(item => item === null) || publisher.inputSha256 !== shortlist.inputSha256 : bound.some(item => item !== null)) {
    context.addIssue({ code: z.ZodIssueCode.custom, message: 'Publication identity does not match its shortlist' });
  }
  if ((publisher.state === 'error') !== (publisher.lastError !== null)) {
    context.addIssue({ code: z.ZodIssueCode.custom, message: 'Publisher error state is inconsistent' });
  }
  for (const value of [publisher.lastCheckedAt, publisher.publishedAt]) {
    if (value && Date.parse(value) > Date.parse(publisher.heartbeatAt) + 5000) {
      context.addIssue({ code: z.ZodIssueCode.custom, message: 'Publication times are out of order' });
    }
  }
});
export type Publication = z.infer<typeof publicationSchema>;

export function publicationFuture(value: Publication, now = Date.now()): boolean {
  return [value.publisher.heartbeatAt, value.publisher.lastCheckedAt, value.publisher.publishedAt]
    .some(time => time !== null && Date.parse(time) > now + 5000)
    || !!value.shortlist && (shortlistAge(value.shortlist, now) === 'invalid-future'
      || [...value.shortlist.stocks, ...value.shortlist.funds].some(row =>
        [row.sourceRetrievedAt, row.priceObservedAt].some(time => Date.parse(time) > now + 5000)));
}

export function publisherView(value: Publication | null, now = Date.now()) {
  if (!value) return { label: 'Saved shortlist', detail: 'Automatic updates are not connected. The dated list is still available.', active: false };
  const status = value.publisher;
  if (publicationFuture(value, now) || now - Date.parse(status.heartbeatAt) > Math.max(90000, status.intervalSeconds * 3000)) {
    return { label: 'Updates interrupted', detail: 'No recent publisher heartbeat. Previous observations remain dated below.', active: false };
  }
  if (status.state === 'error') return { label: 'Waiting for valid data', detail: 'The latest input could not be published. The previous valid shortlist is retained.', active: false };
  if (status.state === 'paused' || status.state === 'stopped') return { label: status.state === 'paused' ? 'Updates paused' : 'Publisher stopped', detail: 'The last published shortlist is retained with its original date.', active: false };
  return { label: 'Automatic screening is running', detail: 'New validated inputs update this list automatically. Routine screening uses no AI calls.', active: true };
}
