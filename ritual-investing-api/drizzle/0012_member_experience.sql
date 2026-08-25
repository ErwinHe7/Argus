BEGIN;

DO $$ BEGIN
  EXECUTE format(
    'GRANT ritual_function_owner TO %I WITH INHERIT TRUE, SET TRUE',
    current_user
  );
END $$;
GRANT CREATE ON SCHEMA ritual_private TO ritual_function_owner;

ALTER TABLE preferences
  ADD COLUMN IF NOT EXISTS ritual_familiarity text,
  ADD COLUMN IF NOT EXISTS ritual_language text,
  ADD COLUMN IF NOT EXISTS ritual_interests jsonb;
ALTER TABLE preferences DROP CONSTRAINT IF EXISTS preferences_ritual_personalization_check;
ALTER TABLE preferences ADD CONSTRAINT preferences_ritual_personalization_check CHECK (
  (ritual_familiarity IS NULL OR ritual_familiarity IN
    ('new','curious','familiar','practiced','prefer_not_to_say'))
  AND (ritual_language IS NULL OR ritual_language IN
    ('practical','balanced','mystical','prefer_not_to_say'))
  AND (ritual_interests IS NULL OR (
    jsonb_typeof(ritual_interests)='array'
    AND jsonb_array_length(ritual_interests) BETWEEN 1 AND 5
    AND ritual_interests <@ '["practical_research","tarot","astrology","moon_cycles","reflection"]'::jsonb
  ))
);

ALTER TABLE investor_profiles
  ADD COLUMN IF NOT EXISTS investing_experience text,
  ADD COLUMN IF NOT EXISTS contribution_rhythm text;
ALTER TABLE investor_profiles DROP CONSTRAINT IF EXISTS investor_profiles_personalization_check;
ALTER TABLE investor_profiles ADD CONSTRAINT investor_profiles_personalization_check CHECK (
  (investing_experience IS NULL OR investing_experience IN
    ('new','some_experience','experienced'))
  AND (contribution_rhythm IS NULL OR contribution_rhythm IN
    ('weekly','biweekly','monthly','irregular','not_sure'))
);

ALTER TABLE onboarding_states
  ADD COLUMN IF NOT EXISTS schema_version integer,
  ADD COLUMN IF NOT EXISTS cohort text;
UPDATE onboarding_states
   SET schema_version=coalesce(schema_version,1),
       cohort=coalesce(
         cohort,
         CASE WHEN current_step='complete'
           THEN 'legacy_complete_v1'
           ELSE 'legacy_incomplete_v1'
         END
       );
ALTER TABLE onboarding_states
  ALTER COLUMN schema_version SET DEFAULT 2,
  ALTER COLUMN schema_version SET NOT NULL,
  ALTER COLUMN cohort SET DEFAULT 'member_v2',
  ALTER COLUMN cohort SET NOT NULL;
ALTER TABLE onboarding_states DROP CONSTRAINT IF EXISTS onboarding_states_schema_cohort_check;
ALTER TABLE onboarding_states ADD CONSTRAINT onboarding_states_schema_cohort_check CHECK (
  schema_version IN (1,2)
  AND cohort IN ('legacy_complete_v1','legacy_incomplete_v1','member_v2')
  AND (cohort <> 'member_v2' OR schema_version=2)
);

CREATE TABLE IF NOT EXISTS onboarding_finalization_commands (
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  command_key text NOT NULL CHECK (command_key ~ '^[!-~]{16,64}$'),
  request_hash text NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$'),
  response jsonb NOT NULL CHECK (jsonb_typeof(response)='object'),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT onboarding_finalization_commands_tenant_key_unique
    UNIQUE (tenant_id,command_key)
);
ALTER TABLE onboarding_finalization_commands ENABLE ROW LEVEL SECURITY;
ALTER TABLE onboarding_finalization_commands FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON onboarding_finalization_commands;
CREATE POLICY tenant_isolation ON onboarding_finalization_commands
  USING (tenant_id=ritual_private.current_tenant_id())
  WITH CHECK (tenant_id=ritual_private.current_tenant_id());

CREATE OR REPLACE FUNCTION ritual_private.bootstrap_member_account_v2(verified_subject text)
RETURNS TABLE (
  account_id uuid,
  account_status text,
  display_name text,
  locale text,
  theme_mode text,
  ritual_mode text,
  ritual_familiarity text,
  ritual_language text,
  ritual_interests jsonb,
  timezone text,
  preferences_version integer,
  current_step text,
  completed_steps jsonb,
  completed_at timestamptz,
  onboarding_schema_version integer,
  onboarding_cohort text,
  onboarding_version integer,
  investor_goal_type text,
  investor_time_horizon text,
  investor_risk_comfort text,
  investing_experience text,
  contribution_rhythm text,
  investor_version integer,
  astrology_birth_date date,
  derived_profile_code text,
  astrology_algorithm_version text,
  astrology_enabled_at timestamptz,
  astrology_version integer,
  plan_code text,
  entitlement_status text,
  portfolio_id uuid,
  portfolio_name text,
  portfolio_currency text,
  portfolio_status text,
  portfolio_version integer,
  reset_generation integer,
  server_time timestamptz
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, public, ritual_private
AS $$
BEGIN
  PERFORM 1
    FROM ritual_private.bootstrap_member_account_u3(verified_subject);

  RETURN QUERY
  SELECT
    account.id,
    account.status,
    profile.display_name,
    profile.locale,
    preference.theme_mode,
    preference.ritual_mode,
    preference.ritual_familiarity,
    preference.ritual_language,
    preference.ritual_interests,
    preference.timezone,
    preference.version,
    onboarding.current_step,
    onboarding.completed_steps,
    onboarding.completed_at,
    onboarding.schema_version,
    onboarding.cohort,
    onboarding.version,
    investor.goal_type,
    investor.time_horizon,
    investor.risk_comfort,
    investor.investing_experience,
    investor.contribution_rhythm,
    investor.version,
    astrology.birth_date,
    astrology.derived_profile_code,
    astrology.algorithm_version,
    astrology.enabled_at,
    astrology.version,
    plan.code,
    entitlement.status,
    portfolio.id,
    portfolio.name,
    portfolio.currency,
    portfolio.status,
    portfolio.version,
    state.reset_generation,
    clock_timestamp()
  FROM accounts account
  JOIN profiles profile ON profile.tenant_id=account.tenant_id
  JOIN preferences preference ON preference.tenant_id=account.tenant_id
  JOIN onboarding_states onboarding ON onboarding.tenant_id=account.tenant_id
  JOIN tenant_demo_states state ON state.tenant_id=account.tenant_id
  JOIN tenant_entitlements entitlement
    ON entitlement.tenant_id=account.tenant_id
   AND entitlement.reset_generation=state.reset_generation
   AND entitlement.status='active'
  JOIN demo_plans plan ON plan.id=entitlement.plan_id
  JOIN demo_portfolios portfolio
    ON portfolio.tenant_id=account.tenant_id
   AND portfolio.reset_generation=state.reset_generation
   AND portfolio.is_default
   AND portfolio.status='active'
  LEFT JOIN investor_profiles investor ON investor.tenant_id=account.tenant_id
  LEFT JOIN astrology_profiles astrology ON astrology.tenant_id=account.tenant_id
  WHERE account.auth0_subject=verified_subject
  LIMIT 1;
END
$$;
ALTER FUNCTION ritual_private.bootstrap_member_account_v2(text)
  OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.bootstrap_member_account_v2(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.bootstrap_member_account_v2(text)
  TO ritual_bootstrap;

CREATE OR REPLACE FUNCTION ritual_private.finalize_member_onboarding(
  verified_subject text,
  p_command_key text,
  p_request_hash text,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, public, ritual_private
AS $$
DECLARE
  v_account accounts%ROWTYPE;
  v_onboarding onboarding_states%ROWTYPE;
  v_existing onboarding_finalization_commands%ROWTYPE;
  v_response jsonb;
  v_enabled boolean;
  v_birth_date date;
  v_profile_code text;
  v_completed_at timestamptz;
BEGIN
  PERFORM 1 FROM ritual_private.bootstrap_member_account_v2(verified_subject);
  SELECT * INTO STRICT v_account
    FROM accounts
   WHERE auth0_subject=verified_subject
     AND status='active'
   FOR UPDATE;

  SELECT * INTO v_existing
    FROM onboarding_finalization_commands
   WHERE tenant_id=v_account.tenant_id AND command_key=p_command_key
   FOR UPDATE;
  IF FOUND THEN
    IF v_existing.request_hash <> p_request_hash THEN
      RAISE EXCEPTION 'onboarding_idempotency_conflict';
    END IF;
    RETURN v_existing.response;
  END IF;

  SELECT * INTO STRICT v_onboarding
    FROM onboarding_states
   WHERE tenant_id=v_account.tenant_id
   FOR UPDATE;
  IF v_onboarding.current_step='complete' THEN
    RAISE EXCEPTION 'onboarding_completed';
  END IF;
  IF (p_payload->>'schema_version')::integer <> 2
     OR (p_payload->>'expected_onboarding_version')::integer <> v_onboarding.version THEN
    RAISE EXCEPTION 'onboarding_version_conflict';
  END IF;
  IF p_payload#>>'{consents,terms,policy_version}' <> '2026-08'
     OR p_payload#>>'{consents,terms,decision}' <> 'accepted'
     OR p_payload#>>'{consents,privacy,policy_version}' <> '2026-08'
     OR p_payload#>>'{consents,privacy,decision}' <> 'accepted'
     OR p_payload#>>'{consents,demo_disclosure,policy_version}' <> '2026-08'
     OR p_payload#>>'{consents,demo_disclosure,decision}' <> 'accepted'
     OR p_payload#>>'{consents,astrology,policy_version}' <> '2026-08' THEN
    RAISE EXCEPTION 'onboarding_policy_invalid';
  END IF;

  v_enabled := (p_payload#>>'{astrology,enabled}')::boolean;
  IF v_enabled IS DISTINCT FROM
       (p_payload#>>'{consents,astrology,decision}'='accepted')
     OR (v_enabled AND p_payload#>>'{astrology,birth_date}' IS NULL)
     OR (NOT v_enabled AND p_payload#>>'{astrology,birth_date}' IS NOT NULL)
     OR (p_payload->'astrology') - 'enabled' - 'birth_date' <> '{}'::jsonb THEN
    RAISE EXCEPTION 'onboarding_consent_invalid';
  END IF;

  UPDATE preferences
     SET ritual_mode=CASE WHEN v_enabled THEN 'astrology' ELSE 'tarot' END,
         ritual_familiarity=p_payload#>>'{ritual,familiarity}',
         ritual_language=p_payload#>>'{ritual,language_preference}',
         ritual_interests=p_payload#>'{ritual,interests}',
         version=version+1
   WHERE tenant_id=v_account.tenant_id;

  INSERT INTO investor_profiles(
    tenant_id,goal_type,time_horizon,risk_comfort,investing_experience,
    contribution_rhythm,version
  ) VALUES (
    v_account.tenant_id,
    p_payload#>>'{investing,goal_type}',
    p_payload#>>'{investing,time_horizon}',
    p_payload#>>'{investing,risk_comfort}',
    p_payload#>>'{investing,experience}',
    p_payload#>>'{investing,contribution_rhythm}',
    1
  )
  ON CONFLICT (tenant_id) DO UPDATE SET
    goal_type=excluded.goal_type,
    time_horizon=excluded.time_horizon,
    risk_comfort=excluded.risk_comfort,
    investing_experience=excluded.investing_experience,
    contribution_rhythm=excluded.contribution_rhythm,
    version=investor_profiles.version+1;

  IF v_enabled THEN
    v_birth_date := (p_payload#>>'{astrology,birth_date}')::date;
    v_profile_code := (ARRAY[
      'lunar_patient','solar_builder','rising_explorer'
    ])[1 + abs(v_birth_date-DATE '1970-01-01') % 3];
    INSERT INTO astrology_profiles(
      tenant_id,birth_date,derived_profile_code,algorithm_version,version
    ) VALUES (v_account.tenant_id,v_birth_date,v_profile_code,'v1',1)
    ON CONFLICT (tenant_id) DO UPDATE SET
      birth_date=excluded.birth_date,
      derived_profile_code=excluded.derived_profile_code,
      algorithm_version='v1',
      enabled_at=clock_timestamp(),
      version=astrology_profiles.version+1;
  ELSE
    DELETE FROM astrology_profiles WHERE tenant_id=v_account.tenant_id;
  END IF;

  INSERT INTO consent_records(tenant_id,policy_code,policy_version,decision)
  VALUES
    (v_account.tenant_id,'terms','2026-08','accepted'),
    (v_account.tenant_id,'privacy','2026-08','accepted'),
    (v_account.tenant_id,'demo_disclosure','2026-08','accepted'),
    (v_account.tenant_id,'astrology','2026-08',
      CASE WHEN v_enabled THEN 'accepted' ELSE 'declined' END)
  ON CONFLICT (tenant_id,policy_code,policy_version,decision) DO NOTHING;

  v_completed_at := clock_timestamp();
  UPDATE onboarding_states
     SET current_step='complete',
         completed_steps='["welcome","ritual","profile"]'::jsonb,
         completed_at=v_completed_at,
         schema_version=2,
         cohort='member_v2',
         version=version+1
   WHERE tenant_id=v_account.tenant_id AND version=v_onboarding.version;
  IF NOT FOUND THEN RAISE EXCEPTION 'onboarding_version_conflict'; END IF;

  SELECT jsonb_build_object(
    'account',jsonb_build_object('id',snapshot.account_id,'status',snapshot.account_status),
    'profile',jsonb_build_object('display_name',snapshot.display_name,'locale',snapshot.locale),
    'preferences',jsonb_build_object(
      'theme_mode',snapshot.theme_mode,'ritual_mode',snapshot.ritual_mode,
      'ritual_familiarity',snapshot.ritual_familiarity,
      'ritual_language',snapshot.ritual_language,
      'ritual_interests',snapshot.ritual_interests,
      'timezone',snapshot.timezone,'locale',snapshot.locale,
      'version',snapshot.preferences_version
    ),
    'investor_profile',jsonb_build_object(
      'experience',snapshot.investing_experience,
      'goal_type',snapshot.investor_goal_type,
      'time_horizon',snapshot.investor_time_horizon,
      'risk_comfort',snapshot.investor_risk_comfort,
      'contribution_rhythm',snapshot.contribution_rhythm,
      'version',snapshot.investor_version,'is_demo',true
    ),
    'astrology_profile',CASE WHEN snapshot.astrology_birth_date IS NULL THEN NULL ELSE
      jsonb_build_object(
        'birth_date',snapshot.astrology_birth_date,
        'derived_profile_code',snapshot.derived_profile_code,
        'algorithm_version',snapshot.astrology_algorithm_version,
        'enabled_at',snapshot.astrology_enabled_at,
        'version',snapshot.astrology_version
      ) END,
    'onboarding',jsonb_build_object(
      'current_step',snapshot.current_step,
      'completed_steps',snapshot.completed_steps,
      'completed_at',snapshot.completed_at,
      'schema_version',snapshot.onboarding_schema_version,
      'cohort',snapshot.onboarding_cohort,
      'version',snapshot.onboarding_version
    ),
    'entitlement',jsonb_build_object(
      'plan_code',snapshot.plan_code,'status',snapshot.entitlement_status
    ),
    'default_portfolio',jsonb_build_object(
      'id',snapshot.portfolio_id,'name',snapshot.portfolio_name,
      'currency',snapshot.portfolio_currency,'status',snapshot.portfolio_status,
      'version',snapshot.portfolio_version
    ),
    'reset_generation',snapshot.reset_generation,
    'server_time',v_completed_at,
    'contract_version','1.0.0'
  ) INTO STRICT v_response
  FROM ritual_private.bootstrap_member_account_v2(verified_subject) snapshot;

  INSERT INTO onboarding_finalization_commands(
    tenant_id,command_key,request_hash,response
  ) VALUES (v_account.tenant_id,p_command_key,p_request_hash,v_response);
  RETURN v_response;
EXCEPTION
  WHEN no_data_found THEN
    RAISE EXCEPTION 'subject_not_eligible';
END
$$;
ALTER FUNCTION ritual_private.finalize_member_onboarding(text,text,text,jsonb)
  OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.finalize_member_onboarding(text,text,text,jsonb)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.finalize_member_onboarding(text,text,text,jsonb)
  TO ritual_bootstrap;

GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE
  preferences,investor_profiles,astrology_profiles,onboarding_states,
  consent_records,onboarding_finalization_commands
  TO ritual_function_owner;

INSERT INTO ritual_private.schema_contract_versions(version,compatibility)
VALUES ('member-experience-v2-n','n')
ON CONFLICT (version) DO NOTHING;

REVOKE CREATE ON SCHEMA ritual_private FROM ritual_function_owner;
DO $$ BEGIN
  EXECUTE format('REVOKE ritual_function_owner FROM %I', current_user);
END $$;

COMMIT;
