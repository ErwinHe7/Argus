BEGIN;

INSERT INTO ritual_private.schema_contract_versions(version, compatibility)
VALUES ('ritual-observability-v1-n', 'n')
ON CONFLICT (version) DO NOTHING;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ritual_audit_reconciler') THEN
    CREATE ROLE ritual_audit_reconciler NOLOGIN NOINHERIT;
  END IF;
END $$;
GRANT ritual_audit_reconciler TO CURRENT_USER;

CREATE TABLE admin_audit_checkpoints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cutoff_at timestamptz NOT NULL UNIQUE,
  event_count bigint NOT NULL CHECK (event_count >= 0),
  denied_count bigint NOT NULL CHECK (denied_count >= 0 AND denied_count <= event_count),
  chain_digest text NOT NULL CHECK (chain_digest ~ '^[0-9a-f]{64}$'),
  recorded_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER admin_audit_checkpoints_immutable
BEFORE UPDATE OR DELETE ON admin_audit_checkpoints
FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();

CREATE OR REPLACE FUNCTION ritual_private.record_admin_audit_checkpoint(
  target_cutoff timestamptz
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog,public,ritual_private
AS $$
DECLARE
  calculated_count bigint;
  calculated_denied bigint;
  calculated_digest text;
  checkpoint admin_audit_checkpoints%ROWTYPE;
BEGIN
  IF target_cutoff IS NULL OR target_cutoff > now() + interval '1 minute' THEN
    RAISE EXCEPTION 'invalid_checkpoint_cutoff';
  END IF;

  SELECT
    count(*),
    count(*) FILTER (WHERE outcome='denied'),
    encode(
      digest(
        coalesce(
          string_agg(
            id::text || ':' || action || ':' || outcome || ':' || request_id::text,
            '|' ORDER BY created_at,id
          ),
          ''
        ),
        'sha256'
      ),
      'hex'
    )
  INTO calculated_count,calculated_denied,calculated_digest
  FROM admin_audit_events
  WHERE created_at < target_cutoff;

  INSERT INTO admin_audit_checkpoints(cutoff_at,event_count,denied_count,chain_digest)
  VALUES(target_cutoff,calculated_count,calculated_denied,calculated_digest)
  ON CONFLICT (cutoff_at) DO NOTHING;

  SELECT * INTO checkpoint
  FROM admin_audit_checkpoints
  WHERE cutoff_at=target_cutoff;

  IF checkpoint.event_count<>calculated_count
     OR checkpoint.denied_count<>calculated_denied
     OR checkpoint.chain_digest<>calculated_digest THEN
    RAISE EXCEPTION 'audit_checkpoint_mismatch';
  END IF;

  RETURN jsonb_build_object(
    'checkpoint_id',checkpoint.id,
    'cutoff_at',checkpoint.cutoff_at,
    'event_count',checkpoint.event_count,
    'denied_count',checkpoint.denied_count,
    'chain_digest',checkpoint.chain_digest
  );
END $$;

ALTER FUNCTION ritual_private.record_admin_audit_checkpoint(timestamptz)
OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.record_admin_audit_checkpoint(timestamptz)
FROM PUBLIC;
REVOKE ALL ON TABLE admin_audit_checkpoints FROM PUBLIC;
GRANT SELECT,INSERT ON TABLE admin_audit_checkpoints TO ritual_function_owner;
GRANT USAGE ON SCHEMA ritual_private TO ritual_audit_reconciler;
GRANT SELECT ON TABLE admin_audit_checkpoints TO ritual_audit_reconciler;
GRANT EXECUTE ON FUNCTION ritual_private.record_admin_audit_checkpoint(timestamptz)
TO ritual_audit_reconciler;

COMMIT;
