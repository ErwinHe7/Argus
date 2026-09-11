-- Private D1 binding only; never exposed through a client database API.
CREATE TABLE broker_links (
 owner_id TEXT PRIMARY KEY,
 flow_generation TEXT NOT NULL,
 link_generation TEXT,
 state TEXT NOT NULL CHECK(state IN ('disconnected','connected','reauthorization_required')),
 token_blob TEXT,
 accounts_json TEXT NOT NULL DEFAULT '[]',
 checked_at INTEGER,
 refresh_lock TEXT,
 refresh_started_at INTEGER
);
CREATE TABLE oauth_sessions (
 state_hash TEXT PRIMARY KEY,
 owner_id TEXT NOT NULL,
 flow_generation TEXT NOT NULL,
 binding_hash TEXT NOT NULL,
 verifier_blob TEXT NOT NULL,
 created_at INTEGER NOT NULL,
 expires_at INTEGER NOT NULL,
 used_at INTEGER
);
CREATE INDEX oauth_owner ON oauth_sessions(owner_id);
CREATE TABLE rate_limits (id TEXT PRIMARY KEY, window INTEGER NOT NULL, count INTEGER NOT NULL);
