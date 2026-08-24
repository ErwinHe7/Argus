import { createRoute, type OpenAPIHono, z } from "@hono/zod-openapi";

import type { AppEnvironment } from "../../app.ts";
import {
  collectionResponse,
  errorResponseSchema,
  objectResponse,
} from "../../contracts/common.ts";
import {
  memberSecurity,
  type MemberRouteDependencies,
} from "../accounts/access.ts";
import { currentMember } from "../u7-support.ts";
import { requestIdFrom } from "../../middleware/request-context.ts";
import {
  decodeCursor,
  encodeCursor,
  InvalidCursorError,
} from "../editorial/cursor.ts";
import {
  createPostgresBriefingRepository,
  type BriefingRepository,
} from "./repository.ts";
import { readDailyBriefing } from "./service.ts";
import {
  briefingDetailSchema,
  briefingReadStateSchema,
  briefingSummarySchema,
} from "./schemas.ts";

const errors = {
  401: {
    description: "Authentication required.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  403: {
    description: "Permission denied.",
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
    description: "Rate limited.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
  503: {
    description: "Temporarily unavailable.",
    content: { "application/json": { schema: errorResponseSchema } },
  },
} as const;
const params = z.object({ briefing_id: z.string().uuid() }).strict();
const listQuery = z
  .object({
    type: z.enum(["daily", "weekly", "moon_cycle"]).optional(),
    period_start: z.string().date().optional(),
    period_end: z.string().date().optional(),
    limit: z.coerce.number().int().min(1).max(50).default(20),
    cursor: z.string().min(1).max(2048).optional(),
  })
  .strict()
  .refine(
    (value) =>
      value.period_start === undefined ||
      value.period_end === undefined ||
      value.period_start <= value.period_end,
    {
      path: ["period_end"],
      message: "period_end must not precede period_start",
    },
  );
const briefingPendingSchema = z
  .object({
    status: z.literal("briefing_pending"),
    local_date: z.string().date(),
  })
  .strict();
const listRoute = createRoute({
  method: "get",
  path: "/v1/briefings",
  operationId: "listBriefings",
  tags: ["Briefings"],
  security: [{ Auth0OAuth: ["read:self"] }],
  request: { query: listQuery },
  responses: {
    200: {
      description: "Bounded immutable current briefings.",
      content: {
        "application/json": {
          schema: collectionResponse(briefingSummarySchema),
        },
      },
    },
    ...errors,
  },
});
const dailyRoute = createRoute({
  method: "get",
  path: "/v1/briefings/daily",
  operationId: "getDailyBriefing",
  tags: ["Briefings"],
  security: [{ Auth0OAuth: ["read:self"] }],
  request: {
    query: z.object({ local_date: z.string().date().optional() }).strict(),
  },
  responses: {
    200: {
      description:
        "Already-generated Daily briefing; this read never generates content.",
      content: {
        "application/json": { schema: objectResponse(briefingDetailSchema) },
      },
    },
    202: {
      description:
        "Daily briefing generation remains queued; this GET performs no generation.",
      content: {
        "application/json": { schema: objectResponse(briefingPendingSchema) },
      },
    },
    ...errors,
  },
});
const detailRoute = createRoute({
  method: "get",
  path: "/v1/briefings/{briefing_id}",
  operationId: "getBriefing",
  tags: ["Briefings"],
  security: [{ Auth0OAuth: ["read:self"] }],
  request: { params },
  responses: {
    200: {
      description: "Immutable briefing detail.",
      content: {
        "application/json": { schema: objectResponse(briefingDetailSchema) },
      },
    },
    ...errors,
  },
});
const readRoute = createRoute({
  method: "put",
  path: "/v1/briefings/{briefing_id}/read-state",
  operationId: "setBriefingReadState",
  tags: ["Briefings"],
  security: [{ Auth0OAuth: ["write:self"] }],
  request: {
    params,
    body: {
      required: true,
      content: { "application/json": { schema: briefingReadStateSchema } },
    },
  },
  responses: {
    200: {
      description: "Updated member read state only.",
      content: {
        "application/json": { schema: objectResponse(briefingSummarySchema) },
      },
    },
    ...errors,
  },
});

export type BriefingRouteDependencies = MemberRouteDependencies & {
  briefingRepository?: BriefingRepository;
};

export function registerBriefingRoutes(
  app: OpenAPIHono<AppEnvironment>,
  dependencies: BriefingRouteDependencies = {},
) {
  const access = (
    context: Parameters<Parameters<typeof app.openapi>[1]>[0],
  ) => ({
    member: currentMember(context),
    repository:
      dependencies.briefingRepository ??
      (context.env.RUNTIME_DATABASE_URL === undefined
        ? undefined
        : createPostgresBriefingRepository(context.env.RUNTIME_DATABASE_URL)),
  });
  for (const middleware of memberSecurity(dependencies, false, "get")) {
    app.use("/v1/briefings", middleware);
    app.use("/v1/briefings/*", middleware);
  }
  for (const middleware of memberSecurity(dependencies, true, "put"))
    app.use(readRoute.getRoutingPath(), middleware);
  app.openapi(listRoute, (async (context: any) => {
    const { member, repository } = access(context);
    if (member === undefined || repository === undefined)
      return context.json(
        {
          error: {
            code: "service_unavailable",
            message: "Briefings are unavailable.",
            request_id: requestIdFrom(context),
            field_errors: [],
            retryable: true,
          },
        },
        503,
      );
    const secret = context.env.CURSOR_SIGNING_KEY;
    if (secret === undefined)
      return context.json(
        {
          error: {
            code: "service_unavailable",
            message: "Briefings are unavailable.",
            request_id: requestIdFrom(context),
            field_errors: [],
            retryable: true,
          },
        },
        503,
      );
    const query = context.req.valid("query");
    const scope = `briefings:${member.tenantId}:${query.type ?? "all"}:${query.period_start ?? "open"}:${query.period_end ?? "open"}`;
    try {
      const after = await decodeCursor(secret, scope, query.cursor);
      const [afterPeriod, afterId] = after?.split("|") ?? [];
      if (
        after !== undefined &&
        (afterPeriod === undefined || afterId === undefined)
      )
        throw new InvalidCursorError();
      const page = await repository.list(member, {
        limit: query.limit,
        ...(query.type === undefined ? {} : { type: query.type }),
        ...(query.period_start === undefined
          ? {}
          : { periodStart: query.period_start }),
        ...(query.period_end === undefined
          ? {}
          : { periodEnd: query.period_end }),
        ...(afterPeriod === undefined
          ? {}
          : { afterPeriod, afterId: afterId! }),
      });
      const nextCursor =
        page.next === null
          ? null
          : await encodeCursor(
              secret,
              scope,
              `${page.next.period}|${page.next.id}`,
            );
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
  app.openapi(dailyRoute, (async (context: any) => {
    const { member, repository } = access(context);
    if (member === undefined || repository === undefined)
      return context.json(
        {
          error: {
            code: "service_unavailable",
            message: "Briefings are unavailable.",
            request_id: requestIdFrom(context),
            field_errors: [],
            retryable: true,
          },
        },
        503,
      );
    const localDate =
      context.req.valid("query").local_date ??
      new Date().toISOString().slice(0, 10);
    const data = await readDailyBriefing(repository, member, localDate);
    return data === null
      ? context.json(
          {
            data: { status: "briefing_pending", local_date: localDate },
            meta: { request_id: requestIdFrom(context) },
          },
          202,
        )
      : context.json(
          { data, meta: { request_id: requestIdFrom(context) } },
          200,
        );
  }) as never);
  app.openapi(detailRoute, (async (context: any) => {
    const { member, repository } = access(context);
    if (member === undefined || repository === undefined)
      return context.json(
        {
          error: {
            code: "service_unavailable",
            message: "Briefings are unavailable.",
            request_id: requestIdFrom(context),
            field_errors: [],
            retryable: true,
          },
        },
        503,
      );
    const data = await repository.get(
      member,
      context.req.valid("param").briefing_id,
    );
    return data === null
      ? context.json(
          {
            error: {
              code: "not_found",
              message: "Briefing not found.",
              request_id: requestIdFrom(context),
              field_errors: [],
              retryable: false,
            },
          },
          404,
        )
      : context.json(
          { data, meta: { request_id: requestIdFrom(context) } },
          200,
        );
  }) as never);
  app.openapi(readRoute, (async (context: any) => {
    const { member, repository } = access(context);
    if (member === undefined || repository === undefined)
      return context.json(
        {
          error: {
            code: "service_unavailable",
            message: "Briefings are unavailable.",
            request_id: requestIdFrom(context),
            field_errors: [],
            retryable: true,
          },
        },
        503,
      );
    const data = await repository.markRead(
      member,
      context.req.valid("param").briefing_id,
      context.req.valid("json").read,
    );
    return data === null
      ? context.json(
          {
            error: {
              code: "not_found",
              message: "Briefing not found.",
              request_id: requestIdFrom(context),
              field_errors: [],
              retryable: false,
            },
          },
          404,
        )
      : context.json(
          { data, meta: { request_id: requestIdFrom(context) } },
          200,
        );
  }) as never);
}
