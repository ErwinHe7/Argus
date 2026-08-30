import type { JsonObject } from "../../db/repository-support.ts";
import type { AdminEditorialKind } from "./schemas.ts";

export interface AdminRepository {
  getStaffPrincipal(): Promise<JsonObject | null>;
  issueStepUp(
    action: "admin_job_retry" | "admin_privacy_retry",
    targetId: string,
  ): Promise<string>;
  listAudit(limit: number): Promise<JsonObject[]>;
  listEditorial(limit: number, kind?: string): Promise<JsonObject[]>;
  getEditorial(itemId: string): Promise<{ revision: JsonObject }>;
  createEditorial(
    kind: AdminEditorialKind,
    slug: string,
    payload: JsonObject,
    requestId: string,
  ): Promise<JsonObject>;
  createEditorialRevision(
    itemId: string,
    payload: JsonObject,
    requestId: string,
  ): Promise<JsonObject>;
  patchEditorialRevision(
    itemId: string,
    revisionId: string,
    expectedVersion: number,
    payload: JsonObject,
    requestId: string,
  ): Promise<JsonObject>;
  commandEditorial(
    action:
      | "request_review"
      | "approve"
      | "changes_requested"
      | "publish"
      | "withdraw",
    itemId: string,
    revisionId: string | null,
    reason: string,
    highTrust: boolean,
    requestId: string,
  ): Promise<JsonObject>;
}
