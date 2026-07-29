PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS data_manifests (
  manifest_id TEXT PRIMARY KEY,
  created_at INTEGER NOT NULL,
  source TEXT NOT NULL,
  scope TEXT NOT NULL CHECK(scope IN ('CONSOLIDATED','NASDAQ_BBO','NASDAQ_DEPTH','INDICATIVE','SYNTHETIC')),
  schema_version TEXT NOT NULL,
  content_sha256 TEXT NOT NULL,
  first_timestamp INTEGER,
  last_timestamp INTEGER,
  row_count INTEGER NOT NULL,
  rejected_count INTEGER NOT NULL DEFAULT 0,
  symbols_json TEXT NOT NULL
) STRICT;

CREATE TABLE IF NOT EXISTS event_log (
  event_id TEXT PRIMARY KEY,
  sequence INTEGER NOT NULL,
  event_time INTEGER NOT NULL,
  available_time INTEGER NOT NULL,
  event_type TEXT NOT NULL,
  source TEXT NOT NULL,
  source_scope TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  lineage_hash TEXT NOT NULL UNIQUE
) STRICT;
CREATE INDEX IF NOT EXISTS idx_event_log_time ON event_log(available_time, sequence);

CREATE TABLE IF NOT EXISTS feature_snapshots (
  snapshot_id TEXT PRIMARY KEY,
  event_time INTEGER NOT NULL,
  symbol TEXT NOT NULL,
  feature_set_hash TEXT NOT NULL,
  values_json TEXT NOT NULL,
  warm INTEGER NOT NULL CHECK(warm IN (0,1)),
  lineage_hash TEXT NOT NULL UNIQUE
) STRICT;

CREATE TABLE IF NOT EXISTS experiments (
  experiment_id TEXT PRIMARY KEY,
  created_at INTEGER NOT NULL,
  hypothesis_id TEXT NOT NULL,
  data_manifest_hash TEXT NOT NULL,
  feature_set_hash TEXT NOT NULL,
  model_type TEXT NOT NULL,
  hyperparameters_json TEXT NOT NULL,
  train_range TEXT NOT NULL,
  validation_range TEXT NOT NULL,
  test_range TEXT NOT NULL,
  label_definition TEXT NOT NULL,
  cost_model_json TEXT NOT NULL,
  random_seed INTEGER NOT NULL,
  inspected INTEGER NOT NULL DEFAULT 0 CHECK(inspected IN (0,1)),
  result_json TEXT,
  promotion_decision TEXT NOT NULL DEFAULT 'CANDIDATE'
) STRICT;

CREATE TABLE IF NOT EXISTS model_registry (
  model_version_id TEXT PRIMARY KEY,
  created_at INTEGER NOT NULL,
  experiment_id TEXT NOT NULL REFERENCES experiments(experiment_id),
  model_hash TEXT NOT NULL UNIQUE,
  calibration_hash TEXT,
  diagnostics_json TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('CANDIDATE','VALIDATED','REJECTED','PAPER','PROMOTED','RETIRED'))
) STRICT;

CREATE TABLE IF NOT EXISTS predictions (
  prediction_id TEXT PRIMARY KEY,
  created_at INTEGER NOT NULL,
  signal_time INTEGER NOT NULL,
  model_version_id TEXT NOT NULL REFERENCES model_registry(model_version_id),
  horizon_minutes INTEGER NOT NULL,
  distribution_json TEXT NOT NULL,
  expected_net_value REAL NOT NULL,
  lower_confidence_bound REAL NOT NULL,
  decision TEXT NOT NULL CHECK(decision IN ('NO_TRADE','LONG','SHORT')),
  lineage_hash TEXT NOT NULL UNIQUE
) STRICT;

CREATE TABLE IF NOT EXISTS risk_decisions (
  risk_decision_id TEXT PRIMARY KEY,
  created_at INTEGER NOT NULL,
  prediction_id TEXT REFERENCES predictions(prediction_id),
  approved INTEGER NOT NULL CHECK(approved IN (0,1)),
  reasons_json TEXT NOT NULL,
  audit_hash TEXT NOT NULL UNIQUE
) STRICT;

CREATE TABLE IF NOT EXISTS orders (
  order_id TEXT PRIMARY KEY,
  idempotency_key TEXT NOT NULL UNIQUE,
  created_at INTEGER NOT NULL,
  signal_time INTEGER NOT NULL,
  submitted_time INTEGER,
  symbol TEXT NOT NULL,
  side TEXT NOT NULL CHECK(side IN ('LONG','SHORT')),
  quantity REAL NOT NULL CHECK(quantity > 0),
  state TEXT NOT NULL,
  risk_decision_id TEXT NOT NULL REFERENCES risk_decisions(risk_decision_id),
  audit_hash TEXT NOT NULL UNIQUE
) STRICT;

CREATE TABLE IF NOT EXISTS fills (
  fill_id TEXT PRIMARY KEY,
  order_id TEXT NOT NULL REFERENCES orders(order_id),
  fill_time INTEGER NOT NULL,
  quantity REAL NOT NULL CHECK(quantity > 0),
  price REAL NOT NULL CHECK(price > 0),
  fee REAL NOT NULL CHECK(fee >= 0),
  slippage REAL NOT NULL CHECK(slippage >= 0),
  source_quote_id TEXT,
  audit_hash TEXT NOT NULL UNIQUE
) STRICT;

CREATE TABLE IF NOT EXISTS ledger_transactions (
  transaction_id TEXT PRIMARY KEY,
  event_time INTEGER NOT NULL,
  event_type TEXT NOT NULL,
  source_id TEXT NOT NULL UNIQUE,
  correction_of TEXT REFERENCES ledger_transactions(transaction_id),
  content_hash TEXT NOT NULL UNIQUE
) STRICT;

CREATE TABLE IF NOT EXISTS ledger_entries (
  entry_id TEXT PRIMARY KEY,
  transaction_id TEXT NOT NULL REFERENCES ledger_transactions(transaction_id),
  account TEXT NOT NULL CHECK(account IN
    ('Cash','Position','RealizedPnL','UnrealizedPnL','Fees','Slippage','Commission','Margin','Adjustment')),
  debit REAL NOT NULL DEFAULT 0 CHECK(debit >= 0),
  credit REAL NOT NULL DEFAULT 0 CHECK(credit >= 0),
  currency TEXT NOT NULL DEFAULT 'USD',
  memo TEXT NOT NULL DEFAULT '',
  CHECK((debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0))
) STRICT;
CREATE INDEX IF NOT EXISTS idx_ledger_entries_transaction ON ledger_entries(transaction_id);

CREATE VIEW IF NOT EXISTS ledger_trial_balance AS
SELECT account, currency, SUM(debit) AS debit, SUM(credit) AS credit,
       SUM(debit-credit) AS balance
FROM ledger_entries GROUP BY account, currency;

CREATE VIEW IF NOT EXISTS unbalanced_transactions AS
SELECT transaction_id, SUM(debit) AS debit, SUM(credit) AS credit
FROM ledger_entries GROUP BY transaction_id
HAVING ABS(SUM(debit)-SUM(credit)) > 0.000001;

CREATE TRIGGER IF NOT EXISTS no_update_event_log BEFORE UPDATE ON event_log
BEGIN SELECT RAISE(ABORT, 'event_log is append-only'); END;
CREATE TRIGGER IF NOT EXISTS no_delete_event_log BEFORE DELETE ON event_log
BEGIN SELECT RAISE(ABORT, 'event_log is append-only'); END;
CREATE TRIGGER IF NOT EXISTS no_update_ledger_transactions BEFORE UPDATE ON ledger_transactions
BEGIN SELECT RAISE(ABORT, 'ledger_transactions is append-only; post a correcting entry'); END;
CREATE TRIGGER IF NOT EXISTS no_delete_ledger_transactions BEFORE DELETE ON ledger_transactions
BEGIN SELECT RAISE(ABORT, 'ledger_transactions is append-only'); END;
CREATE TRIGGER IF NOT EXISTS no_update_ledger_entries BEFORE UPDATE ON ledger_entries
BEGIN SELECT RAISE(ABORT, 'ledger_entries is append-only; post a correcting entry'); END;
CREATE TRIGGER IF NOT EXISTS no_delete_ledger_entries BEFORE DELETE ON ledger_entries
BEGIN SELECT RAISE(ABORT, 'ledger_entries is append-only'); END;
