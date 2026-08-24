import { createRoute, type OpenAPIHono, z } from "@hono/zod-openapi";

import type { AppEnvironment } from "../../app.ts";
import { objectResponse, errorResponseSchema } from "../../contracts/common.ts";
import { auth0Jwk } from "../../middleware/auth0-jwk.ts";
import { authorizeStaff, cloudflareAccessJwk, requireAdminHost, type StaffResolver } from "../../middleware/cloudflare-access.ts";
import { requirePermission } from "../../middleware/permissions.ts";
import { preAuthRateLimit, staffRateLimit, subjectRateLimit } from "../../middleware/rate-limit.ts";
import { adminBodyLimit, consumerBodyLimit, rejectRequestBody, requestMediaBoundary } from "../../middleware/security-headers.ts";
import { requestIdFrom } from "../../middleware/request-context.ts";
import { createPostgresSessionRepository, type SessionRepository } from "./repository.ts";
import { adminSessionDataSchema, sessionBootstrapDataSchema } from "./schemas.ts";
import { bootstrapSession, SessionAccessDeniedError } from "./service.ts";
import type { HonoJsonWebKey } from "hono/utils/jwt/jws";

const bootstrapResponseSchema = objectResponse(sessionBootstrapDataSchema).openapi("SessionBootstrapResponse");
const adminSessionResponseSchema = objectResponse(adminSessionDataSchema).openapi("AdminSessionResponse");

const bootstrapRoute = createRoute({
  method: "post",
  path: "/v1/session/bootstrap",
  operationId: "bootstrapSession",
  tags: ["Session"],
  security: [{ Auth0OAuth: ["write:self"] }],
  responses: {
    200: { description: "Provision or return the canonical member session.", content: { "application/json": { schema: bootstrapResponseSchema } } },
    401: { description: "Invalid API access token.", content: { "application/json": { schema: errorResponseSchema } } },
    403: { description: "Inactive account or missing permission.", content: { "application/json": { schema: errorResponseSchema } } },
    413: { description: "Request body exceeded the consumer cap.", content: { "application/json": { schema: errorResponseSchema } } },
    415: { description: "Request media type or encoding is unsupported.", content: { "application/json": { schema: errorResponseSchema } } },
    422: { description: "Bootstrap does not accept a request body.", content: { "application/json": { schema: errorResponseSchema } } },
    429: { description: "Rate limited.", content: { "application/json": { schema: errorResponseSchema } } },
    503: { description: "Security dependency unavailable.", content: { "application/json": { schema: errorResponseSchema } } },
  },
});

const adminSessionRoute = createRoute({
  method: "get",
  path: "/v1/admin/session",
  operationId: "getAdminSession",
  tags: ["Admin Session"],
  security: [{
    CloudflareAccess: [],
    Auth0OAuth: ["admin:operations:read"],
  }],
  request: {
    headers: z.object({
      "cf-access-jwt-assertion": z.string().min(1).max(16_384),
    }),
  },
  responses: {
    200: { description: "Verified active staff session.", content: { "application/json": { schema: adminSessionResponseSchema } } },
    401: { description: "Missing or invalid token pair.", content: { "application/json": { schema: errorResponseSchema } } },
    403: { description: "Inactive or unauthorized staff principal.", content: { "application/json": { schema: errorResponseSchema } } },
    404: { description: "Admin route is not exposed on this hostname.", content: { "application/json": { schema: errorResponseSchema } } },
    429: { description: "Rate limited.", content: { "application/json": { schema: errorResponseSchema } } },
    503: { description: "Security dependency unavailable.", content: { "application/json": { schema: errorResponseSchema } } },
  },
});

export type SessionRouteDependencies = {
  auth0Keys?: readonly HonoJsonWebKey[];
  accessKeys?: readonly HonoJsonWebKey[];
  sessionRepository?: SessionRepository;
  resolveStaff?: StaffResolver;
};

export function registerSessionRoutes(
  app: OpenAPIHono<AppEnvironment>,
  dependencies: SessionRouteDependencies = {},
): void {
  app.use(bootstrapRoute.getRoutingPath(), preAuthRateLimit("RL_SENSITIVE"));
  app.use(bootstrapRoute.getRoutingPath(), auth0Jwk(dependencies.auth0Keys));
  app.use(bootstrapRoute.getRoutingPath(), requirePermission("write:self"));
  app.use(bootstrapRoute.getRoutingPath(), subjectRateLimit("RL_SENSITIVE"));
  app.use(bootstrapRoute.getRoutingPath(), requestMediaBoundary);
  app.use(bootstrapRoute.getRoutingPath(), consumerBodyLimit);
  app.use(bootstrapRoute.getRoutingPath(), rejectRequestBody);
  app.openapi(bootstrapRoute, async (context) => {
    const principal = context.get("authPrincipal");
    const repository = dependencies.sessionRepository
      ?? (context.env.BOOTSTRAP_DATABASE_URL === undefined
        ? undefined
        : createPostgresSessionRepository(context.env.BOOTSTRAP_DATABASE_URL));
    if (principal === undefined || repository === undefined) {
      return context.json({ error: {
        code: "service_unavailable",
        message: "Session provisioning is unavailable.",
        request_id: requestIdFrom(context),
        field_errors: [],
        retryable: true,
      } }, 503);
    }
    try {
      const data = await bootstrapSession(repository, principal.subject);
      return context.json({ data, meta: { request_id: requestIdFrom(context) } }, 200);
    } catch (error) {
      if (error instanceof SessionAccessDeniedError) {
        return context.json({ error: {
          code: "account_inactive",
          message: "The account is not active.",
          request_id: requestIdFrom(context),
          field_errors: [],
          retryable: false,
        } }, 403);
      }
      return context.json({ error: {
        code: "service_unavailable",
        message: "Session provisioning is temporarily unavailable.",
        request_id: requestIdFrom(context),
        field_errors: [],
        retryable: true,
      } }, 503);
    }
  });

  app.use(adminSessionRoute.getRoutingPath(), requireAdminHost);
  app.use(adminSessionRoute.getRoutingPath(), preAuthRateLimit("RL_ADMIN_READ"));
  app.use(adminSessionRoute.getRoutingPath(), requestMediaBoundary);
  app.use(adminSessionRoute.getRoutingPath(), adminBodyLimit);
  app.use(adminSessionRoute.getRoutingPath(), cloudflareAccessJwk(dependencies.accessKeys));
  app.use(adminSessionRoute.getRoutingPath(), auth0Jwk(dependencies.auth0Keys));
  app.use(adminSessionRoute.getRoutingPath(), requirePermission("admin:operations:read"));
  app.use(adminSessionRoute.getRoutingPath(), authorizeStaff(dependencies.resolveStaff));
  app.use(adminSessionRoute.getRoutingPath(), staffRateLimit("RL_ADMIN_READ"));
  app.openapi(adminSessionRoute, (context) => {
    const staff = context.get("staffPrincipal");
    if (staff === undefined) {
      return context.json({ error: {
        code: "forbidden",
        message: "An active staff principal is required.",
        request_id: requestIdFrom(context),
        field_errors: [],
        retryable: false,
      } }, 403);
    }
    return context.json({
      data: { staff_id: staff.id, display_label: staff.displayLabel },
      meta: { request_id: requestIdFrom(context) },
    }, 200);
  });
}
