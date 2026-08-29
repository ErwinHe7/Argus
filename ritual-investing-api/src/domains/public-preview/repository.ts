import type { DatabaseTransaction } from "../../db/database-port.ts";
import { type JsonObject } from "../../db/repository-support.ts";

export function createSupabasePublicPreviewRepository(
  database: DatabaseTransaction,
) {
  const listPublishedPage = async (input: Readonly<{
    kind: string;
    limit: number;
    after: readonly [slug: string, id: string] | null;
  }>) =>
    (
      await database.query<JsonObject>(
        `select id,kind,slug,revision_id,revision_number,document as payload
           from argus_private.list_current_published_editorial_page(
             $1,$2,$3,$4
           )`,
        [
          input.kind,
          input.limit,
          input.after?.[0] ?? null,
          input.after?.[1] ?? null,
        ],
      )
    ).rows;
  return Object.freeze({
    listPublishedPage,
    listPublished: async (kind: string, limit: number) =>
      listPublishedPage({ kind, limit, after: null }),
    getPublished: async (slug: string) => {
      const result = await database.query<JsonObject>(
        `select id,kind,slug,revision_id,revision_number,document as payload
             from argus_private.get_current_published_editorial($1)`,
        [slug],
      );
      return result.rows[0] ?? null;
    },
  });
}
