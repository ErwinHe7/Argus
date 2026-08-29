import type { JsonObject } from "../../db/repository-support.ts";

export interface EditorialRepository {
  listPublishedPage(input: Readonly<{
    kind: string;
    limit: number;
    after: readonly [slug: string, id: string] | null;
  }>): Promise<JsonObject[]>;
  listPublished(kind: string, limit: number): Promise<JsonObject[]>;
  getPublished(slug: string): Promise<JsonObject | null>;
  listEvidence(claimIds: readonly string[]): Promise<JsonObject[]>;
}
