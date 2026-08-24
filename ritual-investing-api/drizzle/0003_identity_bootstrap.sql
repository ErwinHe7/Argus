BEGIN;

DO $$ BEGIN
  CREATE ROLE ritual_bootstrap NOINHERIT NOLOGIN NOBYPASSRLS;
EXCEPTION WHEN duplicate_object THEN
  ALTER ROLE ritual_bootstrap NOINHERIT NOLOGIN NOBYPASSRLS;
END $$;
DO $$ BEGIN
  CREATE ROLE ritual_staff_resolver NOINHERIT NOLOGIN NOBYPASSRLS;
EXCEPTION WHEN duplicate_object THEN
  ALTER ROLE ritual_staff_resolver NOINHERIT NOLOGIN NOBYPASSRLS;
END $$;

INSERT INTO demo_seed_versions(id, version, fixture_hash, published_at, is_current)
SELECT
  '00000000-0000-4000-8000-000000000301'::uuid,
  1,
  'ritual-demo-seed-v1',
  '2026-08-23T00:00:00Z'::timestamptz,
  NOT EXISTS (SELECT 1 FROM demo_seed_versions WHERE is_current)
ON CONFLICT (id) DO NOTHING;

INSERT INTO demo_plans(id, code, display_name, price_copy, feature_codes, status)
VALUES (
  '00000000-0000-4000-8000-000000000302'::uuid,
  'demo',
  'Ritual Demo',
  'Simulated access only — no charge',
  '["daily_ritual","demo_portfolio"]'::jsonb,
  'active'
)
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION ritual_private.resolve_staff_principal(
  verified_auth0_subject text,
  verified_access_identity text,
  verified_client_id text
)
RETURNS TABLE (
  id uuid,
  auth0_subject text,
  access_identity text,
  allowed_client_id text,
  display_label text,
  revocation_epoch integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT
    staff.id,
    staff.auth0_subject,
    staff.access_identity,
    staff.allowed_client_id,
    staff.display_label,
    staff.revocation_epoch
  FROM public.staff_principals AS staff
  WHERE staff.auth0_subject = verified_auth0_subject
    AND lower(staff.access_identity) = lower(verified_access_identity)
    AND staff.allowed_client_id = verified_client_id
    AND staff.status = 'active'
  LIMIT 1
$$;
ALTER FUNCTION ritual_private.resolve_staff_principal(text, text, text) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.resolve_staff_principal(text, text, text) FROM PUBLIC;
GRANT SELECT ON TABLE staff_principals TO ritual_function_owner;
GRANT USAGE ON SCHEMA ritual_private TO ritual_staff_resolver;
GRANT EXECUTE ON FUNCTION ritual_private.resolve_staff_principal(text, text, text) TO ritual_staff_resolver;

CREATE OR REPLACE FUNCTION ritual_private.bootstrap_member_account(verified_subject text)
RETURNS TABLE (
  account_id uuid,
  account_status text,
  display_name text,
  locale text,
  theme_mode text,
  ritual_mode text,
  timezone text,
  preferences_version integer,
  current_step text,
  completed_steps jsonb,
  onboarding_version integer,
  plan_code text,
  entitlement_status text,
  portfolio_id uuid,
  portfolio_name text,
  portfolio_currency text,
  portfolio_status text,
  portfolio_version integer,
  server_time timestamptz
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, public, ritual_private
AS $$
DECLARE
  existing_account public.accounts%ROWTYPE;
  existing_tenant public.tenants%ROWTYPE;
  new_tenant_id uuid;
  new_account_id uuid;
  new_portfolio_id uuid;
  selected_seed_id uuid;
  selected_seed_version integer;
  selected_plan_id uuid;
BEGIN
  IF verified_subject IS NULL OR char_length(verified_subject) NOT BETWEEN 1 AND 255 THEN
    RAISE EXCEPTION 'subject_not_eligible' USING ERRCODE = 'P0001';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(verified_subject, 0));

  IF EXISTS (
    SELECT 1
    FROM public.deletion_tombstones AS tombstone
    WHERE tombstone.subject_hash = encode(digest(verified_subject, 'sha256'), 'hex')
  ) THEN
    RAISE EXCEPTION 'subject_previously_deleted' USING ERRCODE = 'P0001';
  END IF;

  SELECT account.* INTO existing_account
  FROM public.accounts AS account
  WHERE account.auth0_subject = verified_subject;

  IF FOUND THEN
    SELECT tenant.* INTO existing_tenant
    FROM public.tenants AS tenant
    WHERE tenant.id = existing_account.tenant_id;

    IF existing_account.status <> 'active' OR existing_tenant.status <> 'active' THEN
      RAISE EXCEPTION 'subject_not_eligible' USING ERRCODE = 'P0001';
    END IF;
    new_tenant_id := existing_account.tenant_id;
    new_account_id := existing_account.id;
  ELSE
    SELECT seed.id, seed.version INTO selected_seed_id, selected_seed_version
    FROM public.demo_seed_versions AS seed
    WHERE seed.is_current
    ORDER BY seed.version DESC
    LIMIT 1;
    SELECT plan.id INTO selected_plan_id
    FROM public.demo_plans AS plan
    WHERE plan.code = 'demo' AND plan.status = 'active'
    LIMIT 1;
    IF selected_seed_id IS NULL OR selected_plan_id IS NULL THEN
      RAISE EXCEPTION 'bootstrap_fixture_unavailable' USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO public.tenants(status, seed_version)
    VALUES ('provisioning', selected_seed_version)
    RETURNING id INTO new_tenant_id;
    INSERT INTO public.accounts(tenant_id, auth0_subject, status)
    VALUES (new_tenant_id, verified_subject, 'active')
    RETURNING id INTO new_account_id;
    INSERT INTO public.profiles(tenant_id, display_name, locale)
    VALUES (new_tenant_id, 'Ritual Member', 'en-US');
    INSERT INTO public.preferences(tenant_id, theme_mode, ritual_mode, timezone, locale)
    VALUES (new_tenant_id, 'system', 'tarot', 'UTC', 'en-US');
    INSERT INTO public.onboarding_states(tenant_id, current_step, completed_steps)
    VALUES (new_tenant_id, 'welcome', '[]'::jsonb);
    INSERT INTO public.notification_preferences(tenant_id)
    VALUES (new_tenant_id);
    INSERT INTO public.tenant_demo_states(tenant_id, seed_version_id)
    VALUES (new_tenant_id, selected_seed_id);
    INSERT INTO public.demo_portfolios(tenant_id, name, currency, status)
    VALUES (new_tenant_id, 'Demo Portfolio', 'USD', 'active')
    RETURNING id INTO new_portfolio_id;
    INSERT INTO public.tenant_entitlements(tenant_id, plan_id, status, source, starts_at)
    VALUES (new_tenant_id, selected_plan_id, 'active', 'demo', now());
    UPDATE public.tenants SET status = 'active' WHERE id = new_tenant_id;
  END IF;

  RETURN QUERY
  SELECT
    account.id,
    account.status,
    profile.display_name,
    profile.locale,
    preference.theme_mode,
    preference.ritual_mode,
    preference.timezone,
    preference.version,
    onboarding.current_step,
    onboarding.completed_steps,
    onboarding.version,
    plan.code,
    entitlement.status,
    portfolio.id,
    portfolio.name,
    portfolio.currency,
    portfolio.status,
    portfolio.version,
    now()
  FROM public.accounts AS account
  JOIN public.profiles AS profile ON profile.tenant_id = account.tenant_id
  JOIN public.preferences AS preference ON preference.tenant_id = account.tenant_id
  JOIN public.onboarding_states AS onboarding ON onboarding.tenant_id = account.tenant_id
  JOIN public.tenant_entitlements AS entitlement
    ON entitlement.tenant_id = account.tenant_id AND entitlement.status = 'active'
  JOIN public.demo_plans AS plan ON plan.id = entitlement.plan_id
  JOIN public.demo_portfolios AS portfolio
    ON portfolio.tenant_id = account.tenant_id AND portfolio.status = 'active'
  WHERE account.id = new_account_id
  ORDER BY portfolio.id
  LIMIT 1;
END
$$;
ALTER FUNCTION ritual_private.bootstrap_member_account(text) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.bootstrap_member_account(text) FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE ON TABLE tenants, accounts TO ritual_function_owner;
GRANT SELECT, INSERT ON TABLE profiles, preferences, onboarding_states, notification_preferences,
  tenant_demo_states, demo_portfolios, tenant_entitlements TO ritual_function_owner;
GRANT SELECT ON TABLE demo_seed_versions, demo_plans, deletion_tombstones TO ritual_function_owner;
GRANT USAGE ON SCHEMA ritual_private TO ritual_bootstrap;
GRANT EXECUTE ON FUNCTION ritual_private.bootstrap_member_account(text) TO ritual_bootstrap;

COMMIT;
