import Redis from 'ioredis';

export type AuditEntry = {
  ts: string;
  route: string;
  actor: string;
  action: string;
  status: 'ok' | 'blocked' | 'error';
  meta?: Record<string, unknown>;
};

const MAX_IN_MEMORY = 500;

declare global {
  // eslint-disable-next-line no-var
  var __axio7Audit: AuditEntry[] | undefined;
  // eslint-disable-next-line no-var
  var __axio7Redis: Redis | undefined;
}

function memoryLog(): AuditEntry[] {
  if (!globalThis.__axio7Audit) globalThis.__axio7Audit = [];
  return globalThis.__axio7Audit;
}

function redis(): Redis | null {
  const url = process.env.REDIS_URL;
  if (!url) return null;
  if (!globalThis.__axio7Redis) {
    try {
      globalThis.__axio7Redis = new Redis(url, { lazyConnect: true, maxRetriesPerRequest: 1 });
    } catch (err) {
      console.warn('[audit] redis init failed', err);
      return null;
    }
  }
  return globalThis.__axio7Redis || null;
}

export async function recordAudit(entry: Omit<AuditEntry, 'ts'>): Promise<void> {
  const full: AuditEntry = { ts: new Date().toISOString(), ...entry };

  const log = memoryLog();
  log.push(full);
  if (log.length > MAX_IN_MEMORY) log.splice(0, log.length - MAX_IN_MEMORY);

  const r = redis();
  if (r) {
    try {
      await r.connect().catch(() => undefined);
      await r.lpush('axio7:audit', JSON.stringify(full));
      await r.ltrim('axio7:audit', 0, 9999);
    } catch (err) {
      console.warn('[audit] redis lpush failed', err);
    }
  }
}

export async function readRecentAudit(limit = 50): Promise<AuditEntry[]> {
  const r = redis();
  if (r) {
    try {
      await r.connect().catch(() => undefined);
      const items = await r.lrange('axio7:audit', 0, Math.max(0, limit - 1));
      const out: AuditEntry[] = [];
      for (const item of items) {
        try {
          out.push(JSON.parse(item) as AuditEntry);
        } catch {
          /* skip malformed */
        }
      }
      if (out.length) return out;
    } catch (err) {
      console.warn('[audit] redis lrange failed', err);
    }
  }
  return [...memoryLog()].reverse().slice(0, limit);
}
