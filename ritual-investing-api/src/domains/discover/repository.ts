import type { DatabaseTransaction } from "../../db/database-port.ts";
import { type JsonObject } from "../../db/repository-support.ts";

export function createSupabaseDiscoverRepository(
  database: DatabaseTransaction,
) {
  const listGrimoiresPage = async (
    input: Readonly<{
      limit: number;
      theme: string | undefined;
      after: readonly [slug: string, id: string] | null;
    }>,
  ) =>
    (
      await database.query<JsonObject>(
        `select page.*,page.document as payload
           from argus_private.list_published_grimoires_page(
             $1,$2,$3,$4
           ) page`,
        [
          input.limit,
          input.theme ?? null,
          input.after?.[0] ?? null,
          input.after?.[1] ?? null,
        ],
      )
    ).rows;
  const listCircleTemplatesPage = async (
    input: Readonly<{
      limit: number;
      creator: string | undefined;
      after: readonly [slug: string, id: string] | null;
    }>,
  ) =>
    (
      await database.query<JsonObject>(
        `select page.*,page.document as payload
           from argus_private.list_published_circle_templates_page(
             $1,$2,$3,$4
           ) page`,
        [
          input.limit,
          input.creator ?? null,
          input.after?.[0] ?? null,
          input.after?.[1] ?? null,
        ],
      )
    ).rows;
  const listCreatorsPage = async (
    input: Readonly<{
      limit: number;
      after: readonly [displayName: string, id: string] | null;
    }>,
  ) =>
    (
      await database.query<JsonObject>(
        `select *
           from argus_private.list_published_creators_page(
             $1,$2,$3
           )`,
        [
          input.limit,
          input.after?.[0] ?? null,
          input.after?.[1] ?? null,
        ],
      )
    ).rows;
  return Object.freeze({
    listGrimoiresPage,
    listCircleTemplatesPage,
    listCreatorsPage,
    getCreator: async (id: string) => {
      const result = await database.query<JsonObject>(
        `select creator.id,creator.slug,creator.display_name,creator.bio,
                creator.is_fictional,publication.observed_at
           from argus_app.editorial_creators creator
           join lateral (
             select min(revision.created_at) as observed_at
               from argus_app.community_templates template
               join argus_app.editorial_items item
                 on item.id=template.editorial_item_id
               join argus_app.editorial_revisions revision
                 on revision.item_id=item.id
                and revision.id=item.current_published_revision_id
              where template.creator_id=creator.id
                and template.creator_normalization_state='ready'
                and item.kind='circle_template' and item.status='published'
                and revision.state='published'
             having count(*)>0
           ) publication on true
          where creator.id=$1`,
        [id],
      );
      return result.rows[0] ?? null;
    },
    listGrimoires: async (limit: number, theme?: string) =>
      listGrimoiresPage({ limit, theme, after: null }),
    listCircleTemplates: async (limit: number, creator?: string) =>
      listCircleTemplatesPage({ limit, creator, after: null }),
    getGrimoire: async (id: string) => {
      const result = await database.query<JsonObject>(
        `select grimoire.*,item.slug,revision.id as revision_id,
                revision.created_at as revision_created_at,document.document as payload,
                exists(select 1 from argus_app.member_saved_items saved
                  where saved.tenant_id=argus_private.trusted_request_tenant_id()
                    and saved.lifecycle_id=argus_private.trusted_request_lifecycle_id()
                    and saved.grimoire_id=grimoire.id) as saved,
                coalesce((select jsonb_agg(jsonb_build_object(
                  'id',asset.id,'slug',asset.slug,'symbol',asset.symbol,'name',asset.name,
                  'asset_type',asset.asset_type,'currency',asset.currency,
                  'revision_id',asset_revision.id,'revision_created_at',asset_revision.created_at,
                  'payload',asset_revision.payload
                ) order by entry.ordinal)
                  from argus_app.grimoire_revision_assets entry
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
                 where entry.grimoire_id=grimoire.id
                   and entry.editorial_item_id=item.id
                   and entry.revision_id=revision.id),'[]'::jsonb) as assets
           from argus_app.grimoires grimoire
           join argus_app.editorial_items item on item.id=grimoire.editorial_item_id
           join argus_app.editorial_revisions revision on revision.id=item.current_published_revision_id
           join argus_app.editorial_render_documents document
             on document.item_id=item.id and document.revision_id=revision.id
          where grimoire.id=$1 and item.status='published' and revision.state='published'`,
        [id],
      );
      return result.rows[0] ?? null;
    },
    listCreators: async (limit: number) =>
      listCreatorsPage({ limit, after: null }),
  });
}
