import type { DatabaseTransaction } from "../../db/database-port.ts";
import { type JsonObject } from "../../db/repository-support.ts";

async function selectEvidence(
  database: DatabaseTransaction,
  claimIds: readonly string[],
): Promise<JsonObject[]> {
  return (
    await database.query<JsonObject>(
      `select claim.*, to_jsonb(source) as source
         from argus_app.evidence_claims claim
         join argus_app.evidence_sources source on source.id = claim.source_id
        where claim.id = any($1::uuid[])
          and claim.status = 'active' and source.status = 'active'
        order by claim.observed_at desc nulls last, claim.id`,
      [claimIds],
    )
  ).rows;
}

export function createSupabaseAssetRepository(
  database: DatabaseTransaction,
) {
  const listPage = async (input: Readonly<{
    limit: number;
    assetType: string | undefined;
    symbolPrefix: string | undefined;
    after: readonly [symbol: string, id: string] | null;
  }>) =>
    (
      await database.query<JsonObject>(
        `select page.*,page.document as payload
           from argus_private.list_published_assets_page(
             $1,$2,$3,$4,$5
           ) page`,
        [
          input.limit,
          input.assetType ?? null,
          input.symbolPrefix ?? null,
          input.after?.[0] ?? null,
          input.after?.[1] ?? null,
        ],
      )
    ).rows;
  const publishedAssetSelect = `select asset.*,
      revision.id as revision_id,revision.created_at as revision_created_at,
      revision.metrics_as_of,revision.payload,
      exists(select 1 from argus_app.member_saved_items saved
              where saved.tenant_id=argus_private.trusted_request_tenant_id()
                and saved.lifecycle_id=argus_private.trusted_request_lifecycle_id()
                and saved.asset_id=asset.id) as saved
    from argus_app.catalog_assets asset
    join lateral (
      select candidate.id,candidate.created_at,codex.metrics_as_of,
             document.document as payload
        from argus_app.editorial_items item
        join argus_app.editorial_revisions candidate
          on candidate.id=item.current_published_revision_id
        join argus_app.asset_codex_revisions codex
          on codex.editorial_item_id=item.id and codex.revision_id=candidate.id
         and codex.asset_id=asset.id
        join argus_app.editorial_render_documents document
          on document.item_id=item.id and document.revision_id=candidate.id
       where item.kind='asset_codex' and item.status='published'
         and candidate.state='published'
       limit 1
    ) revision on true`;
  return Object.freeze({
    listPage,
    list: async (limit: number, assetType?: string, symbolPrefix?: string) =>
      listPage({
        limit,
        assetType,
        symbolPrefix,
        after: null,
      }),
    get: async (id: string) => {
      const result = await database.query<JsonObject>(
        `${publishedAssetSelect}
            where asset.id = $1 and asset.status = 'active'`,
        [id],
      );
      return result.rows[0] ?? null;
    },
    listEvidence: async (claimIds: readonly string[]) =>
      selectEvidence(database, claimIds),
    evidence: async (assetId: string) => {
      const result = await database.query<JsonObject>(
        `select claim.*,to_jsonb(source) as source
             from argus_app.catalog_assets asset
             join argus_app.editorial_items item
               on item.kind='asset_codex' and item.status='published'
             join argus_app.editorial_revisions revision
               on revision.id=item.current_published_revision_id
              and revision.state='published'
             join argus_app.asset_codex_revisions codex
               on codex.editorial_item_id=item.id and codex.revision_id=revision.id
              and codex.asset_id=asset.id
             join argus_app.asset_codex_revision_evidence evidence
               on evidence.editorial_item_id=codex.editorial_item_id
              and evidence.revision_id=codex.revision_id
             join argus_app.evidence_claims claim on claim.id=evidence.evidence_claim_id
             join argus_app.evidence_sources source on source.id=claim.source_id
            where asset.id=$1 and asset.status='active'
              and claim.status='active' and source.status='active'
            order by evidence.ordinal`,
        [assetId],
      );
      return result.rows;
    },
    metrics: async (assetId: string) => {
      const result = await database.query<JsonObject>(
        `select jsonb_strip_nulls(jsonb_build_object(
                   'observed_at',metric.observed_at,
                   'price_minor',metric.price_minor,
                   'change_bps',metric.change_bps,
                   'expense_ratio_bps',metric.expense_ratio_bps,
                   'source_label',metric.source_label
                 )) as metric
             from argus_app.catalog_assets asset
             join argus_app.editorial_items item
               on item.kind='asset_codex' and item.status='published'
             join argus_app.editorial_revisions revision
               on revision.id=item.current_published_revision_id
              and revision.state='published'
             join argus_app.asset_codex_revisions codex
               on codex.editorial_item_id=item.id and codex.revision_id=revision.id
              and codex.asset_id=asset.id
             join argus_app.asset_codex_revision_metrics metric
               on metric.editorial_item_id=codex.editorial_item_id
              and metric.revision_id=codex.revision_id
            where asset.id=$1 and asset.status='active'
            order by metric.ordinal
            limit 90`,
        [assetId],
      );
      return result.rows.map((row) => row.metric as JsonObject);
    },
    compare: async (assetIds: readonly string[]) =>
      (
        await database.query<JsonObject>(
          `${publishedAssetSelect}
              where asset.id=any($1::uuid[]) and asset.status='active'
              order by array_position($1::uuid[],asset.id)`,
          [assetIds],
        )
      ).rows,
  });
}
