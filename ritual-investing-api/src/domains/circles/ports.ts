import type { JsonObject } from "../../db/repository-support.ts";

export type CircleAssetInput = Readonly<{
  assetId: string;
  ordinal: number;
  weightBps?: number | null | undefined;
  note?: string | null | undefined;
}>;

export interface CircleRepository {
  listPage(input: Readonly<{
    limit: number;
    includeArchived: boolean;
    after: readonly [
      archived: boolean,
      archivedAt: string | null,
      id: string,
    ] | null;
  }>): Promise<JsonObject[]>;
  list(limit: number): Promise<JsonObject[]>;
  get(id: string): Promise<JsonObject>;
  create(
    input: Readonly<{
      title: string;
      description: string;
      assets?: readonly CircleAssetInput[];
      sourceTemplateId?: string;
    }>,
  ): Promise<JsonObject>;
  update(
    id: string,
    input: Readonly<{ title?: string; description?: string }>,
    expectedVersion: number,
  ): Promise<JsonObject>;
  replaceAssets(
    id: string,
    assets: readonly CircleAssetInput[],
    expectedVersion: number,
  ): Promise<JsonObject>;
  putAsset(
    id: string,
    assetId: string,
    asset: Omit<CircleAssetInput, "assetId">,
    expectedVersion: number,
  ): Promise<JsonObject>;
  deleteAsset(
    id: string,
    assetId: string,
    expectedVersion: number,
  ): Promise<JsonObject>;
  archive(id: string, expectedVersion: number): Promise<JsonObject>;
  getTemplate(id: string): Promise<JsonObject | null>;
  listSaved(limit: number): Promise<JsonObject[]>;
  save(
    itemKind: "asset" | "grimoire" | "circle_template" | "coven",
    itemId: string,
    sourceKind?: string,
    sourceId?: string,
  ): Promise<JsonObject>;
  unsave(
    itemKind: "asset" | "grimoire" | "circle_template" | "coven",
    itemId: string,
  ): Promise<JsonObject>;
}
