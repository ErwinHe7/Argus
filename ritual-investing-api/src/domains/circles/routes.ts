import { createRoute, type OpenAPIHono, z } from "@hono/zod-openapi";

import type { AppEnvironment } from "../../app.ts";
import {
  collectionResponse,
  errorResponseSchema,
  etagSchema,
  idempotencyKeySchema,
  objectResponse,
} from "../../contracts/common.ts";
import { errorResponse } from "../../middleware/responses.ts";
import { requestIdFrom } from "../../middleware/request-context.ts";
import {
  memberAccess,
  memberSecurity,
  type MemberRouteDependencies,
  versionFrom,
} from "../accounts/access.ts";
import {
  IdempotencyConflictError,
  InvalidChildError,
  MemberInputError,
  VersionConflictError,
} from "../accounts/repository.ts";
import { InvalidCursorError } from "../editorial/cursor.ts";
import { resolveSignedPage } from "../editorial/pagination.ts";
import {
  circleAssetMutationSchema,
  circleAssetParamsSchema,
  circleCreateSchema,
  circleIdParamsSchema,
  circleListQuerySchema,
  circlePatchSchema,
  circleViewSchema,
  copyTemplateSchema,
} from "./schemas.ts";

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
  409: {
    description: "Version or idempotency conflict.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  413: {
    description: "Too large.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  415: {
    description: "Unsupported media.",
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

const readSecurity = [{ Auth0OAuth: ["read:self"] }];
const writeSecurity = [{ Auth0OAuth: ["write:self"] }];
const ifMatch = z.object({ "if-match": etagSchema });
const idempotency = z.object({ "idempotency-key": idempotencyKeySchema });

const listRoute = createRoute({
  method: "get",
  path: "/v1/circles",
  operationId: "listCircles",
  tags: ["Circles"],
  security: readSecurity,
  request: { query: circleListQuerySchema },
  responses: {
    200: {
      description: "Private Circles.",
      content: {
        "application/json": {
          schema: collectionResponse(circleViewSchema).openapi(
            "CircleCollectionResponse",
          ),
        },
      },
    },
    ...errors,
  },
});
const getRoute = createRoute({
  method: "get",
  path: "/v1/circles/{id}",
  operationId: "getCircle",
  tags: ["Circles"],
  security: readSecurity,
  request: { params: circleIdParamsSchema },
  responses: {
    200: {
      description: "Private Circle.",
      content: {
        "application/json": {
          schema: objectResponse(circleViewSchema).openapi("CircleResponse"),
        },
      },
    },
    ...errors,
  },
});
const createRouteDefinition = createRoute({
  method: "post",
  path: "/v1/circles",
  operationId: "createCircle",
  tags: ["Circles"],
  security: writeSecurity,
  request: {
    headers: idempotency,
    body: {
      required: true,
      content: { "application/json": { schema: circleCreateSchema } },
    },
  },
  responses: {
    201: {
      description: "Created Circle.",
      content: {
        "application/json": { schema: objectResponse(circleViewSchema) },
      },
    },
    ...errors,
  },
});
const copyRoute = createRoute({
  method: "post",
  path: "/v1/circle-templates/{id}/copies",
  operationId: "copyCircleTemplate",
  tags: ["Circles"],
  security: writeSecurity,
  request: {
    params: circleIdParamsSchema,
    headers: idempotency,
    body: {
      required: false,
      content: { "application/json": { schema: copyTemplateSchema } },
    },
  },
  responses: {
    201: {
      description: "Private frozen copy.",
      content: {
        "application/json": { schema: objectResponse(circleViewSchema) },
      },
    },
    ...errors,
  },
});
const patchRoute = createRoute({
  method: "patch",
  path: "/v1/circles/{id}",
  operationId: "patchCircle",
  tags: ["Circles"],
  security: writeSecurity,
  request: {
    params: circleIdParamsSchema,
    headers: ifMatch,
    body: {
      required: true,
      content: { "application/json": { schema: circlePatchSchema } },
    },
  },
  responses: {
    200: {
      description: "Updated Circle.",
      content: {
        "application/json": { schema: objectResponse(circleViewSchema) },
      },
    },
    ...errors,
  },
});
const archiveRoute = createRoute({
  method: "delete",
  path: "/v1/circles/{id}",
  operationId: "archiveCircle",
  tags: ["Circles"],
  security: writeSecurity,
  request: { params: circleIdParamsSchema, headers: ifMatch },
  responses: { 204: { description: "Archived." }, ...errors },
});
const putAssetRoute = createRoute({
  method: "put",
  path: "/v1/circles/{id}/assets/{asset_id}",
  operationId: "putCircleAsset",
  tags: ["Circles"],
  security: writeSecurity,
  request: {
    params: circleAssetParamsSchema,
    headers: ifMatch,
    body: {
      required: true,
      content: { "application/json": { schema: circleAssetMutationSchema } },
    },
  },
  responses: {
    200: {
      description: "Updated Circle.",
      content: {
        "application/json": { schema: objectResponse(circleViewSchema) },
      },
    },
    ...errors,
  },
});
const deleteAssetRoute = createRoute({
  method: "delete",
  path: "/v1/circles/{id}/assets/{asset_id}",
  operationId: "deleteCircleAsset",
  tags: ["Circles"],
  security: writeSecurity,
  request: { params: circleAssetParamsSchema, headers: ifMatch },
  responses: {
    200: {
      description: "Updated Circle.",
      content: {
        "application/json": { schema: objectResponse(circleViewSchema) },
      },
    },
    ...errors,
  },
});

export function registerCircleRoutes(
  app: OpenAPIHono<AppEnvironment>,
  dependencies: MemberRouteDependencies = {},
): void {
  const secure = (
    route: { getRoutingPath(): string; method: string },
    write: boolean,
  ) => {
    for (const middleware of memberSecurity(
      dependencies,
      write,
      route.method,
    )) {
      app.use(route.getRoutingPath(), middleware);
    }
  };
  const access = (context: any) => memberAccess(context, dependencies);
  const notFound = (context: any) =>
    errorResponse(
      context,
      404,
      "not_found",
      "The requested resource was not found.",
    );
  const success = (context: any, data: unknown, status = 200) => {
    if (typeof data === "object" && data !== null && "version" in data) {
      context.header(
        "ETag",
        `"v${String((data as { version: number }).version)}"`,
      );
    }
    return context.json(
      { data, meta: { request_id: requestIdFrom(context) } },
      status,
    );
  };
  const run = async (
    context: any,
    action: (
      member: NonNullable<ReturnType<typeof access>>,
    ) => Promise<unknown>,
    status = 200,
  ) => {
    const member = access(context);
    if (member === undefined) return unavailable(context);
    try {
      const value = await action(member);
      return value === null
        ? notFound(context)
        : success(context, value, status);
    } catch (error) {
      return circleError(context, error);
    }
  };

  secure(listRoute, false);
  app.openapi(listRoute, async (context) => {
    const member = access(context);
    if (member === undefined) return unavailable(context) as never;
    const query = context.req.valid("query");
    const secret = context.env.CURSOR_SIGNING_KEY;
    if (secret === undefined) return unavailable(context) as never;
    try {
      const page = await resolveSignedPage({
        ...(query.cursor === undefined ? {} : { cursor: query.cursor }),
        secret,
        scope: `circles:${member.member.tenantId}:${query.archived}`,
        load: (after) =>
          member.repository.listCircles(member.member, {
            archived: query.archived,
            limit: query.limit,
            ...(after === undefined ? {} : { after }),
          }),
      });
      return context.json(
        {
          data: page.items,
          meta: {
            request_id: requestIdFrom(context),
            next_cursor: page.nextCursor,
            has_more: page.nextCursor !== null,
          },
        },
        200,
      ) as never;
    } catch (error) {
      if (error instanceof InvalidCursorError) {
        return errorResponse(
          context,
          422,
          "invalid_cursor",
          "The pagination cursor is invalid or stale.",
        ) as never;
      }
      return unavailable(context) as never;
    }
  });

  secure(getRoute, false);
  app.openapi(
    getRoute,
    (context) =>
      run(context, (member) =>
        member.repository.getCircle(
          member.member,
          context.req.valid("param").id,
        ),
      ) as never,
  );

  secure(createRouteDefinition, true);
  app.openapi(
    createRouteDefinition,
    (context) =>
      run(
        context,
        (member) =>
          member.repository.createCircle(
            member.member,
            context.req.valid("json"),
            context.req.header("idempotency-key")!,
          ),
        201,
      ) as never,
  );

  secure(copyRoute, true);
  app.openapi(
    copyRoute,
    (context) =>
      run(
        context,
        (member) =>
          member.repository.copyTemplate(
            member.member,
            context.req.valid("param").id,
            context.req.header("idempotency-key")!,
            context.req.valid("json") ?? {},
          ),
        201,
      ) as never,
  );

  secure(patchRoute, true);
  app.openapi(
    patchRoute,
    (context) =>
      run(context, (member) =>
        member.repository.patchCircle(
          member.member,
          context.req.valid("param").id,
          context.req.valid("json"),
          versionFrom(context.req.header("if-match"))!,
        ),
      ) as never,
  );

  secure(archiveRoute, true);
  app.openapi(archiveRoute, async (context) => {
    const member = access(context);
    if (member === undefined) return unavailable(context) as never;
    try {
      const archived = await member.repository.archiveCircle(
        member.member,
        context.req.valid("param").id,
        versionFrom(context.req.header("if-match"))!,
      );
      return archived
        ? (context.body(null, 204) as never)
        : (notFound(context) as never);
    } catch (error) {
      return circleError(context, error) as never;
    }
  });

  secure(putAssetRoute, true);
  app.openapi(
    putAssetRoute,
    (context) =>
      run(context, (member) => {
        const params = context.req.valid("param");
        const body = context.req.valid("json");
        return member.repository.putCircleAsset(
          member.member,
          params.id,
          params.asset_id,
          {
            asset_id: params.asset_id,
            ordinal: body.ordinal,
            ...(body.weight_bps === undefined
              ? {}
              : { weight_bps: body.weight_bps }),
            ...(body.note === undefined ? {} : { note: body.note }),
          },
          versionFrom(context.req.header("if-match"))!,
        );
      }) as never,
  );

  secure(deleteAssetRoute, true);
  app.openapi(
    deleteAssetRoute,
    (context) =>
      run(context, (member) => {
        const params = context.req.valid("param");
        return member.repository.deleteCircleAsset(
          member.member,
          params.id,
          params.asset_id,
          versionFrom(context.req.header("if-match"))!,
        );
      }) as never,
  );
}

function circleError(context: any, error: unknown) {
  if (
    error instanceof VersionConflictError ||
    (error instanceof Error && error.message.includes("version_conflict"))
  ) {
    return errorResponse(
      context,
      409,
      "version_conflict",
      "This Circle changed. Refresh before retrying.",
    );
  }
  if (
    error instanceof IdempotencyConflictError ||
    (error instanceof Error && error.message.includes("idempotency_conflict"))
  ) {
    return errorResponse(
      context,
      409,
      "idempotency_conflict",
      "That idempotency key was already used for a different request.",
    );
  }
  if (
    error instanceof InvalidChildError ||
    (error instanceof Error && error.message.includes("invalid_child"))
  ) {
    return errorResponse(
      context,
      404,
      "not_found",
      "The requested resource was not found.",
    );
  }
  if (
    error instanceof MemberInputError ||
    (error instanceof Error &&
      /invalid_weight_total|asset_cap|duplicate_(?:asset|ordinal)/.test(
        error.message,
      ))
  ) {
    return errorResponse(
      context,
      422,
      "invalid_circle",
      "The Circle assets violate the cap, uniqueness, or weight rules.",
    );
  }
  return unavailable(context);
}

function unavailable(context: any) {
  return errorResponse(
    context,
    503,
    "service_unavailable",
    "Circle storage is temporarily unavailable.",
    { retryable: true },
  );
}
