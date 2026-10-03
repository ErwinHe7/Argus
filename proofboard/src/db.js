import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

const PUBLIC_COLUMNS =
  'slug, name, website, description, currency, mrr, revenue_30d, active_subscriptions, verified_at, refresh_error, created_at';

export function openDatabase(path) {
  if (path !== ':memory:') mkdirSync(dirname(path), { recursive: true });
  const db = new DatabaseSync(path);
  db.exec(`
    CREATE TABLE IF NOT EXISTS startups (
      slug TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      website TEXT NOT NULL,
      hostname TEXT NOT NULL UNIQUE,
      description TEXT NOT NULL DEFAULT '',
      key_sealed TEXT NOT NULL,
      currency TEXT NOT NULL,
      mrr INTEGER NOT NULL,
      revenue_30d INTEGER NOT NULL,
      active_subscriptions INTEGER NOT NULL,
      verified_at TEXT NOT NULL,
      refresh_error TEXT,
      created_at TEXT NOT NULL
    );
  `);

  return {
    hostnameTaken: (hostname) => Boolean(db.prepare('SELECT 1 FROM startups WHERE hostname = ?').get(hostname)),
    slugTaken: (slug) => Boolean(db.prepare('SELECT 1 FROM startups WHERE slug = ?').get(slug)),
    insert(row) {
      db.prepare(
        `INSERT INTO startups (slug, name, website, hostname, description, key_sealed, currency, mrr,
           revenue_30d, active_subscriptions, verified_at, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      ).run(
        row.slug, row.name, row.website, row.hostname, row.description, row.keySealed, row.currency,
        row.mrr, row.revenue30d, row.activeSubscriptions, row.verifiedAt, row.verifiedAt,
      );
    },
    get: (slug) => db.prepare(`SELECT ${PUBLIC_COLUMNS} FROM startups WHERE slug = ?`).get(slug),
    ranked: (verifiedSince) =>
      db
        .prepare(`SELECT ${PUBLIC_COLUMNS} FROM startups WHERE verified_at >= ? ORDER BY mrr DESC, revenue_30d DESC`)
        .all(verifiedSince),
    sealedKeys: () => db.prepare('SELECT slug, key_sealed FROM startups').all(),
    updateMetrics(slug, m, verifiedAt) {
      db.prepare(
        `UPDATE startups SET currency = ?, mrr = ?, revenue_30d = ?, active_subscriptions = ?,
           verified_at = ?, refresh_error = NULL WHERE slug = ?`,
      ).run(m.currency, m.mrr, m.revenue30d, m.activeSubscriptions, verifiedAt, slug);
    },
    markRefreshError: (slug, message) =>
      db.prepare('UPDATE startups SET refresh_error = ? WHERE slug = ?').run(message, slug),
    close: () => db.close(),
  };
}
