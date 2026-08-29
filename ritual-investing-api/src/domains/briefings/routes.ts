import { z } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { BriefingRepository } from "./ports.ts";
import {
  briefingCollectionResponseSchema,
  briefingDetailResponseSchema,
  briefingPendingResponseSchema,
  briefingSummarySchema,
} from "../content/schemas.ts";
import {
  cursorFilterIdentity,
  keysetPage,
  pagedContentQuery,
  typedKeysetPosition,
} from "../content/pagination.ts";
import {
  contentRecord,
  presentBriefingDetail,
  presentBriefingSummary,
} from "../content/service.ts";
import {
  collectionDataResponse,
  dataResponse,
  HttpBoundaryError,
  parseBody,
  query,
  retainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";
import {
  pageLimitSchema,
  retainedEnvelope,
  uuidSchema,
} from "../retained-http/schemas.ts";
import type { RetainedAppEnvironment } from "../retained-http/types.ts";

export type BriefingRouteRepository = BriefingRepository;

export function registerBriefingRoutes(
  input: Readonly<{
    register: RetainedRouteRegistrar;
    repository: (
      context: Context<RetainedAppEnvironment>,
    ) => BriefingRouteRepository;
  }>,
): void {
  const listBriefings = retainedRoute(
    "get",
    "/v1/briefings",
    "listBriefings",
    "Briefings",
    {
      query: z.object({
        type: z.enum(["daily", "weekly", "moon_cycle"]).optional(),
        period_start: z.string().date().optional(),
        period_end: z.string().date().optional(),
        cursor: pagedContentQuery.shape.cursor,
        limit: pageLimitSchema.optional(),
      }),
      response: briefingCollectionResponseSchema,
    },
  );
  input.register(listBriefings, async (context) => {
    const request = z.object({
      type: z.enum(["daily", "weekly", "moon_cycle"]).optional(),
      period_start: z.string().date().optional(),
      period_end: z.string().date().optional(),
      cursor: pagedContentQuery.shape.cursor,
      limit: pageLimitSchema,
    }).parse(query(context));
    const baseBinding = {
      resource: "briefings:list:v1",
      scope: "member",
      verifiedSubject: context.get("claims").userId,
      filterIdentity: cursorFilterIdentity({
        type: request.type,
        period_start: request.period_start,
        period_end: request.period_end,
      }),
      pageSize: request.limit,
    } as const;
    const binding = request.cursor === undefined
      ? baseBinding
      : { ...baseBinding, cursor: request.cursor };
    const after = await typedKeysetPosition(
      binding,
      z.tuple([z.string().date(), uuidSchema]),
    );
    const rows = await input.repository(context).listPage({
      limit: request.limit + 1,
      type: request.type,
      periodStart: request.period_start,
      periodEnd: request.period_end,
      after,
    });
    const page = await keysetPage(binding, rows, (row) => {
      const briefing = contentRecord(row);
      return [String(briefing.period_end), String(briefing.id)];
    });
    return collectionDataResponse(
      context,
      page.items.map(presentBriefingSummary),
      page.nextCursor,
    );
  });

  const getDaily = retainedRoute(
    "get",
    "/v1/briefings/daily",
    "getDailyBriefing",
    "Briefings",
    {
      query: z.object({ local_date: z.string().date().optional() }),
      response: briefingDetailResponseSchema,
      acceptedResponse: briefingPendingResponseSchema,
    },
  );
  input.register(getDaily, async (context) => {
    const localDate = context.req.query("local_date") ??
      new Date().toISOString().slice(0, 10);
    const value = await input.repository(context).daily(localDate);
    if (value === null || contentRecord(value).status !== "ready") {
      return context.json(
        {
          data: { status: "briefing_pending", local_date: localDate },
          meta: { request_id: context.get("requestId") },
        },
        202,
      );
    }
    return dataResponse(context, presentBriefingDetail(value));
  });

  const briefingPath = z.object({ briefing_id: uuidSchema });
  const getBriefing = retainedRoute(
    "get",
    "/v1/briefings/{briefing_id}",
    "getBriefing",
    "Briefings",
    { pathParams: briefingPath, response: briefingDetailResponseSchema },
  );
  input.register(getBriefing, async (context) => {
    const value = await input.repository(context).get(
      uuidSchema.parse(context.req.param("briefing_id")),
    );
    return dataResponse(
      context,
      value === null ? null : presentBriefingDetail(value),
    );
  });

  const readBody = z.object({ read: z.boolean() }).strict()
    .openapi("SetBriefingReadStateRequest");
  const setReadState = retainedRoute(
    "put",
    "/v1/briefings/{briefing_id}/read-state",
    "setBriefingReadState",
    "Briefings",
    {
      pathParams: briefingPath,
      body: readBody,
      response: retainedEnvelope(
        "BriefingSummaryResponse",
        briefingSummarySchema,
      ),
    },
  );
  input.register(setReadState, async (context) => {
    const body = await parseBody(context, readBody);
    return dataResponse(
      context,
      presentBriefingSummary(
        await input.repository(context).setRead(
          uuidSchema.parse(context.req.param("briefing_id")),
          body.read,
        ),
      ),
    );
  });
}
