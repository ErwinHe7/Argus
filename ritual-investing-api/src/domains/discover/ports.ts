import type { JsonObject } from "../../db/repository-support.ts";

export interface DiscoverRepository {
  listGrimoiresPage(
    input: Readonly<{
      limit: number;
      theme: string | undefined;
      after: readonly [slug: string, id: string] | null;
    }>,
  ): Promise<JsonObject[]>;
  listCircleTemplatesPage(
    input: Readonly<{
      limit: number;
      creator: string | undefined;
      after: readonly [slug: string, id: string] | null;
    }>,
  ): Promise<JsonObject[]>;
  listCreatorsPage(
    input: Readonly<{
      limit: number;
      after: readonly [displayName: string, id: string] | null;
    }>,
  ): Promise<JsonObject[]>;
  getCreator(id: string): Promise<JsonObject | null>;
  listGrimoires(limit: number, theme?: string): Promise<JsonObject[]>;
  listCircleTemplates(limit: number, creator?: string): Promise<JsonObject[]>;
  getGrimoire(id: string): Promise<JsonObject | null>;
  listCreators(limit: number): Promise<JsonObject[]>;
}
