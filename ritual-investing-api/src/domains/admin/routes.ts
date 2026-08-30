import { z } from "@hono/zod-openapi";
import type { Context } from "hono";

import { StaffAuthorizationError } from "../../db/request-transaction.ts";
import type { AdminRepository } from "./ports.ts";
import { adminEditorialKindSchema } from "./schemas.ts";
import {
  dataResponse,
  errorResponse,
  expectedVersion,
  HttpBoundaryError,
  parseBody,
  retainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";
import {
  idempotencyKeySchema,
  jsonObjectSchema,
  pageLimitSchema,
  uuidSchema,
} from "../retained-http/schemas.ts";
import type { RetainedAppEnvironment } from "../retained-http/types.ts";

export type AdminRouteRepository = AdminRepository;

export interface AdminOperationsRouteService {
  listJobs(limit: number): Promise<unknown>;
  listPrivacy(limit: number): Promise<unknown>;
  listBrokerageDiagnostics(limit: number): Promise<unknown>;
  requestJobRetry(
    jobId: string,
    idempotencyKey: string,
    stepUpReceipt: string,
  ): Promise<unknown>;
  requestPrivacyRetry(
    requestId: string,
    idempotencyKey: string,
    stepUpReceipt: string,
  ): Promise<unknown>;
}

export function registerAdminRoutes(
  dependencies: Readonly<{
    register: RetainedRouteRegistrar;
    repository: (
      context: Context<RetainedAppEnvironment>,
    ) => AdminRouteRepository;
    operations: (
      context: Context<RetainedAppEnvironment>,
    ) => AdminOperationsRouteService;
  }>,
): void {
  const adminSession = retainedRoute(
    "get",
    "/v1/admin/session",
    "getAdminSession",
    "Admin",
    { transaction: { mode: "runtime-staff" } },
  );
  dependencies.register(
    adminSession,
    async (context) => {
      const staff = await dependencies.repository(context)
        .getStaffPrincipal();
      if (staff === null) throw new StaffAuthorizationError();
      return dataResponse(context, staff);
    },
  );
  const adminStepUpBody = z.object({
    action: z.enum(["admin_job_retry", "admin_privacy_retry"]),
    target_id: uuidSchema,
  }).strict();
  const adminStepUp = retainedRoute(
    "post",
    "/v1/admin/step-up",
    "issueAdminStepUp",
    "Admin",
    {
      transaction: { mode: "runtime-staff" },
      body: adminStepUpBody,
    },
  );
  dependencies.register(adminStepUp, async (context) => {
    const input = await parseBody(context, adminStepUpBody);
    return dataResponse(context, {
      receipt: await dependencies.repository(context).issueStepUp(
        input.action,
        input.target_id,
      ),
    });
  });
  const adminAudit = retainedRoute(
    "get",
    "/v1/admin/audit",
    "listAdminAudit",
    "Admin",
    {
      transaction: { mode: "runtime-staff", permission: "audit:read" },
      query: z.object({ limit: pageLimitSchema.optional() }),
    },
  );
  dependencies.register(
    adminAudit,
    async (context) =>
      dataResponse(
        context,
        await dependencies.repository(context).listAudit(
          pageLimitSchema.parse(context.req.query("limit")),
        ),
      ),
  );
  const adminEditorialCreateBody = z.object({
    kind: adminEditorialKindSchema,
    slug: z.string().min(1).max(120).regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
    payload: jsonObjectSchema,
  }).strict();
  const adminEditorialRevisionBody = z.object({ payload: jsonObjectSchema })
    .strict();
  const adminEditorialCommandBody = z.object({
    action: z.enum([
      "request_review",
      "approve",
      "changes_requested",
      "publish",
      "withdraw",
    ]),
    revision_id: uuidSchema.nullable(),
    reason: z.string().min(8).max(500),
    high_trust: z.boolean().default(false),
  }).strict();
  const listAdminEditorial = retainedRoute(
    "get",
    "/v1/admin/editorial",
    "listAdminEditorial",
    "Admin",
    {
      transaction: { mode: "staff", permission: "editorial:read" },
      query: z.object({
        limit: pageLimitSchema.optional(),
        kind: adminEditorialKindSchema.optional(),
      }),
    },
  );
  dependencies.register(
    listAdminEditorial,
    async (context) =>
      dataResponse(
        context,
        await dependencies.repository(context).listEditorial(
          pageLimitSchema.parse(context.req.query("limit")),
          context.req.query("kind"),
        ),
      ),
  );
  const createAdminEditorial = retainedRoute(
    "post",
    "/v1/admin/editorial",
    "createAdminEditorial",
    "Admin",
    {
      transaction: { mode: "staff", permission: "editorial:write" },
      body: adminEditorialCreateBody,
    },
  );
  dependencies.register(createAdminEditorial, async (context) => {
    const body = await parseBody(context, adminEditorialCreateBody);
    return dataResponse(
      context,
      await dependencies.repository(context).createEditorial(
        body.kind,
        body.slug,
        body.payload,
        context.get("requestId"),
      ),
    );
  });
  const getAdminEditorial = retainedRoute(
    "get",
    "/v1/admin/editorial/{item_id}",
    "getAdminEditorial",
    "Admin",
    {
      transaction: { mode: "staff", permission: "editorial:read" },
      pathParams: z.object({ item_id: uuidSchema }),
    },
  );
  dependencies.register(getAdminEditorial, async (context) =>
    dataResponse(
      context,
      await dependencies.repository(context).getEditorial(
        uuidSchema.parse(context.req.param("item_id")),
      ),
    ));
  const createAdminEditorialRevision = retainedRoute(
    "post",
    "/v1/admin/editorial/{item_id}/revisions",
    "createAdminEditorialRevision",
    "Admin",
    {
      transaction: { mode: "staff", permission: "editorial:write" },
      pathParams: z.object({ item_id: uuidSchema }),
      body: adminEditorialRevisionBody,
    },
  );
  dependencies.register(createAdminEditorialRevision, async (context) => {
    const body = await parseBody(context, adminEditorialRevisionBody);
    return dataResponse(
      context,
      await dependencies.repository(context).createEditorialRevision(
        uuidSchema.parse(context.req.param("item_id")),
        body.payload,
        context.get("requestId"),
      ),
    );
  });
  const patchAdminEditorialRevision = retainedRoute(
    "patch",
    "/v1/admin/editorial/{item_id}/revisions/{revision_id}",
    "patchAdminEditorialRevision",
    "Admin",
    {
      transaction: { mode: "staff", permission: "editorial:write" },
      pathParams: z.object({ item_id: uuidSchema, revision_id: uuidSchema }),
      headers: z.object({
        "if-match": z.string().regex(/^"v[1-9]\d*"$/),
      }),
      body: adminEditorialRevisionBody,
    },
  );
  dependencies.register(patchAdminEditorialRevision, async (context) => {
    const body = await parseBody(context, adminEditorialRevisionBody);
    return dataResponse(
      context,
      await dependencies.repository(context).patchEditorialRevision(
        uuidSchema.parse(context.req.param("item_id")),
        uuidSchema.parse(context.req.param("revision_id")),
        expectedVersion(context),
        body.payload,
        context.get("requestId"),
      ),
    );
  });
  const commandAdminEditorial = retainedRoute(
    "post",
    "/v1/admin/editorial/{item_id}/commands",
    "commandAdminEditorial",
    "Admin",
    {
      transaction: { mode: "staff" },
      pathParams: z.object({ item_id: uuidSchema }),
      body: adminEditorialCommandBody,
    },
  );
  dependencies.register(commandAdminEditorial, async (context) => {
    const body = await parseBody(context, adminEditorialCommandBody);
    if (body.action !== "withdraw" && body.revision_id === null) {
      throw new HttpBoundaryError(
        422,
        "revision_required",
        "This editorial command requires a revision.",
      );
    }
    const result = await dependencies.repository(context).commandEditorial(
      body.action,
      uuidSchema.parse(context.req.param("item_id")),
      body.revision_id,
      body.reason,
      body.high_trust,
      context.get("requestId"),
    );
    if ("_denied" in result && result._denied === "self_approval") {
      return errorResponse(
        context,
        new HttpBoundaryError(
          403,
          "forbidden",
          "Current staff authorization is required.",
        ),
      );
    }
    return dataResponse(context, result);
  });
  const adminJobs = retainedRoute(
    "get",
    "/v1/admin/operations/jobs",
    "listAdminJobs",
    "Admin Operations",
    {
      transaction: { mode: "staff", permission: "operations:read" },
      query: z.object({ limit: pageLimitSchema.optional() }),
    },
  );
  dependencies.register(
    adminJobs,
    async (context) =>
      dataResponse(
        context,
        await dependencies.operations(context).listJobs(
          pageLimitSchema.parse(context.req.query("limit")),
        ),
      ),
  );
  const adminPrivacy = retainedRoute(
    "get",
    "/v1/admin/operations/privacy",
    "listAdminPrivacy",
    "Admin Operations",
    {
      transaction: { mode: "staff", permission: "privacy:read" },
      query: z.object({ limit: pageLimitSchema.optional() }),
    },
  );
  dependencies.register(
    adminPrivacy,
    async (context) =>
      dataResponse(
        context,
        await dependencies.operations(context).listPrivacy(
          pageLimitSchema.parse(context.req.query("limit")),
        ),
      ),
  );
  const adminBrokerage = retainedRoute(
    "get",
    "/v1/admin/operations/brokerage",
    "listAdminBrokerageDiagnostics",
    "Admin Operations",
    {
      transaction: { mode: "staff", permission: "brokerage:read" },
      query: z.object({ limit: pageLimitSchema.optional() }),
    },
  );
  dependencies.register(adminBrokerage, async (context) =>
    dataResponse(
      context,
      await dependencies.operations(context)
        .listBrokerageDiagnostics(
          pageLimitSchema.parse(context.req.query("limit")),
        ),
    ));
  const adminRetryBody = z.object({
    step_up_receipt: z.string().min(43).max(128).regex(/^[A-Za-z0-9_-]+$/),
  }).strict();
  const retryJob = retainedRoute(
    "post",
    "/v1/admin/operations/jobs/{job_id}/retry",
    "retryAdminJob",
    "Admin Operations",
    {
      transaction: { mode: "staff", permission: "operations:write" },
      pathParams: z.object({ job_id: uuidSchema }),
      headers: z.object({ "idempotency-key": idempotencyKeySchema }),
      body: adminRetryBody,
    },
  );
  dependencies.register(retryJob, async (context) => {
    const body = await parseBody(context, adminRetryBody);
    return dataResponse(context, {
      outbox_id: await dependencies.operations(context)
        .requestJobRetry(
          uuidSchema.parse(context.req.param("job_id")),
          idempotencyKeySchema.parse(context.req.header("idempotency-key")),
          body.step_up_receipt,
        ),
    });
  });
  const retryPrivacy = retainedRoute(
    "post",
    "/v1/admin/operations/privacy/{request_id}/retry",
    "retryAdminPrivacy",
    "Admin Operations",
    {
      transaction: { mode: "staff", permission: "privacy:write" },
      pathParams: z.object({ request_id: uuidSchema }),
      headers: z.object({ "idempotency-key": idempotencyKeySchema }),
      body: adminRetryBody,
    },
  );
  dependencies.register(retryPrivacy, async (context) => {
    const body = await parseBody(context, adminRetryBody);
    return dataResponse(context, {
      outbox_id: await dependencies.operations(context)
        .requestPrivacyRetry(
          uuidSchema.parse(context.req.param("request_id")),
          idempotencyKeySchema.parse(context.req.header("idempotency-key")),
          body.step_up_receipt,
        ),
    });
  });
}
