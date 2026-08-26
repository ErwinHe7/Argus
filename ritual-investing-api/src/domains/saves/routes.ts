import { createRoute, type OpenAPIHono, z } from "@hono/zod-openapi";

import type { AppEnvironment } from "../../app.ts";
import { errorResponseSchema, objectResponse } from "../../contracts/common.ts";
import { errorResponse } from "../../middleware/responses.ts";
import { requestIdFrom } from "../../middleware/request-context.ts";
import {
  memberAccess,
  memberSecurity,
  type MemberRouteDependencies,
} from "../accounts/access.ts";
import { InvalidChildError } from "../accounts/repository.ts";

const paramsSchema = z.object({ id: z.uuid() });
const sourceContextSchema = z
  .object({
    source_kind: z
      .enum(["ritual", "circle", "discover", "search", "direct"])
      .optional(),
    source_id: z.uuid().optional(),
  })
  .strict()
  .superRefine((value, context) => {
    const hasKind = value.source_kind !== undefined;
    const hasId = value.source_id !== undefined;
    if (hasId && !hasKind) {
      context.addIssue({
        code: "custom",
        path: ["source_kind"],
        message: "source_kind is required with source_id",
      });
    }
    if (value.source_kind === "direct" && hasId) {
      context.addIssue({
        code: "custom",
        path: ["source_id"],
        message: "direct saves cannot include source_id",
      });
    }
    if (hasKind && value.source_kind !== "direct" && !hasId) {
      context.addIssue({
        code: "custom",
        path: ["source_id"],
        message: "source_id is required for attributed saves",
      });
    }
  });
const receiptSchema = z
  .object({
    saved: z.literal(true),
    saved_at: z.iso.datetime({ offset: true }),
  })
  .strict()
  .openapi("SavedItemReceipt");
const errors = {
  401: {
    description: "Invalid token.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  403: {
    description: "Denied.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  404: {
    description: "Not found.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  422: {
    description: "Invalid input.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  429: {
    description: "Limited.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  503: {
    description: "Unavailable.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
} as const;
const kinds = [
  { kind: "asset", path: "saved-assets", operation: "Asset" },
  { kind: "grimoire", path: "saved-grimoires", operation: "Grimoire" },
  {
    kind: "circle_template",
    path: "saved-circle-templates",
    operation: "CircleTemplate",
  },
  { kind: "coven", path: "saved-coven", operation: "Coven" },
] as const;

export function registerSaveRoutes(
  app: OpenAPIHono<AppEnvironment>,
  dependencies: MemberRouteDependencies = {},
): void {
  for (const item of kinds) {
    const putRoute = createRoute({
      method: "put",
      path: `/v1/me/${item.path}/{id}`,
      operationId: `save${item.operation}`,
      tags: ["Saves"],
      security: [{ Auth0OAuth: ["write:self"] }],
      request: {
        params: paramsSchema,
        body: {
          required: false,
          content: { "application/json": { schema: sourceContextSchema } },
        },
      },
      responses: {
        200: {
          description: "Saved idempotently.",
          content: {
            "application/json": { schema: objectResponse(receiptSchema) },
          },
        },
        ...errors,
      },
    });
    const deleteRoute = createRoute({
      method: "delete",
      path: `/v1/me/${item.path}/{id}`,
      operationId: `unsave${item.operation}`,
      tags: ["Saves"],
      security: [{ Auth0OAuth: ["write:self"] }],
      request: { params: paramsSchema },
      responses: { 204: { description: "Removed idempotently." }, ...errors },
    });

    for (const middleware of memberSecurity(
      dependencies,
      true,
      putRoute.method,
    )) {
      app.use(putRoute.getRoutingPath(), middleware);
    }
    app.openapi(putRoute, async (context) => {
      const access = memberAccess(context, dependencies);
      if (access === undefined) return unavailable(context) as never;
      try {
        const data = await access.repository.save(
          access.member,
          item.kind,
          context.req.valid("param").id,
          context.req.valid("json") ?? {},
        );
        return context.json(
          { data, meta: { request_id: requestIdFrom(context) } },
          200,
        ) as never;
      } catch (error) {
        return error instanceof InvalidChildError
          ? (errorResponse(
              context,
              404,
              "not_found",
              "The requested resource was not found.",
            ) as never)
          : (unavailable(context) as never);
      }
    });

    for (const middleware of memberSecurity(
      dependencies,
      true,
      deleteRoute.method,
    )) {
      app.use(deleteRoute.getRoutingPath(), middleware);
    }
    app.openapi(deleteRoute, async (context) => {
      const access = memberAccess(context, dependencies);
      if (access === undefined) return unavailable(context) as never;
      try {
        await access.repository.unsave(
          access.member,
          item.kind,
          context.req.valid("param").id,
        );
        return context.body(null, 204) as never;
      } catch {
        return unavailable(context) as never;
      }
    });
  }
}

function unavailable(context: any) {
  return errorResponse(
    context,
    503,
    "service_unavailable",
    "Save storage is temporarily unavailable.",
    { retryable: true },
  );
}
