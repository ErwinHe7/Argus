import type { JsonObject } from "../../db/repository-support.ts";

export interface RowanRepository {
  resolve(surface: string, contextKey: string): Promise<JsonObject>;
}
