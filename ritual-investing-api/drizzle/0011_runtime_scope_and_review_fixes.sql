BEGIN;

DO $$ BEGIN
  EXECUTE format(
    'GRANT ritual_function_owner TO %I WITH INHERIT TRUE, SET TRUE',
    current_user
  );
END $$;
GRANT CREATE ON SCHEMA ritual_private TO ritual_function_owner;

-- Revalidate the resolved member identity inside the same transaction that
-- will touch tenant data. This closes the resolver/use race during deletion
-- or revocation without weakening the tenant RLS boundary.
CREATE OR REPLACE FUNCTION ritual_private.assert_runtime_scope()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM accounts account
      JOIN tenants tenant ON tenant.id=account.tenant_id
     WHERE account.id=nullif(current_setting('ritual.account_id',true),'')::uuid
       AND account.tenant_id=nullif(current_setting('ritual.tenant_id',true),'')::uuid
       AND account.auth0_subject=nullif(current_setting('ritual.principal',true),'')
       AND account.revocation_epoch=nullif(current_setting('ritual.revocation_epoch',true),'')::integer
       AND account.status='active'
       AND tenant.status='active'
  ) THEN
    RAISE EXCEPTION 'runtime scope is stale or invalid' USING ERRCODE='42501';
  END IF;
END
$$;
ALTER FUNCTION ritual_private.assert_runtime_scope() OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.assert_runtime_scope() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.assert_runtime_scope() TO ritual_runtime;

-- Weighted Circles must be replaced as one versioned set. Per-row mutations
-- remain useful for unweighted Circles but cannot preserve a 10,000 bps
-- invariant while changing two or more weighted rows.
CREATE OR REPLACE FUNCTION ritual_private.replace_circle_assets(
  p_tenant uuid,
  p_circle uuid,
  p_version integer,
  p_assets jsonb
)
RETURNS TABLE(ok boolean)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path=pg_catalog,public,ritual_private
AS $$
DECLARE asset_value jsonb;
DECLARE inserted integer;
BEGIN
  IF jsonb_typeof(p_assets) <> 'array' THEN RAISE EXCEPTION 'invalid_assets'; END IF;
  IF jsonb_array_length(p_assets) > 50 THEN RAISE EXCEPTION 'asset_cap'; END IF;
  IF (SELECT count(*) FROM jsonb_array_elements(p_assets)) <>
     (SELECT count(DISTINCT item->>'asset_id') FROM jsonb_array_elements(p_assets) item)
    THEN RAISE EXCEPTION 'duplicate_asset'; END IF;
  IF (SELECT count(*) FROM jsonb_array_elements(p_assets)) <>
     (SELECT count(DISTINCT item->>'ordinal') FROM jsonb_array_elements(p_assets) item)
    THEN RAISE EXCEPTION 'duplicate_ordinal'; END IF;
  IF (SELECT count(*) FROM jsonb_array_elements(p_assets) item WHERE item ? 'weight_bps')
       NOT IN (0,jsonb_array_length(p_assets))
    OR ((SELECT count(*) FROM jsonb_array_elements(p_assets) item WHERE item ? 'weight_bps') > 0
      AND (SELECT coalesce(sum((item->>'weight_bps')::integer),0)
             FROM jsonb_array_elements(p_assets) item) <> 10000)
    THEN RAISE EXCEPTION 'invalid_weight_total'; END IF;

  PERFORM 1 FROM circles WHERE tenant_id=p_tenant AND id=p_circle FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  IF NOT EXISTS(
    SELECT 1 FROM circles WHERE tenant_id=p_tenant AND id=p_circle AND version=p_version
  ) THEN RAISE EXCEPTION 'version_conflict'; END IF;

  DELETE FROM circle_assets WHERE tenant_id=p_tenant AND circle_id=p_circle;
  FOR asset_value IN SELECT value FROM jsonb_array_elements(p_assets) LOOP
    INSERT INTO circle_assets(tenant_id,circle_id,asset_id,ordinal,weight_bps,note)
      SELECT p_tenant,p_circle,asset.id,(asset_value->>'ordinal')::integer,
             (asset_value->>'weight_bps')::integer,asset_value->>'note'
        FROM assets asset
       WHERE asset.id=(asset_value->>'asset_id')::uuid
         AND asset.status='active' AND asset.is_demo;
    GET DIAGNOSTICS inserted=ROW_COUNT;
    IF inserted <> 1 THEN RAISE EXCEPTION 'invalid_child'; END IF;
  END LOOP;
  UPDATE circles SET version=version+1 WHERE tenant_id=p_tenant AND id=p_circle;
  RETURN QUERY SELECT true;
END
$$;
REVOKE ALL ON FUNCTION ritual_private.replace_circle_assets(uuid,uuid,integer,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.replace_circle_assets(uuid,uuid,integer,jsonb) TO ritual_runtime;

-- Permit a crashed, expired lease to be reclaimed with a fresh owner. Every
-- other job-run identity and transition remains append-only/monotonic.
CREATE OR REPLACE FUNCTION ritual_private.enforce_job_run_transition()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'job runs cannot be deleted' USING ERRCODE = '55000';
  END IF;
  IF ROW(NEW.id,NEW.outbox_id,NEW.consumer,NEW.attempt,NEW.correlation_id,
         NEW.created_at)
     IS DISTINCT FROM
     ROW(OLD.id,OLD.outbox_id,OLD.consumer,OLD.attempt,OLD.correlation_id,
         OLD.created_at) THEN
    RAISE EXCEPTION 'job run identity is immutable' USING ERRCODE = '55000';
  END IF;
  IF OLD.status='leased' AND NEW.status='leased' THEN
    IF OLD.lease_until IS NULL OR OLD.lease_until > now()
       OR NEW.lease_owner IS NULL OR NEW.lease_owner IS NOT DISTINCT FROM OLD.lease_owner
       OR NEW.lease_until IS NULL OR NEW.lease_until <= now()
       OR NEW.next_attempt_at IS NOT NULL OR NEW.failure_code IS NOT NULL
       OR NEW.completed_at IS NOT NULL THEN
      RAISE EXCEPTION 'invalid expired lease reclaim' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
  END IF;
  IF OLD.status='retry' AND NEW.status='leased' THEN
    IF OLD.lease_owner IS NOT NULL OR NEW.lease_owner IS NULL
       OR NEW.lease_until IS NULL OR NEW.next_attempt_at IS NOT NULL
       OR NEW.failure_code IS NOT NULL OR NEW.completed_at IS NOT NULL THEN
      RAISE EXCEPTION 'invalid retry lease claim' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
  END IF;
  IF NEW.lease_owner IS DISTINCT FROM OLD.lease_owner THEN
    RAISE EXCEPTION 'job run lease identity is immutable' USING ERRCODE = '55000';
  END IF;
  IF OLD.status <> 'leased' OR NEW.status NOT IN ('completed','retry','dead_letter') THEN
    RAISE EXCEPTION 'invalid job run transition' USING ERRCODE = '23514';
  END IF;
  IF NEW.status = 'completed' AND NEW.completed_at IS NULL THEN
    RAISE EXCEPTION 'completed job run requires completion time' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;

REVOKE CREATE ON SCHEMA ritual_private FROM ritual_function_owner;
DO $$ BEGIN
  EXECUTE format('REVOKE ritual_function_owner FROM %I', current_user);
END $$;

COMMIT;
