import type { JsonObject } from "../../db/repository-support.ts";

export interface BriefingRepository {
  listPage(input: Readonly<{
    limit: number;
    type: string | undefined;
    periodStart: string | undefined;
    periodEnd: string | undefined;
    after: readonly [periodEnd: string, id: string] | null;
  }>): Promise<JsonObject[]>;
  list(
    limit: number,
    type?: string,
    periodStart?: string,
    periodEnd?: string,
  ): Promise<JsonObject[]>;
  get(id: string): Promise<JsonObject | null>;
  daily(localDate: string): Promise<JsonObject | null>;
  setRead(id: string, read: boolean): Promise<JsonObject>;
}
