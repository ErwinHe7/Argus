import type { JsonObject } from "../../db/repository-support.ts";

export interface NotificationRepository {
  list(limit: number): Promise<JsonObject[]>;
  setRead(id: string, read: boolean): Promise<JsonObject>;
  readAll(before: string): Promise<JsonObject>;
  getPreferences(): Promise<JsonObject>;
  updatePreferences(
    patch: JsonObject,
    expectedVersion: number,
  ): Promise<JsonObject>;
}
