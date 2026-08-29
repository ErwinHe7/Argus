import type { DatabaseTransaction } from "../../db/database-port.ts";
import {
  first,
  type JsonObject,
  RepositoryRevisionConflictError,
} from "../../db/repository-support.ts";

export function createSupabaseCircleRepository(
  database: DatabaseTransaction,
) {
  const selectCircle = async (database: DatabaseTransaction, id: string) => {
    const result = await database.query<JsonObject>(
      `select circle.*,true as private,
              (select item.current_published_revision_id
                 from argus_app.community_templates template
                 join argus_app.editorial_items item on item.id=template.editorial_item_id
                where template.id=circle.source_template_id) as source_revision_id,
              coalesce(jsonb_agg(to_jsonb(asset) order by asset.ordinal)
                filter (where asset.id is not null), '[]'::jsonb) as assets
         from argus_app.circles circle
         left join argus_app.circle_assets asset
           on asset.user_id = circle.user_id and asset.circle_id = circle.id
        where circle.user_id = (select argus_private.trusted_request_user_id()) and circle.id = $1
        group by circle.id`,
      [id],
    );
    return first(result.rows);
  };
  const listPage = async (input: Readonly<{
    limit: number;
    includeArchived: boolean;
    after: readonly [
      archived: boolean,
      archivedAt: string | null,
      id: string,
    ] | null;
  }>) =>
    (
      await database.query<JsonObject>(
        `select *
           from argus_private.list_member_circles_page(
             $1,$2,$3,$4,$5
           )`,
        [
          input.limit,
          input.includeArchived,
          input.after?.[0] ?? null,
          input.after?.[1] ?? null,
          input.after?.[2] ?? null,
        ],
      )
    ).rows;
  return Object.freeze({
    listPage,
    list: async (limit: number) =>
      listPage({ limit, includeArchived: true, after: null }),
    get: async (id: string) => selectCircle(database, id),
    create: async (
      input: Readonly<{
        title: string;
        description: string;
        assets?: readonly Readonly<{
          assetId: string;
          ordinal: number;
          weightBps?: number | null | undefined;
          note?: string | null | undefined;
        }>[];
        sourceTemplateId?: string;
      }>,
    ) => {
      const result = await database.query<JsonObject>(
        `insert into argus_app.circles(
             user_id, deletion_epoch, title, description,source_template_id
           )
           select argus_private.trusted_request_user_id(), member.deletion_epoch, $1, $2,$3
             from argus_app.members member
            where member.user_id = argus_private.trusted_request_user_id() and member.status = 'active'
          returning *`,
        [input.title, input.description, input.sourceTemplateId ?? null],
      );
      const circle = first(result.rows);
      for (const asset of input.assets ?? []) {
        await database.query(
          `insert into argus_app.circle_assets(
               user_id,deletion_epoch,circle_id,asset_id,ordinal,weight_bps,note
             ) values(argus_private.trusted_request_user_id(),$1,$2,$3,$4,$5,$6)`,
          [
            circle.deletion_epoch,
            circle.id,
            asset.assetId,
            asset.ordinal,
            asset.weightBps ?? null,
            asset.note ?? null,
          ],
        );
      }
      return selectCircle(database, String(circle.id));
    },
    update: async (
      id: string,
      input: Readonly<{ title?: string; description?: string }>,
      expectedVersion: number,
    ) => {
      const updated = await database.query<JsonObject>(
        `update argus_app.circles
              set title = coalesce($2, title),
                  description = coalesce($3, description),
                  version = version + 1
            where user_id = argus_private.trusted_request_user_id() and id = $1 and version = $4
          returning id`,
        [
          id,
          input.title ?? null,
          input.description ?? null,
          expectedVersion,
        ],
      );
      if (updated.rows.length !== 1) {
        throw new RepositoryRevisionConflictError();
      }
      return selectCircle(database, id);
    },
    replaceAssets: async (
      id: string,
      assets: readonly Readonly<{
        assetId: string;
        ordinal: number;
        weightBps?: number | null | undefined;
        note?: string | null | undefined;
      }>[],
      expectedVersion: number,
    ) => {
      const updated = await database.query<{ deletion_epoch: number }>(
        `update argus_app.circles set version=version+1
          where user_id=argus_private.trusted_request_user_id() and id=$1 and version=$2
        returning deletion_epoch`,
        [id, expectedVersion],
      );
      const circle = first(updated.rows);
      await database.query(
        `delete from argus_app.circle_assets
          where user_id=argus_private.trusted_request_user_id() and circle_id=$1`,
        [id],
      );
      for (const asset of assets) {
        await database.query(
          `insert into argus_app.circle_assets(
             user_id,deletion_epoch,circle_id,asset_id,ordinal,weight_bps,note
           ) values(argus_private.trusted_request_user_id(),$1,$2,$3,$4,$5,$6)`,
          [
            circle.deletion_epoch,
            id,
            asset.assetId,
            asset.ordinal,
            asset.weightBps ?? null,
            asset.note ?? null,
          ],
        );
      }
      return selectCircle(database, id);
    },
    putAsset: async (
      id: string,
      assetId: string,
      asset: Readonly<{
        ordinal: number;
        weightBps?: number | null | undefined;
        note?: string | null | undefined;
      }>,
      expectedVersion: number,
    ) => {
      const updated = await database.query<{ deletion_epoch: number }>(
        `update argus_app.circles set version=version+1
          where user_id=argus_private.trusted_request_user_id() and id=$1 and version=$2
        returning deletion_epoch`,
        [id, expectedVersion],
      );
      const circle = first(updated.rows);
      await database.query(
        `insert into argus_app.circle_assets(
           user_id,deletion_epoch,circle_id,asset_id,ordinal,weight_bps,note
         ) values(argus_private.trusted_request_user_id(),$1,$2,$3,$4,$5,$6)
         on conflict(user_id,circle_id,asset_id) do update
           set ordinal=excluded.ordinal,weight_bps=excluded.weight_bps,note=excluded.note`,
        [
          circle.deletion_epoch,
          id,
          assetId,
          asset.ordinal,
          asset.weightBps ?? null,
          asset.note ?? null,
        ],
      );
      return selectCircle(database, id);
    },
    deleteAsset: async (
      id: string,
      assetId: string,
      expectedVersion: number,
    ) => {
      const updated = await database.query(
        `update argus_app.circles set version=version+1
            where user_id=argus_private.trusted_request_user_id() and id=$1 and version=$2
          returning id`,
        [id, expectedVersion],
      );
      first(updated.rows);
      await database.query(
        `delete from argus_app.circle_assets
            where user_id=argus_private.trusted_request_user_id() and circle_id=$1 and asset_id=$2`,
        [id, assetId],
      );
      return selectCircle(database, id);
    },
    archive: async (id: string, expectedVersion: number) => {
      const updated = await database.query(
        `update argus_app.circles
              set archived_at=coalesce(archived_at,clock_timestamp()),version=version+1
            where user_id=argus_private.trusted_request_user_id() and id=$1 and version=$2
          returning id`,
        [id, expectedVersion],
      );
      first(updated.rows);
      return selectCircle(database, id);
    },
    getTemplate: async (id: string) => {
      const result = await database.query<JsonObject>(
        `select template.*,item.slug,revision.id as revision_id,revision.created_at as revision_created_at,
                creator.id as creator_id,creator.slug as creator_slug,
                creator.display_name as creator_display_name,
                creator.bio as creator_bio,
                creator.is_fictional as creator_is_fictional,
                document.document as payload,
                exists(select 1 from argus_app.member_saved_items saved
                        where saved.tenant_id=argus_private.trusted_request_tenant_id()
                          and saved.lifecycle_id=argus_private.trusted_request_lifecycle_id()
                          and saved.circle_template_id=template.id) as saved,
                coalesce((select jsonb_agg(jsonb_build_object(
                  'id',asset.id,'slug',asset.slug,'symbol',asset.symbol,'name',asset.name,
                  'asset_type',asset.asset_type,'currency',asset.currency,
                  'ordinal',entry.ordinal,'weight_bps',null,'note',null,
                  'revision_id',asset_revision.id,
                  'revision_created_at',asset_revision.created_at,
                  'payload',asset_revision.payload
                ) order by entry.ordinal)
                  from argus_app.community_template_revision_assets entry
                  join argus_app.catalog_assets asset on asset.id=entry.asset_id
                  left join lateral (
                    select r.id,r.created_at,asset_document.document as payload from argus_app.editorial_items i
                    join argus_app.editorial_revisions r on r.id=i.current_published_revision_id
                    join argus_app.editorial_render_documents asset_document
                      on asset_document.item_id=i.id and asset_document.revision_id=r.id
                    join argus_app.asset_codex_revisions codex
                      on codex.editorial_item_id=i.id and codex.revision_id=r.id
                     and codex.asset_id=asset.id
                    where i.kind='asset_codex' and i.status='published' and r.state='published'
                    limit 1
                  ) asset_revision on true
                 where entry.template_id=template.id
                   and entry.editorial_item_id=item.id
                   and entry.revision_id=revision.id),'[]'::jsonb) as assets
           from argus_app.community_templates template
           join argus_app.editorial_creators creator on creator.id=template.creator_id
           join argus_app.editorial_items item on item.id=template.editorial_item_id
           join argus_app.editorial_revisions revision on revision.id=item.current_published_revision_id
           join argus_app.editorial_render_documents document
             on document.item_id=item.id and document.revision_id=revision.id
          where template.id=$1 and item.status='published' and revision.state='published'`,
        [id],
      );
      return result.rows[0] ?? null;
    },
    listSaved: async (limit: number) =>
      (
        await database.query<JsonObject>(
          `select saved.user_id,member.deletion_epoch,saved.item_kind,
                    coalesce(saved.asset_id,saved.grimoire_id,saved.circle_template_id,
                             saved.coven_entry_id) as item_id,
                    saved.source_kind,
                    coalesce(saved.source_ritual_assignment_id,saved.source_circle_id,
                             saved.source_editorial_item_id,saved.source_catalog_asset_id) as source_id,
                    saved.saved_at
               from argus_app.member_saved_items saved
               join argus_app.members member
                 on member.user_id=saved.user_id and member.lifecycle_id=saved.lifecycle_id
              where saved.tenant_id=argus_private.trusted_request_tenant_id()
                and saved.lifecycle_id=argus_private.trusted_request_lifecycle_id()
              order by saved.saved_at desc,saved.item_kind,item_id
              limit $1`,
          [limit],
        )
      ).rows,
    save: async (
      itemKind: "asset" | "grimoire" | "circle_template" | "coven",
      itemId: string,
      sourceKind = "direct",
      sourceId?: string,
    ) => {
      const result = await database.query<JsonObject>(
        `select * from argus_private.save_member_item($1,$2,$3,$4)`,
        [itemKind, itemId, sourceKind, sourceId ?? null],
      );
      return first(result.rows);
    },
    unsave: async (
      itemKind: "asset" | "grimoire" | "circle_template" | "coven",
      itemId: string,
    ) => {
      const result = await database.query<JsonObject>(
        `select argus_private.unsave_member_item($1,$2) as removed`,
        [itemKind, itemId],
      );
      return first(result.rows);
    },
  });
}
