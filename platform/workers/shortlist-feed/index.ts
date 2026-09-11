import { DurableObject } from 'cloudflare:workers';
import { assertMonotonic, canonicalJson, PublicationError, readPublicationBody, validatePublication } from './validation';

type LatestRow = { singleton: number; envelope: string };
type RevisionRow = { revision: string; shortlist_digest: string; input_digest: string; artifact_digest: string; published_at: string };
type PublishResult = { status: 'accepted' | 'unchanged' } | { status: 'rejected'; code: string; httpStatus: number };

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, '0')).join('');
}

/** One explicitly requested public feed is the atomic coordination scope. */
export class ShortlistFeed extends DurableObject<ShortlistFeedEnv> {
  constructor(ctx: DurableObjectState, env: ShortlistFeedEnv) {
    super(ctx, env);
    this.ctx.storage.transactionSync(() => {
      this.ctx.storage.sql.exec(`CREATE TABLE IF NOT EXISTS latest (
        singleton INTEGER PRIMARY KEY CHECK (singleton = 1), envelope TEXT NOT NULL
      )`);
      this.ctx.storage.sql.exec(`CREATE TABLE IF NOT EXISTS revisions (
        revision TEXT PRIMARY KEY, shortlist_digest TEXT NOT NULL, input_digest TEXT NOT NULL,
        artifact_digest TEXT NOT NULL, published_at TEXT NOT NULL
      )`);
    });
  }

  async publish(payload: string): Promise<PublishResult> {
    try {
      // Revalidate at the RPC boundary. Hashing precedes the synchronous
      // transaction; there is no await between its comparison and writes.
      const publication = validatePublication(payload);
      const envelope = canonicalJson(publication);
      validatePublication(envelope);
      const shortlistDigest = publication.shortlist ? await sha256(canonicalJson(publication.shortlist)) : null;
      return this.ctx.storage.transactionSync((): PublishResult => {
        const current = this.ctx.storage.sql.exec<LatestRow>('SELECT singleton, envelope FROM latest WHERE singleton = 1').toArray()[0];
        if (current?.envelope === envelope) return { status: 'unchanged' };
        if (current) assertMonotonic(validatePublication(current.envelope), publication);
        const publisher = publication.publisher;
        if (publication.shortlist && shortlistDigest && publisher.revision && publisher.inputSha256 && publisher.artifactSha256 && publisher.publishedAt) {
          const previous = this.ctx.storage.sql.exec<RevisionRow>('SELECT * FROM revisions WHERE revision = ?', publisher.revision).toArray()[0];
          if (previous && (previous.shortlist_digest !== shortlistDigest || previous.input_digest !== publisher.inputSha256
            || previous.artifact_digest !== publisher.artifactSha256 || previous.published_at !== publisher.publishedAt)) {
            throw new PublicationError('revision_artifact_conflict', 409);
          }
          this.ctx.storage.sql.exec(`INSERT OR IGNORE INTO revisions
            (revision, shortlist_digest, input_digest, artifact_digest, published_at) VALUES (?, ?, ?, ?, ?)`,
          publisher.revision, shortlistDigest, publisher.inputSha256, publisher.artifactSha256, publisher.publishedAt);
        }
        this.ctx.storage.sql.exec('INSERT INTO latest (singleton, envelope) VALUES (1, ?) ON CONFLICT(singleton) DO UPDATE SET envelope = excluded.envelope', envelope);
        return { status: 'accepted' };
      });
    } catch (error) {
      if (error instanceof PublicationError) return { status: 'rejected', code: error.code, httpStatus: error.status };
      throw error;
    }
  }

  read(): string | null {
    return this.ctx.storage.transactionSync(() => {
      const row = this.ctx.storage.sql.exec<LatestRow>('SELECT singleton, envelope FROM latest WHERE singleton = 1').toArray()[0];
      if (!row) return null;
      validatePublication(row.envelope);
      return row.envelope;
    });
  }
}

function response(body: unknown, status = 200, extra: Record<string, string> = {}): Response {
  return Response.json(body, { status, headers: { 'cache-control': 'no-store', 'x-content-type-options': 'nosniff', ...extra } });
}

async function authorized(request: Request, token: string | undefined): Promise<boolean> {
  if (!token) throw new PublicationError('publisher_auth_unconfigured', 503);
  const authorization = request.headers.get('authorization');
  if (!authorization || authorization.length > 4096 || !/^Bearer [^\s]+$/i.test(authorization)) return false;
  const candidate = authorization.slice(7);
  const [provided, expected] = await Promise.all([
    crypto.subtle.digest('SHA-256', new TextEncoder().encode(candidate)),
    crypto.subtle.digest('SHA-256', new TextEncoder().encode(token)),
  ]);
  return crypto.subtle.timingSafeEqual(provided, expected);
}

export default {
  async fetch(request: Request, env: ShortlistFeedEnv): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname !== '/publication' || url.search) return response({ error: 'not_found' }, 404);
    if (request.method !== 'GET' && request.method !== 'POST') return response({ error: 'method_not_allowed' }, 405, { allow: 'GET, POST' });
    try {
      const feed = env.SHORTLIST_FEED.getByName('public-feed');
      if (request.method === 'GET') {
        const envelope = await feed.read();
        return envelope === null ? response({ error: 'publication_unavailable' }, 503)
          : new Response(envelope, { headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', 'x-content-type-options': 'nosniff' } });
      }
      if (!await authorized(request, env.LEO_SHORTLIST_PUBLISH_TOKEN)) return response({ error: 'unauthorized' }, 401, { 'www-authenticate': 'Bearer' });
      if (request.headers.get('content-type')?.split(';')[0].trim().toLowerCase() !== 'application/json'
        || !['', 'identity'].includes(request.headers.get('content-encoding') ?? '')) return response({ error: 'unsupported_media_type' }, 415);
      const payload = await readPublicationBody(request);
      validatePublication(payload);
      const result = await feed.publish(payload);
      return result.status === 'rejected' ? response({ error: result.code }, result.httpStatus) : response(result);
    } catch (error) {
      // Never echo input, authorization, storage exceptions, or source history.
      return error instanceof PublicationError ? response({ error: error.code }, error.status) : response({ error: 'feed_unavailable' }, 503);
    }
  },
} satisfies ExportedHandler<ShortlistFeedEnv>;
