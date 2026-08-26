BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE SCHEMA IF NOT EXISTS ritual_private;

CREATE TABLE IF NOT EXISTS ritual_private.schema_contract_versions (
  version text PRIMARY KEY,
  compatibility text NOT NULL CHECK (compatibility IN ('n-1', 'n')),
  installed_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO ritual_private.schema_contract_versions(version, compatibility)
VALUES ('ritual-foundation-v1-n-1', 'n-1'), ('ritual-foundation-v1-n', 'n')
ON CONFLICT (version) DO NOTHING;

CREATE TABLE IF NOT EXISTS tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  status text NOT NULL DEFAULT 'provisioning' CHECK (status IN ('provisioning','active','suspended','deletion_pending','purging','purged')),
  seed_version integer NOT NULL DEFAULT 1 CHECK (seed_version > 0),
  deletion_scheduled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL UNIQUE REFERENCES tenants(id) ON DELETE CASCADE,
  auth0_subject text NOT NULL UNIQUE CHECK (char_length(auth0_subject) BETWEEN 1 AND 255),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','suspended','deletion_pending','purged')),
  revocation_epoch integer NOT NULL DEFAULT 0 CHECK (revocation_epoch >= 0), last_seen_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS profiles (
  tenant_id uuid PRIMARY KEY REFERENCES tenants(id) ON DELETE CASCADE, display_name text NOT NULL CHECK (char_length(display_name) BETWEEN 1 AND 80),
  avatar_media_id uuid, locale text NOT NULL DEFAULT 'en-US' CHECK (char_length(locale) <= 35)
);
CREATE TABLE IF NOT EXISTS preferences (
  tenant_id uuid PRIMARY KEY REFERENCES tenants(id) ON DELETE CASCADE, theme_mode text NOT NULL DEFAULT 'system' CHECK (theme_mode IN ('system','light','dark')),
  ritual_mode text NOT NULL DEFAULT 'tarot' CHECK (ritual_mode IN ('tarot','astrology')), timezone text NOT NULL DEFAULT 'UTC' CHECK (char_length(timezone) BETWEEN 1 AND 64),
  locale text NOT NULL DEFAULT 'en-US', version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);
CREATE TABLE IF NOT EXISTS astrology_profiles (
  tenant_id uuid PRIMARY KEY REFERENCES tenants(id) ON DELETE CASCADE, birth_date date NOT NULL, derived_profile_code text NOT NULL CHECK (char_length(derived_profile_code) <= 64),
  algorithm_version text NOT NULL CHECK (char_length(algorithm_version) <= 32), enabled_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS investor_profiles (
  tenant_id uuid PRIMARY KEY REFERENCES tenants(id) ON DELETE CASCADE, goal_type text NOT NULL, time_horizon text NOT NULL, risk_comfort text NOT NULL,
  version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);
CREATE TABLE IF NOT EXISTS onboarding_states (
  tenant_id uuid PRIMARY KEY REFERENCES tenants(id) ON DELETE CASCADE, current_step text NOT NULL, completed_steps jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(completed_steps) = 'array'),
  completed_at timestamptz, version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);
CREATE TABLE IF NOT EXISTS consent_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, policy_code text NOT NULL, policy_version text NOT NULL,
  decision text NOT NULL CHECK (decision IN ('accepted','declined','withdrawn')), recorded_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, policy_code, policy_version, recorded_at), UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS device_installations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, platform text NOT NULL CHECK (platform IN ('ios','android','web')),
  push_token_ciphertext text NOT NULL, push_token_hash text NOT NULL, status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','revoked')),
  last_seen_at timestamptz, UNIQUE (tenant_id, id), UNIQUE (tenant_id, push_token_hash)
);
CREATE TABLE IF NOT EXISTS notification_preferences (
  tenant_id uuid PRIMARY KEY REFERENCES tenants(id) ON DELETE CASCADE, daily_ritual boolean NOT NULL DEFAULT true, weekly_recap boolean NOT NULL DEFAULT true,
  moon_cycle boolean NOT NULL DEFAULT true, quiet_hours jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(quiet_hours) = 'object'), version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE IF NOT EXISTS staff_principals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), auth0_subject text NOT NULL UNIQUE, access_identity text NOT NULL, allowed_client_id text NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','disabled')), revocation_epoch integer NOT NULL DEFAULT 0 CHECK (revocation_epoch >= 0),
  display_label text NOT NULL, last_verified_at timestamptz
);
CREATE TABLE IF NOT EXISTS media_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), r2_key text NOT NULL UNIQUE, mime_type text NOT NULL CHECK (mime_type IN ('image/jpeg','image/png','image/webp')),
  byte_size bigint NOT NULL CHECK (byte_size > 0), checksum text NOT NULL, width integer CHECK (width > 0), height integer CHECK (height > 0),
  quarantine_status text NOT NULL CHECK (quarantine_status IN ('pending','clear','rejected')), scan_result text, status text NOT NULL CHECK (status IN ('uploading','active','retired'))
);
CREATE TABLE IF NOT EXISTS editorial_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), kind text NOT NULL CHECK (kind IN ('ritual','asset_codex','coven','grimoire','circle_template','rowan','briefing_template')),
  slug text NOT NULL UNIQUE CHECK (slug = lower(slug) AND slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'), current_published_revision_id uuid,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','withdrawn','retired'))
);
CREATE TABLE IF NOT EXISTS editorial_revisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), item_id uuid NOT NULL REFERENCES editorial_items(id), revision_number integer NOT NULL CHECK (revision_number > 0),
  state text NOT NULL CHECK (state IN ('draft','submitted','approved','rejected','published','withdrawn')), author_staff_id uuid NOT NULL REFERENCES staff_principals(id),
  content_hash text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (item_id, revision_number)
);
ALTER TABLE editorial_items ADD CONSTRAINT editorial_items_current_revision_fk FOREIGN KEY (current_published_revision_id) REFERENCES editorial_revisions(id) DEFERRABLE INITIALLY DEFERRED;
CREATE TABLE IF NOT EXISTS editorial_review_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), revision_id uuid NOT NULL REFERENCES editorial_revisions(id), requested_by uuid NOT NULL REFERENCES staff_principals(id),
  requested_at timestamptz NOT NULL DEFAULT now(), high_trust boolean NOT NULL DEFAULT false, status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed'))
);
CREATE UNIQUE INDEX IF NOT EXISTS editorial_review_requests_open_unique ON editorial_review_requests(revision_id) WHERE status = 'open';
CREATE TABLE IF NOT EXISTS editorial_review_decisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), request_id uuid NOT NULL REFERENCES editorial_review_requests(id), reviewer_id uuid NOT NULL REFERENCES staff_principals(id),
  decision text NOT NULL CHECK (decision IN ('approved','changes_requested','rejected')), reason text NOT NULL, decided_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS publication_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), item_id uuid NOT NULL REFERENCES editorial_items(id), revision_id uuid NOT NULL REFERENCES editorial_revisions(id),
  action text NOT NULL CHECK (action IN ('publish','schedule','withdraw','supersede')), effective_at timestamptz NOT NULL, actor_id uuid NOT NULL REFERENCES staff_principals(id), reason text NOT NULL
);
CREATE TABLE IF NOT EXISTS assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text NOT NULL UNIQUE CHECK (slug = lower(slug)), symbol text NOT NULL, name text NOT NULL,
  asset_type text NOT NULL CHECK (asset_type IN ('equity','etf','index','cash')), currency text NOT NULL CHECK (currency ~ '^[A-Z]{3}$'), exchange text,
  is_demo boolean NOT NULL DEFAULT true, status text NOT NULL CHECK (status IN ('active','inactive')), UNIQUE (symbol, exchange)
);
CREATE TABLE IF NOT EXISTS asset_metric_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), asset_id uuid NOT NULL REFERENCES assets(id), observed_at timestamptz NOT NULL, price_minor bigint NOT NULL CHECK (price_minor >= 0),
  change_bps integer, expense_ratio_bps integer CHECK (expense_ratio_bps IS NULL OR expense_ratio_bps >= 0), source_label text NOT NULL, is_demo boolean NOT NULL DEFAULT true,
  UNIQUE (asset_id, observed_at, source_label)
);
CREATE TABLE IF NOT EXISTS evidence_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), canonical_url text NOT NULL UNIQUE CHECK (canonical_url ~ '^https://'), title text NOT NULL, publisher text NOT NULL,
  published_at timestamptz, retrieved_at timestamptz NOT NULL, source_kind text NOT NULL, status text NOT NULL CHECK (status IN ('active','retired'))
);
CREATE TABLE IF NOT EXISTS evidence_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), source_id uuid NOT NULL REFERENCES evidence_sources(id), claim_type text NOT NULL, summary text NOT NULL,
  observed_at timestamptz, uncertainty text NOT NULL, status text NOT NULL CHECK (status IN ('active','superseded','withdrawn'))
);

CREATE TABLE IF NOT EXISTS ritual_scenarios (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), editorial_item_id uuid NOT NULL UNIQUE REFERENCES editorial_items(id), scenario_key text NOT NULL UNIQUE,
  mode text NOT NULL CHECK (mode IN ('tarot','astrology')), cadence text NOT NULL
);
CREATE TABLE IF NOT EXISTS ritual_scenario_revisions (
  revision_id uuid PRIMARY KEY REFERENCES editorial_revisions(id), title text NOT NULL, interpretation text NOT NULL, guidance text NOT NULL, market_label text NOT NULL,
  art_media_id uuid REFERENCES media_assets(id), observation_at timestamptz NOT NULL, uncertainty text NOT NULL
);
CREATE TABLE IF NOT EXISTS ritual_scenario_ideas (
  revision_id uuid NOT NULL REFERENCES ritual_scenario_revisions(revision_id), asset_id uuid NOT NULL REFERENCES assets(id), ordinal integer NOT NULL CHECK (ordinal BETWEEN 1 AND 5),
  appearance_reason text NOT NULL, risk_summary text NOT NULL, PRIMARY KEY (revision_id, asset_id), UNIQUE (revision_id, ordinal)
);
CREATE TABLE IF NOT EXISTS ritual_scenario_evidence (
  revision_id uuid NOT NULL REFERENCES ritual_scenario_revisions(revision_id), claim_id uuid NOT NULL REFERENCES evidence_claims(id), ordinal integer NOT NULL CHECK (ordinal > 0),
  factor_label text NOT NULL, PRIMARY KEY (revision_id, claim_id), UNIQUE (revision_id, ordinal)
);
CREATE TABLE IF NOT EXISTS ritual_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), local_date date NOT NULL, mode text NOT NULL CHECK (mode IN ('tarot','astrology')), revision_id uuid NOT NULL REFERENCES editorial_revisions(id),
  audience text NOT NULL CHECK (audience IN ('public','member')), state text NOT NULL CHECK (state IN ('draft','scheduled','active','withdrawn')), effective_at timestamptz NOT NULL,
  UNIQUE (local_date, mode, audience)
);
CREATE TABLE IF NOT EXISTS rowan_scripts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), editorial_item_id uuid NOT NULL UNIQUE REFERENCES editorial_items(id), script_key text NOT NULL UNIQUE, surface text NOT NULL
);
CREATE TABLE IF NOT EXISTS rowan_script_revisions (
  revision_id uuid PRIMARY KEY REFERENCES editorial_revisions(id), body_template text NOT NULL, allowed_tokens jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(allowed_tokens) = 'array'), risk_footer text NOT NULL
);
CREATE TABLE IF NOT EXISTS rowan_context_bindings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), surface text NOT NULL, context_key text NOT NULL, script_id uuid NOT NULL REFERENCES rowan_scripts(id), priority integer NOT NULL,
  UNIQUE (surface, context_key, priority)
);
CREATE TABLE IF NOT EXISTS daily_ritual_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, local_date date NOT NULL, mode text NOT NULL CHECK (mode IN ('tarot','astrology')),
  schedule_id uuid NOT NULL REFERENCES ritual_schedules(id), revision_id uuid NOT NULL REFERENCES editorial_revisions(id), rowan_revision_id uuid REFERENCES rowan_script_revisions(revision_id),
  state text NOT NULL CHECK (state IN ('assigned','revealed','completed')), revealed_at timestamptz, completed_at timestamptz,
  UNIQUE (tenant_id, local_date, mode), UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS asset_codex_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), editorial_item_id uuid NOT NULL UNIQUE REFERENCES editorial_items(id), asset_id uuid NOT NULL UNIQUE REFERENCES assets(id)
);
CREATE TABLE IF NOT EXISTS asset_codex_revisions (
  revision_id uuid PRIMARY KEY REFERENCES editorial_revisions(id), thesis text NOT NULL, appearance_reason text NOT NULL, metrics_as_of timestamptz NOT NULL, limitations text NOT NULL
);
CREATE TABLE IF NOT EXISTS asset_codex_risks (
  revision_id uuid NOT NULL REFERENCES asset_codex_revisions(revision_id), ordinal integer NOT NULL CHECK (ordinal > 0), title text NOT NULL, detail text NOT NULL,
  severity text NOT NULL CHECK (severity IN ('low','medium','high')), PRIMARY KEY (revision_id, ordinal)
);
CREATE TABLE IF NOT EXISTS asset_codex_evidence (
  revision_id uuid NOT NULL REFERENCES asset_codex_revisions(revision_id), claim_id uuid NOT NULL REFERENCES evidence_claims(id), ordinal integer NOT NULL CHECK (ordinal > 0),
  PRIMARY KEY (revision_id, claim_id), UNIQUE (revision_id, ordinal)
);
CREATE TABLE IF NOT EXISTS companies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text NOT NULL UNIQUE CHECK (slug = lower(slug)), name text NOT NULL, asset_id uuid REFERENCES assets(id),
  website_url text CHECK (website_url IS NULL OR website_url ~ '^https://'), is_fictional boolean NOT NULL DEFAULT false, status text NOT NULL CHECK (status IN ('active','inactive'))
);
CREATE TABLE IF NOT EXISTS coven_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), editorial_item_id uuid NOT NULL UNIQUE REFERENCES editorial_items(id), company_id uuid NOT NULL UNIQUE REFERENCES companies(id)
);
CREATE TABLE IF NOT EXISTS coven_entry_revisions (
  revision_id uuid PRIMARY KEY REFERENCES editorial_revisions(id), summary text NOT NULL, inclusion_rationale text NOT NULL, limitations text NOT NULL
);
CREATE TABLE IF NOT EXISTS coven_qualifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), entry_id uuid NOT NULL REFERENCES coven_entries(id), category text NOT NULL CHECK (category IN ('founder','owner','chief_executive')),
  person_name text NOT NULL, valid_from date NOT NULL, valid_to date, current_verification_id uuid, CHECK (valid_to IS NULL OR valid_to >= valid_from)
);
CREATE TABLE IF NOT EXISTS coven_verifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), qualification_id uuid NOT NULL REFERENCES coven_qualifications(id), status text NOT NULL CHECK (status IN ('pending','verified','rejected','expired')),
  effective_as_of date NOT NULL, verified_at timestamptz, verified_by uuid REFERENCES staff_principals(id), supersedes_id uuid REFERENCES coven_verifications(id)
);
ALTER TABLE coven_qualifications ADD CONSTRAINT coven_qualifications_current_verification_fk FOREIGN KEY (current_verification_id) REFERENCES coven_verifications(id) DEFERRABLE INITIALLY DEFERRED;
CREATE TABLE IF NOT EXISTS coven_verification_evidence (
  verification_id uuid NOT NULL REFERENCES coven_verifications(id), claim_id uuid NOT NULL REFERENCES evidence_claims(id), ordinal integer NOT NULL CHECK (ordinal > 0),
  PRIMARY KEY (verification_id, claim_id), UNIQUE (verification_id, ordinal)
);

CREATE TABLE IF NOT EXISTS grimoires (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), editorial_item_id uuid NOT NULL UNIQUE REFERENCES editorial_items(id), theme_code text NOT NULL
);
CREATE TABLE IF NOT EXISTS grimoire_revisions (
  revision_id uuid PRIMARY KEY REFERENCES editorial_revisions(id), title text NOT NULL, description text NOT NULL, curator_label text NOT NULL, art_media_id uuid REFERENCES media_assets(id)
);
CREATE TABLE IF NOT EXISTS grimoire_revision_assets (
  revision_id uuid NOT NULL REFERENCES grimoire_revisions(revision_id), asset_id uuid NOT NULL REFERENCES assets(id), ordinal integer NOT NULL CHECK (ordinal > 0), note text,
  PRIMARY KEY (revision_id, asset_id), UNIQUE (revision_id, ordinal)
);
CREATE TABLE IF NOT EXISTS seeded_creators (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text NOT NULL UNIQUE CHECK (slug = lower(slug)), display_name text NOT NULL, bio text NOT NULL,
  avatar_media_id uuid REFERENCES media_assets(id), is_fictional boolean NOT NULL DEFAULT true CHECK (is_fictional), status text NOT NULL CHECK (status IN ('active','retired'))
);
CREATE TABLE IF NOT EXISTS circle_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), editorial_item_id uuid NOT NULL UNIQUE REFERENCES editorial_items(id), creator_id uuid NOT NULL REFERENCES seeded_creators(id), theme_code text NOT NULL
);
CREATE TABLE IF NOT EXISTS circle_template_revisions (
  revision_id uuid PRIMARY KEY REFERENCES editorial_revisions(id), title text NOT NULL, description text NOT NULL, art_media_id uuid REFERENCES media_assets(id)
);
CREATE TABLE IF NOT EXISTS circle_template_assets (
  revision_id uuid NOT NULL REFERENCES circle_template_revisions(revision_id), asset_id uuid NOT NULL REFERENCES assets(id), ordinal integer NOT NULL CHECK (ordinal > 0),
  weight_bps integer CHECK (weight_bps BETWEEN 0 AND 10000), note text, PRIMARY KEY (revision_id, asset_id), UNIQUE (revision_id, ordinal)
);
CREATE TABLE IF NOT EXISTS circles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, title text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 80),
  description text NOT NULL DEFAULT '', source_template_id uuid REFERENCES circle_templates(id), source_revision_id uuid REFERENCES editorial_revisions(id),
  version integer NOT NULL DEFAULT 1 CHECK (version > 0), archived_at timestamptz, UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS circle_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, circle_id uuid NOT NULL, asset_id uuid NOT NULL REFERENCES assets(id),
  ordinal integer NOT NULL CHECK (ordinal BETWEEN 1 AND 50), weight_bps integer CHECK (weight_bps BETWEEN 0 AND 10000), note text,
  FOREIGN KEY (tenant_id, circle_id) REFERENCES circles (tenant_id, id) ON DELETE CASCADE,
  UNIQUE (tenant_id, circle_id, asset_id), UNIQUE (tenant_id, circle_id, ordinal), UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS saved_assets (
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, asset_id uuid NOT NULL REFERENCES assets(id), source_kind text NOT NULL, source_id uuid,
  saved_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (tenant_id, asset_id)
);
CREATE TABLE IF NOT EXISTS saved_grimoires (
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, grimoire_id uuid NOT NULL REFERENCES grimoires(id), revision_id uuid NOT NULL REFERENCES editorial_revisions(id),
  saved_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (tenant_id, grimoire_id)
);
CREATE TABLE IF NOT EXISTS saved_circle_templates (
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, template_id uuid NOT NULL REFERENCES circle_templates(id), revision_id uuid NOT NULL REFERENCES editorial_revisions(id),
  saved_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (tenant_id, template_id)
);
CREATE TABLE IF NOT EXISTS saved_coven_entries (
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, entry_id uuid NOT NULL REFERENCES coven_entries(id), verification_id uuid NOT NULL REFERENCES coven_verifications(id),
  saved_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (tenant_id, entry_id)
);

CREATE TABLE IF NOT EXISTS demo_seed_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), version integer NOT NULL UNIQUE CHECK (version > 0), fixture_hash text NOT NULL UNIQUE,
  published_at timestamptz NOT NULL, is_current boolean NOT NULL DEFAULT false
);
CREATE UNIQUE INDEX IF NOT EXISTS demo_seed_versions_current_unique ON demo_seed_versions(is_current) WHERE is_current;
CREATE TABLE IF NOT EXISTS tenant_demo_states (
  tenant_id uuid PRIMARY KEY REFERENCES tenants(id) ON DELETE CASCADE, seed_version_id uuid NOT NULL REFERENCES demo_seed_versions(id),
  reset_generation integer NOT NULL DEFAULT 1 CHECK (reset_generation > 0), version integer NOT NULL DEFAULT 1 CHECK (version > 0), reset_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS demo_portfolios (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, name text NOT NULL, currency text NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  status text NOT NULL CHECK (status IN ('active','archived')), version integer NOT NULL DEFAULT 1 CHECK (version > 0), UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS portfolio_target_allocations (
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, portfolio_id uuid NOT NULL, asset_id uuid NOT NULL REFERENCES assets(id),
  target_bps integer NOT NULL CHECK (target_bps BETWEEN 0 AND 10000), version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  FOREIGN KEY (tenant_id, portfolio_id) REFERENCES demo_portfolios(tenant_id, id) ON DELETE CASCADE, PRIMARY KEY (tenant_id, portfolio_id, asset_id)
);
CREATE TABLE IF NOT EXISTS idempotency_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, reset_generation integer NOT NULL CHECK (reset_generation > 0),
  operation text NOT NULL, idempotency_key text NOT NULL CHECK (char_length(idempotency_key) BETWEEN 1 AND 64), request_hash text NOT NULL,
  state text NOT NULL DEFAULT 'processing' CHECK (state IN ('processing','completed','rejected')), claim_owner text, lease_until timestamptz, command_id uuid,
  response_hash text, terminal_response jsonb, expires_at timestamptz NOT NULL,
  UNIQUE (tenant_id, reset_generation, operation, idempotency_key), UNIQUE (tenant_id, id),
  CHECK ((state = 'processing' AND terminal_response IS NULL) OR (state IN ('completed','rejected') AND terminal_response IS NOT NULL))
);
CREATE TABLE IF NOT EXISTS simulation_commands (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, reset_generation integer NOT NULL CHECK (reset_generation > 0),
  portfolio_id uuid NOT NULL, idempotency_id uuid NOT NULL UNIQUE, command_type text NOT NULL, status text NOT NULL CHECK (status IN ('committed','rejected')),
  rejection_code text, committed_at timestamptz, FOREIGN KEY (tenant_id, portfolio_id) REFERENCES demo_portfolios(tenant_id, id),
  FOREIGN KEY (tenant_id, idempotency_id) REFERENCES idempotency_records(tenant_id, id), UNIQUE (tenant_id, id),
  CHECK ((status = 'committed' AND rejection_code IS NULL AND committed_at IS NOT NULL) OR (status = 'rejected' AND rejection_code IS NOT NULL))
);
ALTER TABLE idempotency_records ADD CONSTRAINT idempotency_records_command_fk FOREIGN KEY (tenant_id, command_id) REFERENCES simulation_commands(tenant_id, id) DEFERRABLE INITIALLY DEFERRED;
CREATE TABLE IF NOT EXISTS demo_funding_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, fixture_key text NOT NULL, display_label text NOT NULL,
  fictional_last4 text NOT NULL CHECK (fictional_last4 ~ '^[0-9]{4}$'), status text NOT NULL CHECK (status IN ('active','inactive')), UNIQUE (tenant_id, fixture_key), UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS simulated_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, portfolio_id uuid NOT NULL, command_id uuid NOT NULL,
  asset_id uuid NOT NULL REFERENCES assets(id), side text NOT NULL CHECK (side IN ('buy','sell')), order_type text NOT NULL CHECK (order_type = 'market'),
  requested_notional_minor bigint, requested_quantity numeric(30,12), status text NOT NULL CHECK (status IN ('accepted','rejected')), quote_snapshot_id uuid,
  FOREIGN KEY (tenant_id, portfolio_id) REFERENCES demo_portfolios(tenant_id, id), FOREIGN KEY (tenant_id, command_id) REFERENCES simulation_commands(tenant_id, id),
  UNIQUE (tenant_id, command_id), UNIQUE (tenant_id, id), CHECK ((requested_notional_minor IS NULL) <> (requested_quantity IS NULL))
);
CREATE TABLE IF NOT EXISTS simulated_order_fills (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, order_id uuid NOT NULL,
  quantity numeric(30,12) NOT NULL CHECK (quantity > 0), price_minor bigint NOT NULL CHECK (price_minor >= 0), filled_at timestamptz NOT NULL,
  FOREIGN KEY (tenant_id, order_id) REFERENCES simulated_orders(tenant_id, id), UNIQUE (tenant_id, order_id), UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS ledger_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, reset_generation integer NOT NULL CHECK (reset_generation > 0),
  portfolio_id uuid NOT NULL, command_id uuid NOT NULL, entry_type text NOT NULL, effective_at timestamptz NOT NULL, description_code text NOT NULL,
  FOREIGN KEY (tenant_id, portfolio_id) REFERENCES demo_portfolios(tenant_id, id), FOREIGN KEY (tenant_id, command_id) REFERENCES simulation_commands(tenant_id, id),
  UNIQUE (tenant_id, command_id), UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS cash_ledger_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, transaction_id uuid NOT NULL, currency text NOT NULL CHECK (currency ~ '^[A-Z]{3}$'), amount_minor bigint NOT NULL CHECK (amount_minor <> 0),
  FOREIGN KEY (tenant_id, transaction_id) REFERENCES ledger_transactions (tenant_id, id) ON DELETE CASCADE, UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS position_ledger_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, transaction_id uuid NOT NULL, asset_id uuid NOT NULL REFERENCES assets(id),
  quantity numeric(30,12) NOT NULL CHECK (quantity <> 0), unit_price_minor bigint NOT NULL CHECK (unit_price_minor >= 0),
  FOREIGN KEY (tenant_id, transaction_id) REFERENCES ledger_transactions(tenant_id, id) ON DELETE CASCADE, UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS portfolio_positions (
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, portfolio_id uuid NOT NULL, asset_id uuid NOT NULL REFERENCES assets(id), quantity numeric(30,12) NOT NULL,
  cost_basis_minor bigint NOT NULL, as_of_transaction_id uuid NOT NULL, FOREIGN KEY (tenant_id, portfolio_id) REFERENCES demo_portfolios(tenant_id, id) ON DELETE CASCADE,
  FOREIGN KEY (tenant_id, as_of_transaction_id) REFERENCES ledger_transactions(tenant_id, id), PRIMARY KEY (tenant_id, portfolio_id, asset_id)
);
CREATE TABLE IF NOT EXISTS portfolio_balance_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, portfolio_id uuid NOT NULL, as_of_transaction_id uuid NOT NULL,
  projection_generation integer NOT NULL CHECK (projection_generation > 0), as_of timestamptz NOT NULL, cash_minor bigint NOT NULL, market_value_minor bigint NOT NULL, source_hash text NOT NULL,
  FOREIGN KEY (tenant_id, portfolio_id) REFERENCES demo_portfolios(tenant_id, id), FOREIGN KEY (tenant_id, as_of_transaction_id) REFERENCES ledger_transactions(tenant_id, id),
  UNIQUE (tenant_id, portfolio_id, projection_generation), UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS recurring_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, portfolio_id uuid NOT NULL, plan_type text NOT NULL,
  amount_minor bigint NOT NULL CHECK (amount_minor > 0), frequency text NOT NULL CHECK (frequency IN ('weekly','monthly')), next_run_at timestamptz NOT NULL,
  status text NOT NULL CHECK (status IN ('active','paused','cancelled','completed')), version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  FOREIGN KEY (tenant_id, portfolio_id) REFERENCES demo_portfolios(tenant_id, id), UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS recurring_plan_allocations (
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, plan_id uuid NOT NULL, asset_id uuid NOT NULL REFERENCES assets(id), weight_bps integer NOT NULL CHECK (weight_bps BETWEEN 0 AND 10000),
  FOREIGN KEY (tenant_id, plan_id) REFERENCES recurring_plans(tenant_id, id) ON DELETE CASCADE, PRIMARY KEY (tenant_id, plan_id, asset_id)
);
CREATE TABLE IF NOT EXISTS recurring_plan_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, reset_generation integer NOT NULL CHECK (reset_generation > 0),
  plan_id uuid NOT NULL, scheduled_for timestamptz NOT NULL, command_id uuid, status text NOT NULL CHECK (status IN ('due','running','completed','rejected')), attempted_at timestamptz,
  FOREIGN KEY (tenant_id, plan_id) REFERENCES recurring_plans(tenant_id, id), FOREIGN KEY (tenant_id, command_id) REFERENCES simulation_commands(tenant_id, id),
  UNIQUE (tenant_id, plan_id, reset_generation, scheduled_for), UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS rebalance_previews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, reset_generation integer NOT NULL CHECK (reset_generation > 0),
  portfolio_id uuid NOT NULL, input_version integer NOT NULL CHECK (input_version > 0), expires_at timestamptz NOT NULL, status text NOT NULL CHECK (status IN ('active','expired','executed','invalidated')),
  FOREIGN KEY (tenant_id, portfolio_id) REFERENCES demo_portfolios(tenant_id, id), UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS rebalance_preview_trades (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, preview_id uuid NOT NULL, asset_id uuid NOT NULL REFERENCES assets(id),
  side text NOT NULL CHECK (side IN ('buy','sell')), quantity numeric(30,12) NOT NULL CHECK (quantity > 0), notional_minor bigint NOT NULL CHECK (notional_minor >= 0),
  FOREIGN KEY (tenant_id, preview_id) REFERENCES rebalance_previews(tenant_id, id) ON DELETE CASCADE, UNIQUE (tenant_id, preview_id, asset_id), UNIQUE (tenant_id, id)
);

CREATE TABLE IF NOT EXISTS intentions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, title text NOT NULL, target_minor bigint NOT NULL CHECK (target_minor >= 0),
  target_date date, status text NOT NULL CHECK (status IN ('active','completed','archived')), version integer NOT NULL DEFAULT 1 CHECK (version > 0), UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS projection_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, intention_id uuid NOT NULL, as_of_transaction_id uuid NOT NULL,
  projection_generation integer NOT NULL CHECK (projection_generation > 0), input_hash text NOT NULL, model_version text NOT NULL, generated_at timestamptz NOT NULL,
  status text NOT NULL CHECK (status IN ('complete','superseded','failed')), FOREIGN KEY (tenant_id, intention_id) REFERENCES intentions(tenant_id, id),
  FOREIGN KEY (tenant_id, as_of_transaction_id) REFERENCES ledger_transactions(tenant_id, id), UNIQUE (tenant_id, intention_id, projection_generation), UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS projection_points (
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, run_id uuid NOT NULL, point_date date NOT NULL, low_minor bigint NOT NULL, mid_minor bigint NOT NULL, high_minor bigint NOT NULL,
  FOREIGN KEY (tenant_id, run_id) REFERENCES projection_runs(tenant_id, id) ON DELETE CASCADE, PRIMARY KEY (tenant_id, run_id, point_date), CHECK (low_minor <= mid_minor AND mid_minor <= high_minor)
);
CREATE TABLE IF NOT EXISTS briefings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, briefing_type text NOT NULL, period_start date NOT NULL, period_end date NOT NULL,
  generation integer NOT NULL CHECK (generation > 0), supersedes_id uuid, source_watermark uuid, source_hash text NOT NULL, generated_at timestamptz NOT NULL, read_at timestamptz,
  is_current boolean NOT NULL DEFAULT false, UNIQUE (tenant_id, briefing_type, period_start, source_hash), UNIQUE (tenant_id, id),
  FOREIGN KEY (tenant_id, supersedes_id) REFERENCES briefings(tenant_id, id), CHECK (period_end >= period_start)
);
CREATE UNIQUE INDEX IF NOT EXISTS briefings_current_unique ON briefings(tenant_id, briefing_type, period_start, period_end) WHERE is_current;
CREATE TABLE IF NOT EXISTS briefing_sections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, briefing_id uuid NOT NULL, section_type text NOT NULL,
  ordinal integer NOT NULL CHECK (ordinal > 0), payload jsonb NOT NULL CHECK (jsonb_typeof(payload) = 'object'), schema_version integer NOT NULL DEFAULT 1 CHECK (schema_version > 0),
  FOREIGN KEY (tenant_id, briefing_id) REFERENCES briefings(tenant_id, id) ON DELETE CASCADE, UNIQUE (tenant_id, briefing_id, ordinal), UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS demo_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text NOT NULL UNIQUE, display_name text NOT NULL, price_copy text NOT NULL,
  feature_codes jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(feature_codes) = 'array'), status text NOT NULL CHECK (status IN ('active','retired'))
);
CREATE TABLE IF NOT EXISTS tenant_entitlements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, plan_id uuid NOT NULL REFERENCES demo_plans(id),
  status text NOT NULL CHECK (status IN ('active','expired','revoked')), source text NOT NULL DEFAULT 'demo' CHECK (source = 'demo'), starts_at timestamptz NOT NULL, ends_at timestamptz,
  version integer NOT NULL DEFAULT 1 CHECK (version > 0), UNIQUE (tenant_id, id), CHECK (ends_at IS NULL OR ends_at >= starts_at)
);
CREATE UNIQUE INDEX IF NOT EXISTS tenant_entitlements_active_unique ON tenant_entitlements(tenant_id) WHERE status = 'active';
CREATE TABLE IF NOT EXISTS entitlement_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, entitlement_id uuid NOT NULL, event_type text NOT NULL,
  occurred_at timestamptz NOT NULL, command_id uuid, FOREIGN KEY (tenant_id, entitlement_id) REFERENCES tenant_entitlements(tenant_id, id),
  FOREIGN KEY (tenant_id, command_id) REFERENCES simulation_commands(tenant_id, id), UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS demo_checkout_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, plan_id uuid NOT NULL REFERENCES demo_plans(id),
  status text NOT NULL CHECK (status IN ('open','completed','expired','cancelled')), expires_at timestamptz NOT NULL, idempotency_id uuid NOT NULL,
  FOREIGN KEY (tenant_id, idempotency_id) REFERENCES idempotency_records(tenant_id, id), UNIQUE (tenant_id, idempotency_id), UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, kind text NOT NULL, title text NOT NULL, body text NOT NULL,
  deep_link text CHECK (deep_link IS NULL OR deep_link ~ '^/[a-z0-9/_-]+$'), scheduled_at timestamptz, read_at timestamptz, UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS notification_deliveries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, notification_id uuid NOT NULL, installation_id uuid NOT NULL,
  status text NOT NULL CHECK (status IN ('pending','sent','failed','cancelled')), attempt integer NOT NULL DEFAULT 0 CHECK (attempt >= 0), provider_code text, sent_at timestamptz,
  FOREIGN KEY (tenant_id, notification_id) REFERENCES notifications(tenant_id, id), FOREIGN KEY (tenant_id, installation_id) REFERENCES device_installations(tenant_id, id),
  UNIQUE (tenant_id, notification_id, installation_id, attempt), UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS privacy_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, request_type text NOT NULL CHECK (request_type IN ('export','delete')),
  status text NOT NULL CHECK (status IN ('requested','verified','queued','processing','completed','failed','cancelled')), snapshot_at timestamptz, source_watermark uuid,
  archive_schema_version integer, verified_at timestamptz, queued_at timestamptz, completed_at timestamptz, failure_code text, UNIQUE (tenant_id, id)
);
CREATE UNIQUE INDEX IF NOT EXISTS privacy_requests_active_type_unique ON privacy_requests(tenant_id, request_type) WHERE status IN ('requested','verified','queued','processing');
CREATE TABLE IF NOT EXISTS privacy_export_artifacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, request_id uuid NOT NULL, r2_key text NOT NULL UNIQUE,
  manifest_checksum text NOT NULL, publication_state text NOT NULL CHECK (publication_state IN ('staged','published','revoked','deleted')), expires_at timestamptz NOT NULL, downloaded_at timestamptz,
  FOREIGN KEY (tenant_id, request_id) REFERENCES privacy_requests (tenant_id, id) ON DELETE CASCADE, UNIQUE (tenant_id, request_id), UNIQUE (tenant_id, id)
);
CREATE TABLE IF NOT EXISTS content_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE, target_kind text NOT NULL, target_id uuid NOT NULL REFERENCES editorial_items(id),
  reason_code text NOT NULL, detail text CHECK (detail IS NULL OR char_length(detail) <= 1000), created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (tenant_id, id)
);

CREATE TABLE IF NOT EXISTS moderation_cases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), report_id uuid NOT NULL UNIQUE REFERENCES content_reports(id) ON DELETE CASCADE, status text NOT NULL CHECK (status IN ('open','investigating','resolved','dismissed')),
  assignee_id uuid REFERENCES staff_principals(id), resolution_code text, resolved_at timestamptz
);
CREATE TABLE IF NOT EXISTS admin_audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), actor_staff_id uuid NOT NULL REFERENCES staff_principals(id), action text NOT NULL, target_kind text NOT NULL, target_id uuid,
  before_hash text, after_hash text, reason text NOT NULL, request_id uuid NOT NULL, outcome text NOT NULL CHECK (outcome IN ('allowed','denied','failed')), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS security_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), principal_hash text, route_class text NOT NULL, event_type text NOT NULL, outcome text NOT NULL,
  ip_prefix_hash text, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS outbox_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), topic text NOT NULL, aggregate_kind text NOT NULL, aggregate_id uuid NOT NULL, aggregate_version integer NOT NULL CHECK (aggregate_version >= 0),
  tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE, reset_generation integer, dedupe_key text NOT NULL, payload jsonb NOT NULL CHECK (jsonb_typeof(payload) = 'object'),
  available_at timestamptz NOT NULL, published_at timestamptz, UNIQUE (topic, dedupe_key)
);
CREATE TABLE IF NOT EXISTS job_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), outbox_id uuid NOT NULL REFERENCES outbox_events(id), consumer text NOT NULL, status text NOT NULL CHECK (status IN ('leased','completed','retry','dead_letter')),
  attempt integer NOT NULL DEFAULT 0 CHECK (attempt >= 0), lease_until timestamptz, next_attempt_at timestamptz, correlation_id uuid NOT NULL, failure_code text,
  UNIQUE (outbox_id, consumer, attempt)
);
CREATE TABLE IF NOT EXISTS consumer_receipts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), outbox_id uuid NOT NULL REFERENCES outbox_events(id), consumer text NOT NULL, aggregate_version integer NOT NULL CHECK (aggregate_version >= 0),
  outcome_hash text NOT NULL, completed_at timestamptz NOT NULL, UNIQUE (outbox_id, consumer)
);
CREATE TABLE IF NOT EXISTS deletion_tombstones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, subject_hash text NOT NULL UNIQUE, effective_at timestamptz NOT NULL,
  purge_generation integer NOT NULL CHECK (purge_generation > 0), status text NOT NULL CHECK (status IN ('pending','purging','purged','failed')),
  UNIQUE (tenant_id, purge_generation)
);
CREATE TABLE IF NOT EXISTS purge_receipts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tombstone_id uuid NOT NULL REFERENCES deletion_tombstones(id), purge_generation integer NOT NULL CHECK (purge_generation > 0),
  started_at timestamptz NOT NULL, completed_at timestamptz, outcome_hash text, failure_code text, UNIQUE (tombstone_id, purge_generation)
);

CREATE INDEX IF NOT EXISTS accounts_tenant_idx ON accounts(tenant_id);
CREATE INDEX IF NOT EXISTS consent_records_tenant_time_idx ON consent_records(tenant_id, recorded_at DESC, id);
CREATE INDEX IF NOT EXISTS circles_tenant_active_idx ON circles(tenant_id, archived_at, id);
CREATE INDEX IF NOT EXISTS idempotency_records_lookup_idx ON idempotency_records(tenant_id, reset_generation, operation, idempotency_key);
CREATE INDEX IF NOT EXISTS ledger_transactions_tenant_portfolio_watermark_idx ON ledger_transactions(tenant_id, portfolio_id, effective_at, id);
CREATE INDEX IF NOT EXISTS recurring_plans_due_idx ON recurring_plans(tenant_id, next_run_at, id) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS projection_runs_watermark_idx ON projection_runs(tenant_id, intention_id, projection_generation DESC, as_of_transaction_id);
CREATE INDEX IF NOT EXISTS outbox_events_due_idx ON outbox_events(available_at, id) WHERE published_at IS NULL;
CREATE INDEX IF NOT EXISTS job_runs_retry_idx ON job_runs(next_attempt_at, id) WHERE status = 'retry';
CREATE INDEX IF NOT EXISTS deletion_tombstones_restore_guard_idx ON deletion_tombstones(tenant_id, purge_generation DESC) WHERE status IN ('pending','purging','purged');

DO $foreign_key_indexes$
DECLARE foreign_key record;
BEGIN
  FOR foreign_key IN
    SELECT
      constraint_row.conname,
      constraint_row.conrelid::regclass AS relation_name,
      string_agg(quote_ident(attribute_row.attname), ', ' ORDER BY key_column.ordinality) AS column_names
    FROM pg_constraint AS constraint_row
    CROSS JOIN LATERAL unnest(constraint_row.conkey) WITH ORDINALITY AS key_column(attnum, ordinality)
    JOIN pg_attribute AS attribute_row
      ON attribute_row.attrelid = constraint_row.conrelid AND attribute_row.attnum = key_column.attnum
    WHERE constraint_row.contype = 'f'
      AND constraint_row.connamespace = 'public'::regnamespace
    GROUP BY constraint_row.conname, constraint_row.conrelid
  LOOP
    EXECUTE format(
      'CREATE INDEX IF NOT EXISTS %I ON %s (%s)',
      left('fkidx_' || foreign_key.conname, 63),
      foreign_key.relation_name,
      foreign_key.column_names
    );
  END LOOP;
END
$foreign_key_indexes$;

COMMIT;
