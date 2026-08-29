import type { JsonObject } from "../../db/repository-support.ts";

export interface SearchRepository {
  searchPage(input: Readonly<{
    query: string;
    kinds: readonly string[];
    limit: number;
    after: readonly [
      rank: number,
      label: string,
      kind: string,
      id: string,
    ] | null;
  }>): Promise<JsonObject[]>;
}
