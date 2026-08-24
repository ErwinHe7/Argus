import { createRoute, type OpenAPIHono, z } from "@hono/zod-openapi";

import type { AppEnvironment } from "../../../app.ts";
import {
  collectionResponse,
  errorResponseSchema,
  etagSchema,
  idempotencyKeySchema,
  objectResponse,
} from "../../../contracts/common.ts";
import { requestIdFrom } from "../../../middleware/request-context.ts";
import { adminSecurity, type AdminRouteDependencies } from "../access.ts";
import {
  decodeCursor,
  encodeCursor,
  InvalidCursorError,
} from "../../editorial/cursor.ts";
import {
  createPostgresAdminEditorialRepository,
  type AdminEditorialRepository,
} from "./repository.ts";
import {
  editorialItemSchema,
  editorialListQuerySchema,
  editorialPayloadSchemas,
  editorialRevisionSchema,
  publicationSchema,
  reviewDecisionSchema,
  reviewRequestSchema,
  slugSchema,
  withdrawalSchema,
} from "./schemas.ts";
import {
  editorialDefinitions,
  EditorialWorkflowError,
  etagVersion,
} from "./service.ts";

const errors = {
  401: {
    description: "Dual staff authentication required.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  403: {
    description: "Staff permission denied and audited.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  404: {
    description: "Editorial resource not found.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  409: {
    description: "Version, transition, or idempotency conflict.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  422: {
    description: "Strict editorial validation failed.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  429: {
    description: "Rate limited.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  503: {
    description: "Editorial store unavailable.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
} as const;

const idempotencyHeaders = z.object({
  "idempotency-key": idempotencyKeySchema,
});
const etagHeaders = z.object({ "if-match": etagSchema });
const itemParams = z.object({ item_id: z.string().uuid() }).strict();
const revisionParams = itemParams
  .extend({ revision_id: z.string().uuid() })
  .strict();

type RepositoryContext = {
  env: AppEnvironment["Bindings"];
  get(
    key: "staffPrincipal",
  ): AppEnvironment["Variables"]["staffPrincipal"] | undefined;
};

export type AdminEditorialRouteDependencies = AdminRouteDependencies & {
  adminEditorialRepository?: AdminEditorialRepository;
};

function repositoryFor(
  context: RepositoryContext,
  dependencies: AdminEditorialRouteDependencies,
) {
  return (
    dependencies.adminEditorialRepository ??
    (context.env.STAFF_DATABASE_URL === undefined
      ? undefined
      : createPostgresAdminEditorialRepository(context.env.STAFF_DATABASE_URL))
  );
}

function unavailable(context: any) {
  return context.json(
    {
      error: {
        code: "service_unavailable",
        message: "The editorial workflow is unavailable.",
        request_id: requestIdFrom(context),
        field_errors: [],
        retryable: true,
      },
    },
    503,
  );
}

function workflowError(context: any, error: unknown) {
  if (error instanceof InvalidCursorError)
    return context.json(
      {
        error: {
          code: "invalid_cursor",
          message: "The pagination cursor is invalid.",
          request_id: requestIdFrom(context),
          field_errors: [],
          retryable: false,
        },
      },
      422,
    );
  const code =
    error instanceof EditorialWorkflowError
      ? error.code
      : error instanceof Error &&
          /not_found|version_conflict|idempotency_conflict|invalid_transition|self_approval|publishability_failed/.test(
            error.message,
          )
        ? (error.message.match(
            /not_found|version_conflict|idempotency_conflict|invalid_transition|self_approval|publishability_failed/,
          )?.[0] ?? "invalid_transition")
        : undefined;
  if (code !== undefined) {
    const status = code === "not_found" ? 404 : 409;
    return context.json(
      {
        error: {
          code,
          message:
            code === "not_found"
              ? "The editorial resource was not found."
              : "The editorial transition could not be applied.",
          request_id: requestIdFrom(context),
          field_errors: [],
          retryable: false,
        },
      },
      status,
    );
  }
  return unavailable(context);
}

function withEtag(context: any, value: { etag: string }, status = 200) {
  context.header("etag", value.etag);
  context.header("cache-control", "no-store");
  return context.json(
    { data: value, meta: { request_id: requestIdFrom(context) } },
    status,
  );
}

export function registerAdminEditorialRoutes(
  app: OpenAPIHono<AppEnvironment>,
  dependencies: AdminEditorialRouteDependencies = {},
) {
  for (const definition of editorialDefinitions) {
    const suffix = definition.kind
      .split("_")
      .map((part) => part[0]!.toUpperCase() + part.slice(1))
      .join("");
    const payloadSchema = editorialPayloadSchemas[definition.kind];
    const createBody = payloadSchema
      .safeExtend({ slug: slugSchema })
      .openapi(`Create${suffix}Request`);
    const revisionBody = z
      .object({ source_revision_id: z.string().uuid(), payload: payloadSchema })
      .strict()
      .openapi(`Create${suffix}RevisionRequest`);
    const patchBody = z
      .object({ payload: payloadSchema })
      .strict()
      .openapi(`Patch${suffix}RevisionRequest`);

    const listRoute = createRoute({
      method: "get",
      path: definition.path,
      operationId: `listAdmin${suffix}`,
      tags: [`Admin ${suffix}`],
      security: [
        { CloudflareAccess: [], Auth0OAuth: ["admin:editorial:read"] },
      ],
      request: { query: editorialListQuerySchema },
      responses: {
        200: {
          description: "Bounded editorial item summaries.",
          content: {
            "application/json": {
              schema: collectionResponse(editorialItemSchema),
            },
          },
        },
        ...errors,
      },
    } as any);
    const createItemRoute = createRoute({
      method: "post",
      path: definition.path,
      operationId: `createAdmin${suffix}`,
      tags: [`Admin ${suffix}`],
      security: [
        { CloudflareAccess: [], Auth0OAuth: ["admin:editorial:write"] },
      ],
      request: {
        headers: idempotencyHeaders,
        body: {
          required: true,
          content: { "application/json": { schema: createBody } },
        },
      },
      responses: {
        201: {
          description: "Stable item and first typed draft.",
          headers: { ETag: { schema: { type: "string" } } },
          content: {
            "application/json": { schema: objectResponse(editorialItemSchema) },
          },
        },
        ...errors,
      },
    } as any);
    const detailRoute = createRoute({
      method: "get",
      path: `${definition.path}/{item_id}`,
      operationId: `getAdmin${suffix}`,
      tags: [`Admin ${suffix}`],
      security: [
        { CloudflareAccess: [], Auth0OAuth: ["admin:editorial:read"] },
      ],
      request: { params: itemParams },
      responses: {
        200: {
          description: "Editorial item and revision summary.",
          content: {
            "application/json": { schema: objectResponse(editorialItemSchema) },
          },
        },
        ...errors,
      },
    } as any);
    const createRevisionRoute = createRoute({
      method: "post",
      path: `${definition.path}/{item_id}/revisions`,
      operationId: `createAdmin${suffix}Revision`,
      tags: [`Admin ${suffix}`],
      security: [
        { CloudflareAccess: [], Auth0OAuth: ["admin:editorial:write"] },
      ],
      request: {
        params: itemParams,
        headers: idempotencyHeaders,
        body: {
          required: true,
          content: { "application/json": { schema: revisionBody } },
        },
      },
      responses: {
        201: {
          description: "New draft preserving the reviewed source revision.",
          content: {
            "application/json": { schema: objectResponse(editorialItemSchema) },
          },
        },
        ...errors,
      },
    } as any);
    const revisionRoute = createRoute({
      method: "get",
      path: `${definition.path}/{item_id}/revisions/{revision_id}`,
      operationId: `getAdmin${suffix}Revision`,
      tags: [`Admin ${suffix}`],
      security: [
        { CloudflareAccess: [], Auth0OAuth: ["admin:editorial:read"] },
      ],
      request: { params: revisionParams },
      responses: {
        200: {
          description: "Typed immutable or draft revision.",
          content: {
            "application/json": {
              schema: objectResponse(editorialRevisionSchema),
            },
          },
        },
        ...errors,
      },
    } as any);
    const patchRevisionRoute = createRoute({
      method: "patch",
      path: `${definition.path}/{item_id}/revisions/{revision_id}`,
      operationId: `patchAdmin${suffix}Revision`,
      tags: [`Admin ${suffix}`],
      security: [
        { CloudflareAccess: [], Auth0OAuth: ["admin:editorial:write"] },
      ],
      request: {
        params: revisionParams,
        headers: etagHeaders,
        body: {
          required: true,
          content: { "application/json": { schema: patchBody } },
        },
      },
      responses: {
        200: {
          description: "Updated draft only.",
          headers: { ETag: { schema: { type: "string" } } },
          content: {
            "application/json": {
              schema: objectResponse(editorialRevisionSchema),
            },
          },
        },
        ...errors,
      },
    } as any);
    const previewRoute = createRoute({
      method: "get",
      path: `${definition.path}/{item_id}/revisions/{revision_id}/preview`,
      operationId: `previewAdmin${suffix}Revision`,
      tags: [`Admin ${suffix}`],
      security: [
        { CloudflareAccess: [], Auth0OAuth: ["admin:editorial:read"] },
      ],
      request: { params: revisionParams },
      responses: {
        200: {
          description: "Production-serializer preview with no public caching.",
          content: {
            "application/json": {
              schema: objectResponse(editorialRevisionSchema),
            },
          },
        },
        ...errors,
      },
    } as any);
    const reviewRequestRoute = createRoute({
      method: "post",
      path: `${definition.path}/{item_id}/revisions/{revision_id}/review-requests`,
      operationId: `requestAdmin${suffix}Review`,
      tags: [`Admin ${suffix}`],
      security: [
        { CloudflareAccess: [], Auth0OAuth: ["admin:editorial:write"] },
      ],
      request: {
        params: revisionParams,
        headers: idempotencyHeaders,
        body: {
          required: true,
          content: { "application/json": { schema: reviewRequestSchema } },
        },
      },
      responses: {
        200: {
          description: "Submitted revision with server-classified trust.",
          content: {
            "application/json": {
              schema: objectResponse(editorialRevisionSchema),
            },
          },
        },
        ...errors,
      },
    } as any);
    const reviewDecisionRoute = createRoute({
      method: "post",
      path: `${definition.path}/{item_id}/revisions/{revision_id}/review-decisions`,
      operationId: `decideAdmin${suffix}Review`,
      tags: [`Admin ${suffix}`],
      security: [
        { CloudflareAccess: [], Auth0OAuth: ["admin:editorial:review"] },
      ],
      request: {
        params: revisionParams,
        headers: idempotencyHeaders,
        body: {
          required: true,
          content: { "application/json": { schema: reviewDecisionSchema } },
        },
      },
      responses: {
        200: {
          description: "Immutable review decision.",
          content: {
            "application/json": {
              schema: objectResponse(editorialRevisionSchema),
            },
          },
        },
        ...errors,
      },
    } as any);
    const publicationRoute = createRoute({
      method: "post",
      path: `${definition.path}/{item_id}/revisions/{revision_id}/publications`,
      operationId: `publishAdmin${suffix}Revision`,
      tags: [`Admin ${suffix}`],
      security: [
        { CloudflareAccess: [], Auth0OAuth: ["admin:editorial:publish"] },
      ],
      request: {
        params: revisionParams,
        headers: idempotencyHeaders,
        body: {
          required: true,
          content: { "application/json": { schema: publicationSchema } },
        },
      },
      responses: {
        200: {
          description: "Atomic publication pointer and immutable event.",
          content: {
            "application/json": { schema: objectResponse(editorialItemSchema) },
          },
        },
        ...errors,
      },
    } as any);
    const withdrawalRoute = createRoute({
      method: "post",
      path: `${definition.path}/{item_id}/withdrawals`,
      operationId: `withdrawAdmin${suffix}`,
      tags: [`Admin ${suffix}`],
      security: [
        { CloudflareAccess: [], Auth0OAuth: ["admin:editorial:publish"] },
      ],
      request: {
        params: itemParams,
        headers: idempotencyHeaders,
        body: {
          required: true,
          content: { "application/json": { schema: withdrawalSchema } },
        },
      },
      responses: {
        200: {
          description: "Emergency withdrawal preserving immutable assignments.",
          content: {
            "application/json": { schema: objectResponse(editorialItemSchema) },
          },
        },
        ...errors,
      },
    } as any);

    for (const [route, method, permission, rate] of [
      [listRoute, "get", "admin:editorial:read", "RL_ADMIN_READ"],
      [createItemRoute, "post", "admin:editorial:write", "RL_ADMIN_WRITE"],
      [detailRoute, "get", "admin:editorial:read", "RL_ADMIN_READ"],
      [createRevisionRoute, "post", "admin:editorial:write", "RL_ADMIN_WRITE"],
      [revisionRoute, "get", "admin:editorial:read", "RL_ADMIN_READ"],
      [patchRevisionRoute, "patch", "admin:editorial:write", "RL_ADMIN_WRITE"],
      [previewRoute, "get", "admin:editorial:read", "RL_ADMIN_READ"],
      [reviewRequestRoute, "post", "admin:editorial:write", "RL_ADMIN_WRITE"],
      [reviewDecisionRoute, "post", "admin:editorial:review", "RL_ADMIN_HIGH"],
      [publicationRoute, "post", "admin:editorial:publish", "RL_ADMIN_HIGH"],
      [withdrawalRoute, "post", "admin:editorial:publish", "RL_ADMIN_HIGH"],
    ] as const)
      for (const middleware of adminSecurity(
        dependencies,
        method,
        permission,
        rate,
      ))
        app.use(route.getRoutingPath(), middleware);

    app.openapi(listRoute, async (context: any) => {
      const staff = context.get("staffPrincipal");
      const repository = repositoryFor(context, dependencies);
      const secret = context.env.CURSOR_SIGNING_KEY;
      if (
        staff === undefined ||
        repository === undefined ||
        secret === undefined
      )
        return unavailable(context);
      const query = context.req.valid("query");
      const scope = `admin-editorial:${definition.kind}:${query.state ?? "all"}:${query.author_staff_id ?? "all"}:${query.search ?? "all"}`;
      try {
        const after = await decodeCursor(secret, scope, query.cursor);
        const page = await repository.list({
          actorStaffId: staff.id,
          kind: definition.kind,
          limit: query.limit,
          ...(query.state === undefined ? {} : { state: query.state }),
          ...(query.author_staff_id === undefined
            ? {}
            : { authorStaffId: query.author_staff_id }),
          ...(query.search === undefined ? {} : { search: query.search }),
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
        return workflowError(context, error);
      }
    });
    app.openapi(createItemRoute, async (context: any) => {
      const staff = context.get("staffPrincipal");
      const repository = repositoryFor(context, dependencies);
      if (staff === undefined || repository === undefined)
        return unavailable(context);
      const body = context.req.valid("json") as Record<string, unknown> & {
        slug: string;
      };
      const { slug, ...payload } = body;
      try {
        return withEtag(
          context,
          await repository.createItem({
            actorStaffId: staff.id,
            kind: definition.kind,
            slug,
            payload,
            requestId: requestIdFrom(context),
            idempotencyKey: context.req.valid("header")["idempotency-key"],
          }),
          201,
        );
      } catch (error) {
        return workflowError(context, error);
      }
    });
    app.openapi(detailRoute, async (context: any) => {
      const staff = context.get("staffPrincipal");
      const repository = repositoryFor(context, dependencies);
      if (staff === undefined || repository === undefined)
        return unavailable(context);
      try {
        const item = await repository.getItem({
          actorStaffId: staff.id,
          kind: definition.kind,
          itemId: context.req.valid("param").item_id,
        });
        if (item === null) throw new EditorialWorkflowError("not_found");
        return withEtag(context, item);
      } catch (error) {
        return workflowError(context, error);
      }
    });
    app.openapi(createRevisionRoute, async (context: any) => {
      const staff = context.get("staffPrincipal");
      const repository = repositoryFor(context, dependencies);
      if (staff === undefined || repository === undefined)
        return unavailable(context);
      const body = context.req.valid("json");
      try {
        return withEtag(
          context,
          await repository.createRevision({
            actorStaffId: staff.id,
            kind: definition.kind,
            itemId: context.req.valid("param").item_id,
            sourceRevisionId: body.source_revision_id,
            payload: body.payload,
            requestId: requestIdFrom(context),
            idempotencyKey: context.req.valid("header")["idempotency-key"],
          }),
          201,
        );
      } catch (error) {
        return workflowError(context, error);
      }
    });
    const revisionRead = async (context: any) => {
      const staff = context.get("staffPrincipal");
      const repository = repositoryFor(context, dependencies);
      if (staff === undefined || repository === undefined)
        return unavailable(context);
      try {
        const params = context.req.valid("param");
        const revision = await repository.getRevision({
          actorStaffId: staff.id,
          kind: definition.kind,
          itemId: params.item_id,
          revisionId: params.revision_id,
        });
        if (revision === null) throw new EditorialWorkflowError("not_found");
        context.header("cache-control", "no-store");
        return withEtag(context, revision);
      } catch (error) {
        return workflowError(context, error);
      }
    };
    app.openapi(revisionRoute, revisionRead);
    app.openapi(previewRoute, revisionRead);
    app.openapi(patchRevisionRoute, async (context: any) => {
      const staff = context.get("staffPrincipal");
      const repository = repositoryFor(context, dependencies);
      if (staff === undefined || repository === undefined)
        return unavailable(context);
      const params = context.req.valid("param");
      try {
        return withEtag(
          context,
          await repository.patchRevision({
            actorStaffId: staff.id,
            kind: definition.kind,
            itemId: params.item_id,
            revisionId: params.revision_id,
            expectedVersion: etagVersion(
              context.req.valid("header")["if-match"],
            ),
            patch: context.req.valid("json").payload,
            requestId: requestIdFrom(context),
          }),
        );
      } catch (error) {
        return workflowError(context, error);
      }
    });
    app.openapi(reviewRequestRoute, async (context: any) => {
      const staff = context.get("staffPrincipal");
      const repository = repositoryFor(context, dependencies);
      if (staff === undefined || repository === undefined)
        return unavailable(context);
      const params = context.req.valid("param");
      const body = context.req.valid("json");
      try {
        return withEtag(
          context,
          await repository.requestReview({
            actorStaffId: staff.id,
            kind: definition.kind,
            itemId: params.item_id,
            revisionId: params.revision_id,
            note: body.note,
            highTrust: definition.highTrust || body.high_trust === true,
            requestId: requestIdFrom(context),
            idempotencyKey: context.req.valid("header")["idempotency-key"],
          }),
        );
      } catch (error) {
        return workflowError(context, error);
      }
    });
    app.openapi(reviewDecisionRoute, async (context: any) => {
      const staff = context.get("staffPrincipal");
      const repository = repositoryFor(context, dependencies);
      if (staff === undefined || repository === undefined)
        return unavailable(context);
      const params = context.req.valid("param");
      const body = context.req.valid("json");
      try {
        return withEtag(
          context,
          await repository.decideReview({
            actorStaffId: staff.id,
            kind: definition.kind,
            itemId: params.item_id,
            revisionId: params.revision_id,
            decision: body.decision,
            reason: body.reason,
            requestId: requestIdFrom(context),
            idempotencyKey: context.req.valid("header")["idempotency-key"],
          }),
        );
      } catch (error) {
        return workflowError(context, error);
      }
    });
    app.openapi(publicationRoute, async (context: any) => {
      const staff = context.get("staffPrincipal");
      const repository = repositoryFor(context, dependencies);
      if (staff === undefined || repository === undefined)
        return unavailable(context);
      const params = context.req.valid("param");
      const body = context.req.valid("json");
      try {
        return withEtag(
          context,
          await repository.publish({
            actorStaffId: staff.id,
            kind: definition.kind,
            itemId: params.item_id,
            revisionId: params.revision_id,
            effectiveAt: body.effective_at,
            reason: body.reason,
            requestId: requestIdFrom(context),
            idempotencyKey: context.req.valid("header")["idempotency-key"],
          }),
        );
      } catch (error) {
        return workflowError(context, error);
      }
    });
    app.openapi(withdrawalRoute, async (context: any) => {
      const staff = context.get("staffPrincipal");
      const repository = repositoryFor(context, dependencies);
      if (staff === undefined || repository === undefined)
        return unavailable(context);
      const body = context.req.valid("json");
      try {
        return withEtag(
          context,
          await repository.withdraw({
            actorStaffId: staff.id,
            kind: definition.kind,
            itemId: context.req.valid("param").item_id,
            reason: body.reason,
            requestId: requestIdFrom(context),
            idempotencyKey: context.req.valid("header")["idempotency-key"],
          }),
        );
      } catch (error) {
        return workflowError(context, error);
      }
    });
  }
}
