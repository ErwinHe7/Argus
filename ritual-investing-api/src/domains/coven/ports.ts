import type { JsonObject } from "../../db/repository-support.ts";

export interface CovenRepository {
  listPage(input: Readonly<{
    limit: number;
    category: string | undefined;
    verifiedAsOf: string | undefined;
    after: readonly [slug: string, id: string] | null;
  }>): Promise<JsonObject[]>;
  list(limit: number): Promise<JsonObject[]>;
  get(id: string): Promise<JsonObject | null>;
}
