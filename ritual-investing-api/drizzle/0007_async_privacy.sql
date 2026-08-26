BEGIN;

DO $$ BEGIN
  EXECUTE format(
    'GRANT ritual_function_owner TO %I WITH INHERIT TRUE, SET TRUE',
    current_user
  );
END $$;
GRANT CREATE ON SCHEMA ritual_private TO ritual_function_owner;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ritual_media_worker') THEN
    CREATE ROLE ritual_media_worker NOLOGIN NOINHERIT NOBYPASSRLS;
  END IF;
END
$$;

ALTER TABLE outbox_events
  DROP CONSTRAINT outbox_events_tenant_id_fkey;
ALTER TABLE outbox_events
  ADD CONSTRAINT outbox_events_tenant_id_fkey
  FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE SET NULL;
ALTER TABLE outbox_events
  ADD COLUMN schema_version integer NOT NULL DEFAULT 1 CHECK (schema_version > 0),
  ADD COLUMN deletion_generation integer NOT NULL DEFAULT 0 CHECK (deletion_generation >= 0),
  ADD COLUMN created_at timestamptz NOT NULL DEFAULT statement_timestamp();
ALTER TABLE outbox_events
  ADD CONSTRAINT outbox_events_minimal_payload_check CHECK (
    payload::text !~* '"(authorization|password|provider_body|providerbody|push_token|raw_token|secret)"[[:space:]]*:'
  );

ALTER TABLE consumer_receipts
  ADD COLUMN tenant_id uuid,
  ADD COLUMN aggregate_kind text NOT NULL DEFAULT 'legacy',
  ADD COLUMN aggregate_id uuid,
  ADD COLUMN reset_generation integer NOT NULL DEFAULT 0 CHECK (reset_generation >= 0),
  ADD COLUMN deletion_generation integer NOT NULL DEFAULT 0 CHECK (deletion_generation >= 0);

ALTER TABLE job_runs
  ADD COLUMN lease_owner uuid,
  ADD COLUMN created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  ADD COLUMN completed_at timestamptz;

CREATE TABLE aggregate_consumer_watermarks (
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  consumer text NOT NULL CHECK (char_length(consumer) BETWEEN 1 AND 64),
  aggregate_kind text NOT NULL CHECK (char_length(aggregate_kind) BETWEEN 1 AND 64),
  aggregate_id uuid NOT NULL,
  aggregate_version integer NOT NULL CHECK (aggregate_version >= 0),
  reset_generation integer NOT NULL CHECK (reset_generation >= 0),
  deletion_generation integer NOT NULL CHECK (deletion_generation >= 0),
  last_outbox_id uuid NOT NULL REFERENCES outbox_events(id),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  PRIMARY KEY (tenant_id, consumer, aggregate_kind, aggregate_id)
);

CREATE TABLE media_upload_intents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_staff_id uuid NOT NULL REFERENCES staff_principals(id),
  r2_key text NOT NULL UNIQUE CHECK (r2_key ~ '^quarantine/v1/[0-9a-f-]{36}/[0-9a-f-]{36}$'),
  expected_mime text NOT NULL CHECK (expected_mime IN ('image/jpeg','image/png','image/webp')),
  expected_byte_size bigint NOT NULL CHECK (expected_byte_size BETWEEN 1 AND 10485760),
  expected_checksum text NOT NULL CHECK (expected_checksum ~ '^[a-f0-9]{64}$'),
  status text NOT NULL DEFAULT 'issued' CHECK (status IN ('issued','uploaded','scanning','accepted','rejected','expired')),
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  CHECK (expires_at > created_at),
  CHECK ((status IN ('accepted','rejected','expired')) = (consumed_at IS NOT NULL))
);

ALTER TABLE media_assets
  ADD COLUMN upload_intent_id uuid UNIQUE REFERENCES media_upload_intents(id),
  ADD COLUMN actor_staff_id uuid REFERENCES staff_principals(id),
  ADD COLUMN schema_version integer NOT NULL DEFAULT 1 CHECK (schema_version > 0),
  ADD COLUMN accepted_at timestamptz,
  ADD COLUMN version integer NOT NULL DEFAULT 1 CHECK (version > 0);
INSERT INTO media_upload_intents(
  id,actor_staff_id,r2_key,expected_mime,expected_byte_size,expected_checksum,
  status,expires_at,consumed_at,created_at
)
SELECT m.id,s.id,'quarantine/v1/' || s.id::text || '/' || m.id::text,
       m.mime_type,m.byte_size,encode(digest(m.checksum,'sha256'),'hex'),'accepted',statement_timestamp()+interval '1 day',
       statement_timestamp(),statement_timestamp()
  FROM media_assets m
 CROSS JOIN LATERAL (SELECT id FROM staff_principals ORDER BY id LIMIT 1) s
 WHERE m.status='active';
UPDATE media_assets m
   SET upload_intent_id=i.id,actor_staff_id=i.actor_staff_id,accepted_at=i.consumed_at,
       quarantine_status='clear',scan_result='clean'
  FROM media_upload_intents i
 WHERE i.id=m.id AND m.status='active';
ALTER TABLE media_assets
  ADD CONSTRAINT media_assets_quarantine_attach_check CHECK (
    status <> 'active' OR
    (quarantine_status = 'clear' AND scan_result = 'clean' AND upload_intent_id IS NOT NULL AND accepted_at IS NOT NULL)
  );

ALTER TABLE briefings
  ADD COLUMN source_sequence bigint NOT NULL DEFAULT 0 CHECK (source_sequence >= 0),
  ADD COLUMN reset_generation integer NOT NULL DEFAULT 0 CHECK (reset_generation >= 0),
  ADD COLUMN deletion_generation integer NOT NULL DEFAULT 0 CHECK (deletion_generation >= 0);

ALTER TABLE notifications
  ADD COLUMN source_outbox_id uuid REFERENCES outbox_events(id),
  ADD COLUMN reset_generation integer NOT NULL DEFAULT 0 CHECK (reset_generation >= 0),
  ADD COLUMN deletion_generation integer NOT NULL DEFAULT 0 CHECK (deletion_generation >= 0),
  ADD CONSTRAINT notifications_source_unique UNIQUE (tenant_id, source_outbox_id, kind);

UPDATE notification_preferences
   SET quiet_hours='{"enabled":false,"start":"22:00","end":"07:00","timezone":"UTC"}'::jsonb
 WHERE quiet_hours='{}'::jsonb;
ALTER TABLE notification_preferences
  ALTER COLUMN quiet_hours SET DEFAULT '{"enabled":false,"start":"22:00","end":"07:00","timezone":"UTC"}'::jsonb;

ALTER TABLE device_installations
  DROP CONSTRAINT device_installations_tenant_id_push_token_hash_key;
-- A token shared by active registrations cannot be attributed safely to one
-- tenant. Revoke every ambiguous registration before enforcing global scope.
UPDATE device_installations installation
SET status='revoked', push_token_ciphertext='revoked'
WHERE installation.status='active'
  AND EXISTS (
    SELECT 1
    FROM device_installations duplicate
    WHERE duplicate.status='active'
      AND duplicate.push_token_hash=installation.push_token_hash
      AND duplicate.id<>installation.id
  );
CREATE UNIQUE INDEX device_installations_active_token_global_unique
  ON device_installations(push_token_hash) WHERE status='active';

CREATE TABLE member_command_receipts (
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  operation text NOT NULL,
  idempotency_key text NOT NULL CHECK (idempotency_key ~ '^[!-~]{16,64}$'),
  request_hash text NOT NULL CHECK (request_hash ~ '^[a-f0-9]{64}$'),
  response jsonb NOT NULL CHECK (jsonb_typeof(response)='object'),
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  PRIMARY KEY (tenant_id,operation,idempotency_key)
);
ALTER TABLE member_command_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_command_receipts FORCE ROW LEVEL SECURITY;
CREATE POLICY member_command_receipts_runtime_policy ON member_command_receipts
FOR ALL TO ritual_runtime
USING (tenant_id=ritual_private.current_tenant_id())
WITH CHECK (tenant_id=ritual_private.current_tenant_id());
GRANT SELECT,INSERT,UPDATE ON TABLE member_command_receipts TO ritual_runtime;

CREATE TABLE admin_operation_receipts (
  actor_staff_id uuid NOT NULL REFERENCES staff_principals(id),
  operation text NOT NULL CHECK (operation IN ('job.retry','privacy.retry','media.upload-request','media.complete')),
  idempotency_key text NOT NULL CHECK (idempotency_key ~ '^[!-~]{16,64}$'),
  request_hash text NOT NULL CHECK (request_hash ~ '^[a-f0-9]{64}$'),
  response jsonb NOT NULL CHECK (jsonb_typeof(response)='object'),
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  PRIMARY KEY (actor_staff_id,operation,idempotency_key)
);
REVOKE ALL ON TABLE admin_operation_receipts FROM PUBLIC;

CREATE OR REPLACE FUNCTION ritual_private.register_notification_device(
  target_tenant_id uuid,
  target_platform text,
  target_ciphertext text,
  target_token_hash text,
  target_key text,
  target_request_hash text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE device_id uuid:=gen_random_uuid();
DECLARE receipt member_command_receipts%ROWTYPE;
BEGIN
  IF target_tenant_id <> nullif(current_setting('ritual.tenant_id',true),'')::uuid OR
     target_platform NOT IN ('ios','android') OR char_length(target_ciphertext)>8192 OR
     char_length(target_token_hash) NOT BETWEEN 40 AND 128 THEN
    RAISE EXCEPTION 'invalid device registration';
  END IF;
  INSERT INTO member_command_receipts(tenant_id,operation,idempotency_key,request_hash,response)
  VALUES(target_tenant_id,'device.register',target_key,target_request_hash,
         jsonb_build_object('device_id',device_id))
  ON CONFLICT DO NOTHING;
  SELECT * INTO receipt FROM member_command_receipts
   WHERE tenant_id=target_tenant_id AND operation='device.register'
     AND idempotency_key=target_key FOR UPDATE;
  IF receipt.request_hash<>target_request_hash THEN RAISE EXCEPTION 'idempotency_conflict'; END IF;
  device_id:=(receipt.response->>'device_id')::uuid;
  IF EXISTS(SELECT 1 FROM device_installations WHERE id=device_id AND tenant_id=target_tenant_id) THEN
    RETURN device_id;
  END IF;
  UPDATE device_installations SET status='revoked',push_token_ciphertext='revoked'
   WHERE push_token_hash=target_token_hash AND status='active';
  INSERT INTO device_installations(id,tenant_id,platform,push_token_ciphertext,push_token_hash,status,last_seen_at)
  VALUES(device_id,target_tenant_id,target_platform,target_ciphertext,target_token_hash,'active',now());
  RETURN device_id;
END
$$;
ALTER FUNCTION ritual_private.register_notification_device(uuid,text,text,text,text,text) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.register_notification_device(uuid,text,text,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.register_notification_device(uuid,text,text,text,text,text) TO ritual_runtime;
GRANT SELECT,INSERT,UPDATE ON TABLE member_command_receipts,device_installations TO ritual_function_owner;

CREATE OR REPLACE FUNCTION ritual_private.current_deletion_generation(target_tenant_id uuid)
RETURNS integer
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF target_tenant_id<>nullif(current_setting('ritual.tenant_id',true),'')::uuid THEN
    RAISE EXCEPTION 'tenant context mismatch' USING ERRCODE='42501';
  END IF;
  RETURN coalesce((SELECT max(purge_generation) FROM deletion_tombstones
                    WHERE tenant_id=target_tenant_id),0);
END
$$;
ALTER FUNCTION ritual_private.current_deletion_generation(uuid) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.current_deletion_generation(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.current_deletion_generation(uuid) TO ritual_runtime;
GRANT SELECT ON TABLE deletion_tombstones TO ritual_function_owner;

CREATE OR REPLACE FUNCTION ritual_private.member_deletion_replay(
  target_tenant_id uuid,
  target_key text
)
RETURNS TABLE(request_id uuid,tombstone_id uuid,effective_at timestamptz,purge_generation integer)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF target_tenant_id<>nullif(current_setting('ritual.tenant_id',true),'')::uuid THEN
    RAISE EXCEPTION 'tenant context mismatch' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT request.id,tombstone.id,tombstone.effective_at,tombstone.purge_generation
    FROM privacy_requests request
    JOIN deletion_tombstones tombstone
      ON tombstone.tenant_id=request.tenant_id
     AND tombstone.purge_generation=request.purge_generation
   WHERE request.tenant_id=target_tenant_id AND request.request_type='delete'
     AND request.idempotency_key=target_key;
END
$$;
ALTER FUNCTION ritual_private.member_deletion_replay(uuid,text) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.member_deletion_replay(uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.member_deletion_replay(uuid,text) TO ritual_runtime;

CREATE OR REPLACE FUNCTION ritual_private.begin_member_deletion(
  target_tenant_id uuid,
  target_subject_hash text
)
RETURNS TABLE(tombstone_id uuid,effective_at timestamptz,purge_generation integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE target_status text;
DECLARE next_generation integer;
DECLARE new_tombstone_id uuid:=gen_random_uuid();
DECLARE deletion_effective_at timestamptz:=statement_timestamp();
BEGIN
  IF target_tenant_id<>nullif(current_setting('ritual.tenant_id',true),'')::uuid
     OR target_subject_hash !~ '^[a-f0-9]{64}$' THEN
    RAISE EXCEPTION 'tenant context mismatch' USING ERRCODE='42501';
  END IF;
  SELECT status INTO target_status FROM tenants WHERE id=target_tenant_id FOR UPDATE;
  IF target_status<>'active' THEN RAISE EXCEPTION 'deletion_in_progress' USING ERRCODE='23514'; END IF;
  SELECT coalesce(max(t.purge_generation),0)+1 INTO next_generation
    FROM deletion_tombstones t WHERE t.tenant_id=target_tenant_id;
  INSERT INTO deletion_tombstones(id,tenant_id,subject_hash,effective_at,purge_generation,status)
  VALUES(new_tombstone_id,target_tenant_id,target_subject_hash,deletion_effective_at,next_generation,'pending');
  UPDATE accounts SET status='deletion_pending',revocation_epoch=revocation_epoch+1
   WHERE tenant_id=target_tenant_id;
  UPDATE tenants SET status='deletion_pending',deletion_scheduled_at=deletion_effective_at+interval '30 days'
   WHERE id=target_tenant_id;
  UPDATE device_installations SET status='revoked',push_token_ciphertext='revoked'
   WHERE tenant_id=target_tenant_id;
  RETURN QUERY SELECT new_tombstone_id,deletion_effective_at,next_generation;
END
$$;
ALTER FUNCTION ritual_private.begin_member_deletion(uuid,text) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.begin_member_deletion(uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.begin_member_deletion(uuid,text) TO ritual_runtime;
GRANT SELECT ON TABLE privacy_requests,deletion_tombstones,tenants TO ritual_function_owner;
GRANT INSERT ON TABLE deletion_tombstones TO ritual_function_owner;
GRANT UPDATE ON TABLE tenants,accounts,device_installations TO ritual_function_owner;

ALTER TABLE privacy_requests
  ADD COLUMN source_sequence bigint CHECK (source_sequence IS NULL OR source_sequence >= 0),
  ADD COLUMN idempotency_key text,
  ADD COLUMN request_hash text,
  ADD COLUMN purge_generation integer CHECK (purge_generation IS NULL OR purge_generation > 0),
  ADD COLUMN expires_at timestamptz,
  ADD COLUMN export_format text NOT NULL DEFAULT 'zip' CHECK (export_format = 'zip');
CREATE UNIQUE INDEX privacy_requests_idempotency_unique
  ON privacy_requests(tenant_id, request_type, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

ALTER TABLE privacy_export_artifacts
  ADD COLUMN link_nonce_hash text CHECK (link_nonce_hash IS NULL OR link_nonce_hash ~ '^[a-f0-9]{64}$'),
  ADD COLUMN link_expires_at timestamptz,
  ADD COLUMN revoked_at timestamptz,
  ADD COLUMN deleted_at timestamptz;

CREATE TABLE deletion_journal_confirmations (
  tombstone_id uuid NOT NULL REFERENCES deletion_tombstones(id),
  purge_generation integer NOT NULL CHECK (purge_generation > 0),
  r2_key text NOT NULL UNIQUE,
  body_checksum text NOT NULL CHECK (body_checksum ~ '^[a-f0-9]{64}$'),
  confirmed_at timestamptz NOT NULL,
  PRIMARY KEY (tombstone_id, purge_generation),
  CHECK (r2_key = 'deletion-deny/v1/' || tombstone_id::text || '/' || purge_generation::text || '.json')
);

CREATE TABLE deletion_object_receipts (
  tombstone_id uuid NOT NULL REFERENCES deletion_tombstones(id),
  purge_generation integer NOT NULL CHECK (purge_generation > 0),
  object_class text NOT NULL CHECK (object_class IN ('privacy_exports','tenant_quarantine')),
  prefix text NOT NULL,
  listing_checksum text NOT NULL CHECK (listing_checksum ~ '^[a-f0-9]{64}$'),
  confirmed_empty_at timestamptz NOT NULL,
  PRIMARY KEY (tombstone_id, purge_generation, object_class)
);

CREATE TABLE deletion_restore_checkpoints (
  restore_epoch text PRIMARY KEY CHECK (char_length(restore_epoch) BETWEEN 1 AND 128),
  journal_prefix text NOT NULL DEFAULT 'deletion-deny/v1/',
  highest_effective_at timestamptz NOT NULL,
  entry_count bigint NOT NULL CHECK (entry_count >= 0),
  replay_checksum text NOT NULL CHECK (replay_checksum ~ '^[a-f0-9]{64}$'),
  completed_at timestamptz NOT NULL
);

ALTER TABLE aggregate_consumer_watermarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE aggregate_consumer_watermarks FORCE ROW LEVEL SECURITY;
ALTER TABLE media_upload_intents ENABLE ROW LEVEL SECURITY;
ALTER TABLE media_upload_intents FORCE ROW LEVEL SECURITY;

CREATE POLICY aggregate_consumer_watermarks_runtime_policy
ON aggregate_consumer_watermarks
FOR ALL TO ritual_runtime
USING (tenant_id = ritual_private.current_tenant_id())
WITH CHECK (tenant_id = ritual_private.current_tenant_id());

CREATE POLICY media_upload_intents_staff_policy
ON media_upload_intents
FOR ALL TO ritual_staff
USING (true)
WITH CHECK (true);

CREATE POLICY media_upload_intents_worker_policy
ON media_upload_intents
FOR SELECT TO ritual_media_worker
USING (status IN ('scanning','accepted','rejected'));
CREATE POLICY media_upload_intents_worker_update_policy
ON media_upload_intents
FOR UPDATE TO ritual_media_worker
USING (status='scanning')
WITH CHECK (status IN ('accepted','rejected'));

GRANT SELECT, INSERT, UPDATE ON TABLE aggregate_consumer_watermarks TO ritual_runtime;
GRANT SELECT, INSERT ON TABLE outbox_events, consumer_receipts TO ritual_runtime;
GRANT SELECT, INSERT, UPDATE ON TABLE media_upload_intents TO ritual_staff;
GRANT USAGE ON SCHEMA public TO ritual_media_worker;
GRANT SELECT ON TABLE outbox_events, consumer_receipts TO ritual_media_worker;
GRANT INSERT ON TABLE outbox_events, consumer_receipts, media_assets TO ritual_media_worker;
GRANT SELECT (id,r2_key,status,upload_intent_id,actor_staff_id) ON TABLE media_assets TO ritual_media_worker;
GRANT SELECT, UPDATE ON TABLE media_upload_intents TO ritual_media_worker;
GRANT SELECT, INSERT, UPDATE ON TABLE outbox_events, job_runs TO ritual_scheduler;
GRANT SELECT, INSERT ON TABLE consumer_receipts TO ritual_scheduler;
GRANT SELECT, INSERT, UPDATE ON TABLE deletion_journal_confirmations, deletion_object_receipts, deletion_restore_checkpoints TO ritual_privacy_purge;

CREATE OR REPLACE FUNCTION ritual_private.replay_deletion_denial(
  target_tombstone_id uuid,
  target_tenant_id uuid,
  target_subject_hash text,
  target_effective_at timestamptz,
  target_purge_generation integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE existing deletion_tombstones%ROWTYPE;
DECLARE tenant_exists boolean;
BEGIN
  IF target_subject_hash !~ '^[a-f0-9]{64}$' OR target_purge_generation < 1 THEN
    RAISE EXCEPTION 'invalid deletion denial entry';
  END IF;
  SELECT EXISTS (SELECT 1 FROM tenants WHERE id=target_tenant_id) INTO tenant_exists;
  INSERT INTO deletion_tombstones(id,tenant_id,subject_hash,effective_at,purge_generation,status)
  VALUES (target_tombstone_id,target_tenant_id,target_subject_hash,target_effective_at,
          target_purge_generation,CASE WHEN tenant_exists THEN 'pending' ELSE 'purged' END)
  ON CONFLICT (id) DO NOTHING;
  SELECT * INTO existing FROM deletion_tombstones WHERE id=target_tombstone_id;
  IF existing.tenant_id <> target_tenant_id OR existing.subject_hash <> target_subject_hash OR
     existing.purge_generation <> target_purge_generation THEN
    RAISE EXCEPTION 'deletion denial identity conflict';
  END IF;
  IF tenant_exists THEN
    UPDATE accounts SET status='deletion_pending',revocation_epoch=revocation_epoch+1
     WHERE tenant_id=target_tenant_id AND status='active';
    UPDATE tenants SET status='deletion_pending',
      deletion_scheduled_at=coalesce(deletion_scheduled_at,statement_timestamp())
     WHERE id=target_tenant_id AND status NOT IN ('purging','purged');
  END IF;
END
$$;
ALTER FUNCTION ritual_private.replay_deletion_denial(uuid,uuid,text,timestamptz,integer) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.replay_deletion_denial(uuid,uuid,text,timestamptz,integer) FROM PUBLIC;
GRANT USAGE ON SCHEMA ritual_private TO ritual_privacy_purge;
GRANT EXECUTE ON FUNCTION ritual_private.replay_deletion_denial(uuid,uuid,text,timestamptz,integer) TO ritual_privacy_purge;
GRANT SELECT,UPDATE ON TABLE tenants,accounts TO ritual_function_owner;
GRANT SELECT,INSERT,UPDATE ON TABLE deletion_tombstones TO ritual_function_owner;

CREATE OR REPLACE FUNCTION ritual_private.enqueue_scheduled_briefings(
  target_type text,
  target_date date,
  target_sequence integer
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE inserted_count integer;
BEGIN
  IF target_type NOT IN ('daily','weekly','moon_cycle') OR target_sequence < 1 THEN
    RAISE EXCEPTION 'invalid briefing schedule';
  END IF;
  INSERT INTO outbox_events(topic,aggregate_kind,aggregate_id,aggregate_version,
    tenant_id,reset_generation,deletion_generation,dedupe_key,payload,schema_version,available_at)
  SELECT 'briefing.' || target_type || '.requested','tenant',t.id,target_sequence,
    t.id,coalesce(s.reset_generation,0),0,
    t.id::text || ':' || target_type || ':' || target_date::text || ':' || target_sequence::text,
    jsonb_build_object('local_date',target_date::text,'briefing_type',target_type),1,now()
  FROM tenants t LEFT JOIN tenant_demo_states s ON s.tenant_id=t.id
  WHERE t.status='active'
  ON CONFLICT (topic,dedupe_key) DO NOTHING;
  GET DIAGNOSTICS inserted_count = ROW_COUNT;
  RETURN inserted_count;
END
$$;
ALTER FUNCTION ritual_private.enqueue_scheduled_briefings(text,date,integer) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.enqueue_scheduled_briefings(text,date,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.enqueue_scheduled_briefings(text,date,integer) TO ritual_scheduler;
GRANT SELECT ON TABLE tenants,tenant_demo_states TO ritual_function_owner;
GRANT INSERT ON TABLE outbox_events TO ritual_function_owner;

CREATE OR REPLACE FUNCTION ritual_private.create_media_upload_intent(
  target_media_id uuid,
  target_staff_id uuid,
  target_mime text,
  target_byte_size bigint,
  target_checksum text,
  target_key text,
  target_request_hash text,
  target_request_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE receipt admin_operation_receipts%ROWTYPE;
BEGIN
  IF target_staff_id<>nullif(current_setting('ritual.staff_id',true),'')::uuid THEN
    RAISE EXCEPTION 'staff context mismatch' USING ERRCODE='42501';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(target_staff_id::text || ':' || target_key,0));
  SELECT * INTO receipt FROM admin_operation_receipts
   WHERE actor_staff_id=target_staff_id AND operation='media.upload-request'
     AND idempotency_key=target_key FOR UPDATE;
  IF FOUND THEN
    IF receipt.request_hash<>target_request_hash THEN RAISE EXCEPTION 'idempotency_conflict'; END IF;
    RETURN (receipt.response->>'media_id')::uuid;
  END IF;
  INSERT INTO media_upload_intents(
    id,actor_staff_id,r2_key,expected_mime,expected_byte_size,expected_checksum,status,expires_at
  ) VALUES(
    target_media_id,target_staff_id,
    'quarantine/v1/' || target_staff_id::text || '/' || target_media_id::text,
    target_mime,target_byte_size,target_checksum,'issued',now()+interval '10 minutes'
  );
  INSERT INTO admin_operation_receipts(actor_staff_id,operation,idempotency_key,request_hash,response)
  VALUES(target_staff_id,'media.upload-request',target_key,target_request_hash,
         jsonb_build_object('media_id',target_media_id));
  INSERT INTO admin_audit_events(actor_staff_id,action,target_kind,target_id,reason,request_id,outcome)
  VALUES(target_staff_id,'media.upload-request','media_upload_intent',target_media_id,
         'Actor-bound quarantine upload requested',target_request_id,'allowed');
  RETURN target_media_id;
END
$$;
ALTER FUNCTION ritual_private.create_media_upload_intent(uuid,uuid,text,bigint,text,text,text,uuid) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.create_media_upload_intent(uuid,uuid,text,bigint,text,text,text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.create_media_upload_intent(uuid,uuid,text,bigint,text,text,text,uuid) TO ritual_staff;
GRANT SELECT,INSERT ON TABLE media_upload_intents TO ritual_function_owner;
GRANT SELECT,INSERT ON TABLE admin_operation_receipts TO ritual_function_owner;
GRANT INSERT ON TABLE admin_audit_events TO ritual_function_owner;

CREATE OR REPLACE FUNCTION ritual_private.queue_media_scan(
  target_media_id uuid,
  target_staff_id uuid,
  target_checksum text,
  target_key text,
  target_request_hash text,
  target_request_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE intent_status text;
DECLARE new_outbox_id uuid:=gen_random_uuid();
DECLARE receipt admin_operation_receipts%ROWTYPE;
BEGIN
  IF target_staff_id<>nullif(current_setting('ritual.staff_id',true),'')::uuid THEN
    RAISE EXCEPTION 'staff context mismatch' USING ERRCODE='42501';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(target_staff_id::text || ':' || target_key,0));
  SELECT * INTO receipt FROM admin_operation_receipts
   WHERE actor_staff_id=target_staff_id AND operation='media.complete'
     AND idempotency_key=target_key FOR UPDATE;
  IF FOUND THEN
    IF receipt.request_hash<>target_request_hash THEN RAISE EXCEPTION 'idempotency_conflict'; END IF;
    RETURN (receipt.response->>'outbox_id')::uuid;
  END IF;
  SELECT status INTO intent_status FROM media_upload_intents
   WHERE id=target_media_id AND actor_staff_id=target_staff_id
     AND expected_checksum=target_checksum
   FOR UPDATE;
  IF intent_status IS NULL OR intent_status<>'uploaded' THEN
    RAISE EXCEPTION 'media intent not completable' USING ERRCODE='P0002';
  END IF;
  UPDATE media_upload_intents SET status='scanning'
   WHERE id=target_media_id AND actor_staff_id=target_staff_id AND status='uploaded';
  INSERT INTO outbox_events(
    id,topic,aggregate_kind,aggregate_id,aggregate_version,tenant_id,
    reset_generation,deletion_generation,dedupe_key,payload,schema_version,available_at
  ) VALUES(
    new_outbox_id,'media.scan.requested','media-upload-intent',target_media_id,1,NULL,
    0,0,target_media_id::text,
    jsonb_build_object('media_id',target_media_id,'actor_staff_id',target_staff_id),1,now()
  );
  INSERT INTO admin_operation_receipts(
    actor_staff_id,operation,idempotency_key,request_hash,response
  ) VALUES(
    target_staff_id,'media.complete',target_key,target_request_hash,
    jsonb_build_object('outbox_id',new_outbox_id)
  );
  INSERT INTO admin_audit_events(actor_staff_id,action,target_kind,target_id,reason,request_id,outcome)
  VALUES(target_staff_id,'media.complete','media_upload_intent',target_media_id,
         'Quarantine scan requested',target_request_id,'allowed');
  RETURN new_outbox_id;
END
$$;
ALTER FUNCTION ritual_private.queue_media_scan(uuid,uuid,text,text,text,uuid) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.queue_media_scan(uuid,uuid,text,text,text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.queue_media_scan(uuid,uuid,text,text,text,uuid) TO ritual_staff;
GRANT SELECT,UPDATE ON TABLE media_upload_intents TO ritual_function_owner;
GRANT SELECT,INSERT ON TABLE admin_operation_receipts TO ritual_function_owner;

CREATE OR REPLACE FUNCTION ritual_private.triage_content_report(
  target_outbox_id uuid,
  target_tenant_id uuid,
  target_report_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE case_id uuid;
BEGIN
  IF target_tenant_id<>nullif(current_setting('ritual.tenant_id',true),'')::uuid OR
     NOT EXISTS(
       SELECT 1 FROM outbox_events e
        WHERE e.id=target_outbox_id AND e.topic='content-report.created'
          AND e.tenant_id=target_tenant_id AND e.aggregate_kind='content-report'
          AND e.aggregate_id=target_report_id
     ) OR
     NOT EXISTS(
       SELECT 1 FROM content_reports report
       JOIN editorial_items item ON item.id=report.target_id
        WHERE report.id=target_report_id AND report.tenant_id=target_tenant_id
          AND item.status='published'
     ) THEN
    RAISE EXCEPTION 'content report triage scope denied' USING ERRCODE='42501';
  END IF;
  INSERT INTO moderation_cases(report_id,status)
  VALUES(target_report_id,'open')
  ON CONFLICT (report_id) DO NOTHING
  RETURNING id INTO case_id;
  IF case_id IS NULL THEN
    SELECT id INTO case_id FROM moderation_cases WHERE report_id=target_report_id;
  END IF;
  RETURN case_id;
END
$$;
ALTER FUNCTION ritual_private.triage_content_report(uuid,uuid,uuid) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.triage_content_report(uuid,uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.triage_content_report(uuid,uuid,uuid) TO ritual_runtime;
GRANT SELECT ON TABLE outbox_events,content_reports,editorial_items,moderation_cases TO ritual_function_owner;
GRANT INSERT ON TABLE moderation_cases TO ritual_function_owner;

CREATE OR REPLACE FUNCTION ritual_private.retire_media_asset(
  target_media_id uuid,
  target_staff_id uuid,
  target_version integer,
  target_reason text,
  target_request_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE asset media_assets%ROWTYPE;
DECLARE new_outbox_id uuid:=gen_random_uuid();
BEGIN
  IF target_staff_id<>nullif(current_setting('ritual.staff_id',true),'')::uuid OR
     char_length(btrim(target_reason)) NOT BETWEEN 8 AND 500 THEN
    RAISE EXCEPTION 'staff context mismatch' USING ERRCODE='42501';
  END IF;
  SELECT * INTO asset FROM media_assets WHERE media_assets.id=target_media_id FOR UPDATE;
  IF asset.id IS NULL OR asset.status<>'active' THEN
    RAISE EXCEPTION 'media not found' USING ERRCODE='P0002';
  END IF;
  IF asset.version<>target_version THEN RAISE EXCEPTION 'media version conflict'; END IF;
  IF EXISTS(SELECT 1 FROM ritual_scenario_revisions WHERE art_media_id=target_media_id)
     OR EXISTS(SELECT 1 FROM grimoire_revisions WHERE art_media_id=target_media_id)
     OR EXISTS(SELECT 1 FROM seeded_creators WHERE avatar_media_id=target_media_id)
     OR EXISTS(SELECT 1 FROM circle_template_revisions WHERE art_media_id=target_media_id) THEN
    RAISE EXCEPTION 'media asset is referenced';
  END IF;
  UPDATE media_assets SET status='retired',version=version+1 WHERE id=target_media_id;
  INSERT INTO outbox_events(
    id,topic,aggregate_kind,aggregate_id,aggregate_version,tenant_id,
    reset_generation,deletion_generation,dedupe_key,payload,schema_version,available_at
  ) VALUES(
    new_outbox_id,'media.public.cleanup','media-asset',target_media_id,target_version+1,NULL,
    0,0,'retire:' || target_media_id::text || ':' || (target_version+1)::text,
    jsonb_build_object('media_id',target_media_id,'actor_staff_id',target_staff_id),1,now()
  );
  INSERT INTO admin_audit_events(actor_staff_id,action,target_kind,target_id,reason,request_id,outcome)
  VALUES(target_staff_id,'media.retire','media_asset',target_media_id,btrim(target_reason),target_request_id,'allowed');
  RETURN new_outbox_id;
END
$$;
ALTER FUNCTION ritual_private.retire_media_asset(uuid,uuid,integer,text,uuid) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.retire_media_asset(uuid,uuid,integer,text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.retire_media_asset(uuid,uuid,integer,text,uuid) TO ritual_staff;
GRANT SELECT,UPDATE ON TABLE media_assets TO ritual_function_owner;
GRANT SELECT ON TABLE ritual_scenario_revisions,grimoire_revisions,seeded_creators,circle_template_revisions TO ritual_function_owner;

CREATE OR REPLACE FUNCTION ritual_private.authorize_privacy_purge_event(
  target_outbox_id uuid,
  target_tenant_id uuid,
  target_generation integer
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM outbox_events e
      JOIN tenants t ON t.id=e.tenant_id
     WHERE e.id=target_outbox_id
       AND e.topic='privacy.deletion.requested'
       AND e.tenant_id=target_tenant_id
       AND e.deletion_generation=target_generation
       AND t.status IN ('deletion_pending','purging')
       AND target_generation=(SELECT max(d.purge_generation)
                                FROM deletion_tombstones d
                               WHERE d.tenant_id=target_tenant_id)
  )
$$;
ALTER FUNCTION ritual_private.authorize_privacy_purge_event(uuid,uuid,integer) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.authorize_privacy_purge_event(uuid,uuid,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.authorize_privacy_purge_event(uuid,uuid,integer) TO ritual_privacy_purge;
GRANT SELECT ON TABLE outbox_events, consumer_receipts, deletion_tombstones TO ritual_privacy_purge;
GRANT INSERT ON TABLE consumer_receipts TO ritual_privacy_purge;

CREATE OR REPLACE FUNCTION ritual_private.begin_privacy_purge_event(
  target_outbox_id uuid,
  target_tenant_id uuid,
  target_generation integer
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF NOT ritual_private.authorize_privacy_purge_event(
    target_outbox_id,target_tenant_id,target_generation
  ) THEN RETURN false; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(target_outbox_id::text,0));
  UPDATE tenants SET status='purging'
   WHERE id=target_tenant_id AND status IN ('deletion_pending','purging');
  RETURN FOUND;
END
$$;
ALTER FUNCTION ritual_private.begin_privacy_purge_event(uuid,uuid,integer) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.begin_privacy_purge_event(uuid,uuid,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.begin_privacy_purge_event(uuid,uuid,integer) TO ritual_privacy_purge;
GRANT SELECT ON TABLE outbox_events TO ritual_function_owner;
GRANT UPDATE ON TABLE tenants TO ritual_function_owner;

CREATE OR REPLACE FUNCTION ritual_private.admin_job_metadata(target_job_id uuid DEFAULT NULL)
RETURNS TABLE(id uuid,outbox_id uuid,consumer text,status text,attempt integer,
  correlation_id uuid,failure_code text,created_at timestamptz,completed_at timestamptz)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT j.id,j.outbox_id,j.consumer,j.status,j.attempt,j.correlation_id,
         j.failure_code,j.created_at,j.completed_at
    FROM job_runs j
   WHERE target_job_id IS NULL OR j.id=target_job_id
   ORDER BY j.created_at DESC,j.id
   LIMIT CASE WHEN target_job_id IS NULL THEN 100 ELSE 1 END
$$;
ALTER FUNCTION ritual_private.admin_job_metadata(uuid) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.admin_job_metadata(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.admin_job_metadata(uuid) TO ritual_staff;

CREATE OR REPLACE FUNCTION ritual_private.admin_privacy_metadata(target_request_id uuid DEFAULT NULL)
RETURNS TABLE(id uuid,tenant_id uuid,request_type text,status text,snapshot_at timestamptz,
  queued_at timestamptz,completed_at timestamptz,failure_code text,purge_generation integer)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT r.id,r.tenant_id,r.request_type,r.status,r.snapshot_at,r.queued_at,
         r.completed_at,r.failure_code,r.purge_generation
    FROM privacy_requests r
   WHERE target_request_id IS NULL OR r.id=target_request_id
   ORDER BY r.queued_at DESC NULLS LAST,r.id
   LIMIT CASE WHEN target_request_id IS NULL THEN 100 ELSE 1 END
$$;
ALTER FUNCTION ritual_private.admin_privacy_metadata(uuid) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.admin_privacy_metadata(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.admin_privacy_metadata(uuid) TO ritual_staff;

CREATE OR REPLACE FUNCTION ritual_private.admin_retry_privacy_request(target_request_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE target privacy_requests%ROWTYPE;
DECLARE new_outbox_id uuid;
DECLARE target_tombstone_id uuid;
BEGIN
  SELECT * INTO target FROM privacy_requests WHERE id=target_request_id FOR UPDATE;
  IF target.id IS NULL OR target.status <> 'failed' THEN
    RAISE EXCEPTION 'privacy request is not retryable';
  END IF;
  IF target.request_type='delete' THEN
    SELECT id INTO target_tombstone_id FROM deletion_tombstones
     WHERE tenant_id=target.tenant_id AND purge_generation=target.purge_generation;
  END IF;
  UPDATE privacy_requests SET status='queued',failure_code=NULL,queued_at=now()
   WHERE id=target.id;
  INSERT INTO outbox_events(topic,aggregate_kind,aggregate_id,aggregate_version,
    tenant_id,reset_generation,deletion_generation,dedupe_key,payload,schema_version,available_at)
  VALUES (CASE WHEN target.request_type='export' THEN 'privacy.export.requested'
               ELSE 'privacy.deletion.requested' END,
    CASE WHEN target.request_type='export' THEN 'privacy-request' ELSE 'deletion-tombstone' END,
    CASE WHEN target.request_type='export' THEN target.id ELSE target_tombstone_id END,
    coalesce(target.purge_generation,1),target.tenant_id,0,coalesce(target.purge_generation,0),
    'admin-retry:' || target.id::text || ':' || extract(epoch from clock_timestamp())::text,
    CASE WHEN target.request_type='export' THEN jsonb_build_object('request_id',target.id)
         ELSE jsonb_build_object('tombstone_id',target_tombstone_id,'privacy_request_id',target.id) END,
    1,now())
  RETURNING id INTO new_outbox_id;
  RETURN new_outbox_id;
END
$$;
ALTER FUNCTION ritual_private.admin_retry_privacy_request(uuid) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.admin_retry_privacy_request(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.admin_retry_privacy_request(uuid) TO ritual_staff;

CREATE OR REPLACE FUNCTION ritual_private.admin_job_page(
  target_status text,
  after_created_at timestamptz,
  after_id uuid,
  requested_limit integer
)
RETURNS TABLE(id uuid,outbox_id uuid,consumer text,status text,attempt integer,
  correlation_id uuid,failure_code text,created_at timestamptz,completed_at timestamptz)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT j.id,j.outbox_id,j.consumer,j.status,j.attempt,j.correlation_id,
         j.failure_code,j.created_at,j.completed_at
    FROM job_runs j
   WHERE (target_status IS NULL OR j.status=target_status)
     AND (after_created_at IS NULL OR (j.created_at,j.id)<(after_created_at,after_id))
   ORDER BY j.created_at DESC,j.id DESC
   LIMIT least(greatest(requested_limit,1),51)
$$;
ALTER FUNCTION ritual_private.admin_job_page(text,timestamptz,uuid,integer) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.admin_job_page(text,timestamptz,uuid,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.admin_job_page(text,timestamptz,uuid,integer) TO ritual_staff;

CREATE OR REPLACE FUNCTION ritual_private.admin_privacy_page(
  target_status text,
  after_queued_at timestamptz,
  after_id uuid,
  requested_limit integer
)
RETURNS TABLE(id uuid,tenant_id uuid,request_type text,status text,snapshot_at timestamptz,
  queued_at timestamptz,completed_at timestamptz,failure_code text,purge_generation integer)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT r.id,r.tenant_id,r.request_type,r.status,r.snapshot_at,r.queued_at,
         r.completed_at,r.failure_code,r.purge_generation
    FROM privacy_requests r
   WHERE (target_status IS NULL OR r.status=target_status)
     AND (after_queued_at IS NULL OR (r.queued_at,r.id)<(after_queued_at,after_id))
   ORDER BY r.queued_at DESC NULLS LAST,r.id DESC
   LIMIT least(greatest(requested_limit,1),51)
$$;
ALTER FUNCTION ritual_private.admin_privacy_page(text,timestamptz,uuid,integer) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.admin_privacy_page(text,timestamptz,uuid,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.admin_privacy_page(text,timestamptz,uuid,integer) TO ritual_staff;

CREATE OR REPLACE FUNCTION ritual_private.admin_retry_job_command(
  target_job_id uuid,
  target_staff_id uuid,
  target_reason text,
  target_request_id uuid,
  target_key text,
  target_request_hash text
)
RETURNS TABLE(id uuid,outbox_id uuid,consumer text,status text,attempt integer,
  correlation_id uuid,failure_code text,created_at timestamptz,completed_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE claimed integer;
DECLARE receipt admin_operation_receipts%ROWTYPE;
DECLARE target job_runs%ROWTYPE;
DECLARE source_event outbox_events%ROWTYPE;
DECLARE retry_id uuid:=gen_random_uuid();
DECLARE retry_outbox_id uuid;
DECLARE retry_correlation_id uuid:=gen_random_uuid();
DECLARE retry_created_at timestamptz;
BEGIN
  IF nullif(current_setting('ritual.staff_id',true),'')::uuid IS DISTINCT FROM target_staff_id
     OR NOT EXISTS (SELECT 1 FROM staff_principals staff WHERE staff.id=target_staff_id AND staff.status='active') THEN
    RAISE EXCEPTION 'staff context mismatch' USING ERRCODE='42501';
  END IF;
  INSERT INTO admin_operation_receipts(actor_staff_id,operation,idempotency_key,request_hash,response)
  VALUES(target_staff_id,'job.retry',target_key,target_request_hash,
         jsonb_build_object('job_id',target_job_id))
  ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS claimed=ROW_COUNT;
  SELECT * INTO receipt FROM admin_operation_receipts
   WHERE actor_staff_id=target_staff_id AND operation='job.retry'
     AND idempotency_key=target_key FOR UPDATE;
  IF receipt.request_hash<>target_request_hash THEN RAISE EXCEPTION 'idempotency_conflict'; END IF;
  SELECT job.* INTO target FROM job_runs job
   WHERE job.id=(receipt.response->>'job_id')::uuid FOR UPDATE;
  IF target.id IS NULL THEN RAISE EXCEPTION 'operation not found' USING ERRCODE='P0002'; END IF;
  IF target.status NOT IN ('retry','dead_letter') THEN RAISE EXCEPTION 'operation not retryable' USING ERRCODE='23514'; END IF;
  IF claimed=1 THEN
    SELECT event.* INTO source_event FROM outbox_events event WHERE event.id=target.outbox_id FOR UPDATE;
    IF source_event.id IS NULL THEN RAISE EXCEPTION 'source outbox event not found' USING ERRCODE='P0002'; END IF;
    INSERT INTO outbox_events AS retry_event(topic,aggregate_kind,aggregate_id,aggregate_version,tenant_id,reset_generation,deletion_generation,dedupe_key,payload,schema_version,available_at)
    VALUES(source_event.topic,source_event.aggregate_kind,source_event.aggregate_id,source_event.aggregate_version,source_event.tenant_id,source_event.reset_generation,source_event.deletion_generation,
           'admin-retry:'||target.id::text||':'||retry_id::text,source_event.payload,source_event.schema_version,now())
    RETURNING retry_event.id,retry_event.created_at INTO retry_outbox_id,retry_created_at;
    INSERT INTO job_runs(
      id,outbox_id,consumer,status,attempt,next_attempt_at,correlation_id,created_at
    ) VALUES (
      retry_id,retry_outbox_id,target.consumer,'retry',0,now(),
      retry_correlation_id,retry_created_at
    );
    UPDATE admin_operation_receipts
    SET response=jsonb_build_object('job_id',target.id,'retry_id',retry_id,'outbox_id',retry_outbox_id,
                                    'consumer',target.consumer,'correlation_id',retry_correlation_id,
                                    'created_at',retry_created_at)
    WHERE actor_staff_id=target_staff_id AND operation='job.retry' AND idempotency_key=target_key;
    INSERT INTO admin_audit_events(actor_staff_id,action,target_kind,target_id,reason,request_id,outcome)
    VALUES(target_staff_id,'job.retry','job_run',target.id,target_reason,target_request_id,'allowed');
  ELSE
    retry_id=(receipt.response->>'retry_id')::uuid;
    retry_outbox_id=(receipt.response->>'outbox_id')::uuid;
    retry_correlation_id=(receipt.response->>'correlation_id')::uuid;
    retry_created_at=(receipt.response->>'created_at')::timestamptz;
  END IF;
  RETURN QUERY SELECT retry_id,retry_outbox_id,target.consumer,'retry'::text,0::integer,
                      retry_correlation_id,NULL::text,retry_created_at,NULL::timestamptz;
END
$$;
ALTER FUNCTION ritual_private.admin_retry_job_command(uuid,uuid,text,uuid,text,text) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.admin_retry_job_command(uuid,uuid,text,uuid,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.admin_retry_job_command(uuid,uuid,text,uuid,text,text) TO ritual_staff;

CREATE OR REPLACE FUNCTION ritual_private.admin_retry_privacy_command(
  target_request_id uuid,
  target_staff_id uuid,
  target_reason text,
  target_request_correlation_id uuid,
  target_key text,
  target_request_hash text
)
RETURNS TABLE(outbox_id uuid,consumer text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE claimed integer;
DECLARE receipt admin_operation_receipts%ROWTYPE;
DECLARE new_outbox_id uuid;
DECLARE target_consumer text;
BEGIN
  IF nullif(current_setting('ritual.staff_id',true),'')::uuid IS DISTINCT FROM target_staff_id
     OR NOT EXISTS (SELECT 1 FROM staff_principals staff WHERE staff.id=target_staff_id AND staff.status='active') THEN
    RAISE EXCEPTION 'staff context mismatch' USING ERRCODE='42501';
  END IF;
  INSERT INTO admin_operation_receipts(actor_staff_id,operation,idempotency_key,request_hash,response)
  VALUES(target_staff_id,'privacy.retry',target_key,target_request_hash,'{}'::jsonb)
  ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS claimed=ROW_COUNT;
  SELECT * INTO receipt FROM admin_operation_receipts
   WHERE actor_staff_id=target_staff_id AND operation='privacy.retry'
     AND idempotency_key=target_key FOR UPDATE;
  IF receipt.request_hash<>target_request_hash THEN RAISE EXCEPTION 'idempotency_conflict'; END IF;
  IF claimed=0 THEN
    new_outbox_id:=(receipt.response->>'outbox_id')::uuid;
    SELECT CASE WHEN topic='privacy.export.requested' THEN 'privacy-export' ELSE 'privacy-purge' END
      INTO target_consumer FROM outbox_events WHERE id=new_outbox_id;
    RETURN QUERY SELECT new_outbox_id,target_consumer;
    RETURN;
  END IF;
  new_outbox_id:=ritual_private.admin_retry_privacy_request(target_request_id);
  SELECT CASE WHEN topic='privacy.export.requested' THEN 'privacy-export' ELSE 'privacy-purge' END
    INTO target_consumer FROM outbox_events WHERE id=new_outbox_id;
  UPDATE admin_operation_receipts
     SET response=jsonb_build_object('outbox_id',new_outbox_id)
   WHERE actor_staff_id=target_staff_id AND operation='privacy.retry'
     AND idempotency_key=target_key;
  INSERT INTO admin_audit_events(actor_staff_id,action,target_kind,target_id,reason,request_id,outcome)
  VALUES(target_staff_id,'privacy.retry','privacy_request',target_request_id,target_reason,
         target_request_correlation_id,'allowed');
  RETURN QUERY SELECT new_outbox_id,target_consumer;
END
$$;
ALTER FUNCTION ritual_private.admin_retry_privacy_command(uuid,uuid,text,uuid,text,text) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.admin_retry_privacy_command(uuid,uuid,text,uuid,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ritual_private.admin_retry_privacy_command(uuid,uuid,text,uuid,text,text) TO ritual_staff;
REVOKE EXECUTE ON FUNCTION ritual_private.admin_retry_privacy_request(uuid) FROM ritual_staff;
GRANT USAGE ON SCHEMA ritual_private TO ritual_staff;
GRANT SELECT ON TABLE staff_principals,job_runs,privacy_requests,outbox_events TO ritual_function_owner;
GRANT UPDATE ON TABLE job_runs TO ritual_function_owner;
GRANT INSERT,UPDATE ON TABLE admin_operation_receipts TO ritual_function_owner;
GRANT INSERT ON TABLE admin_audit_events,outbox_events TO ritual_function_owner;
GRANT UPDATE ON TABLE privacy_requests TO ritual_function_owner;

CREATE OR REPLACE FUNCTION ritual_private.enforce_outbox_transition()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'outbox events are append-only' USING ERRCODE = '55000';
  END IF;
  IF ROW(NEW.id, NEW.topic, NEW.aggregate_kind, NEW.aggregate_id, NEW.aggregate_version,
         NEW.reset_generation, NEW.deletion_generation, NEW.dedupe_key, NEW.payload,
         NEW.schema_version, NEW.available_at, NEW.created_at)
     IS DISTINCT FROM
     ROW(OLD.id, OLD.topic, OLD.aggregate_kind, OLD.aggregate_id, OLD.aggregate_version,
         OLD.reset_generation, OLD.deletion_generation, OLD.dedupe_key, OLD.payload,
         OLD.schema_version, OLD.available_at, OLD.created_at) THEN
    RAISE EXCEPTION 'outbox event identity and payload are immutable' USING ERRCODE = '55000';
  END IF;
  IF OLD.published_at IS NOT NULL AND NEW.published_at IS DISTINCT FROM OLD.published_at THEN
    RAISE EXCEPTION 'published outbox event is immutable' USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END
$$;

DROP TRIGGER outbox_events_immutable ON outbox_events;
CREATE TRIGGER outbox_events_transition
BEFORE UPDATE OR DELETE ON outbox_events
FOR EACH ROW EXECUTE FUNCTION ritual_private.enforce_outbox_transition();

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
DROP TRIGGER job_runs_immutable ON job_runs;
CREATE TRIGGER job_runs_transition
BEFORE UPDATE OR DELETE ON job_runs
FOR EACH ROW EXECUTE FUNCTION ritual_private.enforce_job_run_transition();

CREATE OR REPLACE FUNCTION ritual_private.enforce_watermark_monotonic()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog
AS $$
BEGIN
  IF NEW.reset_generation < OLD.reset_generation OR
     NEW.deletion_generation < OLD.deletion_generation OR
     (NEW.reset_generation = OLD.reset_generation AND
      NEW.deletion_generation = OLD.deletion_generation AND
      NEW.aggregate_version < OLD.aggregate_version) THEN
    RAISE EXCEPTION 'consumer watermark cannot regress' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;
CREATE TRIGGER aggregate_consumer_watermarks_monotonic
BEFORE UPDATE ON aggregate_consumer_watermarks
FOR EACH ROW EXECUTE FUNCTION ritual_private.enforce_watermark_monotonic();

CREATE OR REPLACE FUNCTION ritual_private.enforce_briefing_sequence_monotonic()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF NEW.is_current AND EXISTS (
    SELECT 1 FROM briefings b
    WHERE b.tenant_id = NEW.tenant_id
      AND b.briefing_type = NEW.briefing_type
      AND b.period_start = NEW.period_start
      AND b.period_end = NEW.period_end
      AND b.is_current
      AND b.id <> NEW.id
      AND ROW(b.reset_generation, b.deletion_generation, b.source_sequence, b.generation)
          >= ROW(NEW.reset_generation, NEW.deletion_generation, NEW.source_sequence, NEW.generation)
  ) THEN
    RAISE EXCEPTION 'briefing watermark cannot regress' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;
ALTER FUNCTION ritual_private.enforce_briefing_sequence_monotonic() OWNER TO ritual_function_owner;
GRANT SELECT ON TABLE briefings TO ritual_function_owner;
DROP TRIGGER briefings_generation_monotonic ON briefings;
CREATE TRIGGER briefings_sequence_monotonic
BEFORE INSERT OR UPDATE OF is_current, source_sequence, reset_generation, deletion_generation ON briefings
FOR EACH ROW EXECUTE FUNCTION ritual_private.enforce_briefing_sequence_monotonic();

CREATE OR REPLACE FUNCTION ritual_private.revoke_exports_for_deletion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF NEW.status IN ('deletion_pending','purging','purged') AND OLD.status IS DISTINCT FROM NEW.status THEN
    UPDATE privacy_requests
       SET status = 'cancelled', completed_at = COALESCE(completed_at, statement_timestamp()),
           failure_code = 'account_deletion'
     WHERE tenant_id = NEW.id AND request_type = 'export'
       AND status IN ('requested','verified','queued','processing');
    UPDATE privacy_export_artifacts
       SET publication_state = 'revoked', revoked_at = COALESCE(revoked_at, statement_timestamp()),
           link_nonce_hash = NULL, link_expires_at = NULL
     WHERE tenant_id = NEW.id AND publication_state IN ('staged','published');
  END IF;
  RETURN NEW;
END
$$;
ALTER FUNCTION ritual_private.revoke_exports_for_deletion() OWNER TO ritual_function_owner;
GRANT SELECT, UPDATE ON TABLE privacy_requests, privacy_export_artifacts TO ritual_function_owner;
CREATE TRIGGER tenants_revoke_exports_for_deletion
AFTER UPDATE OF status ON tenants
FOR EACH ROW EXECUTE FUNCTION ritual_private.revoke_exports_for_deletion();

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
  SELECT tenant_id, status INTO target_tenant_id, tombstone_status
    FROM deletion_tombstones
   WHERE id = target_tombstone_id AND purge_generation = target_generation
   FOR UPDATE;
  IF tombstone_status = 'purged' THEN
    SELECT id INTO receipt_id FROM purge_receipts
     WHERE tombstone_id = target_tombstone_id AND purge_generation = target_generation;
    IF receipt_id IS NULL THEN RAISE EXCEPTION 'purged tombstone has no receipt'; END IF;
    RETURN receipt_id;
  END IF;
  IF target_tenant_id IS NULL OR tombstone_status NOT IN ('pending','purging') OR
     NOT EXISTS (SELECT 1 FROM tenants WHERE id = target_tenant_id AND status = 'purging') THEN
    RAISE EXCEPTION 'purge scope is not authorized';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM deletion_journal_confirmations
     WHERE tombstone_id = target_tombstone_id AND purge_generation = target_generation
  ) THEN
    RAISE EXCEPTION 'journal confirmation required before purge';
  END IF;
  IF 2 <> (
    SELECT count(*) FROM deletion_object_receipts
     WHERE tombstone_id = target_tombstone_id AND purge_generation = target_generation
       AND confirmed_empty_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'external object purge confirmation required';
  END IF;
  INSERT INTO ritual_private.purge_guards(backend_pid, transaction_id, tenant_id, tombstone_id)
  VALUES (pg_backend_pid(), txid_current(), target_tenant_id, target_tombstone_id);
  PERFORM set_config('ritual.tenant_id', target_tenant_id::text, true);
  UPDATE deletion_tombstones SET status = 'purging' WHERE id = target_tombstone_id;
  DELETE FROM tenants WHERE id = target_tenant_id;
  UPDATE deletion_tombstones SET status = 'purged' WHERE id = target_tombstone_id;
  INSERT INTO purge_receipts(tombstone_id, purge_generation, started_at, completed_at, outcome_hash)
  VALUES (target_tombstone_id, target_generation, statement_timestamp(), clock_timestamp(),
          encode(digest(target_tombstone_id::text || ':' || target_generation::text, 'sha256'), 'hex'))
  ON CONFLICT (tombstone_id, purge_generation) DO NOTHING RETURNING id INTO receipt_id;
  IF receipt_id IS NULL THEN
    SELECT id INTO receipt_id FROM purge_receipts
     WHERE tombstone_id = target_tombstone_id AND purge_generation = target_generation;
  END IF;
  DELETE FROM ritual_private.purge_guards
   WHERE backend_pid = pg_backend_pid() AND transaction_id = txid_current();
  RETURN receipt_id;
END
$$;
ALTER FUNCTION ritual_private.purge_tombstoned_tenant(uuid, integer) OWNER TO ritual_function_owner;
REVOKE ALL ON FUNCTION ritual_private.purge_tombstoned_tenant(uuid, integer) FROM PUBLIC;
GRANT SELECT, UPDATE ON TABLE deletion_tombstones TO ritual_function_owner;
GRANT SELECT, DELETE ON TABLE tenants TO ritual_function_owner;
GRANT SELECT, INSERT, UPDATE ON TABLE purge_receipts TO ritual_function_owner;
GRANT SELECT ON TABLE deletion_journal_confirmations, deletion_object_receipts TO ritual_function_owner;
GRANT SELECT, INSERT, DELETE ON TABLE ritual_private.purge_guards TO ritual_function_owner;
GRANT EXECUTE ON FUNCTION ritual_private.purge_tombstoned_tenant(uuid, integer) TO ritual_privacy_purge;

REVOKE CREATE ON SCHEMA ritual_private FROM ritual_function_owner;
DO $$ BEGIN
  EXECUTE format('REVOKE ritual_function_owner FROM %I', current_user);
END $$;

COMMIT;
