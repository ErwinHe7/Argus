BEGIN;

ALTER TABLE daily_ritual_assignments
  ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 1 CHECK (version > 0);

INSERT INTO staff_principals(
  id, auth0_subject, access_identity, allowed_client_id, status,
  revocation_epoch, display_label, last_verified_at
) VALUES
  ('90000000-0000-4000-8000-000000000001', 'fixture:non-login:editor', 'urn:ritual:fixture:editor', 'fixture-client-denied', 'disabled', 0, 'Ritual Fixture Editor', NULL),
  ('90000000-0000-4000-8000-000000000002', 'fixture:non-login:reviewer', 'urn:ritual:fixture:reviewer', 'fixture-client-denied', 'disabled', 0, 'Ritual Fixture Reviewer', NULL)
ON CONFLICT (id) DO NOTHING;

INSERT INTO media_assets(
  id, r2_key, mime_type, byte_size, checksum, width, height,
  quarantine_status, scan_result, status
) VALUES (
  '90000000-0000-4000-8000-000000000003',
  'published/ritual/the-compass.webp', 'image/webp', 1,
  'fixture-the-compass-v1', 1024, 1536, 'clear', 'fixture-reviewed', 'active'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO assets(id, slug, symbol, name, asset_type, currency, exchange, is_demo, status) VALUES
  ('20000000-0000-4000-8000-000000000001', 'vig',  'VIG',  'Vanguard Dividend Appreciation ETF', 'etf', 'USD', 'NYSEARCA', true, 'active'),
  ('20000000-0000-4000-8000-000000000002', 'xlv',  'XLV',  'Health Care Select Sector SPDR Fund', 'etf', 'USD', 'NYSEARCA', true, 'active'),
  ('20000000-0000-4000-8000-000000000003', 'womn', 'WOMN', 'Impact Shares YWCA Women''s Empowerment ETF', 'etf', 'USD', 'NYSEARCA', true, 'active'),
  ('20000000-0000-4000-8000-000000000011', 'aura', 'AURA', 'Aurora Healthworks', 'equity', 'USD', 'DEMO', true, 'active'),
  ('20000000-0000-4000-8000-000000000012', 'jnpr-demo', 'JNPR', 'Juniper Robotics', 'equity', 'USD', 'DEMO', true, 'active'),
  ('20000000-0000-4000-8000-000000000013', 'mrow', 'MROW', 'Morrow Energy', 'equity', 'USD', 'DEMO', true, 'active'),
  ('20000000-0000-4000-8000-000000000014', 'thst', 'THST', 'Thistle Foods', 'equity', 'USD', 'DEMO', true, 'active')
ON CONFLICT (id) DO NOTHING;

INSERT INTO asset_metric_snapshots(
  id, asset_id, observed_at, price_minor, change_bps,
  expense_ratio_bps, source_label, is_demo
) VALUES
  ('22000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', '2026-08-20T13:35:00Z', 20142, 42, 10, 'Ritual deterministic demonstration', true),
  ('22000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000002', '2026-08-20T13:35:00Z', 15331, 31, 10, 'Ritual deterministic demonstration', true),
  ('22000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000003', '2026-08-20T13:35:00Z', 4217, 27, 75, 'Ritual deterministic demonstration', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO evidence_sources(
  id, canonical_url, title, publisher, published_at, retrieved_at,
  source_kind, status
) VALUES
  ('31000000-0000-4000-8000-000000000001', 'https://research.ritual-investing.test/demo/vig',  'Ritual demo market observation — VIG',  'Ritual Research Fixtures', '2026-08-20T13:35:00Z', '2026-08-20T13:35:00Z', 'deterministic_demo', 'active'),
  ('31000000-0000-4000-8000-000000000002', 'https://research.ritual-investing.test/demo/xlv',  'Ritual demo market observation — XLV',  'Ritual Research Fixtures', '2026-08-20T13:35:00Z', '2026-08-20T13:35:00Z', 'deterministic_demo', 'active'),
  ('31000000-0000-4000-8000-000000000003', 'https://research.ritual-investing.test/demo/womn', 'Ritual demo market observation — WOMN', 'Ritual Research Fixtures', '2026-08-20T13:35:00Z', '2026-08-20T13:35:00Z', 'deterministic_demo', 'active'),
  ('31000000-0000-4000-8000-000000000004', 'https://research.ritual-investing.test/demo/coven', 'Ritual fictional Coven verification register', 'Ritual Research Fixtures', '2026-08-20T13:35:00Z', '2026-08-20T13:35:00Z', 'deterministic_demo', 'active')
ON CONFLICT (id) DO NOTHING;

INSERT INTO evidence_claims(
  id, source_id, claim_type, summary, observed_at, uncertainty, status
) VALUES
  ('30000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000001', 'market_factor', 'Lower volatility and durable dividend momentum in the scenario window.', '2026-08-20T13:35:00Z', 'Short windows can reverse and do not predict future returns.', 'active'),
  ('30000000-0000-4000-8000-000000000002', '31000000-0000-4000-8000-000000000002', 'market_factor', 'Defensive relative strength appeared in the simulated scenario window.', '2026-08-20T13:35:00Z', 'Relative strength is descriptive, not a recommendation.', 'active'),
  ('30000000-0000-4000-8000-000000000003', '31000000-0000-4000-8000-000000000003', 'market_factor', 'Broad leadership exposure showed positive breadth in the demo data.', '2026-08-20T13:35:00Z', 'The observation is fictional and may not generalize.', 'active'),
  ('30000000-0000-4000-8000-000000000004', '31000000-0000-4000-8000-000000000004', 'coven_qualification', 'The fictional company and leadership qualification were reviewed for the dated demo register.', '2026-08-20T13:35:00Z', 'All Coven companies and people in this fixture are fictional.', 'active')
ON CONFLICT (id) DO NOTHING;

INSERT INTO editorial_items(id, kind, slug, status) VALUES
  ('11000000-0000-4000-8000-000000000001', 'ritual', 'the-compass', 'published'),
  ('11000000-0000-4000-8000-000000000002', 'ritual', 'the-compass-astrology', 'published'),
  ('11000000-0000-4000-8000-000000000003', 'rowan', 'rowan-daily-counsel', 'published'),
  ('21000000-0000-4000-8000-000000000011', 'asset_codex', 'codex-vig', 'published'),
  ('21000000-0000-4000-8000-000000000012', 'asset_codex', 'codex-xlv', 'published'),
  ('21000000-0000-4000-8000-000000000013', 'asset_codex', 'codex-womn', 'published'),
  ('41000000-0000-4000-8000-000000000001', 'grimoire', 'quiet-power', 'published'),
  ('41000000-0000-4000-8000-000000000002', 'grimoire', 'new-moons', 'published'),
  ('41000000-0000-4000-8000-000000000003', 'grimoire', 'long-horizon', 'published'),
  ('51000000-0000-4000-8000-000000000001', 'circle_template', 'soft-power-portfolio', 'published'),
  ('51000000-0000-4000-8000-000000000002', 'circle_template', 'climate-keepers', 'published'),
  ('61000000-0000-4000-8000-000000000001', 'coven', 'aurora-healthworks', 'published'),
  ('61000000-0000-4000-8000-000000000002', 'coven', 'juniper-robotics', 'published'),
  ('61000000-0000-4000-8000-000000000003', 'coven', 'morrow-energy', 'published'),
  ('61000000-0000-4000-8000-000000000004', 'coven', 'thistle-foods', 'published')
ON CONFLICT (id) DO NOTHING;

INSERT INTO editorial_revisions(
  id, item_id, revision_number, state, author_staff_id, content_hash, created_at
) VALUES
  ('10000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', 1, 'published', '90000000-0000-4000-8000-000000000001', 'fixture-compass-tarot-v1', '2026-08-20T12:10:00Z'),
  ('10000000-0000-4000-8000-000000000011', '11000000-0000-4000-8000-000000000002', 1, 'published', '90000000-0000-4000-8000-000000000001', 'fixture-compass-astrology-v1', '2026-08-20T12:10:00Z'),
  ('10000000-0000-4000-8000-000000000002', '11000000-0000-4000-8000-000000000003', 1, 'published', '90000000-0000-4000-8000-000000000001', 'fixture-rowan-daily-v1', '2026-08-20T12:10:00Z'),
  ('21000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000011', 1, 'published', '90000000-0000-4000-8000-000000000001', 'fixture-codex-vig-v1', '2026-08-20T12:10:00Z'),
  ('21000000-0000-4000-8000-000000000002', '21000000-0000-4000-8000-000000000012', 1, 'published', '90000000-0000-4000-8000-000000000001', 'fixture-codex-xlv-v1', '2026-08-20T12:10:00Z'),
  ('21000000-0000-4000-8000-000000000003', '21000000-0000-4000-8000-000000000013', 1, 'published', '90000000-0000-4000-8000-000000000001', 'fixture-codex-womn-v1', '2026-08-20T12:10:00Z'),
  ('40000000-0000-4000-8000-000000000002', '41000000-0000-4000-8000-000000000001', 1, 'published', '90000000-0000-4000-8000-000000000001', 'fixture-grimoire-quiet-power-v1', '2026-08-20T12:10:00Z'),
  ('40000000-0000-4000-8000-000000000012', '41000000-0000-4000-8000-000000000002', 1, 'published', '90000000-0000-4000-8000-000000000001', 'fixture-grimoire-new-moons-v1', '2026-08-20T12:10:00Z'),
  ('40000000-0000-4000-8000-000000000022', '41000000-0000-4000-8000-000000000003', 1, 'published', '90000000-0000-4000-8000-000000000001', 'fixture-grimoire-long-horizon-v1', '2026-08-20T12:10:00Z'),
  ('50000000-0000-4000-8000-000000000003', '51000000-0000-4000-8000-000000000001', 1, 'published', '90000000-0000-4000-8000-000000000001', 'fixture-template-soft-power-v1', '2026-08-20T12:10:00Z'),
  ('50000000-0000-4000-8000-000000000013', '51000000-0000-4000-8000-000000000002', 1, 'published', '90000000-0000-4000-8000-000000000001', 'fixture-template-climate-keepers-v1', '2026-08-20T12:10:00Z'),
  ('62000000-0000-4000-8000-000000000001', '61000000-0000-4000-8000-000000000001', 1, 'published', '90000000-0000-4000-8000-000000000001', 'fixture-coven-aurora-v1', '2026-08-20T12:10:00Z'),
  ('62000000-0000-4000-8000-000000000002', '61000000-0000-4000-8000-000000000002', 1, 'published', '90000000-0000-4000-8000-000000000001', 'fixture-coven-juniper-v1', '2026-08-20T12:10:00Z'),
  ('62000000-0000-4000-8000-000000000003', '61000000-0000-4000-8000-000000000003', 1, 'published', '90000000-0000-4000-8000-000000000001', 'fixture-coven-morrow-v1', '2026-08-20T12:10:00Z'),
  ('62000000-0000-4000-8000-000000000004', '61000000-0000-4000-8000-000000000004', 1, 'published', '90000000-0000-4000-8000-000000000001', 'fixture-coven-thistle-v1', '2026-08-20T12:10:00Z')
ON CONFLICT (id) DO NOTHING;

UPDATE editorial_items item
SET current_published_revision_id = revision.id
FROM editorial_revisions revision
WHERE revision.item_id = item.id
  AND revision.revision_number = 1
  AND item.id IN (
    '11000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000002',
    '11000000-0000-4000-8000-000000000003', '21000000-0000-4000-8000-000000000011',
    '21000000-0000-4000-8000-000000000012', '21000000-0000-4000-8000-000000000013',
    '41000000-0000-4000-8000-000000000001', '41000000-0000-4000-8000-000000000002',
    '41000000-0000-4000-8000-000000000003', '51000000-0000-4000-8000-000000000001',
    '51000000-0000-4000-8000-000000000002', '61000000-0000-4000-8000-000000000001',
    '61000000-0000-4000-8000-000000000002', '61000000-0000-4000-8000-000000000003',
    '61000000-0000-4000-8000-000000000004'
  );

INSERT INTO ritual_scenarios(id, editorial_item_id, scenario_key, mode, cadence) VALUES
  ('12000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', 'compass_tarot_daily', 'tarot', 'daily'),
  ('12000000-0000-4000-8000-000000000002', '11000000-0000-4000-8000-000000000002', 'compass_astrology_daily', 'astrology', 'daily')
ON CONFLICT (id) DO NOTHING;

INSERT INTO ritual_scenario_revisions(
  revision_id, title, interpretation, guidance, market_label,
  art_media_id, observation_at, uncertainty
) VALUES
  ('10000000-0000-4000-8000-000000000001', 'Direction, not urgency.', 'The strongest path today rewards patience. Favor durable momentum; let noisy names pass without you.', 'Inspect the evidence, compare risks, and choose whether any research path deserves more attention.', 'Market-informed · reveal the pattern', '90000000-0000-4000-8000-000000000003', '2026-08-20T13:35:00Z', 'Uncertainty remains high: the scenario is simulated, prices are fictional, and short-term conditions can reverse.'),
  ('10000000-0000-4000-8000-000000000011', 'Direction, not urgency.', 'The allowlisted derived profile code frames a patient research ritual without exposing precise profile inputs.', 'Inspect the evidence, compare risks, and choose whether any research path deserves more attention.', 'Derived profile · market-informed pattern', '90000000-0000-4000-8000-000000000003', '2026-08-20T13:35:00Z', 'Astrology is an optional framing device; the research scenario remains simulated and uncertain.')
ON CONFLICT (revision_id) DO NOTHING;

INSERT INTO ritual_scenario_ideas(revision_id, asset_id, ordinal, appearance_reason, risk_summary)
SELECT revision_id, asset_id, ordinal, appearance_reason, risk_summary
FROM (VALUES
  ('20000000-0000-4000-8000-000000000001'::uuid, 1, 'Durable dividend growth aligned with The Compass scenario.', 'Dividend strategies can lag and remain exposed to market loss.'),
  ('20000000-0000-4000-8000-000000000002'::uuid, 2, 'Defensive health-care exposure aligned with the scenario window.', 'Sector concentration can underperform broader markets.'),
  ('20000000-0000-4000-8000-000000000003'::uuid, 3, 'Leadership exposure aligned with positive breadth in the fixture.', 'The thematic screen is narrow and the observation is fictional.')
) idea(asset_id, ordinal, appearance_reason, risk_summary)
CROSS JOIN (VALUES
  ('10000000-0000-4000-8000-000000000001'::uuid),
  ('10000000-0000-4000-8000-000000000011'::uuid)
) revision(revision_id)
ON CONFLICT (revision_id, asset_id) DO NOTHING;

INSERT INTO ritual_scenario_evidence(revision_id, claim_id, ordinal, factor_label)
SELECT revision_id, claim_id, ordinal, factor_label
FROM (VALUES
  ('30000000-0000-4000-8000-000000000001'::uuid, 1, 'Durable dividend momentum'),
  ('30000000-0000-4000-8000-000000000002'::uuid, 2, 'Defensive relative strength'),
  ('30000000-0000-4000-8000-000000000003'::uuid, 3, 'Leadership breadth')
) evidence(claim_id, ordinal, factor_label)
CROSS JOIN (VALUES
  ('10000000-0000-4000-8000-000000000001'::uuid),
  ('10000000-0000-4000-8000-000000000011'::uuid)
) revision(revision_id)
ON CONFLICT (revision_id, claim_id) DO NOTHING;

INSERT INTO rowan_scripts(id, editorial_item_id, script_key, surface) VALUES
  ('13000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000003', 'daily_counsel', 'daily_ritual')
ON CONFLICT (id) DO NOTHING;
INSERT INTO rowan_script_revisions(revision_id, body_template, allowed_tokens, risk_footer) VALUES
  ('10000000-0000-4000-8000-000000000002', 'I''ll show you what changed beneath the reading. You decide what, if anything, to explore.', '[]'::jsonb, 'This deterministic demo explains uncertainty and never tells you to trade.')
ON CONFLICT (revision_id) DO NOTHING;
INSERT INTO rowan_context_bindings(id, surface, context_key, script_id, priority) VALUES
  ('13000000-0000-4000-8000-000000000002', 'daily_ritual', 'daily', '13000000-0000-4000-8000-000000000001', 100),
  ('13000000-0000-4000-8000-000000000003', 'evidence', 'evidence', '13000000-0000-4000-8000-000000000001', 100),
  ('13000000-0000-4000-8000-000000000004', 'asset_codex', 'asset', '13000000-0000-4000-8000-000000000001', 100),
  ('13000000-0000-4000-8000-000000000005', 'coven', 'coven', '13000000-0000-4000-8000-000000000001', 100)
ON CONFLICT (id) DO NOTHING;

INSERT INTO asset_codex_entries(id, editorial_item_id, asset_id) VALUES
  ('23000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000011', '20000000-0000-4000-8000-000000000001'),
  ('23000000-0000-4000-8000-000000000002', '21000000-0000-4000-8000-000000000012', '20000000-0000-4000-8000-000000000002'),
  ('23000000-0000-4000-8000-000000000003', '21000000-0000-4000-8000-000000000013', '20000000-0000-4000-8000-000000000003')
ON CONFLICT (id) DO NOTHING;

INSERT INTO asset_codex_revisions(revision_id, thesis, appearance_reason, metrics_as_of, limitations) VALUES
  ('21000000-0000-4000-8000-000000000001', 'VIG is included as a deterministic research example, not a trade instruction.', 'Durable dividend growth aligned with The Compass scenario.', '2026-08-20T13:35:00Z', 'Deterministic demo data; prices and signals are fictional.'),
  ('21000000-0000-4000-8000-000000000002', 'XLV is included as a deterministic research example, not a trade instruction.', 'Defensive health-care exposure aligned with The Compass scenario.', '2026-08-20T13:35:00Z', 'Deterministic demo data; prices and signals are fictional.'),
  ('21000000-0000-4000-8000-000000000003', 'WOMN is included as a deterministic research example, not a trade instruction.', 'Leadership exposure aligned with positive breadth in the fixture.', '2026-08-20T13:35:00Z', 'Deterministic demo data; prices and signals are fictional.')
ON CONFLICT (revision_id) DO NOTHING;

INSERT INTO asset_codex_risks(revision_id, ordinal, title, detail, severity)
SELECT revision_id, 1, 'Scenario and market risk', 'The fixture is simulated and real market conditions can differ materially.', 'medium'
FROM (VALUES
  ('21000000-0000-4000-8000-000000000001'::uuid),
  ('21000000-0000-4000-8000-000000000002'::uuid),
  ('21000000-0000-4000-8000-000000000003'::uuid)
) revision(revision_id)
ON CONFLICT (revision_id, ordinal) DO NOTHING;

INSERT INTO asset_codex_evidence(revision_id, claim_id, ordinal) VALUES
  ('21000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 1),
  ('21000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000002', 1),
  ('21000000-0000-4000-8000-000000000003', '30000000-0000-4000-8000-000000000003', 1)
ON CONFLICT (revision_id, claim_id) DO NOTHING;

INSERT INTO grimoires(id, editorial_item_id, theme_code) VALUES
  ('40000000-0000-4000-8000-000000000001', '41000000-0000-4000-8000-000000000001', 'durability'),
  ('40000000-0000-4000-8000-000000000011', '41000000-0000-4000-8000-000000000002', 'early_themes'),
  ('40000000-0000-4000-8000-000000000021', '41000000-0000-4000-8000-000000000003', 'patient_compounding')
ON CONFLICT (id) DO NOTHING;
INSERT INTO grimoire_revisions(revision_id, title, description, curator_label, art_media_id) VALUES
  ('40000000-0000-4000-8000-000000000002', 'Quiet Power', 'Durability over drama.', 'Ritual Research', NULL),
  ('40000000-0000-4000-8000-000000000012', 'New Moons', 'Early themes to study.', 'Ritual Research', NULL),
  ('40000000-0000-4000-8000-000000000022', 'Long Horizon', 'Patient compounding.', 'Ritual Research', NULL)
ON CONFLICT (revision_id) DO NOTHING;
INSERT INTO grimoire_revision_assets(revision_id, asset_id, ordinal, note)
SELECT revision_id, asset_id, ordinal, 'Deterministic curated research example.'
FROM (VALUES
  ('20000000-0000-4000-8000-000000000001'::uuid, 1),
  ('20000000-0000-4000-8000-000000000002'::uuid, 2),
  ('20000000-0000-4000-8000-000000000003'::uuid, 3)
) asset(asset_id, ordinal)
CROSS JOIN (VALUES
  ('40000000-0000-4000-8000-000000000002'::uuid),
  ('40000000-0000-4000-8000-000000000012'::uuid),
  ('40000000-0000-4000-8000-000000000022'::uuid)
) revision(revision_id)
ON CONFLICT (revision_id, asset_id) DO NOTHING;

INSERT INTO seeded_creators(id, slug, display_name, bio, is_fictional, status) VALUES
  ('50000000-0000-4000-8000-000000000001', 'selene-vale', 'Selene Vale', 'A fictional curator who favors patient, diversified research paths.', true, 'active')
ON CONFLICT (id) DO NOTHING;
INSERT INTO circle_templates(id, editorial_item_id, creator_id, theme_code) VALUES
  ('50000000-0000-4000-8000-000000000002', '51000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000001', 'soft_power'),
  ('50000000-0000-4000-8000-000000000012', '51000000-0000-4000-8000-000000000002', '50000000-0000-4000-8000-000000000001', 'climate')
ON CONFLICT (id) DO NOTHING;
INSERT INTO circle_template_revisions(revision_id, title, description, art_media_id) VALUES
  ('50000000-0000-4000-8000-000000000003', 'Soft Power Portfolio', 'A fictional curator''s diversified demo circle.', NULL),
  ('50000000-0000-4000-8000-000000000013', 'Climate Keepers', 'Themes to compare, edit, and save as a private copy.', NULL)
ON CONFLICT (revision_id) DO NOTHING;
INSERT INTO circle_template_assets(revision_id, asset_id, ordinal, weight_bps, note)
SELECT revision_id, asset_id, ordinal, weight_bps, 'Deterministic template allocation.'
FROM (VALUES
  ('20000000-0000-4000-8000-000000000001'::uuid, 1, 4000),
  ('20000000-0000-4000-8000-000000000002'::uuid, 2, 3500),
  ('20000000-0000-4000-8000-000000000003'::uuid, 3, 2500)
) asset(asset_id, ordinal, weight_bps)
CROSS JOIN (VALUES
  ('50000000-0000-4000-8000-000000000003'::uuid),
  ('50000000-0000-4000-8000-000000000013'::uuid)
) revision(revision_id)
ON CONFLICT (revision_id, asset_id) DO NOTHING;

INSERT INTO companies(id, slug, name, asset_id, website_url, is_fictional, status) VALUES
  ('63000000-0000-4000-8000-000000000001', 'aurora-healthworks', 'Aurora Healthworks', '20000000-0000-4000-8000-000000000011', NULL, true, 'active'),
  ('63000000-0000-4000-8000-000000000002', 'juniper-robotics', 'Juniper Robotics', '20000000-0000-4000-8000-000000000012', NULL, true, 'active'),
  ('63000000-0000-4000-8000-000000000003', 'morrow-energy', 'Morrow Energy', '20000000-0000-4000-8000-000000000013', NULL, true, 'active'),
  ('63000000-0000-4000-8000-000000000004', 'thistle-foods', 'Thistle Foods', '20000000-0000-4000-8000-000000000014', NULL, true, 'active')
ON CONFLICT (id) DO NOTHING;
INSERT INTO coven_entries(id, editorial_item_id, company_id) VALUES
  ('60000000-0000-4000-8000-000000000001', '61000000-0000-4000-8000-000000000001', '63000000-0000-4000-8000-000000000001'),
  ('60000000-0000-4000-8000-000000000002', '61000000-0000-4000-8000-000000000002', '63000000-0000-4000-8000-000000000002'),
  ('60000000-0000-4000-8000-000000000003', '61000000-0000-4000-8000-000000000003', '63000000-0000-4000-8000-000000000003'),
  ('60000000-0000-4000-8000-000000000004', '61000000-0000-4000-8000-000000000004', '63000000-0000-4000-8000-000000000004')
ON CONFLICT (id) DO NOTHING;
INSERT INTO coven_entry_revisions(revision_id, summary, inclusion_rationale, limitations) VALUES
  ('62000000-0000-4000-8000-000000000001', 'Preventive health technology in the fictional Founders'' Coven directory.', 'Included under the founder qualification only.', 'Fictional demonstration record; not an investment recommendation.'),
  ('62000000-0000-4000-8000-000000000002', 'Industrial automation in the fictional Founders'' Coven directory.', 'Included under the chief executive qualification only.', 'Fictional demonstration record; not an investment recommendation.'),
  ('62000000-0000-4000-8000-000000000003', 'Distributed clean energy in the fictional Founders'' Coven directory.', 'Included under the owner qualification only.', 'Fictional demonstration record; not an investment recommendation.'),
  ('62000000-0000-4000-8000-000000000004', 'Sustainable nutrition in the fictional Founders'' Coven directory.', 'Included under the founder qualification only.', 'Fictional demonstration record; not an investment recommendation.')
ON CONFLICT (revision_id) DO NOTHING;
INSERT INTO coven_qualifications(id, entry_id, category, person_name, valid_from, valid_to) VALUES
  ('64000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000001', 'founder', 'Maya Rowan', '2026-01-01', NULL),
  ('64000000-0000-4000-8000-000000000002', '60000000-0000-4000-8000-000000000002', 'chief_executive', 'Elena Park', '2026-01-01', NULL),
  ('64000000-0000-4000-8000-000000000003', '60000000-0000-4000-8000-000000000003', 'owner', 'Asha Morrow', '2026-01-01', NULL),
  ('64000000-0000-4000-8000-000000000004', '60000000-0000-4000-8000-000000000004', 'founder', 'Nora Thistle', '2026-01-01', NULL)
ON CONFLICT (id) DO NOTHING;
INSERT INTO coven_verifications(id, qualification_id, status, effective_as_of, verified_at, verified_by) VALUES
  ('65000000-0000-4000-8000-000000000001', '64000000-0000-4000-8000-000000000001', 'verified', '2026-08-20', '2026-08-20T12:20:00Z', '90000000-0000-4000-8000-000000000002'),
  ('65000000-0000-4000-8000-000000000002', '64000000-0000-4000-8000-000000000002', 'verified', '2026-08-20', '2026-08-20T12:20:00Z', '90000000-0000-4000-8000-000000000002'),
  ('65000000-0000-4000-8000-000000000003', '64000000-0000-4000-8000-000000000003', 'verified', '2026-08-20', '2026-08-20T12:20:00Z', '90000000-0000-4000-8000-000000000002'),
  ('65000000-0000-4000-8000-000000000004', '64000000-0000-4000-8000-000000000004', 'verified', '2026-08-20', '2026-08-20T12:20:00Z', '90000000-0000-4000-8000-000000000002')
ON CONFLICT (id) DO NOTHING;
UPDATE coven_qualifications qualification
SET current_verification_id = verification.id
FROM coven_verifications verification
WHERE verification.qualification_id = qualification.id
  AND qualification.id IN (
    '64000000-0000-4000-8000-000000000001', '64000000-0000-4000-8000-000000000002',
    '64000000-0000-4000-8000-000000000003', '64000000-0000-4000-8000-000000000004'
  );
INSERT INTO coven_verification_evidence(verification_id, claim_id, ordinal)
SELECT verification_id, '30000000-0000-4000-8000-000000000004'::uuid, 1
FROM (VALUES
  ('65000000-0000-4000-8000-000000000001'::uuid),
  ('65000000-0000-4000-8000-000000000002'::uuid),
  ('65000000-0000-4000-8000-000000000003'::uuid),
  ('65000000-0000-4000-8000-000000000004'::uuid)
) verification(verification_id)
ON CONFLICT (verification_id, claim_id) DO NOTHING;

INSERT INTO editorial_review_requests(
  id, revision_id, requested_by, requested_at, high_trust, status
)
SELECT gen_random_uuid(), revision.id, '90000000-0000-4000-8000-000000000001',
       '2026-08-20T12:15:00Z', item.kind IN ('ritual', 'rowan', 'coven'), 'closed'
FROM editorial_revisions revision
JOIN editorial_items item ON item.id = revision.item_id
WHERE revision.author_staff_id = '90000000-0000-4000-8000-000000000001'
  AND revision.created_at = '2026-08-20T12:10:00Z';
INSERT INTO editorial_review_decisions(
  id, request_id, reviewer_id, decision, reason, decided_at
)
SELECT gen_random_uuid(), request.id, '90000000-0000-4000-8000-000000000002',
       'approved', 'Deterministic fixture reviewed for product-contract fidelity.',
       '2026-08-20T12:20:00Z'
FROM editorial_review_requests request
WHERE request.requested_by = '90000000-0000-4000-8000-000000000001'
  AND request.requested_at = '2026-08-20T12:15:00Z';
INSERT INTO publication_events(
  id, item_id, revision_id, action, effective_at, actor_id, reason
)
SELECT gen_random_uuid(), revision.item_id, revision.id, 'publish',
       '2026-08-20T12:30:00Z', '90000000-0000-4000-8000-000000000002',
       'Publish reviewed deterministic contract fixture.'
FROM editorial_revisions revision
WHERE revision.author_staff_id = '90000000-0000-4000-8000-000000000001'
  AND revision.created_at = '2026-08-20T12:10:00Z';

INSERT INTO ritual_schedules(
  id, local_date, mode, revision_id, audience, state, effective_at
)
SELECT gen_random_uuid(), day::date, mode.mode, mode.revision_id, audience.audience,
       'active', day::date::timestamp AT TIME ZONE 'UTC'
FROM generate_series('2026-01-01'::date, '2029-12-31'::date, interval '1 day') day
CROSS JOIN (VALUES
  ('tarot'::text, '10000000-0000-4000-8000-000000000001'::uuid),
  ('astrology'::text, '10000000-0000-4000-8000-000000000011'::uuid)
) mode(mode, revision_id)
CROSS JOIN (VALUES ('public'::text), ('member'::text)) audience(audience)
ON CONFLICT (local_date, mode, audience) DO NOTHING;

REVOKE SELECT ON ritual_public.daily_ritual_preview,
  ritual_public.asset_codex_preview,
  ritual_public.coven_preview
FROM ritual_public;

CREATE SCHEMA IF NOT EXISTS ritual_catalog;
REVOKE ALL ON SCHEMA ritual_catalog FROM PUBLIC;

CREATE OR REPLACE VIEW ritual_public.daily_ritual_preview_v1
WITH (security_barrier = true) AS
SELECT schedule.local_date,
       schedule.mode,
       revision.id AS revision_id,
       jsonb_build_object(
         'date', schedule.local_date::text,
         'mode', schedule.mode,
         'title', typed.title,
         'art', jsonb_build_object(
           'key', 'the_compass',
           'alt', 'The Compass tarot card: a woman holding a lantern at a celestial crossroads'
         ),
         'interpretation_excerpt', left(typed.interpretation, 500),
         'market_label', typed.market_label,
         'idea_teasers', (
           SELECT jsonb_agg(jsonb_build_object(
             'symbol', asset.symbol,
             'name', asset.name,
             'appearance_reason', idea.appearance_reason
           ) ORDER BY idea.ordinal)
           FROM ritual_scenario_ideas idea
           JOIN assets asset ON asset.id = idea.asset_id
           WHERE idea.revision_id = revision.id
         ),
         'demo', jsonb_build_object(
           'is_demo', true,
           'observed_at', to_char(typed.observation_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
           'source_label', 'Ritual deterministic demonstration',
           'limitations', jsonb_build_array(
             'Deterministic demo data; prices and signals are fictional.',
             'Educational exploration only; not investment advice.'
           )
         )
       ) AS payload
FROM ritual_schedules schedule
JOIN editorial_revisions revision ON revision.id = schedule.revision_id
JOIN editorial_items item ON item.id = revision.item_id
JOIN ritual_scenario_revisions typed ON typed.revision_id = revision.id
WHERE schedule.audience = 'public'
  AND schedule.state = 'active'
  AND revision.state = 'published'
  AND item.status = 'published'
  AND item.current_published_revision_id = revision.id;

CREATE OR REPLACE VIEW ritual_public.coven_v1
WITH (security_barrier = true) AS
SELECT item.slug,
       qualification.category,
       revision.id AS revision_id,
       lower(company.name) || '|' || entry.id::text AS sort_key,
       jsonb_build_object(
         'slug', item.slug,
         'company', company.name,
         'category', qualification.category,
         'verified_as_of', verification.effective_as_of::text,
         'teaser', typed.summary,
         'demo', jsonb_build_object(
           'is_demo', true,
           'observed_at', to_char(verification.verified_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
           'source_label', 'Ritual fictional Coven verification register',
           'limitations', jsonb_build_array(
             'Fictional demonstration record; not an investment recommendation.'
           )
         )
       ) AS payload
FROM coven_entries entry
JOIN editorial_items item ON item.id = entry.editorial_item_id
JOIN editorial_revisions revision ON revision.id = item.current_published_revision_id
JOIN coven_entry_revisions typed ON typed.revision_id = revision.id
JOIN companies company ON company.id = entry.company_id
JOIN coven_qualifications qualification ON qualification.entry_id = entry.id
JOIN coven_verifications verification ON verification.id = qualification.current_verification_id
WHERE item.status = 'published'
  AND revision.state = 'published'
  AND verification.status = 'verified';

CREATE OR REPLACE VIEW ritual_public.discover_v1
WITH (security_barrier = true) AS
SELECT 'asset'::text AS kind,
       item.slug,
       revision.id AS revision_id,
       'asset|' || asset.symbol || '|' || asset.id::text AS sort_key,
       jsonb_build_object(
         'kind', 'asset', 'slug', item.slug, 'symbol', asset.symbol,
         'title', asset.name, 'teaser', typed.appearance_reason,
         'demo', jsonb_build_object(
           'is_demo', true,
           'observed_at', to_char(typed.metrics_as_of AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
           'source_label', 'Ritual deterministic demonstration',
           'limitations', jsonb_build_array(typed.limitations)
         )
       ) AS payload
FROM asset_codex_entries entry
JOIN editorial_items item ON item.id = entry.editorial_item_id
JOIN editorial_revisions revision ON revision.id = item.current_published_revision_id
JOIN asset_codex_revisions typed ON typed.revision_id = revision.id
JOIN assets asset ON asset.id = entry.asset_id
WHERE item.status = 'published' AND revision.state = 'published' AND asset.status = 'active'
UNION ALL
SELECT 'coven', coven.slug, coven.revision_id,
       'coven|' || coven.sort_key,
       jsonb_build_object(
         'kind', 'coven', 'slug', coven.slug,
         'title', coven.payload->>'company',
         'category', coven.category,
         'verified_as_of', coven.payload->>'verified_as_of',
         'teaser', coven.payload->>'teaser',
         'demo', coven.payload->'demo'
       )
FROM ritual_public.coven_v1 coven
UNION ALL
SELECT 'grimoire', item.slug, revision.id,
       'grimoire|' || lower(typed.title) || '|' || grimoire.id::text,
       jsonb_build_object(
         'kind', 'grimoire', 'slug', item.slug, 'title', typed.title,
         'teaser', typed.description,
         'demo', jsonb_build_object(
           'is_demo', true, 'observed_at', '2026-08-20T13:35:00.000Z',
           'source_label', 'Ritual deterministic demonstration',
           'limitations', jsonb_build_array('Curated demo research; not investment advice.')
         )
       )
FROM grimoires grimoire
JOIN editorial_items item ON item.id = grimoire.editorial_item_id
JOIN editorial_revisions revision ON revision.id = item.current_published_revision_id
JOIN grimoire_revisions typed ON typed.revision_id = revision.id
WHERE item.status = 'published' AND revision.state = 'published'
UNION ALL
SELECT 'circle_template', item.slug, revision.id,
       'circle_template|' || lower(typed.title) || '|' || template.id::text,
       jsonb_build_object(
         'kind', 'circle_template', 'slug', item.slug, 'title', typed.title,
         'teaser', typed.description, 'creator_label', creator.display_name,
         'is_fictional', true,
         'demo', jsonb_build_object(
           'is_demo', true, 'observed_at', '2026-08-20T13:35:00.000Z',
           'source_label', 'Ritual deterministic demonstration',
           'limitations', jsonb_build_array('Fictional seeded community example.')
         )
       )
FROM circle_templates template
JOIN editorial_items item ON item.id = template.editorial_item_id
JOIN editorial_revisions revision ON revision.id = item.current_published_revision_id
JOIN circle_template_revisions typed ON typed.revision_id = revision.id
JOIN seeded_creators creator ON creator.id = template.creator_id
WHERE item.status = 'published' AND revision.state = 'published' AND creator.status = 'active';

CREATE OR REPLACE VIEW ritual_catalog.asset_evidence_v1
WITH (security_barrier = true) AS
SELECT entry.asset_id,
       revision.id AS revision_id,
       link.ordinal,
       jsonb_build_object(
         'claim_id', claim.id,
         'factor_label', claim.claim_type,
         'summary', claim.summary,
         'observed_at', to_char(claim.observed_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
         'uncertainty', claim.uncertainty,
         'source', jsonb_build_object(
           'title', source.title, 'publisher', source.publisher,
           'url', source.canonical_url,
           'published_at', CASE WHEN source.published_at IS NULL THEN NULL
             ELSE to_jsonb(to_char(source.published_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')) END
         )
       ) AS payload
FROM asset_codex_entries entry
JOIN editorial_items item ON item.id = entry.editorial_item_id
JOIN editorial_revisions revision ON revision.id = item.current_published_revision_id
JOIN asset_codex_evidence link ON link.revision_id = revision.id
JOIN evidence_claims claim ON claim.id = link.claim_id
JOIN evidence_sources source ON source.id = claim.source_id
WHERE item.status = 'published' AND revision.state = 'published'
  AND claim.status = 'active' AND source.status = 'active';

CREATE OR REPLACE VIEW ritual_catalog.assets_v1
WITH (security_barrier = true) AS
SELECT asset.id,
       asset.symbol,
       asset.asset_type,
       revision.id AS revision_id,
       asset.symbol || '|' || asset.id::text AS sort_key,
       jsonb_build_object(
         'id', asset.id, 'slug', asset.slug, 'symbol', asset.symbol,
         'name', asset.name, 'asset_type', asset.asset_type,
         'currency', asset.currency, 'revision_id', revision.id,
         'appearance_reason', typed.appearance_reason,
         'thesis', typed.thesis,
         'risks', (
           SELECT jsonb_agg(jsonb_build_object(
             'title', risk.title, 'detail', risk.detail, 'severity', risk.severity
           ) ORDER BY risk.ordinal)
           FROM asset_codex_risks risk WHERE risk.revision_id = revision.id
         ),
         'evidence', (
           SELECT jsonb_agg(evidence.payload - 'source' ORDER BY evidence.ordinal)
           FROM ritual_catalog.asset_evidence_v1 evidence
           WHERE evidence.asset_id = asset.id AND evidence.revision_id = revision.id
         ),
         'metrics_as_of', to_char(typed.metrics_as_of AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
         'limitations', typed.limitations,
         'saved', false,
         'demo', jsonb_build_object(
           'is_demo', true,
           'observed_at', to_char(typed.metrics_as_of AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
           'source_label', 'Ritual fixture ' || asset.symbol,
           'limitations', jsonb_build_array(
             'Deterministic demo data; prices and signals are fictional.',
             'Educational exploration only; not investment advice.'
           )
         )
       ) AS payload
FROM asset_codex_entries entry
JOIN editorial_items item ON item.id = entry.editorial_item_id
JOIN editorial_revisions revision ON revision.id = item.current_published_revision_id
JOIN asset_codex_revisions typed ON typed.revision_id = revision.id
JOIN assets asset ON asset.id = entry.asset_id
WHERE item.status = 'published' AND revision.state = 'published' AND asset.status = 'active';

CREATE OR REPLACE VIEW ritual_catalog.asset_metrics_v1
WITH (security_barrier = true) AS
SELECT metric.asset_id,
       metric.observed_at,
       jsonb_build_object(
         'observed_at', to_char(metric.observed_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
         'price_minor', metric.price_minor,
         'change_bps', metric.change_bps,
         'expense_ratio_bps', metric.expense_ratio_bps,
         'source_label', metric.source_label,
         'demo', jsonb_build_object(
           'is_demo', true,
           'observed_at', to_char(metric.observed_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
           'source_label', metric.source_label,
           'limitations', jsonb_build_array('Deterministic demo metric; not live market data.')
         )
       ) AS payload
FROM asset_metric_snapshots metric
JOIN assets asset ON asset.id = metric.asset_id
WHERE asset.status = 'active' AND metric.is_demo = true;

CREATE OR REPLACE VIEW ritual_catalog.coven_evidence_v1
WITH (security_barrier = true) AS
SELECT entry.id AS entry_id,
       qualification.id AS qualification_id,
       evidence.ordinal,
       jsonb_build_object(
         'claim_id', claim.id,
         'factor_label', claim.claim_type,
         'summary', claim.summary,
         'observed_at', to_char(claim.observed_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
         'uncertainty', claim.uncertainty,
         'source', jsonb_build_object(
           'title', source.title, 'publisher', source.publisher,
           'url', source.canonical_url,
           'published_at', CASE WHEN source.published_at IS NULL THEN NULL
             ELSE to_jsonb(to_char(source.published_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')) END
         )
       ) AS payload
FROM coven_entries entry
JOIN coven_qualifications qualification ON qualification.entry_id = entry.id
JOIN coven_verifications verification ON verification.id = qualification.current_verification_id
JOIN coven_verification_evidence evidence ON evidence.verification_id = verification.id
JOIN evidence_claims claim ON claim.id = evidence.claim_id
JOIN evidence_sources source ON source.id = claim.source_id
WHERE verification.status = 'verified'
  AND claim.status = 'active' AND source.status = 'active';

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
         ORDER BY qualification.category, qualification.id
         LIMIT 1
       ) AS category,
       (
         SELECT verification.effective_as_of
         FROM coven_qualifications qualification
         JOIN coven_verifications verification ON verification.id = qualification.current_verification_id
         WHERE qualification.entry_id = entry.id AND verification.status = 'verified'
         ORDER BY qualification.category, qualification.id
         LIMIT 1
       ) AS verified_as_of,
       revision.id AS revision_id,
       lower(company.name) || '|' || entry.id::text AS sort_key,
       jsonb_build_object(
         'id', entry.id, 'slug', item.slug, 'company', company.name,
         'symbol', asset.symbol, 'summary', typed.summary,
         'inclusion_rationale', typed.inclusion_rationale,
         'limitations', typed.limitations,
         'qualifications', (
           SELECT jsonb_agg(jsonb_build_object(
             'category', qualification.category,
             'person_name', qualification.person_name,
             'effective_date', qualification.valid_from::text,
             'valid_to', CASE WHEN qualification.valid_to IS NULL THEN NULL ELSE qualification.valid_to::text END,
             'verified_as_of', verification.effective_as_of::text,
             'evidence', (
               SELECT coalesce(jsonb_agg(evidence.payload - 'source' ORDER BY evidence.ordinal), '[]'::jsonb)
               FROM ritual_catalog.coven_evidence_v1 evidence
               WHERE evidence.qualification_id = qualification.id
             )
           ) ORDER BY qualification.category, qualification.id)
           FROM coven_qualifications qualification
           JOIN coven_verifications verification ON verification.id = qualification.current_verification_id
           WHERE qualification.entry_id = entry.id AND verification.status = 'verified'
         ),
         'revision_id', revision.id,
         'saved', false,
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
    SELECT 1
    FROM coven_qualifications qualification
    JOIN coven_verifications verification ON verification.id = qualification.current_verification_id
    WHERE qualification.entry_id = entry.id AND verification.status = 'verified'
  );

CREATE OR REPLACE VIEW ritual_catalog.creators_v1
WITH (security_barrier = true) AS
SELECT creator.id,
       lower(creator.display_name) || '|' || creator.id::text AS sort_key,
       jsonb_build_object(
         'id', creator.id, 'slug', creator.slug,
         'display_name', creator.display_name, 'bio', creator.bio,
         'is_fictional', true,
         'demo', jsonb_build_object(
           'is_demo', true, 'observed_at', '2026-08-20T13:35:00.000Z',
           'source_label', 'Ritual deterministic demonstration',
           'limitations', jsonb_build_array('Fictional seeded creator; not a real member.')
         )
       ) AS payload
FROM seeded_creators creator
WHERE creator.status = 'active' AND creator.is_fictional = true;

CREATE OR REPLACE VIEW ritual_catalog.grimoires_v1
WITH (security_barrier = true) AS
SELECT grimoire.id,
       grimoire.theme_code AS theme,
       lower(typed.title) || '|' || grimoire.id::text AS sort_key,
       jsonb_build_object(
         'id', grimoire.id, 'slug', item.slug, 'title', typed.title,
         'description', typed.description, 'theme', grimoire.theme_code,
         'curator_label', typed.curator_label, 'revision_id', revision.id,
         'demo', jsonb_build_object(
           'is_demo', true, 'observed_at', '2026-08-20T13:35:00.000Z',
           'source_label', 'Ritual deterministic demonstration',
           'limitations', jsonb_build_array('Curated demo research; not investment advice.')
         )
       ) AS payload,
       jsonb_build_object(
         'id', grimoire.id, 'slug', item.slug, 'title', typed.title,
         'description', typed.description, 'theme', grimoire.theme_code,
         'curator_label', typed.curator_label, 'revision_id', revision.id,
         'demo', jsonb_build_object(
           'is_demo', true, 'observed_at', '2026-08-20T13:35:00.000Z',
           'source_label', 'Ritual deterministic demonstration',
           'limitations', jsonb_build_array('Curated demo research; not investment advice.')
         ),
         'assets', (
           SELECT jsonb_agg(asset.payload - ARRAY['thesis','risks','evidence','metrics_as_of','limitations','saved'] ORDER BY link.ordinal)
           FROM grimoire_revision_assets link
           JOIN ritual_catalog.assets_v1 asset ON asset.id = link.asset_id
           WHERE link.revision_id = revision.id
         )
       ) AS detail_payload
FROM grimoires grimoire
JOIN editorial_items item ON item.id = grimoire.editorial_item_id
JOIN editorial_revisions revision ON revision.id = item.current_published_revision_id
JOIN grimoire_revisions typed ON typed.revision_id = revision.id
WHERE item.status = 'published' AND revision.state = 'published';

CREATE OR REPLACE VIEW ritual_catalog.circle_templates_v1
WITH (security_barrier = true) AS
SELECT template.id,
       template.theme_code AS theme,
       creator.slug AS creator_slug,
       lower(typed.title) || '|' || template.id::text AS sort_key,
       jsonb_build_object(
         'id', template.id, 'slug', item.slug, 'title', typed.title,
         'description', typed.description, 'theme', template.theme_code,
         'creator', creator_view.payload, 'revision_id', revision.id,
         'demo', jsonb_build_object(
           'is_demo', true, 'observed_at', '2026-08-20T13:35:00.000Z',
           'source_label', 'Ritual deterministic demonstration',
           'limitations', jsonb_build_array('Fictional seeded community example.')
         )
       ) AS payload,
       jsonb_build_object(
         'id', template.id, 'slug', item.slug, 'title', typed.title,
         'description', typed.description, 'theme', template.theme_code,
         'creator', creator_view.payload, 'revision_id', revision.id,
         'demo', jsonb_build_object(
           'is_demo', true, 'observed_at', '2026-08-20T13:35:00.000Z',
           'source_label', 'Ritual deterministic demonstration',
           'limitations', jsonb_build_array('Fictional seeded community example.')
         ),
         'assets', (
           SELECT jsonb_agg(
             (asset.payload - ARRAY['thesis','risks','evidence','metrics_as_of','limitations','saved'])
             || jsonb_build_object(
               'ordinal', link.ordinal, 'weight_bps', link.weight_bps, 'note', link.note
             ) ORDER BY link.ordinal
           )
           FROM circle_template_assets link
           JOIN ritual_catalog.assets_v1 asset ON asset.id = link.asset_id
           WHERE link.revision_id = revision.id
         )
       ) AS detail_payload
FROM circle_templates template
JOIN editorial_items item ON item.id = template.editorial_item_id
JOIN editorial_revisions revision ON revision.id = item.current_published_revision_id
JOIN circle_template_revisions typed ON typed.revision_id = revision.id
JOIN seeded_creators creator ON creator.id = template.creator_id
JOIN ritual_catalog.creators_v1 creator_view ON creator_view.id = creator.id
WHERE item.status = 'published' AND revision.state = 'published' AND creator.status = 'active';

CREATE OR REPLACE VIEW ritual_catalog.discover_v1
WITH (security_barrier = true) AS
SELECT 'asset'::text AS kind,
       'asset|' || asset.sort_key AS sort_key,
       jsonb_build_object(
         'kind', 'asset',
         'asset', asset.payload - ARRAY['thesis','risks','evidence','metrics_as_of','limitations','saved']
       ) AS payload
FROM ritual_catalog.assets_v1 asset
UNION ALL
SELECT 'coven', 'coven|' || coven.sort_key,
       jsonb_build_object(
         'kind', 'coven',
         'coven', jsonb_build_object(
           'id', coven.payload->'id', 'slug', coven.payload->'slug',
           'company', coven.payload->'company',
           'category', coven.payload->'qualifications'->0->'category',
           'effective_date', coven.payload->'qualifications'->0->'effective_date',
           'verified_as_of', coven.payload->'qualifications'->0->'verified_as_of',
           'teaser', coven.payload->'summary', 'revision_id', coven.payload->'revision_id',
           'demo', coven.payload->'demo'
         )
       )
FROM ritual_catalog.coven_v1 coven
UNION ALL
SELECT 'grimoire', 'grimoire|' || grimoire.sort_key,
       jsonb_build_object('kind', 'grimoire', 'grimoire', grimoire.payload)
FROM ritual_catalog.grimoires_v1 grimoire
UNION ALL
SELECT 'circle_template', 'circle_template|' || template.sort_key,
       jsonb_build_object('kind', 'circle_template', 'circle_template', template.payload)
FROM ritual_catalog.circle_templates_v1 template;

CREATE MATERIALIZED VIEW ritual_catalog.search_v1 AS
SELECT discover.kind,
       discover.sort_key,
       discover.payload,
       to_tsvector('simple', coalesce(discover.payload::text, '')) AS search_document
FROM ritual_catalog.discover_v1 discover;

CREATE UNIQUE INDEX ritual_catalog_search_v1_sort_key_idx
  ON ritual_catalog.search_v1(sort_key);
CREATE INDEX ritual_catalog_search_v1_document_idx
  ON ritual_catalog.search_v1 USING gin(search_document);

CREATE OR REPLACE VIEW ritual_catalog.ritual_evidence_v1
WITH (security_barrier = true) AS
SELECT link.revision_id,
       link.ordinal,
       jsonb_build_object(
         'claim_id', claim.id, 'factor_label', link.factor_label,
         'summary', claim.summary,
         'observed_at', to_char(claim.observed_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
         'uncertainty', claim.uncertainty,
         'source', jsonb_build_object(
           'title', source.title, 'publisher', source.publisher,
           'url', source.canonical_url,
           'published_at', CASE WHEN source.published_at IS NULL THEN NULL
             ELSE to_jsonb(to_char(source.published_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')) END
         )
       ) AS payload
FROM ritual_scenario_evidence link
JOIN evidence_claims claim ON claim.id = link.claim_id
JOIN evidence_sources source ON source.id = claim.source_id;

CREATE OR REPLACE VIEW ritual_catalog.ritual_revisions_v1
WITH (security_barrier = true) AS
SELECT revision.id AS revision_id,
       jsonb_build_object(
         'revision', jsonb_build_object('id', revision.id, 'number', revision.revision_number),
         'title', typed.title,
         'art', jsonb_build_object(
           'key', 'the_compass',
           'alt', 'The Compass tarot card: a woman holding a lantern at a celestial crossroads'
         ),
         'interpretation', typed.interpretation,
         'guidance', typed.guidance,
         'market_label', typed.market_label,
         'ideas', (
           SELECT jsonb_agg(jsonb_build_object(
             'asset_id', asset.id, 'symbol', asset.symbol, 'name', asset.name,
             'appearance_reason', idea.appearance_reason,
             'risk_summary', idea.risk_summary
           ) ORDER BY idea.ordinal)
           FROM ritual_scenario_ideas idea
           JOIN assets asset ON asset.id = idea.asset_id
           WHERE idea.revision_id = revision.id
         ),
         'evidence', (
           SELECT jsonb_agg(evidence.payload - 'source' ORDER BY evidence.ordinal)
           FROM ritual_catalog.ritual_evidence_v1 evidence
           WHERE evidence.revision_id = revision.id
         ),
         'demo', jsonb_build_object(
           'is_demo', true,
           'observed_at', to_char(typed.observation_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
           'source_label', 'Ritual deterministic demonstration',
           'limitations', jsonb_build_array(
             'Deterministic demo data; prices and signals are fictional.',
             'Educational exploration only; not investment advice.'
           )
         )
       ) AS payload
FROM editorial_revisions revision
JOIN ritual_scenario_revisions typed ON typed.revision_id = revision.id
WHERE revision.state IN ('published', 'withdrawn');

CREATE OR REPLACE VIEW ritual_catalog.rowan_revisions_v1
WITH (security_barrier = true) AS
SELECT revision.id AS revision_id,
       revision.state,
       script.surface,
       jsonb_build_object(
         'script_revision_id', revision.id,
         'surface', script.surface,
         'body', typed.body_template,
         'risk_footer', typed.risk_footer
       ) AS payload
FROM editorial_revisions revision
JOIN rowan_script_revisions typed ON typed.revision_id = revision.id
JOIN rowan_scripts script ON script.editorial_item_id = revision.item_id
WHERE revision.state IN ('published', 'withdrawn')
  AND typed.allowed_tokens = '[]'::jsonb
  AND typed.body_template !~ '(\{\{|\$\{|\[\[|<%)';

CREATE OR REPLACE VIEW ritual_catalog.rowan_v1
WITH (security_barrier = true) AS
SELECT binding.surface,
       binding.context_key,
       binding.priority,
       jsonb_set(revision.payload, '{surface}', to_jsonb(binding.surface)) AS payload
FROM rowan_context_bindings binding
JOIN rowan_scripts script ON script.id = binding.script_id
JOIN editorial_items item ON item.id = script.editorial_item_id
JOIN ritual_catalog.rowan_revisions_v1 revision
  ON revision.revision_id = item.current_published_revision_id
WHERE item.status = 'published' AND revision.state = 'published';

REVOKE ALL ON ALL TABLES IN SCHEMA ritual_public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA ritual_catalog FROM PUBLIC;
GRANT USAGE ON SCHEMA ritual_public TO ritual_public;
GRANT SELECT ON ritual_public.daily_ritual_preview_v1,
  ritual_public.discover_v1,
  ritual_public.coven_v1
TO ritual_public;
GRANT USAGE ON SCHEMA ritual_catalog TO ritual_runtime;
GRANT SELECT ON ALL TABLES IN SCHEMA ritual_catalog TO ritual_runtime;

COMMIT;
