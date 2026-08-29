-- Deterministic, non-brokerage fixtures only. Member identities and Webull-derived
-- facts are intentionally absent: tests create transient users inside transactions.

insert into argus_app.catalog_assets (
  id, slug, symbol, name, asset_type, currency, exchange, status
) values (
  '10000000-0000-4000-8000-000000000002',
  'broad-market-example',
  'ARGX',
  'Argus broad-market research example',
  'etf',
  'USD',
  'SYNTHETIC',
  'active'
)
on conflict (id) do update set
  slug = excluded.slug,
  symbol = excluded.symbol,
  name = excluded.name,
  asset_type = excluded.asset_type,
  currency = excluded.currency,
  exchange = excluded.exchange,
  status = excluded.status;

insert into argus_app.evidence_sources (
  id, canonical_url, title, publisher, published_at, retrieved_at, source_kind, status
) values (
  '10000000-0000-4000-8000-000000000003',
  'https://example.invalid/argus-synthetic-research',
  'Synthetic research fixture',
  'Argus local development',
  '2026-01-01T00:00:00Z',
  '2026-01-01T00:00:00Z',
  'synthetic_fixture',
  'active'
)
on conflict (id) do update set
  title = excluded.title,
  publisher = excluded.publisher,
  published_at = excluded.published_at,
  retrieved_at = excluded.retrieved_at,
  source_kind = excluded.source_kind,
  status = excluded.status;

insert into argus_app.evidence_claims (
  id, source_id, claim_type, summary, observed_at, uncertainty, status
) values (
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000003',
  'fixture',
  'Synthetic evidence used only to prove clean local resets.',
  '2026-01-01T00:00:00Z',
  'Not real market evidence.',
  'active'
)
on conflict (id) do update set
  source_id = excluded.source_id,
  claim_type = excluded.claim_type,
  summary = excluded.summary,
  observed_at = excluded.observed_at,
  uncertainty = excluded.uncertainty,
  status = excluded.status;

insert into argus_app.editorial_items (
  id, kind, slug, status, created_at
) values (
  '10000000-0000-4000-8000-000000000001',
  'ritual',
  'local-reset-ritual',
  'published',
  '2026-01-01T00:00:00Z'
)
on conflict (id) do update set
  kind = excluded.kind,
  slug = excluded.slug
where editorial_items.kind is distinct from excluded.kind
   or editorial_items.slug is distinct from excluded.slug;
