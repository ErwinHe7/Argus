BEGIN;

-- These roles are capabilities inside a dedicated waitlist database. Runtime
-- and maintenance are changed to LOGIN only by the environment-local
-- provisioning script after their secrets exist.
DO $roles$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'waitlist_function_owner') THEN
    CREATE ROLE waitlist_function_owner;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'waitlist_runtime') THEN
    CREATE ROLE waitlist_runtime;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'waitlist_maintenance') THEN
    CREATE ROLE waitlist_maintenance;
  END IF;

  ALTER ROLE waitlist_function_owner NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOLOGIN NOREPLICATION NOBYPASSRLS;
  ALTER ROLE waitlist_runtime NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOLOGIN NOREPLICATION NOBYPASSRLS;
  ALTER ROLE waitlist_maintenance NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOLOGIN NOREPLICATION NOBYPASSRLS;
END
$roles$;

-- Neon managed owners do not implicitly inherit roles they create. Membership
-- exists only while ownership is transferred and is revoked before commit.
DO $membership$
BEGIN
  EXECUTE pg_catalog.format(
    'GRANT waitlist_function_owner TO %I WITH INHERIT FALSE, SET TRUE',
    current_user
  );
END
$membership$;

CREATE SCHEMA IF NOT EXISTS waitlist_private;
REVOKE ALL ON SCHEMA waitlist_private FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

CREATE TABLE waitlist_private.provisional_submissions (
  normalized_email text PRIMARY KEY,
  notice_version text NOT NULL,
  submitted_at timestamptz NOT NULL DEFAULT pg_catalog.clock_timestamp(),
  CONSTRAINT provisional_submissions_normalized_email_check CHECK (
    normalized_email = pg_catalog.lower(pg_catalog.btrim(normalized_email))
    AND pg_catalog.char_length(normalized_email) BETWEEN 3 AND 254
    AND normalized_email ~ '^[^[:space:]@]+@[^[:space:]@]+$'
  ),
  CONSTRAINT provisional_submissions_notice_version_check CHECK (
    pg_catalog.char_length(notice_version) BETWEEN 1 AND 128
    AND notice_version ~ '^[a-z0-9][a-z0-9-]*$'
  )
);

CREATE FUNCTION waitlist_private.reject_submission_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, waitlist_private
AS $function$
BEGIN
  RAISE EXCEPTION 'provisional waitlist submissions are immutable' USING ERRCODE = '55000';
END
$function$;

CREATE TRIGGER provisional_submissions_are_immutable
BEFORE UPDATE ON waitlist_private.provisional_submissions
FOR EACH ROW EXECUTE FUNCTION waitlist_private.reject_submission_update();

CREATE FUNCTION waitlist_private.submit_provisional(
  candidate_email text,
  accepted_notice_version text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, waitlist_private
AS $function$
DECLARE
  normalized text;
BEGIN
  IF candidate_email IS NULL OR accepted_notice_version IS NULL THEN
    RAISE EXCEPTION 'invalid provisional submission' USING ERRCODE = '22023';
  END IF;

  normalized := pg_catalog.lower(pg_catalog.btrim(candidate_email));
  IF pg_catalog.char_length(normalized) NOT BETWEEN 3 AND 254
     OR normalized !~ '^[^[:space:]@]+@[^[:space:]@]+$'
     OR pg_catalog.char_length(accepted_notice_version) NOT BETWEEN 1 AND 128
     OR accepted_notice_version !~ '^[a-z0-9][a-z0-9-]*$' THEN
    RAISE EXCEPTION 'invalid provisional submission' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('just-build-this-waitlist-identity-v1:' || normalized, 0)
  );

  INSERT INTO waitlist_private.provisional_submissions (
    normalized_email,
    notice_version,
    submitted_at
  ) VALUES (
    normalized,
    accepted_notice_version,
    pg_catalog.clock_timestamp()
  )
  ON CONFLICT (normalized_email) DO NOTHING;
END
$function$;

CREATE FUNCTION waitlist_private.purge_expired()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, waitlist_private
AS $function$
DECLARE
  deleted_count bigint;
BEGIN
  DELETE FROM waitlist_private.provisional_submissions
  WHERE submitted_at <= pg_catalog.clock_timestamp() - interval '23 months 29 days';
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END
$function$;

-- Removal deliberately does not reveal whether a row existed. Every verified
-- request receives a database-owned timestamp so the external denial journal
-- can also protect an already-absent row from provider restore history.
CREATE FUNCTION waitlist_private.remove_verified(candidate_email text)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, waitlist_private
AS $function$
DECLARE
  normalized text;
  removed_at timestamptz;
BEGIN
  IF candidate_email IS NULL THEN
    RAISE EXCEPTION 'invalid verified removal' USING ERRCODE = '22023';
  END IF;
  normalized := pg_catalog.lower(pg_catalog.btrim(candidate_email));
  IF pg_catalog.char_length(normalized) NOT BETWEEN 3 AND 254
     OR normalized !~ '^[^[:space:]@]+@[^[:space:]@]+$' THEN
    RAISE EXCEPTION 'invalid verified removal' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('just-build-this-waitlist-identity-v1:' || normalized, 0)
  );

  DELETE FROM waitlist_private.provisional_submissions
  WHERE normalized_email = normalized;
  removed_at := pg_catalog.clock_timestamp();
  RETURN removed_at;
END
$function$;

CREATE FUNCTION waitlist_private.replay_denial(
  candidate_email text,
  denied_at timestamptz
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, waitlist_private
AS $function$
DECLARE
  normalized text;
  deleted_count bigint;
BEGIN
  IF candidate_email IS NULL OR denied_at IS NULL THEN
    RAISE EXCEPTION 'invalid denial replay' USING ERRCODE = '22023';
  END IF;
  normalized := pg_catalog.lower(pg_catalog.btrim(candidate_email));
  IF pg_catalog.char_length(normalized) NOT BETWEEN 3 AND 254
     OR normalized !~ '^[^[:space:]@]+@[^[:space:]@]+$'
     OR denied_at > pg_catalog.clock_timestamp() + interval '5 minutes' THEN
    RAISE EXCEPTION 'invalid denial replay' USING ERRCODE = '22023';
  END IF;


  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('just-build-this-waitlist-identity-v1:' || normalized, 0)
  );

  DELETE FROM waitlist_private.provisional_submissions
  WHERE normalized_email = normalized
    AND submitted_at <= denied_at;
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END
$function$;

REVOKE ALL ON waitlist_private.provisional_submissions FROM PUBLIC, waitlist_runtime, waitlist_maintenance;
REVOKE ALL ON FUNCTION waitlist_private.reject_submission_update() FROM PUBLIC, waitlist_runtime, waitlist_maintenance;
REVOKE ALL ON FUNCTION waitlist_private.submit_provisional(text, text) FROM PUBLIC, waitlist_runtime, waitlist_maintenance;
REVOKE ALL ON FUNCTION waitlist_private.purge_expired() FROM PUBLIC, waitlist_runtime, waitlist_maintenance;
REVOKE ALL ON FUNCTION waitlist_private.remove_verified(text) FROM PUBLIC, waitlist_runtime, waitlist_maintenance;
REVOKE ALL ON FUNCTION waitlist_private.replay_denial(text, timestamptz) FROM PUBLIC, waitlist_runtime, waitlist_maintenance;

GRANT USAGE ON SCHEMA waitlist_private TO waitlist_function_owner, waitlist_runtime, waitlist_maintenance;
GRANT EXECUTE ON FUNCTION waitlist_private.submit_provisional(text, text) TO waitlist_runtime;
GRANT EXECUTE ON FUNCTION waitlist_private.purge_expired() TO waitlist_runtime, waitlist_maintenance;
GRANT EXECUTE ON FUNCTION waitlist_private.remove_verified(text) TO waitlist_maintenance;
GRANT EXECUTE ON FUNCTION waitlist_private.replay_denial(text, timestamptz) TO waitlist_maintenance;

ALTER TABLE waitlist_private.provisional_submissions OWNER TO waitlist_function_owner;
ALTER FUNCTION waitlist_private.reject_submission_update() OWNER TO waitlist_function_owner;
ALTER FUNCTION waitlist_private.submit_provisional(text, text) OWNER TO waitlist_function_owner;
ALTER FUNCTION waitlist_private.purge_expired() OWNER TO waitlist_function_owner;
ALTER FUNCTION waitlist_private.remove_verified(text) OWNER TO waitlist_function_owner;
ALTER FUNCTION waitlist_private.replay_denial(text, timestamptz) OWNER TO waitlist_function_owner;

ALTER DEFAULT PRIVILEGES FOR ROLE waitlist_function_owner IN SCHEMA waitlist_private
  REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE waitlist_function_owner IN SCHEMA waitlist_private
  REVOKE ALL ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE waitlist_function_owner IN SCHEMA waitlist_private
  REVOKE ALL ON FUNCTIONS FROM PUBLIC;

DO $database_grants$
BEGIN
  EXECUTE pg_catalog.format('REVOKE CONNECT, TEMPORARY ON DATABASE %I FROM PUBLIC', pg_catalog.current_database());
  EXECUTE pg_catalog.format('GRANT CONNECT ON DATABASE %I TO waitlist_runtime, waitlist_maintenance', pg_catalog.current_database());
END
$database_grants$;

DO $membership$
BEGIN
  EXECUTE pg_catalog.format('REVOKE waitlist_function_owner FROM %I', current_user);
END
$membership$;

COMMIT;
