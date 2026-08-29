import type { JsonObject } from "../../db/repository-support.ts";

export interface AssetRepository {
  listPage(input: Readonly<{
    limit: number;
    assetType: string | undefined;
    symbolPrefix: string | undefined;
    after: readonly [symbol: string, id: string] | null;
  }>): Promise<JsonObject[]>;
  list(
    limit: number,
    assetType?: string,
    symbolPrefix?: string,
  ): Promise<JsonObject[]>;
  get(id: string): Promise<JsonObject | null>;
  listEvidence(claimIds: readonly string[]): Promise<JsonObject[]>;
  evidence(assetId: string): Promise<JsonObject[]>;
  metrics(assetId: string): Promise<JsonObject[]>;
  compare(assetIds: readonly string[]): Promise<JsonObject[]>;
}
