PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS application_workspaces (
  owner_hash TEXT PRIMARY KEY,
  profile_json TEXT,
  facts_json TEXT NOT NULL DEFAULT '{"workAuthorizedUS":"","needsSponsorship":"","notes":""}',
  preferences_json TEXT NOT NULL DEFAULT '{"titles":[],"locations":[],"exclude":[],"companies":[]}',
  resume_name TEXT,
  resume_key TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS application_saved_jobs (
  owner_hash TEXT NOT NULL REFERENCES application_workspaces(owner_hash) ON DELETE CASCADE,
  job_key TEXT NOT NULL,
  position INTEGER NOT NULL,
  job_json TEXT NOT NULL,
  PRIMARY KEY (owner_hash, job_key)
);

CREATE TABLE IF NOT EXISTS application_hunts (
  id TEXT PRIMARY KEY,
  owner_hash TEXT NOT NULL REFERENCES application_workspaces(owner_hash) ON DELETE CASCADE,
  submit_mode INTEGER NOT NULL CHECK (submit_mode IN (0, 1)),
  status TEXT NOT NULL CHECK (status IN ('queued', 'running', 'complete', 'stopped', 'errored')),
  authorized_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS application_hunts_owner_created ON application_hunts(owner_hash, created_at DESC);

CREATE TABLE IF NOT EXISTS application_hunt_jobs (
  hunt_id TEXT NOT NULL REFERENCES application_hunts(id) ON DELETE CASCADE,
  owner_hash TEXT NOT NULL REFERENCES application_workspaces(owner_hash) ON DELETE CASCADE,
  job_key TEXT NOT NULL,
  position INTEGER NOT NULL,
  job_json TEXT NOT NULL,
  submit_mode INTEGER NOT NULL CHECK (submit_mode IN (0, 1)),
  status TEXT NOT NULL DEFAULT 'queued',
  submission_attempted INTEGER NOT NULL DEFAULT 0 CHECK (submission_attempted IN (0, 1)),
  blocked INTEGER NOT NULL DEFAULT 1 CHECK (blocked IN (0, 1)),
  result_json TEXT,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (hunt_id, job_key)
);

-- Reserving every real application in the same D1 transaction closes the race
-- between simultaneous requests. Dry runs never reserve a submission.
CREATE UNIQUE INDEX IF NOT EXISTS application_submission_guard
  ON application_hunt_jobs(owner_hash, job_key)
  WHERE submit_mode = 1 AND blocked = 1;
