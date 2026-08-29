import type { JsonObject } from "../../db/repository-support.ts";

export interface ModerationRepository {
  report(
    input: Readonly<{
      targetKind: string;
      targetId: string;
      reasonCode: string;
      details?: string;
    }>,
  ): Promise<JsonObject>;
  decide(
    caseId: string,
    expectedVersion: number,
    decision: JsonObject,
    correlationId: string,
  ): Promise<JsonObject>;
}
