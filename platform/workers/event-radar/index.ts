import { DurableObject } from 'cloudflare:workers';
import seed from '../../features/research-desk/data/event-radar.json';
import { validateRadar } from '../../features/research-desk/radar/contract';
import { mergeManualSeed, refreshRadar, sha256 } from './collector';

type LatestRow = { artifact: string; refreshing_until: number };

/** One public calendar publication is the atomic coordination scope. */
export class EventRadarFeed extends DurableObject<EventRadarEnv> {
  constructor(ctx: DurableObjectState, env: EventRadarEnv) {
    super(ctx, env);
    this.ctx.storage.transactionSync(() => {
      this.ctx.storage.sql.exec('CREATE TABLE IF NOT EXISTS publication (singleton INTEGER PRIMARY KEY CHECK(singleton = 1), artifact TEXT NOT NULL, refreshing_until INTEGER NOT NULL DEFAULT 0)');
      this.ctx.storage.sql.exec('CREATE TABLE IF NOT EXISTS source_versions (source_id TEXT NOT NULL, content_sha256 TEXT NOT NULL, first_seen TEXT NOT NULL, PRIMARY KEY(source_id, content_sha256))');
      this.ctx.storage.sql.exec('INSERT OR IGNORE INTO publication (singleton, artifact) VALUES (1, ?)', JSON.stringify(validateRadar(seed)));
    });
  }

  read(): string {
    const row = this.ctx.storage.sql.exec<LatestRow>('SELECT artifact, refreshing_until FROM publication WHERE singleton = 1').one();
    validateRadar(JSON.parse(row.artifact));
    return row.artifact;
  }

  async refresh(): Promise<{ status: string; generatedAt?: string; sources?: number; failed?: number; digest?: string }> {
    const now = Date.now();
    const previous = this.ctx.storage.transactionSync(() => {
      const row = this.ctx.storage.sql.exec<LatestRow>('SELECT artifact, refreshing_until FROM publication WHERE singleton = 1').one();
      if (row.refreshing_until > now) return null;
      this.ctx.storage.sql.exec('UPDATE publication SET refreshing_until = ? WHERE singleton = 1', now + 60_000);
      return validateRadar(JSON.parse(row.artifact));
    });
    if (!previous) return { status: 'already_running' };
    try {
      const reviewed = mergeManualSeed(previous, validateRadar(seed), now);
      const next = await refreshRadar(reviewed, now);
      const payload = JSON.stringify(next); const digest = await sha256(payload);
      const accepted = this.ctx.storage.transactionSync(() => {
        const row = this.ctx.storage.sql.exec<LatestRow>('SELECT artifact, refreshing_until FROM publication WHERE singleton = 1').one();
        if (row.refreshing_until !== now + 60_000) return false;
        for (const source of next.sources) if (source.contentSha256 && source.retrievedAt) {
          this.ctx.storage.sql.exec('INSERT OR IGNORE INTO source_versions (source_id, content_sha256, first_seen) VALUES (?, ?, ?)', source.id, source.contentSha256, source.retrievedAt);
        }
        this.ctx.storage.sql.exec('UPDATE publication SET artifact = ?, refreshing_until = 0 WHERE singleton = 1', payload);
        return true;
      });
      return accepted ? { status: 'published', generatedAt: next.generatedAt, sources: next.sources.length, failed: next.coverage.failedSourceCount, digest } : { status: 'superseded' };
    } finally {
      this.ctx.storage.sql.exec('UPDATE publication SET refreshing_until = 0 WHERE singleton = 1 AND refreshing_until = ?', now + 60_000);
    }
  }
}

const headers = { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', 'x-content-type-options': 'nosniff' };
export default {
  async fetch(request: Request, env: EventRadarEnv): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname !== '/radar' || url.search) return Response.json({ error: 'not_found' }, { status: 404, headers });
    if (request.method !== 'GET' && request.method !== 'HEAD') return Response.json({ error: 'read_only' }, { status: 405, headers: { ...headers, allow: 'GET, HEAD' } });
    try {
      const artifact = await env.EVENT_RADAR.getByName('official-calendar').read();
      return new Response(request.method === 'HEAD' ? null : artifact, { headers });
    } catch {
      return new Response(request.method === 'HEAD' ? null : '{"error":"radar_unavailable"}', { status: 503, headers });
    }
  },
  async scheduled(_controller: ScheduledController, env: EventRadarEnv): Promise<void> {
    const result = await env.EVENT_RADAR.getByName('official-calendar').refresh();
    console.log(JSON.stringify({ event: 'calendar_refresh', ...result }));
  },
} satisfies ExportedHandler<EventRadarEnv>;
