import type { DatabaseTransaction } from "../../db/database-port.ts";
import { type JsonObject } from "../../db/repository-support.ts";
import type { SearchRepository } from "./ports.ts";

export function createSupabaseSearchRepository(
  database: DatabaseTransaction,
): SearchRepository {
  return Object.freeze({
    searchPage: async (input: Parameters<SearchRepository["searchPage"]>[0]) =>
      (
        await database.query<JsonObject>(
          `select result_kind,id,slug,label,rank,revision_id,summary
             from argus_private.search_published_content_page(
               $1,$2::text[],$3,$4,$5,$6,$7
             )`,
          [
            input.query,
            input.kinds,
            input.limit,
            input.after?.[0] ?? null,
            input.after?.[1] ?? null,
            input.after?.[2] ?? null,
            input.after?.[3] ?? null,
          ],
        )
      ).rows,
  });
}
