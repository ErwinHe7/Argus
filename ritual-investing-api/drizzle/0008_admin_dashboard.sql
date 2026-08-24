BEGIN;

INSERT INTO ritual_private.schema_contract_versions(version, compatibility)
VALUES ('ritual-admin-v1-n', 'n')
ON CONFLICT (version) DO NOTHING;

ALTER TABLE editorial_items
  ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE editorial_revisions
  ADD COLUMN IF NOT EXISTS payload jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(payload)='object'),
  ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  ADD COLUMN IF NOT EXISTS submitted_at timestamptz;
ALTER TABLE assets ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 1 CHECK (version > 0);
ALTER TABLE evidence_sources ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 1 CHECK (version > 0);
ALTER TABLE seeded_creators ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 1 CHECK (version > 0);
ALTER TABLE ritual_schedules ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 1 CHECK (version > 0);
ALTER TABLE coven_qualifications ADD COLUMN IF NOT EXISTS submitted_by uuid REFERENCES staff_principals(id);
ALTER TABLE moderation_cases ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 1 CHECK (version > 0);
ALTER TABLE admin_operation_receipts
  DROP CONSTRAINT admin_operation_receipts_operation_check,
  ADD CONSTRAINT admin_operation_receipts_operation_check CHECK (
    operation IN ('job.retry','privacy.retry','media.upload-request','media.complete')
    OR (
      char_length(operation) BETWEEN 3 AND 160
      AND operation ~ '^(editorial|catalog|moderation):[a-z0-9:_-]+$'
    )
  );

CREATE TABLE IF NOT EXISTS briefing_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  editorial_item_id uuid NOT NULL UNIQUE REFERENCES editorial_items(id),
  template_key text NOT NULL UNIQUE,
  briefing_type text NOT NULL CHECK (briefing_type IN ('daily','weekly','moon_cycle'))
);
CREATE TABLE IF NOT EXISTS briefing_template_revisions (
  revision_id uuid PRIMARY KEY REFERENCES editorial_revisions(id),
  title text NOT NULL,
  sections jsonb NOT NULL CHECK (jsonb_typeof(sections)='array')
);
CREATE TABLE IF NOT EXISTS moderation_case_decisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id uuid NOT NULL REFERENCES moderation_cases(id),
  actor_staff_id uuid NOT NULL REFERENCES staff_principals(id),
  outcome text NOT NULL,
  reason text NOT NULL,
  decided_at timestamptz NOT NULL DEFAULT now()
);

-- The original trigger freezes the legacy row shape. Drop it transactionally
-- before backfilling the additive payload, then replace it below with the
-- reviewed draft-only transition guard.
DROP TRIGGER IF EXISTS editorial_revisions_immutable ON editorial_revisions;

UPDATE editorial_revisions revision
SET payload=jsonb_build_object(
  'scenario_key',scenario.scenario_key,'mode',scenario.mode,'cadence',scenario.cadence,
  'title',typed.title,'interpretation',typed.interpretation,'guidance',typed.guidance,
  'market_label',typed.market_label,'art_media_id',typed.art_media_id,
  'observation_at',typed.observation_at,'uncertainty',typed.uncertainty,
  'ideas',coalesce((SELECT jsonb_agg(jsonb_build_object('asset_id',idea.asset_id,'appearance_reason',idea.appearance_reason,'risk_summary',idea.risk_summary) ORDER BY idea.ordinal) FROM ritual_scenario_ideas idea WHERE idea.revision_id=revision.id),'[]'::jsonb),
  'evidence',coalesce((SELECT jsonb_agg(jsonb_build_object('claim_id',evidence.claim_id,'factor_label',evidence.factor_label) ORDER BY evidence.ordinal) FROM ritual_scenario_evidence evidence WHERE evidence.revision_id=revision.id),'[]'::jsonb)
)
FROM editorial_items item
JOIN ritual_scenarios scenario ON scenario.editorial_item_id=item.id
JOIN ritual_scenario_revisions typed ON true
WHERE revision.item_id=item.id AND typed.revision_id=revision.id AND item.kind='ritual';

UPDATE editorial_revisions revision
SET payload=jsonb_build_object(
  'asset_id',entry.asset_id,'thesis',typed.thesis,'appearance_reason',typed.appearance_reason,
  'metrics_as_of',typed.metrics_as_of,'limitations',typed.limitations,
  'risks',coalesce((SELECT jsonb_agg(jsonb_build_object('title',risk.title,'detail',risk.detail,'severity',risk.severity) ORDER BY risk.ordinal) FROM asset_codex_risks risk WHERE risk.revision_id=revision.id),'[]'::jsonb),
  'evidence_claim_ids',coalesce((SELECT jsonb_agg(evidence.claim_id ORDER BY evidence.ordinal) FROM asset_codex_evidence evidence WHERE evidence.revision_id=revision.id),'[]'::jsonb)
)
FROM editorial_items item
JOIN asset_codex_entries entry ON entry.editorial_item_id=item.id
JOIN asset_codex_revisions typed ON true
WHERE revision.item_id=item.id AND typed.revision_id=revision.id AND item.kind='asset_codex';

UPDATE editorial_revisions revision
SET payload=jsonb_build_object('company_id',entry.company_id,'summary',typed.summary,'inclusion_rationale',typed.inclusion_rationale,'limitations',typed.limitations)
FROM editorial_items item
JOIN coven_entries entry ON entry.editorial_item_id=item.id
JOIN coven_entry_revisions typed ON true
WHERE revision.item_id=item.id AND typed.revision_id=revision.id AND item.kind='coven';

UPDATE editorial_revisions revision
SET payload=jsonb_build_object(
  'theme_code',grimoire.theme_code,'title',typed.title,'description',typed.description,'curator_label',typed.curator_label,'art_media_id',typed.art_media_id,
  'assets',coalesce((SELECT jsonb_agg(jsonb_build_object('asset_id',asset.asset_id,'note',asset.note) ORDER BY asset.ordinal) FROM grimoire_revision_assets asset WHERE asset.revision_id=revision.id),'[]'::jsonb)
)
FROM editorial_items item
JOIN grimoires grimoire ON grimoire.editorial_item_id=item.id
JOIN grimoire_revisions typed ON true
WHERE revision.item_id=item.id AND typed.revision_id=revision.id AND item.kind='grimoire';

UPDATE editorial_revisions revision
SET payload=jsonb_build_object(
  'creator_id',template.creator_id,'theme_code',template.theme_code,'title',typed.title,'description',typed.description,'art_media_id',typed.art_media_id,
  'assets',coalesce((SELECT jsonb_agg(jsonb_build_object('asset_id',asset.asset_id,'note',asset.note,'weight_bps',asset.weight_bps) ORDER BY asset.ordinal) FROM circle_template_assets asset WHERE asset.revision_id=revision.id),'[]'::jsonb)
)
FROM editorial_items item
JOIN circle_templates template ON template.editorial_item_id=item.id
JOIN circle_template_revisions typed ON true
WHERE revision.item_id=item.id AND typed.revision_id=revision.id AND item.kind='circle_template';

UPDATE editorial_revisions revision
SET payload=jsonb_build_object('script_key',script.script_key,'surface',script.surface,'body_template',typed.body_template,'allowed_tokens',typed.allowed_tokens,'risk_footer',typed.risk_footer)
FROM editorial_items item
JOIN rowan_scripts script ON script.editorial_item_id=item.id
JOIN rowan_script_revisions typed ON true
WHERE revision.item_id=item.id AND typed.revision_id=revision.id AND item.kind='rowan';

UPDATE editorial_revisions SET content_hash=encode(digest(payload::text,'sha256'),'hex');

CREATE OR REPLACE FUNCTION ritual_private.enforce_editorial_revision_transition()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
BEGIN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'immutable editorial revision'; END IF;
  IF NEW.id<>OLD.id OR NEW.item_id<>OLD.item_id OR NEW.revision_number<>OLD.revision_number
     OR NEW.author_staff_id<>OLD.author_staff_id OR NEW.created_at<>OLD.created_at THEN
    RAISE EXCEPTION 'immutable editorial revision identity';
  END IF;
  IF OLD.state='draft' AND NEW.state='draft' THEN
    IF NEW.version<>OLD.version+1 THEN RAISE EXCEPTION 'version_conflict'; END IF;
    RETURN NEW;
  END IF;
  IF OLD.state='draft' AND NEW.state='submitted' THEN
    IF NEW.payload<>OLD.payload OR NEW.content_hash<>OLD.content_hash OR NEW.version<>OLD.version THEN
      RAISE EXCEPTION 'immutable submitted payload';
    END IF;
    RETURN NEW;
  END IF;
  IF OLD.state='submitted' AND NEW.state IN ('approved','rejected') THEN
    IF NEW.payload<>OLD.payload OR NEW.content_hash<>OLD.content_hash OR NEW.version<>OLD.version THEN
      RAISE EXCEPTION 'immutable reviewed payload';
    END IF;
    RETURN NEW;
  END IF;
  IF OLD.state='approved' AND NEW.state='published' THEN
    IF NEW.payload<>OLD.payload OR NEW.content_hash<>OLD.content_hash OR NEW.version<>OLD.version THEN
      RAISE EXCEPTION 'immutable published payload';
    END IF;
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'invalid_transition';
END $$;
REVOKE ALL ON FUNCTION ritual_private.enforce_editorial_revision_transition() FROM PUBLIC;
CREATE TRIGGER editorial_revisions_transition BEFORE UPDATE OR DELETE ON editorial_revisions
FOR EACH ROW EXECUTE FUNCTION ritual_private.enforce_editorial_revision_transition();

CREATE TRIGGER briefing_template_revisions_immutable BEFORE UPDATE OR DELETE ON briefing_template_revisions
FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();
CREATE TRIGGER moderation_case_decisions_immutable BEFORE UPDATE OR DELETE ON moderation_case_decisions
FOR EACH ROW EXECUTE FUNCTION ritual_private.reject_immutable_change();

CREATE OR REPLACE FUNCTION ritual_private.assert_active_staff(target_staff_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
BEGIN
  IF current_setting('ritual.staff_id',true) IS DISTINCT FROM target_staff_id::text
     OR NOT EXISTS (SELECT 1 FROM staff_principals WHERE id=target_staff_id AND status='active') THEN
    RAISE EXCEPTION 'staff_denied';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.record_admin_denial(
  target_staff_id uuid, target_action text, target_reason text, target_request_id uuid
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE audit_id uuid;
BEGIN
  PERFORM ritual_private.assert_active_staff(target_staff_id);
  IF char_length(target_action) NOT BETWEEN 1 AND 160 OR char_length(target_reason) NOT BETWEEN 1 AND 500 THEN
    RAISE EXCEPTION 'invalid_audit';
  END IF;
  INSERT INTO admin_audit_events(actor_staff_id,action,target_kind,target_id,reason,request_id,outcome)
  VALUES(target_staff_id,target_action,'route',NULL,target_reason,target_request_id,'denied') RETURNING id INTO audit_id;
  RETURN audit_id;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.admin_idempotency_replay(
  target_staff_id uuid, target_operation text, target_key text, target_hash text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE found_hash text; found_response jsonb;
BEGIN
  SELECT request_hash,response INTO found_hash,found_response
  FROM admin_operation_receipts
  WHERE actor_staff_id=target_staff_id AND operation=target_operation AND idempotency_key=target_key
  FOR UPDATE;
  IF found_hash IS NULL THEN RETURN NULL; END IF;
  IF found_hash<>target_hash THEN RAISE EXCEPTION 'idempotency_conflict'; END IF;
  RETURN found_response;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.admin_idempotency_store(
  target_staff_id uuid, target_operation text, target_key text, target_hash text, target_response jsonb
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
BEGIN
  INSERT INTO admin_operation_receipts(actor_staff_id,operation,idempotency_key,request_hash,response)
  VALUES(target_staff_id,target_operation,target_key,target_hash,target_response);
END $$;

CREATE OR REPLACE FUNCTION ritual_private.admin_revision_view(target_revision_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
SELECT jsonb_build_object(
  'id',revision.id,'revision_number',revision.revision_number,
  'state',CASE WHEN revision.state='submitted' THEN 'in_review'
               WHEN revision.state='rejected' AND decision.decision='changes_requested' THEN 'changes_requested'
               ELSE revision.state END,
  'version',revision.version,'author_staff_id',revision.author_staff_id,
  'payload',revision.payload,'etag',format('"v%s"',revision.version)
)
FROM editorial_revisions revision
LEFT JOIN LATERAL (
  SELECT review_decision.decision
  FROM editorial_review_requests request
  JOIN editorial_review_decisions review_decision ON review_decision.request_id=request.id
  WHERE request.revision_id=revision.id
  ORDER BY review_decision.decided_at DESC,review_decision.id DESC LIMIT 1
) decision ON true
WHERE revision.id=target_revision_id
$$;

CREATE OR REPLACE FUNCTION ritual_private.admin_item_view(target_item_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
SELECT jsonb_build_object(
  'id',item.id,
  'kind',CASE item.kind WHEN 'ritual' THEN 'ritual_scenario' WHEN 'coven' THEN 'coven_entry' WHEN 'rowan' THEN 'rowan_script' ELSE item.kind END,
  'slug',item.slug,'status',item.status,'version',item.version,
  'current_published_revision_id',item.current_published_revision_id,
  'revision',ritual_private.admin_revision_view(latest.id),'etag',format('"v%s"',item.version)
)
FROM editorial_items item
LEFT JOIN LATERAL (SELECT id FROM editorial_revisions WHERE item_id=item.id ORDER BY revision_number DESC LIMIT 1) latest ON true
WHERE item.id=target_item_id
$$;

REVOKE ALL ON FUNCTION ritual_private.record_admin_denial(uuid,text,text,uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION ritual_private.assert_active_staff(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION ritual_private.admin_idempotency_replay(uuid,text,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ritual_private.admin_idempotency_store(uuid,text,text,text,jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION ritual_private.admin_revision_view(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION ritual_private.admin_item_view(uuid) FROM PUBLIC;

CREATE OR REPLACE FUNCTION ritual_private.materialize_editorial_revision(
  target_kind text, target_revision_id uuid, target_payload jsonb
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE item_count integer; total_weight integer;
BEGIN
  IF target_payload ? 'art_media_id' AND target_payload->>'art_media_id' IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM media_assets WHERE id=(target_payload->>'art_media_id')::uuid AND status='active' AND quarantine_status='clear'
  ) THEN RAISE EXCEPTION 'publishability_failed'; END IF;
  IF target_kind='ritual_scenario' THEN
    IF jsonb_array_length(target_payload->'ideas') NOT BETWEEN 3 AND 5 OR jsonb_array_length(target_payload->'evidence')<1 THEN
      RAISE EXCEPTION 'publishability_failed';
    END IF;
    INSERT INTO ritual_scenario_revisions(revision_id,title,interpretation,guidance,market_label,art_media_id,observation_at,uncertainty)
    VALUES(target_revision_id,target_payload->>'title',target_payload->>'interpretation',target_payload->>'guidance',target_payload->>'market_label',(target_payload->>'art_media_id')::uuid,(target_payload->>'observation_at')::timestamptz,target_payload->>'uncertainty')
    ON CONFLICT (revision_id) DO NOTHING;
    INSERT INTO ritual_scenario_ideas(revision_id,asset_id,ordinal,appearance_reason,risk_summary)
    SELECT target_revision_id,(entry.value->>'asset_id')::uuid,entry.ordinality,entry.value->>'appearance_reason',entry.value->>'risk_summary'
    FROM jsonb_array_elements(target_payload->'ideas') WITH ORDINALITY entry(value,ordinality)
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS item_count=ROW_COUNT;
    IF item_count<>jsonb_array_length(target_payload->'ideas') THEN RAISE EXCEPTION 'publishability_failed'; END IF;
    INSERT INTO ritual_scenario_evidence(revision_id,claim_id,ordinal,factor_label)
    SELECT target_revision_id,(entry.value->>'claim_id')::uuid,entry.ordinality,entry.value->>'factor_label'
    FROM jsonb_array_elements(target_payload->'evidence') WITH ORDINALITY entry(value,ordinality)
    JOIN evidence_claims claim ON claim.id=(entry.value->>'claim_id')::uuid AND claim.status='active'
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS item_count=ROW_COUNT;
    IF item_count<>jsonb_array_length(target_payload->'evidence') THEN RAISE EXCEPTION 'publishability_failed'; END IF;
  ELSIF target_kind='asset_codex' THEN
    IF jsonb_array_length(target_payload->'risks')<1 OR jsonb_array_length(target_payload->'evidence_claim_ids')<1 THEN RAISE EXCEPTION 'publishability_failed'; END IF;
    INSERT INTO asset_codex_revisions(revision_id,thesis,appearance_reason,metrics_as_of,limitations)
    VALUES(target_revision_id,target_payload->>'thesis',target_payload->>'appearance_reason',(target_payload->>'metrics_as_of')::timestamptz,target_payload->>'limitations') ON CONFLICT DO NOTHING;
    INSERT INTO asset_codex_risks(revision_id,ordinal,title,detail,severity)
    SELECT target_revision_id,entry.ordinality,entry.value->>'title',entry.value->>'detail',entry.value->>'severity'
    FROM jsonb_array_elements(target_payload->'risks') WITH ORDINALITY entry(value,ordinality) ON CONFLICT DO NOTHING;
    INSERT INTO asset_codex_evidence(revision_id,claim_id,ordinal)
    SELECT target_revision_id,(entry.value#>>'{}')::uuid,entry.ordinality
    FROM jsonb_array_elements(target_payload->'evidence_claim_ids') WITH ORDINALITY entry(value,ordinality)
    JOIN evidence_claims claim ON claim.id=(entry.value#>>'{}')::uuid AND claim.status='active' ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS item_count=ROW_COUNT;
    IF item_count<>jsonb_array_length(target_payload->'evidence_claim_ids') THEN RAISE EXCEPTION 'publishability_failed'; END IF;
  ELSIF target_kind='coven_entry' THEN
    INSERT INTO coven_entry_revisions(revision_id,summary,inclusion_rationale,limitations)
    VALUES(target_revision_id,target_payload->>'summary',target_payload->>'inclusion_rationale',target_payload->>'limitations') ON CONFLICT DO NOTHING;
  ELSIF target_kind='grimoire' THEN
    INSERT INTO grimoire_revisions(revision_id,title,description,curator_label,art_media_id)
    VALUES(target_revision_id,target_payload->>'title',target_payload->>'description',target_payload->>'curator_label',(target_payload->>'art_media_id')::uuid) ON CONFLICT DO NOTHING;
    INSERT INTO grimoire_revision_assets(revision_id,asset_id,ordinal,note)
    SELECT target_revision_id,(entry.value->>'asset_id')::uuid,entry.ordinality,entry.value->>'note'
    FROM jsonb_array_elements(target_payload->'assets') WITH ORDINALITY entry(value,ordinality) ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS item_count=ROW_COUNT;
    IF item_count<>jsonb_array_length(target_payload->'assets') THEN RAISE EXCEPTION 'publishability_failed'; END IF;
  ELSIF target_kind='circle_template' THEN
    SELECT sum((entry.value->>'weight_bps')::integer) INTO total_weight FROM jsonb_array_elements(target_payload->'assets') entry(value);
    IF total_weight<>10000 THEN RAISE EXCEPTION 'publishability_failed'; END IF;
    INSERT INTO circle_template_revisions(revision_id,title,description,art_media_id)
    VALUES(target_revision_id,target_payload->>'title',target_payload->>'description',(target_payload->>'art_media_id')::uuid) ON CONFLICT DO NOTHING;
    INSERT INTO circle_template_assets(revision_id,asset_id,ordinal,weight_bps,note)
    SELECT target_revision_id,(entry.value->>'asset_id')::uuid,entry.ordinality,(entry.value->>'weight_bps')::integer,entry.value->>'note'
    FROM jsonb_array_elements(target_payload->'assets') WITH ORDINALITY entry(value,ordinality) ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS item_count=ROW_COUNT;
    IF item_count<>jsonb_array_length(target_payload->'assets') THEN RAISE EXCEPTION 'publishability_failed'; END IF;
  ELSIF target_kind='rowan_script' THEN
    IF target_payload->>'body_template' ~* '(urgent|exclusive|only I|guarantee|must invest|act now|love you|jealous)' THEN RAISE EXCEPTION 'publishability_failed'; END IF;
    INSERT INTO rowan_script_revisions(revision_id,body_template,allowed_tokens,risk_footer)
    VALUES(target_revision_id,target_payload->>'body_template',target_payload->'allowed_tokens',target_payload->>'risk_footer') ON CONFLICT DO NOTHING;
  ELSIF target_kind='briefing_template' THEN
    INSERT INTO briefing_template_revisions(revision_id,title,sections)
    VALUES(target_revision_id,target_payload->>'title',target_payload->'sections') ON CONFLICT DO NOTHING;
  ELSE RAISE EXCEPTION 'invalid editorial kind';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.admin_editorial_page(
  target_kind text,target_state text,target_author uuid,target_search text,target_after text,target_limit integer
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE database_kind text; result jsonb;
BEGIN
  database_kind=CASE target_kind WHEN 'ritual_scenario' THEN 'ritual' WHEN 'coven_entry' THEN 'coven' WHEN 'rowan_script' THEN 'rowan' ELSE target_kind END;
  IF target_limit NOT BETWEEN 1 AND 50 THEN RAISE EXCEPTION 'invalid_limit'; END IF;
  SELECT jsonb_build_object(
    'items',coalesce(jsonb_agg(ritual_private.admin_item_view(page.id) ORDER BY page.slug,page.id),'[]'::jsonb),
    'next',CASE WHEN count(*)=target_limit THEN max(page.slug||'|'||page.id::text) ELSE NULL END
  ) INTO result
  FROM (
    SELECT item.id,item.slug FROM editorial_items item
    WHERE item.kind=database_kind
      AND (target_state IS NULL OR item.status=target_state)
      AND (target_search IS NULL OR item.slug ILIKE '%'||replace(replace(target_search,'%',''),'_','')||'%')
      AND (target_author IS NULL OR EXISTS (SELECT 1 FROM editorial_revisions revision WHERE revision.item_id=item.id AND revision.author_staff_id=target_author))
      AND (target_after IS NULL OR item.slug||'|'||item.id::text>target_after)
    ORDER BY item.slug,item.id LIMIT target_limit
  ) page;
  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.admin_editorial_item(target_kind text,target_item_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE database_kind text; result jsonb;
BEGIN
  database_kind=CASE target_kind WHEN 'ritual_scenario' THEN 'ritual' WHEN 'coven_entry' THEN 'coven' WHEN 'rowan_script' THEN 'rowan' ELSE target_kind END;
  SELECT ritual_private.admin_item_view(id) INTO result FROM editorial_items WHERE id=target_item_id AND kind=database_kind;
  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.admin_editorial_revision(target_kind text,target_item_id uuid,target_revision_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE database_kind text; result jsonb;
BEGIN
  database_kind=CASE target_kind WHEN 'ritual_scenario' THEN 'ritual' WHEN 'coven_entry' THEN 'coven' WHEN 'rowan_script' THEN 'rowan' ELSE target_kind END;
  SELECT ritual_private.admin_revision_view(revision.id) INTO result FROM editorial_revisions revision JOIN editorial_items item ON item.id=revision.item_id WHERE revision.id=target_revision_id AND item.id=target_item_id AND item.kind=database_kind;
  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.admin_editorial_create(
  target_staff_id uuid,target_kind text,target_slug text,target_payload jsonb,target_request_id uuid,target_key text,target_hash text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE database_kind text; operation text; replay jsonb; item_id uuid; revision_id uuid; result jsonb; after_digest text;
BEGIN
  PERFORM ritual_private.assert_active_staff(target_staff_id);
  database_kind=CASE target_kind WHEN 'ritual_scenario' THEN 'ritual' WHEN 'coven_entry' THEN 'coven' WHEN 'rowan_script' THEN 'rowan' ELSE target_kind END;
  IF database_kind NOT IN ('ritual','asset_codex','coven','grimoire','circle_template','rowan','briefing_template') OR target_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' THEN RAISE EXCEPTION 'invalid_transition'; END IF;
  operation='editorial:'||target_kind||':create'; replay=ritual_private.admin_idempotency_replay(target_staff_id,operation,target_key,target_hash); IF replay IS NOT NULL THEN RETURN replay; END IF;
  INSERT INTO editorial_items(kind,slug,status) VALUES(database_kind,target_slug,'draft') RETURNING id INTO item_id;
  INSERT INTO editorial_revisions(item_id,revision_number,state,author_staff_id,content_hash,payload)
  VALUES(item_id,1,'draft',target_staff_id,encode(digest(target_payload::text,'sha256'),'hex'),target_payload) RETURNING id INTO revision_id;
  IF target_kind='ritual_scenario' THEN INSERT INTO ritual_scenarios(editorial_item_id,scenario_key,mode,cadence) VALUES(item_id,target_payload->>'scenario_key',target_payload->>'mode',target_payload->>'cadence');
  ELSIF target_kind='asset_codex' THEN INSERT INTO asset_codex_entries(editorial_item_id,asset_id) VALUES(item_id,(target_payload->>'asset_id')::uuid);
  ELSIF target_kind='coven_entry' THEN INSERT INTO coven_entries(editorial_item_id,company_id) VALUES(item_id,(target_payload->>'company_id')::uuid);
  ELSIF target_kind='grimoire' THEN INSERT INTO grimoires(editorial_item_id,theme_code) VALUES(item_id,target_payload->>'theme_code');
  ELSIF target_kind='circle_template' THEN INSERT INTO circle_templates(editorial_item_id,creator_id,theme_code) VALUES(item_id,(target_payload->>'creator_id')::uuid,target_payload->>'theme_code');
  ELSIF target_kind='rowan_script' THEN INSERT INTO rowan_scripts(editorial_item_id,script_key,surface) VALUES(item_id,target_payload->>'script_key',target_payload->>'surface');
  ELSIF target_kind='briefing_template' THEN INSERT INTO briefing_templates(editorial_item_id,template_key,briefing_type) VALUES(item_id,target_payload->>'template_key',target_payload->>'briefing_type'); END IF;
  after_digest=encode(digest(target_payload::text,'sha256'),'hex');
  INSERT INTO admin_audit_events(actor_staff_id,action,target_kind,target_id,after_hash,reason,request_id,outcome) VALUES(target_staff_id,operation,target_kind,item_id,after_digest,'Created editorial draft.',target_request_id,'allowed');
  result=ritual_private.admin_item_view(item_id); PERFORM ritual_private.admin_idempotency_store(target_staff_id,operation,target_key,target_hash,result); RETURN result;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.admin_editorial_revision_create(
  target_staff_id uuid,target_kind text,target_item_id uuid,target_source_revision_id uuid,target_payload jsonb,target_request_id uuid,target_key text,target_hash text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE operation text; replay jsonb; new_revision_id uuid; next_number integer; result jsonb;
BEGIN
  PERFORM ritual_private.assert_active_staff(target_staff_id); operation='editorial:'||target_kind||':revision:create'; replay=ritual_private.admin_idempotency_replay(target_staff_id,operation,target_key,target_hash); IF replay IS NOT NULL THEN RETURN replay; END IF;
  IF ritual_private.admin_editorial_item(target_kind,target_item_id) IS NULL OR NOT EXISTS(SELECT 1 FROM editorial_revisions WHERE id=target_source_revision_id AND item_id=target_item_id) THEN RAISE EXCEPTION 'not_found'; END IF;
  PERFORM 1 FROM editorial_items WHERE id=target_item_id FOR UPDATE;
  SELECT coalesce(max(revision_number),0)+1 INTO next_number FROM editorial_revisions WHERE item_id=target_item_id;
  INSERT INTO editorial_revisions(item_id,revision_number,state,author_staff_id,content_hash,payload) VALUES(target_item_id,next_number,'draft',target_staff_id,encode(digest(target_payload::text,'sha256'),'hex'),target_payload) RETURNING id INTO new_revision_id;
  UPDATE editorial_items SET version=version+1,updated_at=now() WHERE id=target_item_id;
  INSERT INTO admin_audit_events(actor_staff_id,action,target_kind,target_id,before_hash,after_hash,reason,request_id,outcome) SELECT target_staff_id,operation,target_kind,target_item_id,content_hash,encode(digest(target_payload::text,'sha256'),'hex'),'Created a new draft from an immutable revision.',target_request_id,'allowed' FROM editorial_revisions WHERE id=target_source_revision_id;
  result=ritual_private.admin_item_view(target_item_id); PERFORM ritual_private.admin_idempotency_store(target_staff_id,operation,target_key,target_hash,result); RETURN result;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.admin_editorial_revision_patch(
  target_staff_id uuid,target_kind text,target_item_id uuid,target_revision_id uuid,target_version integer,target_patch jsonb,target_request_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE before_digest text; result jsonb;
BEGIN
  PERFORM ritual_private.assert_active_staff(target_staff_id);
  SELECT content_hash INTO before_digest FROM editorial_revisions WHERE id=target_revision_id AND item_id=target_item_id AND state='draft' AND version=target_version FOR UPDATE;
  IF before_digest IS NULL THEN
    IF ritual_private.admin_editorial_revision(target_kind,target_item_id,target_revision_id) IS NULL THEN RAISE EXCEPTION 'not_found'; ELSE RAISE EXCEPTION 'version_conflict'; END IF;
  END IF;
  UPDATE editorial_revisions SET payload=target_patch,content_hash=encode(digest(target_patch::text,'sha256'),'hex'),version=version+1 WHERE id=target_revision_id;
  INSERT INTO admin_audit_events(actor_staff_id,action,target_kind,target_id,before_hash,after_hash,reason,request_id,outcome) VALUES(target_staff_id,'editorial:'||target_kind||':revision:patch',target_kind,target_revision_id,before_digest,encode(digest(target_patch::text,'sha256'),'hex'),'Updated editorial draft.',target_request_id,'allowed');
  result=ritual_private.admin_revision_view(target_revision_id); RETURN result;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.admin_editorial_review_request(
  target_staff_id uuid,target_kind text,target_item_id uuid,target_revision_id uuid,target_note text,target_high_trust boolean,target_request_id uuid,target_key text,target_hash text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE operation text; replay jsonb; payload_value jsonb; result jsonb; classified boolean;
BEGIN
  PERFORM ritual_private.assert_active_staff(target_staff_id); operation='editorial:'||target_kind||':review-request'; replay=ritual_private.admin_idempotency_replay(target_staff_id,operation,target_key,target_hash); IF replay IS NOT NULL THEN RETURN replay; END IF;
  SELECT payload INTO payload_value FROM editorial_revisions WHERE id=target_revision_id AND item_id=target_item_id AND state='draft' AND author_staff_id=target_staff_id FOR UPDATE;
  IF payload_value IS NULL THEN RAISE EXCEPTION 'invalid_transition'; END IF;
  classified=target_high_trust OR target_kind IN ('ritual_scenario','rowan_script');
  PERFORM ritual_private.materialize_editorial_revision(target_kind,target_revision_id,payload_value);
  INSERT INTO editorial_review_requests(revision_id,requested_by,high_trust,status) VALUES(target_revision_id,target_staff_id,classified,'open');
  UPDATE editorial_revisions SET state='submitted',submitted_at=now() WHERE id=target_revision_id;
  INSERT INTO admin_audit_events(actor_staff_id,action,target_kind,target_id,after_hash,reason,request_id,outcome) VALUES(target_staff_id,operation,target_kind,target_revision_id,encode(digest(payload_value::text,'sha256'),'hex'),target_note,target_request_id,'allowed');
  result=ritual_private.admin_revision_view(target_revision_id); PERFORM ritual_private.admin_idempotency_store(target_staff_id,operation,target_key,target_hash,result); RETURN result;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.admin_editorial_review_decision(
  target_staff_id uuid,target_kind text,target_item_id uuid,target_revision_id uuid,target_decision text,target_reason text,target_request_id uuid,target_key text,target_hash text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE operation text; replay jsonb; request_record editorial_review_requests%ROWTYPE; author_id uuid; result jsonb;
BEGIN
  PERFORM ritual_private.assert_active_staff(target_staff_id); operation='editorial:'||target_kind||':review-decision'; replay=ritual_private.admin_idempotency_replay(target_staff_id,operation,target_key,target_hash); IF replay IS NOT NULL THEN RETURN replay; END IF;
  SELECT request.* INTO request_record FROM editorial_review_requests request JOIN editorial_revisions revision ON revision.id=request.revision_id WHERE request.revision_id=target_revision_id AND revision.item_id=target_item_id AND revision.state='submitted' ORDER BY request.requested_at DESC LIMIT 1 FOR UPDATE OF request;
  IF request_record.id IS NULL THEN RAISE EXCEPTION 'invalid_transition'; END IF;
  SELECT author_staff_id INTO author_id FROM editorial_revisions WHERE id=target_revision_id;
  IF request_record.high_trust AND author_id=target_staff_id THEN
    INSERT INTO admin_audit_events(actor_staff_id,action,target_kind,target_id,reason,request_id,outcome) VALUES(target_staff_id,operation,target_kind,target_revision_id,'Self-approval denied for a high-trust revision.',target_request_id,'denied');
    RETURN jsonb_build_object('_denied','self_approval');
  END IF;
  INSERT INTO editorial_review_decisions(request_id,reviewer_id,decision,reason) VALUES(request_record.id,target_staff_id,target_decision,target_reason);
  UPDATE editorial_revisions SET state=CASE WHEN target_decision='approved' THEN 'approved' ELSE 'rejected' END WHERE id=target_revision_id;
  INSERT INTO admin_audit_events(actor_staff_id,action,target_kind,target_id,reason,request_id,outcome) VALUES(target_staff_id,operation,target_kind,target_revision_id,target_reason,target_request_id,'allowed');
  result=ritual_private.admin_revision_view(target_revision_id); PERFORM ritual_private.admin_idempotency_store(target_staff_id,operation,target_key,target_hash,result); RETURN result;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.admin_editorial_publish(
  target_staff_id uuid,target_kind text,target_item_id uuid,target_revision_id uuid,target_effective_at timestamptz,target_reason text,target_request_id uuid,target_key text,target_hash text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE operation text; replay jsonb; result jsonb; previous_id uuid; event_action text;
BEGIN
  PERFORM ritual_private.assert_active_staff(target_staff_id); operation='editorial:'||target_kind||':publish'; replay=ritual_private.admin_idempotency_replay(target_staff_id,operation,target_key,target_hash); IF replay IS NOT NULL THEN RETURN replay; END IF;
  IF NOT EXISTS(SELECT 1 FROM editorial_revisions WHERE id=target_revision_id AND item_id=target_item_id AND state='approved') THEN RAISE EXCEPTION 'invalid_transition'; END IF;
  SELECT current_published_revision_id INTO previous_id FROM editorial_items WHERE id=target_item_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'not_found'; END IF;
  event_action=CASE WHEN target_effective_at<=now() THEN 'publish' ELSE 'schedule' END;
  INSERT INTO publication_events(item_id,revision_id,action,effective_at,actor_id,reason) VALUES(target_item_id,target_revision_id,event_action,target_effective_at,target_staff_id,target_reason);
  IF event_action='publish' THEN
    UPDATE editorial_revisions SET state='published'
    WHERE id=target_revision_id AND item_id=target_item_id AND state='approved';
    IF NOT FOUND THEN RAISE EXCEPTION 'invalid_transition'; END IF;
    UPDATE editorial_items SET current_published_revision_id=target_revision_id,status='published',version=version+1,updated_at=now() WHERE id=target_item_id;
  ELSE
    UPDATE editorial_items SET version=version+1,updated_at=now() WHERE id=target_item_id;
    INSERT INTO outbox_events(topic,aggregate_kind,aggregate_id,aggregate_version,tenant_id,reset_generation,dedupe_key,payload,available_at,deletion_generation)
    SELECT 'editorial.publication.scheduled','editorial-item',target_item_id,version,NULL,0,target_item_id::text||':'||target_revision_id::text||':'||version::text,jsonb_build_object('item_id',target_item_id,'revision_id',target_revision_id,'actor_staff_id',target_staff_id,'reason',target_reason),target_effective_at,0 FROM editorial_items WHERE id=target_item_id;
  END IF;
  INSERT INTO admin_audit_events(actor_staff_id,action,target_kind,target_id,before_hash,after_hash,reason,request_id,outcome) VALUES(target_staff_id,operation,target_kind,target_item_id,CASE WHEN previous_id IS NULL THEN NULL ELSE encode(digest(previous_id::text,'sha256'),'hex') END,encode(digest(target_revision_id::text,'sha256'),'hex'),target_reason,target_request_id,'allowed');
  result=ritual_private.admin_item_view(target_item_id); PERFORM ritual_private.admin_idempotency_store(target_staff_id,operation,target_key,target_hash,result); RETURN result;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.admin_editorial_withdraw(
  target_staff_id uuid,target_kind text,target_item_id uuid,target_reason text,target_request_id uuid,target_key text,target_hash text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE operation text; replay jsonb; previous_id uuid; result jsonb;
BEGIN
  PERFORM ritual_private.assert_active_staff(target_staff_id); operation='editorial:'||target_kind||':withdraw'; replay=ritual_private.admin_idempotency_replay(target_staff_id,operation,target_key,target_hash); IF replay IS NOT NULL THEN RETURN replay; END IF;
  SELECT current_published_revision_id INTO previous_id FROM editorial_items WHERE id=target_item_id AND current_published_revision_id IS NOT NULL FOR UPDATE;
  IF previous_id IS NULL THEN RAISE EXCEPTION 'invalid_transition'; END IF;
  UPDATE editorial_items SET current_published_revision_id=NULL,status='withdrawn',version=version+1,updated_at=now() WHERE id=target_item_id;
  INSERT INTO publication_events(item_id,revision_id,action,effective_at,actor_id,reason) VALUES(target_item_id,previous_id,'withdraw',now(),target_staff_id,target_reason);
  INSERT INTO outbox_events(topic,aggregate_kind,aggregate_id,aggregate_version,tenant_id,reset_generation,dedupe_key,payload,available_at,deletion_generation) SELECT 'editorial.withdrawn','editorial-item',id,version,NULL,0,id::text||':'||version::text,jsonb_build_object('item_id',id,'revision_id',previous_id),now(),0 FROM editorial_items WHERE id=target_item_id;
  INSERT INTO admin_audit_events(actor_staff_id,action,target_kind,target_id,before_hash,reason,request_id,outcome) VALUES(target_staff_id,operation,target_kind,target_item_id,encode(digest(previous_id::text,'sha256'),'hex'),target_reason,target_request_id,'allowed');
  result=ritual_private.admin_item_view(target_item_id); PERFORM ritual_private.admin_idempotency_store(target_staff_id,operation,target_key,target_hash,result); RETURN result;
END $$;

REVOKE ALL ON FUNCTION ritual_private.materialize_editorial_revision(text,uuid,jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION ritual_private.admin_editorial_page(text,text,uuid,text,text,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION ritual_private.admin_editorial_item(text,uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION ritual_private.admin_editorial_revision(text,uuid,uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION ritual_private.admin_editorial_create(uuid,text,text,jsonb,uuid,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ritual_private.admin_editorial_revision_create(uuid,text,uuid,uuid,jsonb,uuid,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ritual_private.admin_editorial_revision_patch(uuid,text,uuid,uuid,integer,jsonb,uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION ritual_private.admin_editorial_review_request(uuid,text,uuid,uuid,text,boolean,uuid,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ritual_private.admin_editorial_review_decision(uuid,text,uuid,uuid,text,text,uuid,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ritual_private.admin_editorial_publish(uuid,text,uuid,uuid,timestamptz,text,uuid,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ritual_private.admin_editorial_withdraw(uuid,text,uuid,text,uuid,text,text) FROM PUBLIC;

CREATE OR REPLACE FUNCTION ritual_private.admin_catalog_item(target_kind text,target_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE result jsonb;
BEGIN
  IF target_kind='asset' THEN
    SELECT to_jsonb(asset)||jsonb_build_object('etag',format('"v%s"',asset.version)) INTO result FROM assets asset WHERE id=target_id;
  ELSIF target_kind='evidence_source' THEN
    SELECT to_jsonb(source)||jsonb_build_object('etag',format('"v%s"',source.version)) INTO result FROM evidence_sources source WHERE id=target_id;
  ELSIF target_kind='evidence_claim' THEN
    SELECT to_jsonb(claim) INTO result FROM evidence_claims claim WHERE id=target_id;
  ELSIF target_kind='seeded_creator' THEN
    SELECT to_jsonb(creator)||jsonb_build_object('etag',format('"v%s"',creator.version)) INTO result FROM seeded_creators creator WHERE id=target_id;
  ELSIF target_kind='ritual_schedule' THEN
    SELECT to_jsonb(schedule)||jsonb_build_object('etag',format('"v%s"',schedule.version)) INTO result FROM ritual_schedules schedule WHERE id=target_id;
  ELSE RAISE EXCEPTION 'invalid catalog kind';
  END IF;
  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.admin_catalog_page(target_kind text,target_filters jsonb,target_after text,target_limit integer)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE result jsonb;
BEGIN
  IF target_limit NOT BETWEEN 1 AND 50 THEN RAISE EXCEPTION 'invalid_limit'; END IF;
  IF target_kind='asset' THEN
    SELECT jsonb_build_object('items',coalesce(jsonb_agg(ritual_private.admin_catalog_item('asset',page.id) ORDER BY page.id),'[]'::jsonb),'next',CASE WHEN count(*)=target_limit THEN max(page.id::text) ELSE NULL END) INTO result
    FROM (SELECT id FROM assets WHERE (target_filters->>'status' IS NULL OR status=target_filters->>'status') AND (target_filters->>'type' IS NULL OR asset_type=target_filters->>'type') AND (target_filters->>'search' IS NULL OR symbol ILIKE '%'||target_filters->>'search'||'%' OR name ILIKE '%'||target_filters->>'search'||'%') AND (target_after IS NULL OR id::text>target_after) ORDER BY id LIMIT target_limit) page;
  ELSIF target_kind='evidence_source' THEN
    SELECT jsonb_build_object('items',coalesce(jsonb_agg(ritual_private.admin_catalog_item('evidence_source',page.id) ORDER BY page.id),'[]'::jsonb),'next',CASE WHEN count(*)=target_limit THEN max(page.id::text) ELSE NULL END) INTO result
    FROM (SELECT id FROM evidence_sources WHERE (target_filters->>'status' IS NULL OR status=target_filters->>'status') AND (target_filters->>'search' IS NULL OR title ILIKE '%'||target_filters->>'search'||'%' OR publisher ILIKE '%'||target_filters->>'search'||'%') AND (target_after IS NULL OR id::text>target_after) ORDER BY id LIMIT target_limit) page;
  ELSIF target_kind='evidence_claim' THEN
    SELECT jsonb_build_object('items',coalesce(jsonb_agg(ritual_private.admin_catalog_item('evidence_claim',page.id) ORDER BY page.id),'[]'::jsonb),'next',CASE WHEN count(*)=target_limit THEN max(page.id::text) ELSE NULL END) INTO result
    FROM (SELECT id FROM evidence_claims WHERE (target_filters->>'status' IS NULL OR status=target_filters->>'status') AND (target_filters->>'search' IS NULL OR summary ILIKE '%'||target_filters->>'search'||'%') AND (target_after IS NULL OR id::text>target_after) ORDER BY id LIMIT target_limit) page;
  ELSIF target_kind='seeded_creator' THEN
    SELECT jsonb_build_object('items',coalesce(jsonb_agg(ritual_private.admin_catalog_item('seeded_creator',page.id) ORDER BY page.id),'[]'::jsonb),'next',CASE WHEN count(*)=target_limit THEN max(page.id::text) ELSE NULL END) INTO result
    FROM (SELECT id FROM seeded_creators WHERE (target_filters->>'status' IS NULL OR status=target_filters->>'status') AND (target_filters->>'search' IS NULL OR display_name ILIKE '%'||target_filters->>'search'||'%') AND (target_after IS NULL OR id::text>target_after) ORDER BY id LIMIT target_limit) page;
  ELSIF target_kind='ritual_schedule' THEN
    SELECT jsonb_build_object('items',coalesce(jsonb_agg(ritual_private.admin_catalog_item('ritual_schedule',page.id) ORDER BY page.local_date,page.id),'[]'::jsonb),'next',CASE WHEN count(*)=target_limit THEN max(page.local_date::text||'|'||page.id::text) ELSE NULL END) INTO result
    FROM (SELECT id,local_date FROM ritual_schedules WHERE local_date BETWEEN (target_filters->>'from')::date AND (target_filters->>'to')::date AND (target_filters->>'mode' IS NULL OR mode=target_filters->>'mode') AND (target_filters->>'state' IS NULL OR state=target_filters->>'state') AND (target_after IS NULL OR local_date::text||'|'||id::text>target_after) ORDER BY local_date,id LIMIT target_limit) page;
  ELSE RAISE EXCEPTION 'invalid catalog kind';
  END IF;
  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.admin_catalog_command(
  target_staff_id uuid,target_action text,target_id uuid,target_payload jsonb,target_version integer,target_request_id uuid,target_key text,target_hash text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE replay jsonb; result jsonb; created_id uuid; before_value jsonb; operation text; row_total integer; qualification_record coven_qualifications%ROWTYPE;
BEGIN
  PERFORM ritual_private.assert_active_staff(target_staff_id); operation='catalog:'||target_action;
  IF target_key IS NOT NULL THEN replay=ritual_private.admin_idempotency_replay(target_staff_id,operation,target_key,target_hash); IF replay IS NOT NULL THEN RETURN replay; END IF; END IF;
  IF target_action='create:asset' THEN
    INSERT INTO assets(slug,symbol,name,asset_type,currency,exchange,is_demo,status) VALUES(target_payload->>'slug',upper(target_payload->>'symbol'),target_payload->>'name',target_payload->>'asset_type',target_payload->>'currency',target_payload->>'exchange',true,target_payload->>'status') RETURNING id INTO created_id;
  ELSIF target_action='patch:asset' THEN
    SELECT to_jsonb(asset) INTO before_value FROM assets asset WHERE id=target_id AND version=target_version FOR UPDATE; IF before_value IS NULL THEN RAISE EXCEPTION 'version_conflict'; END IF;
    IF EXISTS(SELECT 1 FROM asset_codex_entries entry JOIN editorial_items item ON item.id=entry.editorial_item_id WHERE entry.asset_id=target_id AND item.current_published_revision_id IS NOT NULL)
       AND (target_payload ? 'symbol' OR target_payload ? 'asset_type' OR target_payload ? 'currency' OR target_payload ? 'exchange') THEN RAISE EXCEPTION 'invalid_transition'; END IF;
    UPDATE assets SET symbol=coalesce(upper(target_payload->>'symbol'),symbol),name=coalesce(target_payload->>'name',name),asset_type=coalesce(target_payload->>'asset_type',asset_type),currency=coalesce(target_payload->>'currency',currency),exchange=CASE WHEN target_payload ? 'exchange' THEN target_payload->>'exchange' ELSE exchange END,status=coalesce(target_payload->>'status',status),version=version+1 WHERE id=target_id; created_id=target_id;
  ELSIF target_action='create:evidence_source' THEN
    INSERT INTO evidence_sources(canonical_url,title,publisher,published_at,retrieved_at,source_kind,status) VALUES(target_payload->>'canonical_url',target_payload->>'title',target_payload->>'publisher',(target_payload->>'published_at')::timestamptz,(target_payload->>'retrieved_at')::timestamptz,target_payload->>'source_kind',target_payload->>'status') RETURNING id INTO created_id;
  ELSIF target_action='patch:evidence_source' THEN
    SELECT to_jsonb(source) INTO before_value FROM evidence_sources source WHERE id=target_id AND version=target_version FOR UPDATE; IF before_value IS NULL THEN RAISE EXCEPTION 'version_conflict'; END IF;
    IF target_payload ? 'canonical_url' AND EXISTS(SELECT 1 FROM evidence_claims claim JOIN ritual_scenario_evidence evidence ON evidence.claim_id=claim.id JOIN editorial_revisions revision ON revision.id=evidence.revision_id JOIN editorial_items item ON item.id=revision.item_id WHERE claim.source_id=target_id AND item.current_published_revision_id=revision.id) THEN RAISE EXCEPTION 'invalid_transition'; END IF;
    UPDATE evidence_sources SET canonical_url=coalesce(target_payload->>'canonical_url',canonical_url),title=coalesce(target_payload->>'title',title),publisher=coalesce(target_payload->>'publisher',publisher),published_at=CASE WHEN target_payload ? 'published_at' THEN (target_payload->>'published_at')::timestamptz ELSE published_at END,retrieved_at=coalesce((target_payload->>'retrieved_at')::timestamptz,retrieved_at),source_kind=coalesce(target_payload->>'source_kind',source_kind),status=coalesce(target_payload->>'status',status),version=version+1 WHERE id=target_id; created_id=target_id;
  ELSIF target_action='create:evidence_claim' THEN
    INSERT INTO evidence_claims(source_id,claim_type,summary,observed_at,uncertainty,status) VALUES((target_payload->>'source_id')::uuid,target_payload->>'claim_type',target_payload->>'summary',(target_payload->>'observed_at')::timestamptz,target_payload->>'uncertainty',target_payload->>'status') RETURNING id INTO created_id;
  ELSIF target_action='create:seeded_creator' THEN
    IF target_payload->>'avatar_media_id' IS NOT NULL AND NOT EXISTS(SELECT 1 FROM media_assets WHERE id=(target_payload->>'avatar_media_id')::uuid AND status='active' AND quarantine_status='clear') THEN RAISE EXCEPTION 'publishability_failed'; END IF;
    INSERT INTO seeded_creators(slug,display_name,bio,avatar_media_id,is_fictional,status) VALUES(target_payload->>'slug',target_payload->>'display_name',target_payload->>'bio',(target_payload->>'avatar_media_id')::uuid,true,target_payload->>'status') RETURNING id INTO created_id;
  ELSIF target_action='patch:seeded_creator' THEN
    SELECT to_jsonb(creator) INTO before_value FROM seeded_creators creator WHERE id=target_id AND version=target_version FOR UPDATE; IF before_value IS NULL THEN RAISE EXCEPTION 'version_conflict'; END IF;
    IF target_payload->>'avatar_media_id' IS NOT NULL AND NOT EXISTS(SELECT 1 FROM media_assets WHERE id=(target_payload->>'avatar_media_id')::uuid AND status='active' AND quarantine_status='clear') THEN RAISE EXCEPTION 'publishability_failed'; END IF;
    UPDATE seeded_creators SET display_name=coalesce(target_payload->>'display_name',display_name),bio=coalesce(target_payload->>'bio',bio),avatar_media_id=CASE WHEN target_payload ? 'avatar_media_id' THEN (target_payload->>'avatar_media_id')::uuid ELSE avatar_media_id END,status=coalesce(target_payload->>'status',status),version=version+1 WHERE id=target_id; created_id=target_id;
  ELSIF target_action='append:asset_metric' THEN
    IF (target_payload->>'observed_at')::timestamptz>now() THEN RAISE EXCEPTION 'invalid_transition'; END IF;
    INSERT INTO asset_metric_snapshots(asset_id,observed_at,price_minor,change_bps,expense_ratio_bps,source_label,is_demo) VALUES(target_id,(target_payload->>'observed_at')::timestamptz,(target_payload->>'price_minor')::bigint,(target_payload->>'change_bps')::integer,(target_payload->>'expense_ratio_bps')::integer,target_payload->>'source_label',true) RETURNING id INTO created_id;
    SELECT to_jsonb(snapshot) INTO result FROM asset_metric_snapshots snapshot WHERE id=created_id;
  ELSIF target_action='append:coven_qualification' THEN
    INSERT INTO coven_qualifications(entry_id,category,person_name,valid_from,valid_to,submitted_by) VALUES(target_id,target_payload->>'category',target_payload->>'person_name',(target_payload->>'valid_from')::date,(target_payload->>'valid_to')::date,target_staff_id) RETURNING id INTO created_id;
    SELECT to_jsonb(qualification) INTO result FROM coven_qualifications qualification WHERE id=created_id;
  ELSIF target_action='append:coven_verification' THEN
    SELECT * INTO qualification_record FROM coven_qualifications WHERE id=target_id FOR UPDATE; IF qualification_record.id IS NULL THEN RAISE EXCEPTION 'not_found'; END IF;
    IF qualification_record.submitted_by IS NULL THEN
      INSERT INTO admin_audit_events(actor_staff_id,action,target_kind,target_id,reason,request_id,outcome) VALUES(target_staff_id,operation,'coven_qualification',target_id,'Verification denied because the qualification submitter is unknown.',target_request_id,'denied'); RETURN jsonb_build_object('_denied','unknown_submitter');
    ELSIF qualification_record.submitted_by=target_staff_id THEN
      INSERT INTO admin_audit_events(actor_staff_id,action,target_kind,target_id,reason,request_id,outcome) VALUES(target_staff_id,operation,'coven_qualification',target_id,'Self-verification denied.',target_request_id,'denied'); RETURN jsonb_build_object('_denied','self_approval');
    END IF;
    INSERT INTO coven_verifications(qualification_id,status,effective_as_of,verified_at,verified_by,supersedes_id) VALUES(target_id,target_payload->>'decision',(target_payload->>'effective_as_of')::date,now(),target_staff_id,qualification_record.current_verification_id) RETURNING id INTO created_id;
    INSERT INTO coven_verification_evidence(verification_id,claim_id,ordinal)
    SELECT created_id,(entry.value#>>'{}')::uuid,entry.ordinality FROM jsonb_array_elements(target_payload->'evidence_claim_ids') WITH ORDINALITY entry(value,ordinality)
    JOIN evidence_claims claim ON claim.id=(entry.value#>>'{}')::uuid AND claim.status='active' AND claim.observed_at IS NOT NULL AND claim.observed_at::date<=(target_payload->>'effective_as_of')::date;
    GET DIAGNOSTICS row_total=ROW_COUNT; IF row_total<>jsonb_array_length(target_payload->'evidence_claim_ids') THEN RAISE EXCEPTION 'publishability_failed'; END IF;
    UPDATE coven_qualifications SET current_verification_id=created_id WHERE id=target_id;
    SELECT to_jsonb(verification)||jsonb_build_object('evidence_claim_ids',target_payload->'evidence_claim_ids') INTO result FROM coven_verifications verification WHERE id=created_id;
  ELSIF target_action='create:ritual_schedule' THEN
    IF NOT EXISTS(SELECT 1 FROM editorial_revisions revision JOIN editorial_items item ON item.id=revision.item_id WHERE revision.id=(target_payload->>'revision_id')::uuid AND revision.state='approved' AND item.kind='ritual') THEN RAISE EXCEPTION 'publishability_failed'; END IF;
    INSERT INTO ritual_schedules(local_date,mode,revision_id,audience,state,effective_at) VALUES((target_payload->>'local_date')::date,target_payload->>'mode',(target_payload->>'revision_id')::uuid,target_payload->>'audience','scheduled',(target_payload->>'effective_at')::timestamptz) RETURNING id INTO created_id;
  ELSIF target_action='patch:ritual_schedule' THEN
    SELECT to_jsonb(schedule) INTO before_value FROM ritual_schedules schedule WHERE id=target_id AND version=target_version FOR UPDATE; IF before_value IS NULL THEN RAISE EXCEPTION 'version_conflict'; END IF;
    IF target_payload ? 'revision_id' AND EXISTS(SELECT 1 FROM daily_ritual_assignments WHERE schedule_id=target_id) THEN RAISE EXCEPTION 'invalid_transition'; END IF;
    IF target_payload ? 'revision_id' AND NOT EXISTS(SELECT 1 FROM editorial_revisions revision JOIN editorial_items item ON item.id=revision.item_id WHERE revision.id=(target_payload->>'revision_id')::uuid AND revision.state='approved' AND item.kind='ritual') THEN RAISE EXCEPTION 'publishability_failed'; END IF;
    UPDATE ritual_schedules SET revision_id=coalesce((target_payload->>'revision_id')::uuid,revision_id),effective_at=coalesce((target_payload->>'effective_at')::timestamptz,effective_at),version=version+1 WHERE id=target_id; created_id=target_id;
  ELSIF target_action='withdraw:ritual_schedule' THEN
    SELECT to_jsonb(schedule) INTO before_value FROM ritual_schedules schedule WHERE id=target_id AND version=target_version FOR UPDATE; IF before_value IS NULL THEN RAISE EXCEPTION 'version_conflict'; END IF;
    UPDATE ritual_schedules SET state='withdrawn',version=version+1 WHERE id=target_id; created_id=target_id;
  ELSE RAISE EXCEPTION 'invalid catalog action';
  END IF;
  IF result IS NULL THEN result=ritual_private.admin_catalog_item(split_part(target_action,':',2),created_id); END IF;
  INSERT INTO admin_audit_events(actor_staff_id,action,target_kind,target_id,before_hash,after_hash,reason,request_id,outcome)
  VALUES(target_staff_id,operation,replace(split_part(target_action,':',2),'create_',''),created_id,CASE WHEN before_value IS NULL THEN NULL ELSE encode(digest(before_value::text,'sha256'),'hex') END,encode(digest(result::text,'sha256'),'hex'),coalesce(target_payload->>'reason','Applied reviewed administrative change.'),target_request_id,'allowed');
  IF target_key IS NOT NULL THEN PERFORM ritual_private.admin_idempotency_store(target_staff_id,operation,target_key,target_hash,result); END IF;
  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.admin_audit_page(target_actor uuid,target_action text,target_kind text,target_from timestamptz,target_to timestamptz,target_after text,target_limit integer)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE result jsonb;
BEGIN
  IF target_limit NOT BETWEEN 1 AND 50 OR (target_from IS NOT NULL AND target_to IS NOT NULL AND (target_to<=target_from OR target_to-target_from>interval '31 days')) THEN RAISE EXCEPTION 'invalid_filter'; END IF;
  SELECT jsonb_build_object('items',coalesce(jsonb_agg(to_jsonb(page) ORDER BY page.created_at DESC,page.id DESC),'[]'::jsonb),'next',CASE WHEN count(*)=target_limit THEN min(page.created_at::text||'|'||page.id::text) ELSE NULL END) INTO result
  FROM (SELECT id,actor_staff_id,action,target_kind,target_id,before_hash,after_hash,reason,request_id,outcome,created_at FROM admin_audit_events WHERE (target_actor IS NULL OR actor_staff_id=target_actor) AND (target_action IS NULL OR action=target_action) AND (target_kind IS NULL OR target_kind=admin_audit_events.target_kind) AND (target_from IS NULL OR created_at>=target_from) AND (target_to IS NULL OR created_at<target_to) AND (target_after IS NULL OR created_at::text||'|'||id::text<target_after) ORDER BY created_at DESC,id DESC LIMIT target_limit) page;
  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.admin_moderation_page(target_filters jsonb,target_after text,target_limit integer)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE result jsonb;
BEGIN
  IF target_limit NOT BETWEEN 1 AND 50 THEN RAISE EXCEPTION 'invalid_limit'; END IF;
  SELECT jsonb_build_object('items',coalesce(jsonb_agg(jsonb_build_object('id',page.id,'target_kind',page.target_kind,'target_id',page.target_id,'reason_code',page.reason_code,'detail',page.detail,'status',page.status,'created_at',page.created_at) ORDER BY page.created_at DESC,page.id DESC),'[]'::jsonb),'next',CASE WHEN count(*)=target_limit THEN min(page.created_at::text||'|'||page.id::text) ELSE NULL END) INTO result
  FROM (SELECT report.id,report.target_kind,report.target_id,report.reason_code,report.detail,report.created_at,CASE coalesce(moderation.status,'open') WHEN 'investigating' THEN 'triaged' ELSE coalesce(moderation.status,'open') END status FROM content_reports report LEFT JOIN moderation_cases moderation ON moderation.report_id=report.id WHERE (target_filters->>'status' IS NULL OR CASE coalesce(moderation.status,'open') WHEN 'investigating' THEN 'triaged' ELSE coalesce(moderation.status,'open') END=target_filters->>'status') AND (target_filters->>'target_kind' IS NULL OR report.target_kind=target_filters->>'target_kind') AND (target_filters->>'from' IS NULL OR report.created_at>=(target_filters->>'from')::timestamptz) AND (target_filters->>'to' IS NULL OR report.created_at<(target_filters->>'to')::timestamptz) AND (target_after IS NULL OR report.created_at::text||'|'||report.id::text<target_after) ORDER BY report.created_at DESC,report.id DESC LIMIT target_limit) page;
  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.admin_moderation_case(target_case_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
SELECT jsonb_build_object('id',moderation.id,'report',jsonb_build_object('id',report.id,'target_kind',report.target_kind,'target_id',report.target_id,'reason_code',report.reason_code,'detail',report.detail,'status',CASE moderation.status WHEN 'investigating' THEN 'triaged' ELSE moderation.status END,'created_at',report.created_at),'status',moderation.status,'assignee_id',moderation.assignee_id,'resolution_code',moderation.resolution_code,'resolved_at',moderation.resolved_at,'version',moderation.version,'etag',format('"v%s"',moderation.version),'decisions',coalesce((SELECT jsonb_agg(jsonb_build_object('outcome',decision.outcome,'reason',decision.reason,'decided_at',decision.decided_at) ORDER BY decision.decided_at,decision.id) FROM moderation_case_decisions decision WHERE decision.case_id=moderation.id),'[]'::jsonb))
FROM moderation_cases moderation JOIN content_reports report ON report.id=moderation.report_id WHERE moderation.id=target_case_id
$$;

CREATE OR REPLACE FUNCTION ritual_private.admin_moderation_command(target_staff_id uuid,target_action text,target_id uuid,target_payload jsonb,target_version integer,target_request_id uuid,target_key text,target_hash text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE operation text; replay jsonb; case_id uuid; before_value jsonb; result jsonb;
BEGIN
  PERFORM ritual_private.assert_active_staff(target_staff_id); operation='moderation:'||target_action;
  IF target_key IS NOT NULL THEN replay=ritual_private.admin_idempotency_replay(target_staff_id,operation,target_key,target_hash); IF replay IS NOT NULL THEN RETURN replay; END IF; END IF;
  IF target_action='create_case' THEN
    IF NOT EXISTS(SELECT 1 FROM content_reports WHERE id=target_id) THEN RAISE EXCEPTION 'not_found'; END IF;
    INSERT INTO moderation_cases(report_id,status,assignee_id) VALUES(target_id,'open',(target_payload->>'assignee_id')::uuid) ON CONFLICT(report_id) DO UPDATE SET assignee_id=coalesce(excluded.assignee_id,moderation_cases.assignee_id) RETURNING id INTO case_id;
    INSERT INTO moderation_case_decisions(case_id,actor_staff_id,outcome,reason) VALUES(case_id,target_staff_id,'opened',target_payload->>'note');
  ELSIF target_action='patch_case' THEN
    SELECT ritual_private.admin_moderation_case(target_id) INTO before_value; IF before_value IS NULL THEN RAISE EXCEPTION 'not_found'; END IF; IF (before_value->>'version')::integer<>target_version THEN RAISE EXCEPTION 'version_conflict'; END IF;
    UPDATE moderation_cases SET status=target_payload->>'status',resolution_code=target_payload->>'resolution_code',resolved_at=CASE WHEN target_payload->>'status' IN ('resolved','dismissed') THEN now() ELSE NULL END,version=version+1 WHERE id=target_id; case_id=target_id;
    INSERT INTO moderation_case_decisions(case_id,actor_staff_id,outcome,reason) VALUES(case_id,target_staff_id,target_payload->>'status',target_payload->>'reason');
  ELSE RAISE EXCEPTION 'invalid_transition'; END IF;
  result=ritual_private.admin_moderation_case(case_id);
  INSERT INTO admin_audit_events(actor_staff_id,action,target_kind,target_id,before_hash,after_hash,reason,request_id,outcome) VALUES(target_staff_id,operation,'moderation_case',case_id,CASE WHEN before_value IS NULL THEN NULL ELSE encode(digest(before_value::text,'sha256'),'hex') END,encode(digest(result::text,'sha256'),'hex'),coalesce(target_payload->>'reason',target_payload->>'note'),target_request_id,'allowed');
  IF target_key IS NOT NULL THEN PERFORM ritual_private.admin_idempotency_store(target_staff_id,operation,target_key,target_hash,result); END IF; RETURN result;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.apply_scheduled_publication(target_event_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE scheduled_item_id uuid; scheduled_revision_id uuid; expected_version integer; revision_state text;
BEGIN
  SELECT event.aggregate_id,event.aggregate_version,(event.payload->>'revision_id')::uuid INTO scheduled_item_id,expected_version,scheduled_revision_id FROM outbox_events event WHERE event.id=target_event_id AND event.topic='editorial.publication.scheduled';
  IF scheduled_item_id IS NULL THEN RETURN 'stale'; END IF;
  SELECT revision.state INTO revision_state
  FROM editorial_items item
  JOIN editorial_revisions revision ON revision.id=scheduled_revision_id AND revision.item_id=item.id
  WHERE item.id=scheduled_item_id AND item.version=expected_version
  FOR UPDATE OF item,revision;
  IF revision_state IS DISTINCT FROM 'approved' THEN RETURN 'stale'; END IF;
  UPDATE editorial_revisions SET state='published'
  WHERE id=scheduled_revision_id AND item_id=scheduled_item_id AND state='approved';
  IF NOT FOUND THEN RETURN 'stale'; END IF;
  UPDATE editorial_items SET current_published_revision_id=scheduled_revision_id,status='published',updated_at=now() WHERE id=scheduled_item_id AND version=expected_version;
  IF NOT FOUND THEN RAISE EXCEPTION 'scheduled publication item changed'; END IF;
  RETURN 'published';
END $$;

ALTER FUNCTION ritual_private.enforce_editorial_revision_transition() OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.assert_active_staff(uuid) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.record_admin_denial(uuid,text,text,uuid) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.admin_idempotency_replay(uuid,text,text,text) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.admin_idempotency_store(uuid,text,text,text,jsonb) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.admin_revision_view(uuid) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.admin_item_view(uuid) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.materialize_editorial_revision(text,uuid,jsonb) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.admin_editorial_page(text,text,uuid,text,text,integer) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.admin_editorial_item(text,uuid) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.admin_editorial_revision(text,uuid,uuid) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.admin_editorial_create(uuid,text,text,jsonb,uuid,text,text) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.admin_editorial_revision_create(uuid,text,uuid,uuid,jsonb,uuid,text,text) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.admin_editorial_revision_patch(uuid,text,uuid,uuid,integer,jsonb,uuid) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.admin_editorial_review_request(uuid,text,uuid,uuid,text,boolean,uuid,text,text) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.admin_editorial_review_decision(uuid,text,uuid,uuid,text,text,uuid,text,text) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.admin_editorial_publish(uuid,text,uuid,uuid,timestamptz,text,uuid,text,text) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.admin_editorial_withdraw(uuid,text,uuid,text,uuid,text,text) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.admin_catalog_item(text,uuid) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.admin_catalog_page(text,jsonb,text,integer) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.admin_catalog_command(uuid,text,uuid,jsonb,integer,uuid,text,text) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.admin_audit_page(uuid,text,text,timestamptz,timestamptz,text,integer) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.admin_moderation_page(jsonb,text,integer) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.admin_moderation_case(uuid) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.admin_moderation_command(uuid,text,uuid,jsonb,integer,uuid,text,text) OWNER TO ritual_function_owner;
ALTER FUNCTION ritual_private.apply_scheduled_publication(uuid) OWNER TO ritual_function_owner;

REVOKE ALL ON FUNCTION ritual_private.admin_catalog_item(text,uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION ritual_private.admin_catalog_page(text,jsonb,text,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION ritual_private.admin_catalog_command(uuid,text,uuid,jsonb,integer,uuid,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ritual_private.admin_audit_page(uuid,text,text,timestamptz,timestamptz,text,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION ritual_private.admin_moderation_page(jsonb,text,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION ritual_private.admin_moderation_case(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION ritual_private.admin_moderation_command(uuid,text,uuid,jsonb,integer,uuid,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ritual_private.apply_scheduled_publication(uuid) FROM PUBLIC;
REVOKE INSERT,UPDATE,DELETE ON TABLE admin_audit_events FROM ritual_staff;

GRANT SELECT,INSERT,UPDATE ON TABLE editorial_items,editorial_revisions,editorial_review_requests,editorial_review_decisions,publication_events,
  assets,asset_metric_snapshots,evidence_sources,evidence_claims,ritual_scenarios,ritual_scenario_revisions,ritual_scenario_ideas,ritual_scenario_evidence,
  ritual_schedules,rowan_scripts,rowan_script_revisions,asset_codex_entries,asset_codex_revisions,asset_codex_risks,asset_codex_evidence,
  coven_entries,coven_entry_revisions,coven_qualifications,coven_verifications,coven_verification_evidence,grimoires,grimoire_revisions,
  grimoire_revision_assets,seeded_creators,circle_templates,circle_template_revisions,circle_template_assets,briefing_templates,briefing_template_revisions,
  moderation_cases,moderation_case_decisions,admin_audit_events,admin_operation_receipts,outbox_events,media_assets,companies,content_reports,daily_ritual_assignments
TO ritual_function_owner;
GRANT USAGE ON SCHEMA ritual_private TO ritual_staff;
GRANT EXECUTE ON FUNCTION ritual_private.record_admin_denial(uuid,text,text,uuid),
  ritual_private.admin_editorial_page(text,text,uuid,text,text,integer),ritual_private.admin_editorial_item(text,uuid),ritual_private.admin_editorial_revision(text,uuid,uuid),
  ritual_private.admin_editorial_create(uuid,text,text,jsonb,uuid,text,text),ritual_private.admin_editorial_revision_create(uuid,text,uuid,uuid,jsonb,uuid,text,text),
  ritual_private.admin_editorial_revision_patch(uuid,text,uuid,uuid,integer,jsonb,uuid),ritual_private.admin_editorial_review_request(uuid,text,uuid,uuid,text,boolean,uuid,text,text),
  ritual_private.admin_editorial_review_decision(uuid,text,uuid,uuid,text,text,uuid,text,text),ritual_private.admin_editorial_publish(uuid,text,uuid,uuid,timestamptz,text,uuid,text,text),
  ritual_private.admin_editorial_withdraw(uuid,text,uuid,text,uuid,text,text),ritual_private.admin_catalog_item(text,uuid),ritual_private.admin_catalog_page(text,jsonb,text,integer),
  ritual_private.admin_catalog_command(uuid,text,uuid,jsonb,integer,uuid,text,text),ritual_private.admin_audit_page(uuid,text,text,timestamptz,timestamptz,text,integer),
  ritual_private.admin_moderation_page(jsonb,text,integer),ritual_private.admin_moderation_case(uuid),ritual_private.admin_moderation_command(uuid,text,uuid,jsonb,integer,uuid,text,text)
TO ritual_staff;
GRANT EXECUTE ON FUNCTION ritual_private.apply_scheduled_publication(uuid) TO ritual_scheduler;

COMMIT;
