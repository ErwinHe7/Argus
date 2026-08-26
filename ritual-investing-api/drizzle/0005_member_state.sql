BEGIN;

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 1;
ALTER TABLE astrology_profiles ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 1;
ALTER TABLE saved_assets ADD COLUMN IF NOT EXISTS revision_id uuid REFERENCES editorial_revisions(id);
UPDATE saved_assets saved
SET revision_id = item.current_published_revision_id
FROM asset_codex_entries entry
JOIN editorial_items item ON item.id = entry.editorial_item_id
WHERE saved.asset_id = entry.asset_id
  AND saved.revision_id IS NULL
  AND item.current_published_revision_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS saved_assets_revision_idx ON saved_assets(revision_id) WHERE revision_id IS NOT NULL;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS focus_label text CHECK (focus_label IS NULL OR char_length(focus_label) BETWEEN 1 AND 120);
UPDATE companies SET focus_label=CASE slug
  WHEN 'aurora-healthworks' THEN 'Preventive health technology'
  WHEN 'juniper-robotics' THEN 'Industrial automation'
  WHEN 'morrow-energy' THEN 'Distributed clean energy'
  WHEN 'thistle-foods' THEN 'Sustainable nutrition'
  ELSE focus_label END
WHERE slug IN ('aurora-healthworks','juniper-robotics','morrow-energy','thistle-foods');

CREATE OR REPLACE VIEW ritual_catalog.coven_v1
WITH (security_barrier = true) AS
SELECT entry.id,
       ARRAY(
         SELECT qualification.category
         FROM coven_qualifications qualification
         JOIN coven_verifications verification ON verification.id = qualification.current_verification_id
         WHERE qualification.entry_id = entry.id AND verification.status = 'verified'
         ORDER BY qualification.category, qualification.id
       ) AS categories,
       (
         SELECT qualification.category
         FROM coven_qualifications qualification
         JOIN coven_verifications verification ON verification.id = qualification.current_verification_id
         WHERE qualification.entry_id = entry.id AND verification.status = 'verified'
         ORDER BY qualification.category, qualification.id LIMIT 1
       ) AS category,
       (
         SELECT verification.effective_as_of
         FROM coven_qualifications qualification
         JOIN coven_verifications verification ON verification.id = qualification.current_verification_id
         WHERE qualification.entry_id = entry.id AND verification.status = 'verified'
         ORDER BY qualification.category, qualification.id LIMIT 1
       ) AS verified_as_of,
       revision.id AS revision_id,
       lower(company.name) || '|' || entry.id::text AS sort_key,
       jsonb_build_object(
         'id', entry.id, 'slug', item.slug, 'company', company.name,
         'symbol', asset.symbol, 'focus', coalesce(company.focus_label,typed.summary),
         'summary', typed.summary, 'inclusion_rationale', typed.inclusion_rationale,
         'limitations', typed.limitations,
         'qualifications', (
           SELECT jsonb_agg(jsonb_build_object(
             'category', qualification.category, 'person_name', qualification.person_name,
             'effective_date', qualification.valid_from::text,
             'valid_to', CASE WHEN qualification.valid_to IS NULL THEN NULL ELSE qualification.valid_to::text END,
             'verified_as_of', verification.effective_as_of::text,
             'evidence', (
               SELECT coalesce(jsonb_agg(evidence.payload - 'source' ORDER BY evidence.ordinal), '[]'::jsonb)
               FROM ritual_catalog.coven_evidence_v1 evidence WHERE evidence.qualification_id = qualification.id
             )
           ) ORDER BY qualification.category, qualification.id)
           FROM coven_qualifications qualification
           JOIN coven_verifications verification ON verification.id = qualification.current_verification_id
           WHERE qualification.entry_id = entry.id AND verification.status = 'verified'
         ),
         'revision_id', revision.id, 'saved', false,
         'demo', jsonb_build_object(
           'is_demo', true,
           'observed_at', to_char((
             SELECT max(verification.verified_at)
             FROM coven_qualifications qualification
             JOIN coven_verifications verification ON verification.id = qualification.current_verification_id
             WHERE qualification.entry_id = entry.id AND verification.status = 'verified'
           ) AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
           'source_label', 'Ritual fictional Coven verification register',
           'limitations', jsonb_build_array(typed.limitations)
         )
       ) AS payload
FROM coven_entries entry
JOIN editorial_items item ON item.id = entry.editorial_item_id
JOIN editorial_revisions revision ON revision.id = item.current_published_revision_id
JOIN coven_entry_revisions typed ON typed.revision_id = revision.id
JOIN companies company ON company.id = entry.company_id
LEFT JOIN assets asset ON asset.id = company.asset_id
WHERE item.status = 'published' AND revision.state = 'published'
  AND EXISTS (
    SELECT 1 FROM coven_qualifications qualification
    JOIN coven_verifications verification ON verification.id = qualification.current_verification_id
    WHERE qualification.entry_id = entry.id AND verification.status = 'verified'
  );

CREATE OR REPLACE VIEW ritual_catalog.discover_v1
WITH (security_barrier = true) AS
SELECT 'asset'::text AS kind,
       'asset|' || asset.sort_key AS sort_key,
       jsonb_build_object('kind','asset','asset',asset.payload - ARRAY['thesis','risks','evidence','metrics_as_of','limitations','saved']) AS payload
FROM ritual_catalog.assets_v1 asset
UNION ALL
SELECT 'coven','coven|' || coven.sort_key,
       jsonb_build_object('kind','coven','coven',jsonb_build_object(
         'id',coven.payload->'id','slug',coven.payload->'slug','company',coven.payload->'company',
         'symbol',coven.payload->'symbol','focus',coven.payload->'focus',
         'category',coven.payload->'qualifications'->0->'category',
         'effective_date',coven.payload->'qualifications'->0->'effective_date',
         'verified_as_of',coven.payload->'qualifications'->0->'verified_as_of',
         'teaser',coven.payload->'summary','revision_id',coven.payload->'revision_id','demo',coven.payload->'demo'
       ))
FROM ritual_catalog.coven_v1 coven
UNION ALL
SELECT 'grimoire','grimoire|' || grimoire.sort_key,jsonb_build_object('kind','grimoire','grimoire',grimoire.payload)
FROM ritual_catalog.grimoires_v1 grimoire
UNION ALL
SELECT 'circle_template','circle_template|' || template.sort_key,jsonb_build_object('kind','circle_template','circle_template',template.payload)
FROM ritual_catalog.circle_templates_v1 template;

REFRESH MATERIALIZED VIEW ritual_catalog.search_v1;

ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_locale_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_locale_check CHECK (locale ~ '^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$');
ALTER TABLE preferences DROP CONSTRAINT IF EXISTS preferences_locale_check;
ALTER TABLE preferences ADD CONSTRAINT preferences_locale_check CHECK (locale ~ '^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$');
ALTER TABLE astrology_profiles DROP CONSTRAINT IF EXISTS astrology_profiles_code_check;
ALTER TABLE astrology_profiles ADD CONSTRAINT astrology_profiles_code_check CHECK (derived_profile_code IN ('lunar_patient','solar_builder','rising_explorer'));
ALTER TABLE astrology_profiles DROP CONSTRAINT IF EXISTS astrology_profiles_algorithm_check;
ALTER TABLE astrology_profiles ADD CONSTRAINT astrology_profiles_algorithm_check CHECK (algorithm_version = 'v1');
ALTER TABLE investor_profiles DROP CONSTRAINT IF EXISTS investor_profiles_enums_check;
ALTER TABLE investor_profiles ADD CONSTRAINT investor_profiles_enums_check CHECK (
  goal_type IN ('calm_fund','long_term_growth','income','exploration') AND
  time_horizon IN ('short','medium','long') AND risk_comfort IN ('low','moderate','high')
);
ALTER TABLE consent_records DROP CONSTRAINT IF EXISTS consent_records_history_unique;
CREATE UNIQUE INDEX IF NOT EXISTS consent_records_decision_unique
  ON consent_records(tenant_id, policy_code, policy_version, decision);

CREATE TABLE IF NOT EXISTS member_idempotency_records (
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  operation text NOT NULL,
  key text NOT NULL CHECK (key ~ '^[!-~]{16,64}$'),
  request_hash text NOT NULL,
  resource_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '24 hours'),
  UNIQUE (tenant_id, operation, key)
);
ALTER TABLE member_idempotency_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_idempotency_records FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON member_idempotency_records;
CREATE POLICY tenant_isolation ON member_idempotency_records
  USING (tenant_id = ritual_private.current_tenant_id())
  WITH CHECK (tenant_id = ritual_private.current_tenant_id());

CREATE OR REPLACE FUNCTION ritual_private.advance_onboarding(p_tenant uuid, p_version integer, p_next text, p_completed jsonb)
RETURNS SETOF onboarding_states LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE current onboarding_states%ROWTYPE; allowed boolean;
BEGIN
  SELECT * INTO current FROM onboarding_states WHERE tenant_id=p_tenant FOR UPDATE;
  IF current.version <> p_version THEN RAISE EXCEPTION 'version_conflict'; END IF;
  allowed := CASE current.current_step
    WHEN 'welcome' THEN p_next='ritual' WHEN 'ritual' THEN p_next='profile'
    WHEN 'profile' THEN p_next='complete' ELSE false END;
  IF NOT allowed THEN RAISE EXCEPTION 'invalid_transition'; END IF;
  RETURN QUERY UPDATE onboarding_states SET current_step=p_next,completed_steps=p_completed,
    completed_at=CASE WHEN p_next='complete' THEN now() ELSE NULL END,version=version+1
    WHERE tenant_id=p_tenant AND version=p_version RETURNING *;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.create_circle(p_tenant uuid,p_key text,p_title text,p_description text,p_assets jsonb)
RETURNS TABLE(circle_id uuid) LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE existing uuid; new_id uuid:=gen_random_uuid(); v_request_hash text:=encode(digest(jsonb_build_array(p_title,p_description,p_assets)::text,'sha256'),'hex'); asset_value jsonb;
BEGIN
  IF jsonb_typeof(p_assets) <> 'array' THEN RAISE EXCEPTION 'invalid_assets'; END IF;
  IF jsonb_array_length(p_assets) > 50 THEN RAISE EXCEPTION 'asset_cap'; END IF;
  IF (SELECT count(*) FROM jsonb_array_elements(p_assets)) <>
     (SELECT count(DISTINCT item->>'asset_id') FROM jsonb_array_elements(p_assets) item)
    THEN RAISE EXCEPTION 'duplicate_asset'; END IF;
  IF (SELECT count(*) FROM jsonb_array_elements(p_assets)) <>
     (SELECT count(DISTINCT item->>'ordinal') FROM jsonb_array_elements(p_assets) item)
    THEN RAISE EXCEPTION 'duplicate_ordinal'; END IF;
  IF (SELECT count(*) FROM jsonb_array_elements(p_assets) item WHERE item ? 'weight_bps') NOT IN (0, jsonb_array_length(p_assets))
    OR ((SELECT count(*) FROM jsonb_array_elements(p_assets) item WHERE item ? 'weight_bps') > 0
      AND (SELECT coalesce(sum((item->>'weight_bps')::integer),0) FROM jsonb_array_elements(p_assets) item) <> 10000)
    THEN RAISE EXCEPTION 'invalid_weight_total'; END IF;
  INSERT INTO member_idempotency_records(tenant_id,operation,key,request_hash,resource_id) VALUES(p_tenant,'circle.create',p_key,v_request_hash,new_id)
  ON CONFLICT(tenant_id,operation,key) DO NOTHING;
  SELECT resource_id INTO existing FROM member_idempotency_records r WHERE r.tenant_id=p_tenant AND r.operation='circle.create' AND r.key=p_key AND r.request_hash=v_request_hash;
  IF existing IS NULL THEN RAISE EXCEPTION 'idempotency_conflict'; END IF;
  IF EXISTS(SELECT 1 FROM circles WHERE tenant_id=p_tenant AND id=existing) THEN RETURN QUERY SELECT existing; RETURN; END IF;
  INSERT INTO circles(id,tenant_id,title,description) VALUES(existing,p_tenant,p_title,p_description);
  FOR asset_value IN SELECT value FROM jsonb_array_elements(p_assets) LOOP
    IF NOT EXISTS(SELECT 1 FROM assets WHERE id=(asset_value->>'asset_id')::uuid AND status='active') THEN RAISE EXCEPTION 'invalid_child'; END IF;
    INSERT INTO circle_assets(tenant_id,circle_id,asset_id,ordinal,weight_bps,note) VALUES(p_tenant,existing,(asset_value->>'asset_id')::uuid,(asset_value->>'ordinal')::int,(asset_value->>'weight_bps')::int,asset_value->>'note');
  END LOOP;
  RETURN QUERY SELECT existing;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.copy_circle_template(p_tenant uuid,p_template uuid,p_key text,p_title text)
RETURNS TABLE(circle_id uuid) LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE rev uuid; frozen_title text; frozen_description text; existing uuid; new_id uuid:=gen_random_uuid(); v_request_hash text;
BEGIN
  SELECT i.current_published_revision_id,r.title,r.description INTO rev,frozen_title,frozen_description FROM circle_templates t JOIN editorial_items i ON i.id=t.editorial_item_id JOIN circle_template_revisions r ON r.revision_id=i.current_published_revision_id WHERE t.id=p_template AND i.status='published';
  IF rev IS NULL THEN RETURN; END IF; v_request_hash:=encode(digest(jsonb_build_array(p_template,rev,p_title)::text,'sha256'),'hex');
  INSERT INTO member_idempotency_records(tenant_id,operation,key,request_hash,resource_id) VALUES(p_tenant,'circle.copy',p_key,v_request_hash,new_id) ON CONFLICT DO NOTHING;
  SELECT resource_id INTO existing FROM member_idempotency_records r WHERE r.tenant_id=p_tenant AND r.operation='circle.copy' AND r.key=p_key AND r.request_hash=v_request_hash;
  IF existing IS NULL THEN RAISE EXCEPTION 'idempotency_conflict'; END IF;
  IF EXISTS(SELECT 1 FROM circles WHERE tenant_id=p_tenant AND id=existing) THEN RETURN QUERY SELECT existing; RETURN; END IF;
  IF (SELECT count(*) FROM circle_template_assets WHERE revision_id=rev) > 50 THEN RAISE EXCEPTION 'asset_cap'; END IF;
  IF (SELECT count(weight_bps) FROM circle_template_assets WHERE revision_id=rev) NOT IN (0,(SELECT count(*) FROM circle_template_assets WHERE revision_id=rev))
    OR ((SELECT count(weight_bps) FROM circle_template_assets WHERE revision_id=rev)>0
      AND (SELECT coalesce(sum(weight_bps),0) FROM circle_template_assets WHERE revision_id=rev)<>10000)
    THEN RAISE EXCEPTION 'invalid_weight_total'; END IF;
  INSERT INTO circles(id,tenant_id,title,description,source_template_id,source_revision_id) VALUES(existing,p_tenant,coalesce(p_title,frozen_title),frozen_description,p_template,rev);
  INSERT INTO circle_assets(tenant_id,circle_id,asset_id,ordinal,weight_bps,note) SELECT p_tenant,existing,asset_id,ordinal,weight_bps,note FROM circle_template_assets WHERE revision_id=rev;
  RETURN QUERY SELECT existing;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.put_circle_asset(p_tenant uuid,p_circle uuid,p_asset uuid,p_version integer,p_ordinal integer,p_weight integer,p_note text)
RETURNS TABLE(ok boolean) LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,public,ritual_private AS $$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM circles WHERE tenant_id=p_tenant AND id=p_circle FOR UPDATE) THEN RETURN; END IF;
  IF NOT EXISTS(SELECT 1 FROM circles WHERE tenant_id=p_tenant AND id=p_circle AND version=p_version) THEN RAISE EXCEPTION 'version_conflict'; END IF;
  IF NOT EXISTS(SELECT 1 FROM assets WHERE id=p_asset AND status='active') THEN RETURN; END IF;
  IF NOT EXISTS(SELECT 1 FROM circle_assets WHERE tenant_id=p_tenant AND circle_id=p_circle AND asset_id=p_asset) AND (SELECT count(*) FROM circle_assets WHERE tenant_id=p_tenant AND circle_id=p_circle)>=50 THEN RAISE EXCEPTION 'asset_cap'; END IF;
  IF EXISTS(SELECT 1 FROM circle_assets WHERE tenant_id=p_tenant AND circle_id=p_circle AND ordinal=p_ordinal AND asset_id<>p_asset) THEN RAISE EXCEPTION 'duplicate_ordinal'; END IF;
  INSERT INTO circle_assets(tenant_id,circle_id,asset_id,ordinal,weight_bps,note) VALUES(p_tenant,p_circle,p_asset,p_ordinal,p_weight,p_note) ON CONFLICT(tenant_id,circle_id,asset_id) DO UPDATE SET ordinal=excluded.ordinal,weight_bps=excluded.weight_bps,note=excluded.note;
  IF (SELECT count(weight_bps) FROM circle_assets WHERE tenant_id=p_tenant AND circle_id=p_circle) NOT IN (0,(SELECT count(*) FROM circle_assets WHERE tenant_id=p_tenant AND circle_id=p_circle))
    OR ((SELECT count(weight_bps) FROM circle_assets WHERE tenant_id=p_tenant AND circle_id=p_circle)>0 AND (SELECT coalesce(sum(weight_bps),0) FROM circle_assets WHERE tenant_id=p_tenant AND circle_id=p_circle)<>10000) THEN RAISE EXCEPTION 'invalid_weight_total'; END IF;
  UPDATE circles SET version=version+1 WHERE tenant_id=p_tenant AND id=p_circle; RETURN QUERY SELECT true;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.delete_circle_asset(p_tenant uuid,p_circle uuid,p_asset uuid,p_version integer)
RETURNS TABLE(ok boolean) LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,public,ritual_private AS $$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM circles WHERE tenant_id=p_tenant AND id=p_circle FOR UPDATE) THEN RETURN; END IF;
  IF NOT EXISTS(SELECT 1 FROM circles WHERE tenant_id=p_tenant AND id=p_circle AND version=p_version) THEN RAISE EXCEPTION 'version_conflict'; END IF;
  DELETE FROM circle_assets WHERE tenant_id=p_tenant AND circle_id=p_circle AND asset_id=p_asset;
  IF (SELECT count(weight_bps) FROM circle_assets WHERE tenant_id=p_tenant AND circle_id=p_circle) NOT IN (0,(SELECT count(*) FROM circle_assets WHERE tenant_id=p_tenant AND circle_id=p_circle))
    OR ((SELECT count(weight_bps) FROM circle_assets WHERE tenant_id=p_tenant AND circle_id=p_circle)>0 AND (SELECT coalesce(sum(weight_bps),0) FROM circle_assets WHERE tenant_id=p_tenant AND circle_id=p_circle)<>10000) THEN RAISE EXCEPTION 'invalid_weight_total'; END IF;
  UPDATE circles SET version=version+1 WHERE tenant_id=p_tenant AND id=p_circle; RETURN QUERY SELECT true;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.save_member_item(p_tenant uuid,p_kind text,p_id uuid,p_context jsonb)
RETURNS TABLE(saved boolean,saved_at timestamptz) LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,public,ritual_private AS $$
DECLARE stamp timestamptz; source_uuid uuid; v_source_kind text:=coalesce(p_context->>'source_kind','direct');
BEGIN
  IF (p_context ? 'source_id') <> ((p_context ? 'source_kind') AND v_source_kind <> 'direct') THEN RAISE EXCEPTION 'invalid_source_context'; END IF;
  IF v_source_kind NOT IN ('ritual','circle','discover','search','direct') THEN RAISE EXCEPTION 'invalid_source_context'; END IF;
  IF p_context ? 'source_id' THEN
    BEGIN source_uuid := (p_context->>'source_id')::uuid;
    EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'invalid_source_context'; END;
    IF v_source_kind='ritual' AND NOT EXISTS(SELECT 1 FROM daily_ritual_assignments WHERE tenant_id=p_tenant AND id=source_uuid) THEN RETURN;
    ELSIF v_source_kind='circle' AND NOT EXISTS(SELECT 1 FROM circles WHERE tenant_id=p_tenant AND id=source_uuid) THEN RETURN;
    ELSIF v_source_kind IN ('discover','search') AND NOT EXISTS(SELECT 1 FROM editorial_items WHERE id=source_uuid AND status='published') THEN RETURN;
    END IF;
  END IF;
  IF p_kind='asset' THEN
    IF NOT EXISTS(SELECT 1 FROM assets WHERE id=p_id AND status='active') THEN RETURN; END IF;
    INSERT INTO saved_assets(tenant_id,asset_id,revision_id,source_kind,source_id)
      SELECT p_tenant,a.id,i.current_published_revision_id,v_source_kind,source_uuid FROM assets a LEFT JOIN asset_codex_entries e ON e.asset_id=a.id LEFT JOIN editorial_items i ON i.id=e.editorial_item_id WHERE a.id=p_id AND a.status='active'
      ON CONFLICT(tenant_id,asset_id) DO NOTHING RETURNING saved_assets.saved_at INTO stamp;
    IF stamp IS NULL THEN SELECT saved_at INTO stamp FROM saved_assets WHERE tenant_id=p_tenant AND asset_id=p_id; END IF;
  ELSIF p_kind='grimoire' THEN
    INSERT INTO saved_grimoires(tenant_id,grimoire_id,revision_id) SELECT p_tenant,g.id,i.current_published_revision_id FROM grimoires g JOIN editorial_items i ON i.id=g.editorial_item_id WHERE g.id=p_id AND i.status='published' ON CONFLICT(tenant_id,grimoire_id) DO NOTHING RETURNING saved_grimoires.saved_at INTO stamp;
    IF stamp IS NULL THEN SELECT saved_at INTO stamp FROM saved_grimoires WHERE tenant_id=p_tenant AND grimoire_id=p_id; END IF;
  ELSIF p_kind='circle_template' THEN
    INSERT INTO saved_circle_templates(tenant_id,template_id,revision_id) SELECT p_tenant,t.id,i.current_published_revision_id FROM circle_templates t JOIN editorial_items i ON i.id=t.editorial_item_id WHERE t.id=p_id AND i.status='published' ON CONFLICT(tenant_id,template_id) DO NOTHING RETURNING saved_circle_templates.saved_at INTO stamp;
    IF stamp IS NULL THEN SELECT saved_at INTO stamp FROM saved_circle_templates WHERE tenant_id=p_tenant AND template_id=p_id; END IF;
  ELSIF p_kind='coven' THEN
    INSERT INTO saved_coven_entries(tenant_id,entry_id,verification_id) SELECT p_tenant,e.id,q.current_verification_id FROM coven_entries e JOIN editorial_items i ON i.id=e.editorial_item_id JOIN coven_qualifications q ON q.entry_id=e.id WHERE e.id=p_id AND i.status='published' AND q.current_verification_id IS NOT NULL LIMIT 1 ON CONFLICT(tenant_id,entry_id) DO NOTHING RETURNING saved_coven_entries.saved_at INTO stamp;
    IF stamp IS NULL THEN SELECT saved_at INTO stamp FROM saved_coven_entries WHERE tenant_id=p_tenant AND entry_id=p_id; END IF;
  END IF;
  IF stamp IS NULL THEN RETURN; END IF; RETURN QUERY SELECT true,stamp;
END $$;

CREATE OR REPLACE FUNCTION ritual_private.unsave_member_item(p_tenant uuid,p_kind text,p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,public,ritual_private AS $$ BEGIN
  IF p_kind='asset' THEN DELETE FROM saved_assets WHERE tenant_id=p_tenant AND asset_id=p_id;
  ELSIF p_kind='grimoire' THEN DELETE FROM saved_grimoires WHERE tenant_id=p_tenant AND grimoire_id=p_id;
  ELSIF p_kind='circle_template' THEN DELETE FROM saved_circle_templates WHERE tenant_id=p_tenant AND template_id=p_id;
  ELSIF p_kind='coven' THEN DELETE FROM saved_coven_entries WHERE tenant_id=p_tenant AND entry_id=p_id; END IF;
END $$;

REVOKE ALL ON FUNCTION ritual_private.advance_onboarding(uuid,integer,text,jsonb),ritual_private.create_circle(uuid,text,text,text,jsonb),ritual_private.copy_circle_template(uuid,uuid,text,text),ritual_private.put_circle_asset(uuid,uuid,uuid,integer,integer,integer,text),ritual_private.delete_circle_asset(uuid,uuid,uuid,integer),ritual_private.save_member_item(uuid,text,uuid,jsonb),ritual_private.unsave_member_item(uuid,text,uuid) FROM PUBLIC;
GRANT SELECT,INSERT,UPDATE,DELETE ON member_idempotency_records TO ritual_runtime;
GRANT EXECUTE ON FUNCTION ritual_private.advance_onboarding(uuid,integer,text,jsonb),ritual_private.create_circle(uuid,text,text,text,jsonb),ritual_private.copy_circle_template(uuid,uuid,text,text),ritual_private.put_circle_asset(uuid,uuid,uuid,integer,integer,integer,text),ritual_private.delete_circle_asset(uuid,uuid,uuid,integer),ritual_private.save_member_item(uuid,text,uuid,jsonb),ritual_private.unsave_member_item(uuid,text,uuid) TO ritual_runtime;

COMMIT;
