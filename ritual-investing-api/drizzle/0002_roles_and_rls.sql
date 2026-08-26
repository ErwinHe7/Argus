BEGIN;

DO $$ BEGIN
  CREATE ROLE ritual_public NOINHERIT NOLOGIN NOBYPASSRLS;
EXCEPTION WHEN duplicate_object THEN
  ALTER ROLE ritual_public NOINHERIT NOLOGIN NOBYPASSRLS;
END $$;
DO $$ BEGIN
  CREATE ROLE ritual_identity_resolver NOINHERIT NOLOGIN NOBYPASSRLS;
EXCEPTION WHEN duplicate_object THEN
  ALTER ROLE ritual_identity_resolver NOINHERIT NOLOGIN NOBYPASSRLS;
END $$;
DO $$ BEGIN
  CREATE ROLE ritual_runtime NOINHERIT NOLOGIN NOBYPASSRLS;
EXCEPTION WHEN duplicate_object THEN
  ALTER ROLE ritual_runtime NOINHERIT NOLOGIN NOBYPASSRLS;
END $$;
DO $$ BEGIN
  CREATE ROLE ritual_staff NOINHERIT NOLOGIN NOBYPASSRLS;
EXCEPTION WHEN duplicate_object THEN
  ALTER ROLE ritual_staff NOINHERIT NOLOGIN NOBYPASSRLS;
END $$;
DO $$ BEGIN
  CREATE ROLE ritual_scheduler NOINHERIT NOLOGIN NOBYPASSRLS;
EXCEPTION WHEN duplicate_object THEN
  ALTER ROLE ritual_scheduler NOINHERIT NOLOGIN NOBYPASSRLS;
END $$;
DO $$ BEGIN
  CREATE ROLE ritual_privacy_purge NOINHERIT NOLOGIN NOBYPASSRLS;
EXCEPTION WHEN duplicate_object THEN
  ALTER ROLE ritual_privacy_purge NOINHERIT NOLOGIN NOBYPASSRLS;
END $$;
DO $$ BEGIN
  CREATE ROLE ritual_function_owner NOINHERIT NOLOGIN BYPASSRLS;
EXCEPTION WHEN duplicate_object THEN
  ALTER ROLE ritual_function_owner NOINHERIT NOLOGIN BYPASSRLS;
END $$;

-- Managed Postgres owners such as Neon receive CREATEROLE without implicit
-- SET membership in roles they create. Grant only temporary SET membership
-- for ownership transfer; it is revoked before this transaction commits.
DO $$ BEGIN
  EXECUTE format(
    'GRANT ritual_function_owner TO %I WITH INHERIT FALSE, SET TRUE',
    current_user
  );
END $$;

CREATE SCHEMA IF NOT EXISTS ritual_public;
REVOKE ALL ON SCHEMA ritual_private FROM PUBLIC;
REVOKE ALL ON SCHEMA ritual_public FROM PUBLIC;
GRANT USAGE, CREATE ON SCHEMA ritual_private TO ritual_function_owner;
GRANT USAGE ON SCHEMA public TO ritual_function_owner;

CREATE OR REPLACE FUNCTION ritual_private.current_tenant_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog
AS $$
  SELECT nullif(current_setting('ritual.tenant_id', true), '')::uuid
$$;
REVOKE ALL ON FUNCTION ritual_private.current_tenant_id() FROM PUBLIC;
GRANT USAGE ON SCHEMA ritual_private TO ritual_runtime;
GRANT EXECUTE ON FUNCTION ritual_private.current_tenant_id() TO ritual_runtime;

ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenants FORCE ROW LEVEL SECURITY;
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts FORCE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles FORCE ROW LEVEL SECURITY;
ALTER TABLE preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE preferences FORCE ROW LEVEL SECURITY;
ALTER TABLE astrology_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE astrology_profiles FORCE ROW LEVEL SECURITY;
ALTER TABLE investor_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE investor_profiles FORCE ROW LEVEL SECURITY;
ALTER TABLE onboarding_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE onboarding_states FORCE ROW LEVEL SECURITY;
ALTER TABLE consent_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE consent_records FORCE ROW LEVEL SECURITY;
ALTER TABLE device_installations ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_installations FORCE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences FORCE ROW LEVEL SECURITY;
ALTER TABLE daily_ritual_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_ritual_assignments FORCE ROW LEVEL SECURITY;
ALTER TABLE circles ENABLE ROW LEVEL SECURITY;
ALTER TABLE circles FORCE ROW LEVEL SECURITY;
ALTER TABLE circle_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE circle_assets FORCE ROW LEVEL SECURITY;
ALTER TABLE saved_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_assets FORCE ROW LEVEL SECURITY;
ALTER TABLE saved_grimoires ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_grimoires FORCE ROW LEVEL SECURITY;
ALTER TABLE saved_circle_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_circle_templates FORCE ROW LEVEL SECURITY;
ALTER TABLE saved_coven_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_coven_entries FORCE ROW LEVEL SECURITY;
ALTER TABLE tenant_demo_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_demo_states FORCE ROW LEVEL SECURITY;
ALTER TABLE demo_portfolios ENABLE ROW LEVEL SECURITY;
ALTER TABLE demo_portfolios FORCE ROW LEVEL SECURITY;
ALTER TABLE portfolio_target_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio_target_allocations FORCE ROW LEVEL SECURITY;
ALTER TABLE idempotency_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE idempotency_records FORCE ROW LEVEL SECURITY;
ALTER TABLE simulation_commands ENABLE ROW LEVEL SECURITY;
ALTER TABLE simulation_commands FORCE ROW LEVEL SECURITY;
ALTER TABLE demo_funding_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE demo_funding_sources FORCE ROW LEVEL SECURITY;
ALTER TABLE simulated_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE simulated_orders FORCE ROW LEVEL SECURITY;
ALTER TABLE simulated_order_fills ENABLE ROW LEVEL SECURITY;
ALTER TABLE simulated_order_fills FORCE ROW LEVEL SECURITY;
ALTER TABLE ledger_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ledger_transactions FORCE ROW LEVEL SECURITY;
ALTER TABLE cash_ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_ledger_entries FORCE ROW LEVEL SECURITY;
ALTER TABLE position_ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE position_ledger_entries FORCE ROW LEVEL SECURITY;
ALTER TABLE portfolio_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio_positions FORCE ROW LEVEL SECURITY;
ALTER TABLE portfolio_balance_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio_balance_snapshots FORCE ROW LEVEL SECURITY;
ALTER TABLE recurring_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_plans FORCE ROW LEVEL SECURITY;
ALTER TABLE recurring_plan_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_plan_allocations FORCE ROW LEVEL SECURITY;
ALTER TABLE recurring_plan_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_plan_runs FORCE ROW LEVEL SECURITY;
ALTER TABLE rebalance_previews ENABLE ROW LEVEL SECURITY;
ALTER TABLE rebalance_previews FORCE ROW LEVEL SECURITY;
ALTER TABLE rebalance_preview_trades ENABLE ROW LEVEL SECURITY;
ALTER TABLE rebalance_preview_trades FORCE ROW LEVEL SECURITY;
ALTER TABLE intentions ENABLE ROW LEVEL SECURITY;
ALTER TABLE intentions FORCE ROW LEVEL SECURITY;
ALTER TABLE projection_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE projection_runs FORCE ROW LEVEL SECURITY;
ALTER TABLE projection_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE projection_points FORCE ROW LEVEL SECURITY;
ALTER TABLE briefings ENABLE ROW LEVEL SECURITY;
ALTER TABLE briefings FORCE ROW LEVEL SECURITY;
ALTER TABLE briefing_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE briefing_sections FORCE ROW LEVEL SECURITY;
ALTER TABLE tenant_entitlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_entitlements FORCE ROW LEVEL SECURITY;
ALTER TABLE entitlement_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE entitlement_events FORCE ROW LEVEL SECURITY;
ALTER TABLE demo_checkout_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE demo_checkout_sessions FORCE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications FORCE ROW LEVEL SECURITY;
ALTER TABLE notification_deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_deliveries FORCE ROW LEVEL SECURITY;
ALTER TABLE privacy_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE privacy_requests FORCE ROW LEVEL SECURITY;
ALTER TABLE privacy_export_artifacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE privacy_export_artifacts FORCE ROW LEVEL SECURITY;
ALTER TABLE content_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_reports FORCE ROW LEVEL SECURITY;

DO $policies$
DECLARE table_name text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'tenants' AND policyname = 'tenant_isolation') THEN
    CREATE POLICY tenant_isolation ON tenants
      USING (id = ritual_private.current_tenant_id())
      WITH CHECK (id = ritual_private.current_tenant_id());
  END IF;

  FOREACH table_name IN ARRAY ARRAY[
    'accounts','profiles','preferences','astrology_profiles','investor_profiles','onboarding_states','consent_records',
    'device_installations','notification_preferences','daily_ritual_assignments','circles','circle_assets','saved_assets','saved_grimoires',
    'saved_circle_templates','saved_coven_entries','tenant_demo_states','demo_portfolios','portfolio_target_allocations','idempotency_records',
    'simulation_commands','demo_funding_sources','simulated_orders','simulated_order_fills','ledger_transactions','cash_ledger_entries',
    'position_ledger_entries','portfolio_positions','portfolio_balance_snapshots','recurring_plans','recurring_plan_allocations',
    'recurring_plan_runs','rebalance_previews','rebalance_preview_trades','intentions','projection_runs','projection_points','briefings',
    'briefing_sections','tenant_entitlements','entitlement_events','demo_checkout_sessions','notifications','notification_deliveries',
    'privacy_requests','privacy_export_artifacts','content_reports'
  ] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = table_name AND policyname = 'tenant_isolation') THEN
      EXECUTE format(
        'CREATE POLICY tenant_isolation ON %I USING (tenant_id = ritual_private.current_tenant_id()) WITH CHECK (tenant_id = ritual_private.current_tenant_id())',
        table_name
      );
    END IF;
  END LOOP;
END
$policies$;

CREATE OR REPLACE FUNCTION ritual_private.resolve_account_context(verified_subject text)
RETURNS TABLE (
  account_id uuid,
  tenant_id uuid,
  account_status text,
  tenant_status text,
  revocation_epoch integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, ritual_private
AS $$
  SELECT a.id, a.tenant_id, a.status, t.status, a.revocation_epoch
  FROM public.accounts AS a
  JOIN public.tenants AS t ON t.id = a.tenant_id
  WHERE a.auth0_subject = verified_subject
    AND a.status = 'active'
    AND t.status = 'active'
  LIMIT 1
$$;
ALTER FUNCTION ritual_private.resolve_account_context(text) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.resolve_account_context(text) FROM PUBLIC;
GRANT SELECT ON TABLE accounts, tenants TO ritual_function_owner;
GRANT USAGE ON SCHEMA ritual_private TO ritual_identity_resolver;
GRANT EXECUTE ON FUNCTION ritual_private.resolve_account_context(text) TO ritual_identity_resolver;

CREATE VIEW ritual_public.daily_ritual_preview
WITH (security_barrier = true)
AS
SELECT
  s.local_date,
  s.mode,
  r.id AS revision_id,
  typed.title,
  typed.interpretation,
  typed.guidance,
  typed.market_label,
  typed.observation_at,
  typed.uncertainty
FROM public.ritual_schedules AS s
JOIN public.editorial_revisions AS r ON r.id = s.revision_id
JOIN public.editorial_items AS item ON item.id = r.item_id
JOIN public.ritual_scenario_revisions AS typed ON typed.revision_id = r.id
WHERE s.audience = 'public'
  AND s.state = 'active'
  AND r.state = 'published'
  AND item.current_published_revision_id = r.id;

CREATE VIEW ritual_public.asset_codex_preview
WITH (security_barrier = true)
AS
SELECT
  item.slug,
  asset.symbol,
  asset.name,
  revision.id AS revision_id,
  typed.thesis,
  typed.appearance_reason,
  typed.metrics_as_of,
  typed.limitations
FROM public.asset_codex_entries AS entry
JOIN public.editorial_items AS item ON item.id = entry.editorial_item_id
JOIN public.editorial_revisions AS revision ON revision.id = item.current_published_revision_id
JOIN public.asset_codex_revisions AS typed ON typed.revision_id = revision.id
JOIN public.assets AS asset ON asset.id = entry.asset_id
WHERE item.status = 'published' AND revision.state = 'published' AND asset.status = 'active';

CREATE VIEW ritual_public.coven_preview
WITH (security_barrier = true)
AS
SELECT
  item.slug,
  company.name,
  qualification.category,
  qualification.person_name,
  verification.effective_as_of,
  typed.summary,
  typed.inclusion_rationale,
  typed.limitations
FROM public.coven_entries AS entry
JOIN public.editorial_items AS item ON item.id = entry.editorial_item_id
JOIN public.editorial_revisions AS revision ON revision.id = item.current_published_revision_id
JOIN public.coven_entry_revisions AS typed ON typed.revision_id = revision.id
JOIN public.companies AS company ON company.id = entry.company_id
JOIN public.coven_qualifications AS qualification ON qualification.entry_id = entry.id
JOIN public.coven_verifications AS verification ON verification.id = qualification.current_verification_id
WHERE item.status = 'published' AND revision.state = 'published' AND verification.status = 'verified';

REVOKE ALL ON ALL TABLES IN SCHEMA ritual_public FROM PUBLIC;
GRANT USAGE ON SCHEMA ritual_public TO ritual_public;
GRANT SELECT ON ritual_public.daily_ritual_preview, ritual_public.asset_codex_preview, ritual_public.coven_preview TO ritual_public;

GRANT USAGE ON SCHEMA public TO ritual_runtime;
GRANT SELECT, UPDATE ON TABLE tenants, accounts TO ritual_runtime;
GRANT SELECT, INSERT, UPDATE ON TABLE idempotency_records TO ritual_runtime;
GRANT SELECT, INSERT ON TABLE
  consent_records, simulation_commands, simulated_orders, simulated_order_fills, ledger_transactions, cash_ledger_entries,
  position_ledger_entries, portfolio_balance_snapshots, recurring_plan_runs, projection_runs, projection_points,
  briefing_sections, entitlement_events, notification_deliveries
TO ritual_runtime;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  profiles, preferences, astrology_profiles, investor_profiles, onboarding_states, device_installations, notification_preferences,
  daily_ritual_assignments, circles, circle_assets, saved_assets, saved_grimoires, saved_circle_templates, saved_coven_entries,
  tenant_demo_states, demo_portfolios, portfolio_target_allocations, demo_funding_sources, portfolio_positions, recurring_plans,
  recurring_plan_allocations, rebalance_previews, rebalance_preview_trades, intentions, briefings, tenant_entitlements,
  demo_checkout_sessions, notifications, privacy_requests, privacy_export_artifacts, content_reports
TO ritual_runtime;
GRANT SELECT ON TABLE
  media_assets, editorial_items, editorial_revisions, publication_events, assets, asset_metric_snapshots, evidence_sources, evidence_claims,
  ritual_scenarios, ritual_scenario_revisions, ritual_scenario_ideas, ritual_scenario_evidence, ritual_schedules, rowan_scripts,
  rowan_script_revisions, rowan_context_bindings, asset_codex_entries, asset_codex_revisions, asset_codex_risks, asset_codex_evidence,
  companies, coven_entries, coven_entry_revisions, coven_qualifications, coven_verifications, coven_verification_evidence,
  grimoires, grimoire_revisions, grimoire_revision_assets, seeded_creators, circle_templates, circle_template_revisions,
  circle_template_assets, demo_seed_versions, demo_plans
TO ritual_runtime;

GRANT USAGE ON SCHEMA public TO ritual_staff;
GRANT SELECT, INSERT, UPDATE ON TABLE
  staff_principals, media_assets, editorial_items, coven_qualifications, moderation_cases
TO ritual_staff;
GRANT SELECT, INSERT ON TABLE
  editorial_revisions, editorial_review_requests, editorial_review_decisions, publication_events, asset_metric_snapshots, evidence_sources, evidence_claims,
  ritual_scenarios, ritual_scenario_revisions, ritual_scenario_ideas, ritual_scenario_evidence, ritual_schedules, rowan_scripts,
  rowan_script_revisions, rowan_context_bindings, asset_codex_entries, asset_codex_revisions, asset_codex_risks, asset_codex_evidence,
  companies, coven_entries, coven_entry_revisions, coven_verifications, coven_verification_evidence, grimoires, grimoire_revisions,
  grimoire_revision_assets, seeded_creators, circle_templates, circle_template_revisions, circle_template_assets, admin_audit_events
TO ritual_staff;
GRANT SELECT ON TABLE assets, demo_plans TO ritual_staff;

CREATE TABLE IF NOT EXISTS ritual_private.purge_guards (
  backend_pid integer NOT NULL,
  transaction_id bigint NOT NULL,
  tenant_id uuid NOT NULL,
  tombstone_id uuid NOT NULL,
  PRIMARY KEY (backend_pid, transaction_id)
);
REVOKE ALL ON ritual_private.purge_guards FROM PUBLIC;

CREATE OR REPLACE FUNCTION ritual_private.reject_immutable_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ritual_private
AS $$
DECLARE row_tenant uuid;
BEGIN
  IF to_jsonb(OLD) ? 'tenant_id' THEN
    row_tenant := nullif(to_jsonb(OLD)->>'tenant_id', '')::uuid;
    IF row_tenant IS NOT NULL AND EXISTS (
      SELECT 1 FROM ritual_private.purge_guards
      WHERE backend_pid = pg_backend_pid()
        AND transaction_id = txid_current()
        AND tenant_id = row_tenant
    ) THEN
      RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
    END IF;
  END IF;
  RAISE EXCEPTION '% is immutable; append a replacement record', TG_TABLE_NAME USING ERRCODE = '55000';
END
$$;
ALTER FUNCTION ritual_private.reject_immutable_change() OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.reject_immutable_change() FROM PUBLIC;
GRANT SELECT ON ritual_private.purge_guards TO ritual_function_owner;

CREATE OR REPLACE FUNCTION ritual_private.reject_portfolio_watermark_regression()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE old_effective_at timestamptz;
DECLARE new_effective_at timestamptz;
BEGIN
  IF NEW.as_of_transaction_id = OLD.as_of_transaction_id THEN RETURN NEW; END IF;
  SELECT effective_at INTO old_effective_at FROM public.ledger_transactions
    WHERE tenant_id = OLD.tenant_id AND id = OLD.as_of_transaction_id;
  SELECT effective_at INTO new_effective_at FROM public.ledger_transactions
    WHERE tenant_id = NEW.tenant_id AND id = NEW.as_of_transaction_id;
  IF new_effective_at IS NULL OR old_effective_at IS NULL OR new_effective_at < old_effective_at THEN
    RAISE EXCEPTION 'portfolio watermark cannot regress' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;
ALTER FUNCTION ritual_private.reject_portfolio_watermark_regression() OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.reject_portfolio_watermark_regression() FROM PUBLIC;
GRANT SELECT ON TABLE ledger_transactions TO ritual_function_owner;

CREATE OR REPLACE FUNCTION ritual_private.enforce_briefing_generation_monotonic()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF NEW.is_current AND EXISTS (
    SELECT 1 FROM public.briefings AS current_briefing
    WHERE current_briefing.tenant_id = NEW.tenant_id
      AND current_briefing.briefing_type = NEW.briefing_type
      AND current_briefing.period_start = NEW.period_start
      AND current_briefing.period_end = NEW.period_end
      AND current_briefing.is_current
      AND current_briefing.id <> NEW.id
      AND current_briefing.generation >= NEW.generation
  ) THEN
    RAISE EXCEPTION 'briefing generation cannot regress' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;
ALTER FUNCTION ritual_private.enforce_briefing_generation_monotonic() OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.enforce_briefing_generation_monotonic() FROM PUBLIC;
GRANT SELECT ON TABLE briefings TO ritual_function_owner;

CREATE TRIGGER portfolio_positions_watermark_monotonic
BEFORE UPDATE OF as_of_transaction_id ON portfolio_positions
FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_portfolio_watermark_regression();
CREATE TRIGGER briefings_generation_monotonic
BEFORE INSERT OR UPDATE OF is_current ON briefings
FOR EACH ROW EXECUTE FUNCTION ritual_private.enforce_briefing_generation_monotonic();

CREATE OR REPLACE FUNCTION ritual_private.enforce_idempotency_transition()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog
AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND (
    NEW.tenant_id <> OLD.tenant_id OR NEW.reset_generation <> OLD.reset_generation OR
    NEW.operation <> OLD.operation OR NEW.idempotency_key <> OLD.idempotency_key OR
    NEW.request_hash <> OLD.request_hash
  ) THEN
    RAISE EXCEPTION 'idempotency identity and request hash are immutable' USING ERRCODE = '23514';
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.state IN ('completed','rejected') THEN
    RAISE EXCEPTION 'terminal idempotency record is immutable' USING ERRCODE = '55000';
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.state = 'processing' AND NEW.state = 'processing'
    AND OLD.lease_until > statement_timestamp() AND NEW.claim_owner IS DISTINCT FROM OLD.claim_owner THEN
    RAISE EXCEPTION 'active idempotency lease cannot be stolen' USING ERRCODE = '55P03';
  END IF;
  IF TG_OP = 'UPDATE' AND NEW.state IN ('completed','rejected')
    AND OLD.claim_owner IS DISTINCT FROM NEW.claim_owner THEN
    RAISE EXCEPTION 'only the lease owner may terminalize idempotency' USING ERRCODE = '55P03';
  END IF;
  RETURN NEW;
END
$$;
REVOKE ALL ON FUNCTION ritual_private.enforce_idempotency_transition() FROM PUBLIC;
CREATE TRIGGER idempotency_records_controlled_transition
BEFORE UPDATE ON idempotency_records
FOR EACH ROW EXECUTE FUNCTION ritual_private.enforce_idempotency_transition();

CREATE OR REPLACE FUNCTION ritual_private.enforce_current_reset_generation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE current_generation integer;
BEGIN
  SELECT reset_generation INTO current_generation
  FROM public.tenant_demo_states WHERE tenant_id = NEW.tenant_id;
  IF current_generation IS NULL OR NEW.reset_generation <> current_generation THEN
    RAISE EXCEPTION 'stale reset generation' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;
ALTER FUNCTION ritual_private.enforce_current_reset_generation() OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.enforce_current_reset_generation() FROM PUBLIC;
GRANT SELECT ON TABLE tenant_demo_states TO ritual_function_owner;
CREATE TRIGGER idempotency_records_current_generation BEFORE INSERT ON idempotency_records FOR EACH ROW EXECUTE FUNCTION ritual_private.enforce_current_reset_generation();
CREATE TRIGGER simulation_commands_current_generation BEFORE INSERT ON simulation_commands FOR EACH ROW EXECUTE FUNCTION ritual_private.enforce_current_reset_generation();
CREATE TRIGGER recurring_plan_runs_current_generation BEFORE INSERT ON recurring_plan_runs FOR EACH ROW EXECUTE FUNCTION ritual_private.enforce_current_reset_generation();
CREATE TRIGGER rebalance_previews_current_generation BEFORE INSERT ON rebalance_previews FOR EACH ROW EXECUTE FUNCTION ritual_private.enforce_current_reset_generation();

CREATE OR REPLACE FUNCTION ritual_private.validate_simulation_command_ledger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE transaction_count integer;
DECLARE posting_count integer;
BEGIN
  SELECT count(*) INTO transaction_count FROM public.ledger_transactions
    WHERE tenant_id = NEW.tenant_id AND command_id = NEW.id;
  SELECT count(*) INTO posting_count
  FROM public.ledger_transactions AS transaction
  LEFT JOIN public.cash_ledger_entries AS cash
    ON cash.tenant_id = transaction.tenant_id AND cash.transaction_id = transaction.id
  LEFT JOIN public.position_ledger_entries AS position
    ON position.tenant_id = transaction.tenant_id AND position.transaction_id = transaction.id
  WHERE transaction.tenant_id = NEW.tenant_id AND transaction.command_id = NEW.id
    AND (cash.id IS NOT NULL OR position.id IS NOT NULL);
  IF NEW.status = 'committed' AND (transaction_count <> 1 OR posting_count < 1) THEN
    RAISE EXCEPTION 'committed command requires exactly one posted ledger transaction' USING ERRCODE = '23514';
  END IF;
  IF NEW.status = 'rejected' AND transaction_count <> 0 THEN
    RAISE EXCEPTION 'rejected command cannot have a ledger effect' USING ERRCODE = '23514';
  END IF;
  RETURN NULL;
END
$$;
ALTER FUNCTION ritual_private.validate_simulation_command_ledger() OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.validate_simulation_command_ledger() FROM PUBLIC;
GRANT SELECT ON TABLE ledger_transactions, cash_ledger_entries, position_ledger_entries TO ritual_function_owner;
CREATE CONSTRAINT TRIGGER simulation_commands_ledger_invariant
AFTER INSERT ON simulation_commands DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION ritual_private.validate_simulation_command_ledger();

CREATE OR REPLACE FUNCTION ritual_private.validate_order_fill_invariant()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE fill_count integer;
BEGIN
  SELECT count(*) INTO fill_count FROM public.simulated_order_fills
    WHERE tenant_id = NEW.tenant_id AND order_id = NEW.id;
  IF (NEW.status = 'accepted' AND fill_count <> 1) OR (NEW.status = 'rejected' AND fill_count <> 0) THEN
    RAISE EXCEPTION 'accepted order requires one fill and rejected order requires none' USING ERRCODE = '23514';
  END IF;
  RETURN NULL;
END
$$;
ALTER FUNCTION ritual_private.validate_order_fill_invariant() OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.validate_order_fill_invariant() FROM PUBLIC;
GRANT SELECT ON TABLE simulated_order_fills TO ritual_function_owner;
CREATE CONSTRAINT TRIGGER simulated_orders_fill_invariant
AFTER INSERT ON simulated_orders DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION ritual_private.validate_order_fill_invariant();

CREATE TRIGGER consent_records_immutable BEFORE UPDATE OR DELETE ON consent_records FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER editorial_revisions_immutable BEFORE UPDATE OR DELETE ON editorial_revisions FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER editorial_review_requests_immutable BEFORE UPDATE OR DELETE ON editorial_review_requests FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER editorial_review_decisions_immutable BEFORE UPDATE OR DELETE ON editorial_review_decisions FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER publication_events_immutable BEFORE UPDATE OR DELETE ON publication_events FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER asset_metric_snapshots_immutable BEFORE UPDATE OR DELETE ON asset_metric_snapshots FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER evidence_claims_immutable BEFORE UPDATE OR DELETE ON evidence_claims FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER ritual_scenario_revisions_immutable BEFORE UPDATE OR DELETE ON ritual_scenario_revisions FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER ritual_scenario_ideas_immutable BEFORE UPDATE OR DELETE ON ritual_scenario_ideas FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER ritual_scenario_evidence_immutable BEFORE UPDATE OR DELETE ON ritual_scenario_evidence FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER rowan_script_revisions_immutable BEFORE UPDATE OR DELETE ON rowan_script_revisions FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER asset_codex_revisions_immutable BEFORE UPDATE OR DELETE ON asset_codex_revisions FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER asset_codex_risks_immutable BEFORE UPDATE OR DELETE ON asset_codex_risks FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER asset_codex_evidence_immutable BEFORE UPDATE OR DELETE ON asset_codex_evidence FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER coven_entry_revisions_immutable BEFORE UPDATE OR DELETE ON coven_entry_revisions FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER coven_verifications_immutable BEFORE UPDATE OR DELETE ON coven_verifications FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER coven_verification_evidence_immutable BEFORE UPDATE OR DELETE ON coven_verification_evidence FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER grimoire_revisions_immutable BEFORE UPDATE OR DELETE ON grimoire_revisions FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER grimoire_revision_assets_immutable BEFORE UPDATE OR DELETE ON grimoire_revision_assets FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER circle_template_revisions_immutable BEFORE UPDATE OR DELETE ON circle_template_revisions FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER circle_template_assets_immutable BEFORE UPDATE OR DELETE ON circle_template_assets FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER demo_seed_versions_immutable BEFORE UPDATE OR DELETE ON demo_seed_versions FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER simulation_commands_immutable BEFORE UPDATE OR DELETE ON simulation_commands FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER simulated_orders_immutable BEFORE UPDATE OR DELETE ON simulated_orders FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER simulated_order_fills_immutable BEFORE UPDATE OR DELETE ON simulated_order_fills FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER ledger_transactions_immutable BEFORE UPDATE OR DELETE ON ledger_transactions FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER cash_ledger_entries_immutable BEFORE UPDATE OR DELETE ON cash_ledger_entries FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER position_ledger_entries_immutable BEFORE UPDATE OR DELETE ON position_ledger_entries FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER portfolio_balance_snapshots_immutable BEFORE UPDATE OR DELETE ON portfolio_balance_snapshots FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER recurring_plan_runs_immutable BEFORE UPDATE OR DELETE ON recurring_plan_runs FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER projection_runs_immutable BEFORE UPDATE OR DELETE ON projection_runs FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER projection_points_immutable BEFORE UPDATE OR DELETE ON projection_points FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER briefing_sections_immutable BEFORE UPDATE OR DELETE ON briefing_sections FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER entitlement_events_immutable BEFORE UPDATE OR DELETE ON entitlement_events FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER notification_deliveries_immutable BEFORE UPDATE OR DELETE ON notification_deliveries FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER admin_audit_events_immutable BEFORE UPDATE OR DELETE ON admin_audit_events FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER security_events_immutable BEFORE UPDATE OR DELETE ON security_events FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER outbox_events_immutable BEFORE UPDATE OR DELETE ON outbox_events FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER job_runs_immutable BEFORE UPDATE OR DELETE ON job_runs FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER consumer_receipts_immutable BEFORE UPDATE OR DELETE ON consumer_receipts FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER deletion_tombstones_immutable BEFORE UPDATE OR DELETE ON deletion_tombstones FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER purge_receipts_immutable BEFORE UPDATE OR DELETE ON purge_receipts FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();

CREATE OR REPLACE FUNCTION ritual_private.claim_due_outbox(consumer_name text, lease_seconds integer)
RETURNS TABLE (outbox_id uuid, tenant_id uuid, reset_generation integer, aggregate_version integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, ritual_private
AS $$
DECLARE selected_event outbox_events%ROWTYPE;
BEGIN
  IF char_length(consumer_name) NOT BETWEEN 1 AND 64 OR lease_seconds NOT BETWEEN 5 AND 300 THEN
    RAISE EXCEPTION 'invalid scheduler lease';
  END IF;
  SELECT * INTO selected_event FROM outbox_events
  WHERE published_at IS NULL AND available_at <= now()
  ORDER BY available_at, id FOR UPDATE SKIP LOCKED LIMIT 1;
  IF NOT FOUND THEN RETURN; END IF;
  INSERT INTO job_runs(outbox_id, consumer, status, attempt, lease_until, correlation_id)
  VALUES (selected_event.id, consumer_name, 'leased',
    COALESCE((SELECT max(attempt) + 1 FROM job_runs WHERE job_runs.outbox_id = selected_event.id AND job_runs.consumer = consumer_name), 0),
    now() + make_interval(secs => lease_seconds), gen_random_uuid());
  RETURN QUERY SELECT selected_event.id, selected_event.tenant_id, selected_event.reset_generation, selected_event.aggregate_version;
END
$$;
ALTER FUNCTION ritual_private.claim_due_outbox(text, integer) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.claim_due_outbox(text, integer) FROM PUBLIC;
GRANT SELECT ON TABLE outbox_events, job_runs TO ritual_function_owner;
GRANT INSERT ON TABLE job_runs TO ritual_function_owner;
GRANT USAGE ON SCHEMA ritual_private TO ritual_scheduler;
GRANT EXECUTE ON FUNCTION ritual_private.claim_due_outbox(text, integer) TO ritual_scheduler;

CREATE OR REPLACE FUNCTION ritual_private.purge_tombstoned_tenant(target_tombstone_id uuid, target_generation integer)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, ritual_private
AS $$
DECLARE target_tenant_id uuid;
DECLARE receipt_id uuid;
DECLARE tombstone_status text;
BEGIN
  SELECT tenant_id, status INTO target_tenant_id, tombstone_status FROM deletion_tombstones
  WHERE id = target_tombstone_id AND purge_generation = target_generation
  FOR UPDATE;
  IF tombstone_status = 'purged' THEN
    SELECT id INTO receipt_id FROM purge_receipts
      WHERE tombstone_id = target_tombstone_id AND purge_generation = target_generation;
    IF receipt_id IS NULL THEN RAISE EXCEPTION 'purged tombstone has no receipt'; END IF;
    RETURN receipt_id;
  END IF;
  IF target_tenant_id IS NULL OR tombstone_status NOT IN ('pending','purging')
    OR NOT EXISTS (SELECT 1 FROM tenants WHERE id = target_tenant_id AND status = 'purging') THEN
    RAISE EXCEPTION 'purge scope is not authorized';
  END IF;
  INSERT INTO ritual_private.purge_guards(backend_pid, transaction_id, tenant_id, tombstone_id)
  VALUES (pg_backend_pid(), txid_current(), target_tenant_id, target_tombstone_id);
  PERFORM set_config('ritual.tenant_id', target_tenant_id::text, true);
  UPDATE deletion_tombstones SET status = 'purging' WHERE id = target_tombstone_id;
  DELETE FROM tenants WHERE id = target_tenant_id;
  UPDATE deletion_tombstones SET status = 'purged' WHERE id = target_tombstone_id;
  INSERT INTO purge_receipts(tombstone_id, purge_generation, started_at, completed_at, outcome_hash)
  VALUES (target_tombstone_id, target_generation, statement_timestamp(), clock_timestamp(), encode(digest(target_tombstone_id::text || ':' || target_generation::text, 'sha256'), 'hex'))
  ON CONFLICT (tombstone_id, purge_generation) DO NOTHING
  RETURNING id INTO receipt_id;
  IF receipt_id IS NULL THEN
    SELECT id INTO receipt_id FROM purge_receipts
      WHERE tombstone_id = target_tombstone_id AND purge_generation = target_generation;
  END IF;
  DELETE FROM ritual_private.purge_guards WHERE backend_pid = pg_backend_pid() AND transaction_id = txid_current();
  RETURN receipt_id;
END
$$;
ALTER FUNCTION ritual_private.purge_tombstoned_tenant(uuid, integer) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.purge_tombstoned_tenant(uuid, integer) FROM PUBLIC;
GRANT SELECT, UPDATE ON TABLE deletion_tombstones TO ritual_function_owner;
GRANT SELECT, DELETE ON TABLE tenants TO ritual_function_owner;
GRANT SELECT, INSERT, UPDATE ON TABLE purge_receipts TO ritual_function_owner;
GRANT SELECT, INSERT, DELETE ON TABLE ritual_private.purge_guards TO ritual_function_owner;
GRANT USAGE ON SCHEMA ritual_private TO ritual_privacy_purge;
GRANT EXECUTE ON FUNCTION ritual_private.purge_tombstoned_tenant(uuid, integer) TO ritual_privacy_purge;

DO $$ BEGIN
  EXECUTE format('REVOKE ritual_function_owner FROM %I', current_user);
END $$;

REVOKE CREATE ON SCHEMA ritual_private FROM ritual_function_owner;

COMMIT;
