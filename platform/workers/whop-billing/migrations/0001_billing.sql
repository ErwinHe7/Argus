-- Private Worker binding only; no public database API. Every account query is owner-scoped.
CREATE TABLE checkouts (
  reference TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  whop_id TEXT UNIQUE,
  url TEXT
);
CREATE INDEX checkouts_owner ON checkouts(owner_id, created_at DESC);
CREATE TABLE memberships (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  reference TEXT NOT NULL REFERENCES checkouts(reference),
  status TEXT NOT NULL,
  checked_at INTEGER NOT NULL,
  period_end TEXT,
  cancel_at_period_end INTEGER NOT NULL CHECK (cancel_at_period_end IN (0,1))
);
CREATE INDEX memberships_owner ON memberships(owner_id);
CREATE TABLE events (id TEXT PRIMARY KEY, kind TEXT NOT NULL, received_at INTEGER NOT NULL);
CREATE TABLE rate_limits (id TEXT PRIMARY KEY, window INTEGER NOT NULL, count INTEGER NOT NULL);
