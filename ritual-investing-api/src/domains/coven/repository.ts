import type { DatabaseTransaction } from "../../db/database-port.ts";
import { type JsonObject } from "../../db/repository-support.ts";

export function createSupabaseCovenRepository(
  database: DatabaseTransaction,
) {
  const listPage = async (input: Readonly<{
    limit: number;
    category: string | undefined;
    verifiedAsOf: string | undefined;
    after: readonly [slug: string, id: string] | null;
  }>) =>
    (
      await database.query<JsonObject>(
        `select page.*,page.document as payload
           from argus_private.list_published_coven_page(
             $1,$2,$3,$4,$5
           ) page`,
        [
          input.limit,
          input.category ?? null,
          input.verifiedAsOf ?? null,
          input.after?.[0] ?? null,
          input.after?.[1] ?? null,
        ],
      )
    ).rows;
  const select = `select coven.id,coven.editorial_item_id,coven.company_id,
                         coalesce((select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                           'criterion_code',qualification.criterion_code,
                           'claim',qualification.claim,
                           'category',qualification.category,
                           'person_name',qualification.person_name,
                           'effective_date',qualification.effective_date,
                           'valid_to',qualification.valid_to,
                           'verified_as_of',qualification.verified_as_of,
                           'evidence_claim_id',qualification.evidence_claim_id
                         )) order by qualification.ordinal)
                           from argus_app.coven_qualifications qualification
                          where qualification.coven_entry_id=coven.id
                            and qualification.editorial_item_id=item.id
                            and qualification.revision_id=revision.id),'[]'::jsonb)
                           as qualification_payload,
                         to_jsonb(company) as company,
                         asset.symbol,revision.id as revision_id,
                         revision.created_at as revision_created_at,
                         document.document as payload, item.slug,
                         exists(select 1 from argus_app.member_saved_items saved
                           where saved.tenant_id=argus_private.trusted_request_tenant_id()
                             and saved.lifecycle_id=argus_private.trusted_request_lifecycle_id()
                             and saved.coven_entry_id=coven.id) as saved
                    from argus_app.coven_entries coven
                    join argus_app.companies company on company.id = coven.company_id
                    left join argus_app.catalog_assets asset on asset.id=company.asset_id
                    join argus_app.editorial_items item
                      on item.id = coven.editorial_item_id
                    join argus_app.editorial_revisions revision
                      on revision.id = item.current_published_revision_id
                    join argus_app.editorial_render_documents document
                      on document.item_id=item.id and document.revision_id=revision.id
                   where item.status = 'published' and revision.state = 'published'`;
  return Object.freeze({
    listPage,
    list: async (limit: number) =>
      listPage({
        limit,
        category: undefined,
        verifiedAsOf: undefined,
        after: null,
      }),
    get: async (id: string) => {
      const result = await database.query<JsonObject>(
        `${select} and coven.id = $1`,
        [id],
      );
      return result.rows[0] ?? null;
    },
  });
}
