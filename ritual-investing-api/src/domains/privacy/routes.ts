import { createRoute, type OpenAPIHono, z } from "@hono/zod-openapi";

import type { AppEnvironment } from "../../app.ts";
import {
  errorResponseSchema,
  idempotencyKeySchema,
  objectResponse,
} from "../../contracts/common.ts";
import { requestIdFrom } from "../../middleware/request-context.ts";
import {
  privacySecurity,
  type MemberRouteDependencies,
} from "../accounts/access.ts";
import { currentMember } from "../u7-support.ts";
import {
  createPostgresPrivacyRepository,
  PrivacyConflictError,
  type PrivacyRepository,
} from "./repository.ts";
import {
  deletionCreateSchema,
  deletionReceiptSchema,
  exportCreateSchema,
  privacyRequestSchema,
} from "./schemas.ts";

const errors = {
  401: {
    description: "Authentication required.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  403: {
    description: "Privacy permission and recent authentication required.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  404: {
    description: "Not found.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  409: {
    description: "Conflicting idempotency replay.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  422: {
    description: "Invalid input.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  429: {
    description: "Sensitive route rate limited.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  503: {
    description: "Temporarily unavailable.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
} as const;
const commandHeaders = z.object({ "idempotency-key": idempotencyKeySchema });
const requestParams = z.object({ request_id: z.string().uuid() }).strict();
const createExport = createRoute({
  method: "post",
  path: "/v1/me/privacy/exports",
  operationId: "requestPrivacyExport",
  tags: ["Privacy"],
  security: [{ Auth0OAuth: ["privacy:self"] }],
  request: {
    headers: commandHeaders,
    body: {
      required: true,
      content: { "application/json": { schema: exportCreateSchema } },
    },
  },
  responses: {
    202: {
      description: "Queued coherent ZIP snapshot export.",
      content: {
        "application/json": { schema: objectResponse(privacyRequestSchema) },
      },
    },
    ...errors,
  },
});
const getExport = createRoute({
  method: "get",
  path: "/v1/me/privacy/exports/{request_id}",
  operationId: "getPrivacyExport",
  tags: ["Privacy"],
  security: [{ Auth0OAuth: ["privacy:self"] }],
  request: { params: requestParams },
  responses: {
    200: {
      description: "Export status with a short-lived link when ready.",
      content: {
        "application/json": { schema: objectResponse(privacyRequestSchema) },
      },
    },
    ...errors,
  },
});
const download = createRoute({
  method: "get",
  path: "/v1/me/privacy/exports/{request_id}/download",
  operationId: "downloadPrivacyExport",
  tags: ["Privacy"],
  security: [{ Auth0OAuth: ["privacy:self"] }],
  request: {
    params: requestParams,
    query: z.object({ token: z.string().regex(/^[a-f0-9]{64}$/) }).strict(),
  },
  responses: {
    200: {
      description: "One-time ZIP archive download.",
      content: {
        "application/zip": {
          schema: z.string().openapi({ format: "binary" }),
        },
      },
    },
    ...errors,
  },
});
const deletion = createRoute({
  method: "post",
  path: "/v1/me/privacy/deletion-requests",
  operationId: "requestAccountDeletion",
  tags: ["Privacy"],
  security: [{ Auth0OAuth: ["privacy:self"] }],
  request: {
    headers: commandHeaders,
    body: {
      required: true,
      content: { "application/json": { schema: deletionCreateSchema } },
    },
  },
  responses: {
    202: {
      description: "Immediate revocation and verified purge queued.",
      content: {
        "application/json": { schema: objectResponse(deletionReceiptSchema) },
      },
    },
    ...errors,
  },
});

export type PrivacyRouteDependencies = MemberRouteDependencies & {
  privacyRepository?: PrivacyRepository;
};

export function registerPrivacyRoutes(
  app: OpenAPIHono<AppEnvironment>,
  dependencies: PrivacyRouteDependencies = {},
) {
  for (const method of ["get", "post"] as const)
    for (const middleware of privacySecurity(dependencies, method))
      app.use("/v1/me/privacy/*", middleware);
  const access = (context: any) => ({
    member: currentMember(context),
    repository:
      dependencies.privacyRepository ??
      (context.env.RUNTIME_DATABASE_URL === undefined
        ? undefined
        : createPostgresPrivacyRepository(context.env.RUNTIME_DATABASE_URL)),
  });
  const unavailable = (context: any) =>
    context.json(
      {
        error: {
          code: "service_unavailable",
          message: "Privacy operations are unavailable.",
          request_id: requestIdFrom(context),
          field_errors: [],
          retryable: true,
        },
      },
      503,
    );
  const notFound = (context: any, message: string) =>
    context.json(
      {
        error: {
          code: "not_found",
          message,
          request_id: requestIdFrom(context),
          field_errors: [],
          retryable: false,
        },
      },
      404,
    );
  app.openapi(createExport, (async (context: any) => {
    const { member, repository } = access(context);
    if (member === undefined || repository === undefined)
      return unavailable(context);
    try {
      const data = await repository.requestExport(
        member,
        context.req.valid("json").format,
        context.req.valid("header")["idempotency-key"],
      );
      return context.json(
        { data, meta: { request_id: requestIdFrom(context) } },
        202,
      );
    } catch (error) {
      if (!(error instanceof PrivacyConflictError)) throw error;
      return context.json(
        {
          error: {
            code: error.message,
            message:
              "The privacy request conflicts with an active or prior request.",
            request_id: requestIdFrom(context),
            field_errors: [],
            retryable: false,
          },
        },
        409,
      );
    }
  }) as never);
  app.openapi(getExport, (async (context: any) => {
    const { member, repository } = access(context);
    if (member === undefined || repository === undefined)
      return unavailable(context);
    const data = await repository.getRequest(
      member,
      context.req.valid("param").request_id,
    );
    if (data === null) return notFound(context, "Export not found.");
    const link =
      data.status === "completed"
        ? await repository.createDownloadLink(
            member,
            data.id,
            context.env.API_ORIGIN,
          )
        : null;
    return context.json(
      {
        data: { ...data, download_link: link },
        meta: { request_id: requestIdFrom(context) },
      },
      200,
    );
  }) as never);
  app.openapi(download, (async (context: any) => {
    const { member, repository } = access(context);
    const bucket = context.env.PRIVACY_EXPORTS;
    if (
      member === undefined ||
      repository === undefined ||
      bucket === undefined
    )
      return unavailable(context);
    const key = await repository.consumeDownload(
      member,
      context.req.valid("param").request_id,
      context.req.valid("query").token,
    );
    if (key === null) return notFound(context, "Download is unavailable.");
    const object = await bucket.get(key);
    if (object === null) return unavailable(context);
    return context.body(object.body, 200, {
      "content-type": "application/zip",
      "content-disposition": `attachment; filename="ritual-privacy-${context.req.valid("param").request_id}.zip"`,
      "cache-control": "private, no-store",
    });
  }) as never);
  app.openapi(deletion, (async (context: any) => {
    const { member, repository } = access(context);
    if (member === undefined || repository === undefined)
      return unavailable(context);
    context.req.valid("json");
    try {
      const data = await repository.requestDeletion(
        member,
        context.req.valid("header")["idempotency-key"],
      );
      return context.json(
        { data, meta: { request_id: requestIdFrom(context) } },
        202,
      );
    } catch (error) {
      if (!(error instanceof PrivacyConflictError)) throw error;
      return context.json(
        {
          error: {
            code: error.message,
            message: "Deletion is already in progress.",
            request_id: requestIdFrom(context),
            field_errors: [],
            retryable: false,
          },
        },
        409,
      );
    }
  }) as never);
}
