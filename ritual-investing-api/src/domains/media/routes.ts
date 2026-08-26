import { createRoute, type OpenAPIHono, z } from "@hono/zod-openapi";

import type { AppEnvironment } from "../../app.ts";
import {
  collectionResponse,
  errorResponseSchema,
  idempotencyKeySchema,
  objectResponse,
} from "../../contracts/common.ts";
import { requestIdFrom } from "../../middleware/request-context.ts";
import { errorResponse } from "../../middleware/responses.ts";
import {
  adminBinaryUploadSecurity,
  adminSecurity,
  type AdminRouteDependencies,
} from "../admin/access.ts";
import {
  decodeCursor,
  encodeCursor,
  InvalidCursorError,
} from "../editorial/cursor.ts";
import {
  createPostgresMediaRepository,
  MediaConflictError,
  type MediaRepository,
} from "./repository.ts";
import {
  adminMediaSchema,
  mediaCompleteSchema,
  mediaDeleteSchema,
  mediaScanJobSchema,
  mediaUploadIntentSchema,
  mediaUploadRequestSchema,
} from "./schemas.ts";

const binaryBodySchema = z.string().openapi({ format: "binary" });

const errors = {
  400: {
    description: "Quarantine validation failed.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  401: {
    description: "Dual authentication required.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  403: {
    description: "Editor permission denied.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  404: {
    description: "Not found.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  409: {
    description: "State, reference, or idempotency conflict.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  413: {
    description: "Upload too large.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  422: {
    description: "Invalid input.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  429: {
    description: "Upload rate limited.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  503: {
    description: "Quarantine service unavailable.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
} as const;
const params = z.object({ media_id: z.string().uuid() }).strict();
const idempotencyHeaders = z.object({
  "idempotency-key": idempotencyKeySchema,
});
const deleteHeaders = z.object({
  "if-match": z.string().regex(/^"v[1-9]\d*"$/),
});
const listQuery = z
  .object({
    status: z
      .enum([
        "issued",
        "uploaded",
        "scanning",
        "accepted",
        "rejected",
        "expired",
      ])
      .optional(),
    mime_type: z.enum(["image/jpeg", "image/png", "image/webp"]).optional(),
    search: z
      .string()
      .trim()
      .min(4)
      .max(64)
      .regex(/^[a-f0-9-]+$/i)
      .optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
    cursor: z.string().min(1).max(2048).optional(),
  })
  .strict();

const requestUpload = createRoute({
  method: "post",
  path: "/v1/admin/media/upload-requests",
  operationId: "requestMediaUpload",
  tags: ["Admin Media"],
  security: [{ CloudflareAccess: [], Auth0OAuth: ["admin:media:write"] }],
  request: {
    headers: idempotencyHeaders,
    body: {
      required: true,
      content: { "application/json": { schema: mediaUploadRequestSchema } },
    },
  },
  responses: {
    201: {
      description: "Single-use actor-bound quarantine upload intent.",
      content: {
        "application/json": { schema: objectResponse(mediaUploadIntentSchema) },
      },
    },
    ...errors,
  },
});
const uploadContent = createRoute({
  method: "put",
  path: "/v1/admin/media/upload-requests/{media_id}/content",
  operationId: "uploadMediaQuarantineContent",
  tags: ["Admin Media"],
  security: [{ CloudflareAccess: [], Auth0OAuth: ["admin:media:write"] }],
  request: {
    params,
    body: {
      required: true,
      content: {
        "application/octet-stream": { schema: binaryBodySchema },
      },
    },
  },
  responses: {
    204: { description: "Bytes stored in R2 quarantine only." },
    ...errors,
  },
});
const completeUpload = createRoute({
  method: "post",
  path: "/v1/admin/media/{media_id}/complete",
  operationId: "completeMediaUpload",
  tags: ["Admin Media"],
  security: [{ CloudflareAccess: [], Auth0OAuth: ["admin:media:write"] }],
  request: {
    params,
    headers: idempotencyHeaders,
    body: {
      required: true,
      content: { "application/json": { schema: mediaCompleteSchema } },
    },
  },
  responses: {
    202: {
      description:
        "Actor-bound quarantine object accepted for asynchronous validation.",
      content: {
        "application/json": { schema: objectResponse(mediaScanJobSchema) },
      },
    },
    ...errors,
  },
});
const listMedia = createRoute({
  method: "get",
  path: "/v1/admin/media",
  operationId: "listAdminMedia",
  tags: ["Admin Media"],
  security: [{ CloudflareAccess: [], Auth0OAuth: ["admin:media:read"] }],
  request: { query: listQuery },
  responses: {
    200: {
      description:
        "Bounded media lifecycle metadata without scanner bodies or write URLs.",
      content: {
        "application/json": { schema: collectionResponse(adminMediaSchema) },
      },
    },
    ...errors,
  },
});
const getMedia = createRoute({
  method: "get",
  path: "/v1/admin/media/{media_id}",
  operationId: "getAdminMedia",
  tags: ["Admin Media"],
  security: [{ CloudflareAccess: [], Auth0OAuth: ["admin:media:read"] }],
  request: { params },
  responses: {
    200: {
      description:
        "Quarantine, scan, reference, derivative, and version status.",
      content: {
        "application/json": { schema: objectResponse(adminMediaSchema) },
      },
    },
    ...errors,
  },
});
const deleteMedia = createRoute({
  method: "delete",
  path: "/v1/admin/media/{media_id}",
  operationId: "deleteAdminMedia",
  tags: ["Admin Media"],
  security: [{ CloudflareAccess: [], Auth0OAuth: ["admin:media:write"] }],
  request: {
    params,
    headers: deleteHeaders,
    body: {
      required: true,
      content: { "application/json": { schema: mediaDeleteSchema } },
    },
  },
  responses: {
    204: {
      description: "Unreferenced media retired and derivative cleanup queued.",
    },
    ...errors,
  },
});

export type MediaRouteDependencies = AdminRouteDependencies & {
  mediaRepository?: MediaRepository;
};

function versionFrom(value: string): number {
  return Number(value.slice(2, -1));
}

export function registerMediaRoutes(
  app: OpenAPIHono<AppEnvironment>,
  dependencies: MediaRouteDependencies = {},
) {
  for (const route of [requestUpload, completeUpload])
    for (const middleware of adminSecurity(
      dependencies,
      "post",
      "admin:media:write",
      "RL_UPLOAD",
    ))
      app.use(route.getRoutingPath(), middleware);
  for (const route of [listMedia, getMedia])
    for (const middleware of adminSecurity(
      dependencies,
      "get",
      "admin:media:read",
      "RL_ADMIN_READ",
    ))
      app.use(route.getRoutingPath(), middleware);
  for (const middleware of adminSecurity(
    dependencies,
    "delete",
    "admin:media:write",
    "RL_ADMIN_WRITE",
  ))
    app.use(deleteMedia.getRoutingPath(), middleware);
  for (const middleware of adminBinaryUploadSecurity(dependencies))
    app.use(uploadContent.getRoutingPath(), middleware);
  const repository = (context: any) =>
    dependencies.mediaRepository ??
    (context.env.STAFF_DATABASE_URL === undefined
      ? undefined
      : createPostgresMediaRepository(context.env.STAFF_DATABASE_URL));
  const unavailable = (context: any) =>
    context.json(
      {
        error: {
          code: "service_unavailable",
          message: "Media quarantine is unavailable.",
          request_id: requestIdFrom(context),
          field_errors: [],
          retryable: true,
        },
      },
      503,
    );
  const missing = (context: any) =>
    context.json(
      {
        error: {
          code: "not_found",
          message: "Media not found.",
          request_id: requestIdFrom(context),
          field_errors: [],
          retryable: false,
        },
      },
      404,
    );
  const conflict = (context: any, error: MediaConflictError) =>
    context.json(
      {
        error: {
          code: error.code,
          message:
            error.code === "referenced"
              ? "Referenced media cannot be retired."
              : error.code === "version_conflict"
                ? "The media version has changed."
                : "The idempotency key conflicts with a prior request.",
          request_id: requestIdFrom(context),
          field_errors: [],
          retryable: false,
        },
      },
      409,
    );

  app.openapi(requestUpload, (async (context: any) => {
    const staff = context.get("staffPrincipal");
    const repo = repository(context);
    if (
      staff === undefined ||
      repo === undefined ||
      context.env.MEDIA_QUARANTINE === undefined
    )
      return unavailable(context);
    try {
      const intent = await repo.createIntent(
        staff,
        context.req.valid("json"),
        context.req.valid("header")["idempotency-key"],
        requestIdFrom(context),
      );
      return context.json(
        {
          data: {
            media_id: intent.id,
            quarantine_key: intent.r2Key,
            upload_url: `${context.env.API_ORIGIN}/v1/admin/media/upload-requests/${intent.id}/content`,
            expires_at: intent.expiresAt.toISOString(),
          },
          meta: { request_id: requestIdFrom(context) },
        },
        201,
      );
    } catch (error) {
      if (error instanceof MediaConflictError) return conflict(context, error);
      throw error;
    }
  }) as never);
  app.openapi(uploadContent, (async (context: any) => {
    const staff = context.get("staffPrincipal");
    const repo = repository(context);
    const bucket = context.env.MEDIA_QUARANTINE;
    if (staff === undefined || repo === undefined || bucket === undefined)
      return unavailable(context);
    const intent = await repo.getIntentForCompletion(
      staff,
      context.req.valid("param").media_id,
    );
    if (intent === null) return missing(context);
    const contentType = context.req.header("content-type")?.split(";", 1)[0];
    const bytes = await context.req.arrayBuffer();
    if (
      !["application/octet-stream", intent.expectedMime].includes(
        contentType ?? "",
      ) ||
      bytes.byteLength !== intent.expectedByteSize
    )
      return context.json(
        {
          error: {
            code: "upload_mismatch",
            message: "Upload does not match its intent.",
            request_id: requestIdFrom(context),
            field_errors: [],
            retryable: false,
          },
        },
        400,
      );
    await bucket.put(intent.r2Key, bytes, {
      httpMetadata: { contentType: intent.expectedMime },
      customMetadata: { upload_intent_id: intent.id, actor_staff_id: staff.id },
    });
    if (!(await repo.markUploaded(staff, intent.id))) {
      await bucket.delete(intent.r2Key);
      return missing(context);
    }
    return context.body(null, 204);
  }) as never);
  app.openapi(completeUpload, (async (context: any) => {
    const staff = context.get("staffPrincipal");
    const repo = repository(context);
    if (staff === undefined || repo === undefined) return unavailable(context);
    try {
      const mediaId = context.req.valid("param").media_id;
      const outboxId = await repo.queueScan(
        staff,
        mediaId,
        context.req.valid("json").checksum,
        context.req.valid("header")["idempotency-key"],
        requestIdFrom(context),
      );
      if (outboxId === null) return missing(context);
      return context.json(
        {
          data: { media_id: mediaId, status: "scanning", outbox_id: outboxId },
          meta: { request_id: requestIdFrom(context) },
        },
        202,
      );
    } catch (error) {
      if (error instanceof MediaConflictError) return conflict(context, error);
      throw error;
    }
  }) as never);
  app.openapi(listMedia, (async (context: any) => {
    const staff = context.get("staffPrincipal");
    const repo = repository(context);
    const secret = context.env.CURSOR_SIGNING_KEY;
    if (staff === undefined || repo === undefined || secret === undefined)
      return unavailable(context);
    const query = context.req.valid("query");
    const scope = `admin:media:${query.status ?? "all"}:${query.mime_type ?? "all"}:${query.search ?? "all"}`;
    try {
      const after = await decodeCursor(secret, scope, query.cursor);
      const page = await repo.list(staff, {
        limit: query.limit,
        ...(query.status === undefined ? {} : { status: query.status }),
        ...(query.mime_type === undefined ? {} : { mimeType: query.mime_type }),
        ...(query.search === undefined
          ? {}
          : { search: query.search.toLowerCase() }),
        ...(after === undefined ? {} : { after }),
      });
      const nextCursor =
        page.next === null
          ? null
          : await encodeCursor(secret, scope, page.next);
      return context.json(
        {
          data: page.items,
          meta: {
            request_id: requestIdFrom(context),
            next_cursor: nextCursor,
            has_more: nextCursor !== null,
          },
        },
        200,
      );
    } catch (error) {
      if (!(error instanceof InvalidCursorError)) throw error;
      return context.json(
        {
          error: {
            code: "invalid_cursor",
            message: "The cursor is invalid for this collection.",
            request_id: requestIdFrom(context),
            field_errors: [{ path: "query.cursor", code: "invalid_cursor" }],
            retryable: false,
          },
        },
        422,
      );
    }
  }) as never);
  app.openapi(getMedia, (async (context: any) => {
    const staff = context.get("staffPrincipal");
    const repo = repository(context);
    if (staff === undefined || repo === undefined) return unavailable(context);
    const data = await repo.get(staff, context.req.valid("param").media_id);
    return data === null
      ? missing(context)
      : context.json(
          { data, meta: { request_id: requestIdFrom(context) } },
          200,
        );
  }) as never);
  app.openapi(deleteMedia, (async (context: any) => {
    const staff = context.get("staffPrincipal");
    const repo = repository(context);
    if (staff === undefined || repo === undefined) return unavailable(context);
    try {
      const outboxId = await repo.retire(
        staff,
        context.req.valid("param").media_id,
        versionFrom(context.req.valid("header")["if-match"]),
        context.req.valid("json").reason,
        requestIdFrom(context),
      );
      return outboxId === null ? missing(context) : context.body(null, 204);
    } catch (error) {
      if (error instanceof MediaConflictError) return conflict(context, error);
      throw error;
    }
  }) as never);
}
