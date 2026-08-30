import { OpenAPIHono } from "@hono/zod-openapi";
import type { Context, MiddlewareHandler } from "hono";

import type { VerifiedRequestClaims } from "./db/request-claims.ts";
import {
  RepositoryNotFoundError,
  RepositoryRevisionConflictError,
  RepositoryStepUpRequiredError,
} from "./db/repository-support.ts";
import { StaffAuthorizationError } from "./db/request-transaction.ts";
import type { RateLimitPort } from "./ports/infrastructure.ts";
import {
  type AccountRouteRepository,
  registerAccountMutationRoutes,
  registerAccountReadRoute,
} from "./domains/accounts/routes.ts";
import {
  type AdminOperationsRouteService,
  type AdminRouteRepository,
  registerAdminRoutes,
} from "./domains/admin/routes.ts";
import {
  type AssetRouteRepository,
  registerAssetRoutes,
} from "./domains/assets/routes.ts";
import {
  type BriefingRouteRepository,
  registerBriefingRoutes,
} from "./domains/briefings/routes.ts";
import {
  type BrokerageConnectionRouteService,
  registerBrokerageRoutes,
} from "./domains/brokerage/routes.ts";
import {
  mapBrokerageConnectionBoundaryError,
} from "./domains/brokerage-connections/error-mapping.ts";
import { BrokerageProjectionError } from "./domains/brokerage-projections/types.ts";
import type { BrokerageProjectionService } from "./domains/brokerage-projections/service.ts";
import { BrokerageOrderError } from "./domains/brokerage-orders/types.ts";
import type { BrokerageOrderService } from "./domains/brokerage-orders/service.ts";
import {
  type CircleRouteRepository,
  registerCircleRoutes,
} from "./domains/circles/routes.ts";
import {
  type CovenRouteRepository,
  registerCovenRoutes,
} from "./domains/coven/routes.ts";
import {
  type DiscoverRouteRepository,
  registerDiscoverRoutes,
} from "./domains/discover/routes.ts";
import {
  type EditorialRouteRepository,
  registerEditorialRoutes,
} from "./domains/editorial/routes.ts";
import {
  type IntentionRouteRepository,
  registerIntentionRoutes,
} from "./domains/intentions/routes.ts";
import { mapScenarioBoundaryError } from "./domains/intentions/error-mapping.ts";
import {
  type MediaRouteRepository,
  registerMediaRoutes,
} from "./domains/media/routes.ts";
import {
  type ModerationRouteRepository,
  registerModerationRoutes,
} from "./domains/moderation/routes.ts";
import {
  type NotificationRouteRepository,
  registerNotificationRoutes,
} from "./domains/notifications/routes.ts";
import { registerPlatformRoutes } from "./domains/platform/routes.ts";
import { createPlatformContractService } from "./domains/platform/service.ts";
import {
  type PrivacyRouteService,
  registerPrivacyRoutes,
} from "./domains/privacy/routes.ts";
import {
  type PublicPreviewRouteRepository,
  registerPublicPreviewRoutes,
} from "./domains/public-preview/routes.ts";
import {
  bearerToken,
  claimsFrom,
  digest,
  errorResponse,
  HttpBoundaryError,
  mountRetainedRoute,
  normalizedRoute,
  retainedRouteAccess,
  type RetainedRouteRegistrar,
  type RetainedTransactionPolicy,
} from "./domains/retained-http/boundary.ts";
import type {
  RetainedAppEnvironment,
  RetainedRuntimeBindings,
  RetainedTelemetryEvent,
  VerifiedSupabasePrincipal,
} from "./domains/retained-http/types.ts";
import {
  registerRitualRoutes,
  type RitualRouteRepository,
} from "./domains/rituals/routes.ts";
import {
  registerRowanRoutes,
  type RowanRouteRepository,
} from "./domains/rowan/routes.ts";
import { registerSearchRoutes } from "./domains/search/routes.ts";
import type { SearchRepository } from "./domains/search/ports.ts";
import { registerSessionRoutes } from "./domains/session/routes.ts";
import {
  createSessionService,
  type SessionServiceRepository,
} from "./domains/session/service.ts";

export type {
  RetainedAppEnvironment,
  RetainedRuntimeBindings,
  RetainedTelemetryEvent,
  VerifiedSupabasePrincipal,
} from "./domains/retained-http/types.ts";

export type RetainedRepositorySet = Readonly<{
  session: SessionServiceRepository;
  accounts: AccountRouteRepository;
  assets: AssetRouteRepository;
  editorial: EditorialRouteRepository;
  briefings: BriefingRouteRepository;
  circles: CircleRouteRepository;
  coven: CovenRouteRepository;
  discover: DiscoverRouteRepository;
  media: MediaRouteRepository;
  moderation: ModerationRouteRepository;
  notifications: NotificationRouteRepository;
  rituals: RitualRouteRepository;
  rowan: RowanRouteRepository;
  search: SearchRepository;
  admin: AdminRouteRepository;
  adminOperations: AdminOperationsRouteService;
  scenarios: IntentionRouteRepository;
}>;

export type PublicPreviewRepository = PublicPreviewRouteRepository;

export type RetainedTokenVerifier = (
  token: string,
) => Promise<VerifiedSupabasePrincipal>;

export type CreateRetainedAppOptions = Readonly<{
  verifyAccessToken: RetainedTokenVerifier;
  withRepositories<T>(
    claims: VerifiedRequestClaims,
    transaction: Exclude<
      RetainedTransactionPolicy,
      "none" | "public-preview"
    >,
    callback: (repositories: RetainedRepositorySet) => Promise<T>,
  ): Promise<T>;
  withPublicPreview<T>(
    callback: (repository: PublicPreviewRepository) => Promise<T>,
  ): Promise<T>;
  createPrivacyService: (claims: VerifiedRequestClaims) => PrivacyRouteService;
  rateLimit: RateLimitPort;
  createBrokerageConnections?: (
    claims: VerifiedRequestClaims,
  ) => BrokerageConnectionRouteService;
  createBrokerageProjections?: (
    claims: VerifiedRequestClaims,
  ) => BrokerageProjectionService;
  createBrokerageOrders?: (
    claims: VerifiedRequestClaims,
  ) => BrokerageOrderService;
  requestId?: () => string;
  telemetry?: (event: RetainedTelemetryEvent) => void | Promise<void>;
}>;

const requestIdPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function repositories(
  context: Context<RetainedAppEnvironment>,
): RetainedRepositorySet {
  return context.get("repositorySet") as RetainedRepositorySet;
}

function publicPreviewRepository(
  context: Context<RetainedAppEnvironment>,
): PublicPreviewRepository {
  return context.get("publicPreviewRepository") as PublicPreviewRepository;
}

export function buildRetainedOpenApiDocument(
  app: OpenAPIHono<RetainedAppEnvironment>,
) {
  const document = app.getOpenAPIDocument({
    openapi: "3.0.3",
    info: {
      title: "Argus API",
      version: "2.0.0",
      description:
        "Supabase Edge contract for Argus-owned member, editorial, privacy, and staff data. Brokerage routes are added only after the Webull protocol gate.",
    },
    servers: [
      { url: "https://PROJECT_REF.supabase.co/functions/v1/api" },
    ],
  });
  document.components = {
    ...document.components,
    securitySchemes: {
      SupabaseBearer: {
        type: "http",
        scheme: "bearer",
        bearerFormat: "JWT",
        description:
          "Supabase Auth access token verified by signature, issuer, audience, expiry, session, role, and AAL at the Edge boundary.",
      },
    },
  };
  return document;
}

export function createRetainedApp(options: CreateRetainedAppOptions) {
  const app = new OpenAPIHono<RetainedAppEnvironment>({
    defaultHook: (result) => {
      if (!result.success) {
        throw new HttpBoundaryError(
          422,
          "validation_failed",
          "The request failed validation.",
        );
      }
    },
  });

  const requestContext: MiddlewareHandler<RetainedAppEnvironment> = async (
    context,
    next,
  ) => {
    const incoming = context.req.header("x-request-id");
    const requestId = incoming !== undefined && requestIdPattern.test(incoming)
      ? incoming
      : (options.requestId?.() ?? crypto.randomUUID());
    context.set("requestId", requestId);
    context.header("x-request-id", requestId);
    const startedAt = performance.now();
    await next();
    context.header("x-content-type-options", "nosniff");
    context.header("x-frame-options", "DENY");
    context.header("referrer-policy", "no-referrer");
    if (context.req.header("authorization") !== undefined) {
      context.header("cache-control", "private, no-store");
    }
    try {
      await options.telemetry?.({
        event: "http.request",
        requestId,
        method: context.req.method,
        route: normalizedRoute(context.req.path),
        status: context.res.status,
        latencyMs: Math.round(performance.now() - startedAt),
      });
    } catch {
      // Telemetry is deliberately best-effort. A failed sink must never replace
      // an already-computed response or expose sink details to the caller.
    }
  };
  app.use("*", requestContext);

  const exactOriginCors: MiddlewareHandler<RetainedAppEnvironment> = async (
    context,
    next,
  ) => {
    const origin = context.req.header("origin");
    const allowedOrigins = context.req.path.startsWith("/v1/admin/")
      ? [context.env.adminOrigin]
      : context.env.consumerOrigins;
    const matchedOrigin = origin !== undefined && allowedOrigins.includes(origin)
      ? origin
      : undefined;
    if (origin !== undefined && matchedOrigin === undefined) {
      throw new HttpBoundaryError(
        403,
        "origin_denied",
        "The request origin is not allowed.",
      );
    }
    if (matchedOrigin !== undefined) {
      context.header("access-control-allow-origin", matchedOrigin);
      context.header(
        "access-control-allow-methods",
        "GET, POST, PUT, PATCH, DELETE, OPTIONS",
      );
      context.header(
        "access-control-allow-headers",
        "authorization, content-type, if-match, idempotency-key, x-request-id",
      );
      context.header(
        "access-control-expose-headers",
        "content-disposition, content-length, etag, retry-after, x-content-sha256, x-request-id",
      );
      context.header("access-control-max-age", "600");
      context.header("vary", "origin");
    }
    if (context.req.method === "OPTIONS") {
      context.res = context.body(null, 204);
      return;
    }
    await next();
  };
  app.use("*", exactOriginCors);

  const webOriginBoundary: MiddlewareHandler<RetainedAppEnvironment> = async (
    context,
    next,
  ) => {
    const origin = context.req.header("origin");
    const isConsumerWebRequest = origin !== undefined &&
      context.env.consumerOrigins.includes(origin) &&
      !context.req.path.startsWith("/v1/admin/");
    if (!isConsumerWebRequest) {
      await next();
      return;
    }

    const path = context.req.path;
    const isPrivacyCapability = path.startsWith("/v1/privacy/") ||
      path === "/v1/member/step-up";
    const sensitiveCapability = path.startsWith("/v1/brokerage/");
    if (sensitiveCapability) {
      throw new HttpBoundaryError(
        503,
        "web_capability_unavailable",
        "This capability is not available on the public beta website.",
      );
    }

    const isMutation = ["POST", "PUT", "PATCH", "DELETE"].includes(
      context.req.method,
    );
    if (
      context.env.webAdmission === "contained" &&
      (path === "/v1/session/bootstrap" ||
        (isMutation && !isPrivacyCapability))
    ) {
      throw new HttpBoundaryError(
        503,
        "web_admission_closed",
        "Public beta web traffic is temporarily contained.",
        true,
      );
    }
    await next();
  };
  app.use("*", webOriginBoundary);

  const enforceJsonBoundary: MiddlewareHandler<RetainedAppEnvironment> = async (
    context,
    next,
  ) => {
    if (context.req.raw.body !== null) {
      const declaredSize = Number(context.req.header("content-length"));
      if (Number.isFinite(declaredSize) && declaredSize > 65_536) {
        throw new HttpBoundaryError(
          413,
          "payload_too_large",
          "The request body exceeds the allowed size.",
        );
      }
      const copy = await context.req.raw.clone().arrayBuffer();
      if (copy.byteLength > 65_536) {
        throw new HttpBoundaryError(
          413,
          "payload_too_large",
          "The request body exceeds the allowed size.",
        );
      }
      if (copy.byteLength > 0) {
        const contentType = context.req.header("content-type")
          ?.split(";", 1)[0]
          ?.trim()
          .toLowerCase();
        if (contentType !== "application/json") {
          throw new HttpBoundaryError(
            415,
            "unsupported_media_type",
            "JSON requests require application/json.",
          );
        }
      }
    }
    await next();
  };
  app.use("*", enforceJsonBoundary);

  const authenticate: MiddlewareHandler<RetainedAppEnvironment> = async (
    context,
    next,
  ) => {
    const token = bearerToken(context.req.header("authorization"));
    if (token === null) {
      throw new HttpBoundaryError(
        401,
        "unauthorized",
        "A valid Supabase access token is required.",
      );
    }
    try {
      const principal = Object.freeze(await options.verifyAccessToken(token));
      context.set("principal", principal);
      context.set("claims", claimsFrom(principal));
    } catch {
      throw new HttpBoundaryError(
        401,
        "unauthorized",
        "A valid Supabase access token is required.",
      );
    }
    await next();
  };

  const enforceRateLimit: MiddlewareHandler<RetainedAppEnvironment> = async (
    context,
    next,
  ) => {
    const principal = context.get("principal");
    const scope = await digest(
      [
        principal?.userId ?? "public",
        context.req.method,
        normalizedRoute(context.req.path),
      ].join("\u001f"),
    );
    try {
      const outcome = await options.rateLimit.allow(scope, {
        limit: principal === undefined ? 120 : 240,
        windowSeconds: 60,
      });
      if (!outcome.allowed) {
        throw new HttpBoundaryError(
          429,
          "rate_limited",
          "The request rate limit was exceeded.",
          true,
          outcome.retryAfterSeconds ?? 60,
        );
      }
    } catch (error) {
      if (error instanceof HttpBoundaryError) throw error;
      throw new HttpBoundaryError(
        503,
        "service_unavailable",
        "The request rate limit could not be checked.",
        true,
      );
    }
    await next();
  };

  const requireAal2: MiddlewareHandler<RetainedAppEnvironment> = async (
    context,
    next,
  ) => {
    if (context.get("principal")?.aal !== "aal2") {
      throw new HttpBoundaryError(
        403,
        "aal2_required",
        "A current AAL2 staff session is required.",
      );
    }
    await next();
  };

  app.onError((error, context) => {
    if (error instanceof HttpBoundaryError) {
      return errorResponse(context, error);
    }
    if (error instanceof RepositoryNotFoundError) {
      return errorResponse(
        context,
        new HttpBoundaryError(
          404,
          "not_found",
          "The requested resource was not found.",
        ),
      );
    }
    if (error instanceof RepositoryRevisionConflictError) {
      return errorResponse(
        context,
        new HttpBoundaryError(
          409,
          "revision_conflict",
          "The resource changed. Refresh before retrying.",
        ),
      );
    }
    if (error instanceof RepositoryStepUpRequiredError) {
      return errorResponse(
        context,
        new HttpBoundaryError(
          403,
          "step_up_required",
          "A current action-bound authorization is required.",
        ),
      );
    }
    const scenarioError = mapScenarioBoundaryError(error);
    if (scenarioError !== undefined) {
      return errorResponse(context, scenarioError);
    }
    if (error instanceof StaffAuthorizationError) {
      return errorResponse(
        context,
        new HttpBoundaryError(
          403,
          "forbidden",
          "Current staff authorization is required.",
        ),
      );
    }
    const connectionError = mapBrokerageConnectionBoundaryError(error);
    if (connectionError !== undefined) {
      return errorResponse(context, connectionError);
    }
    if (error instanceof BrokerageProjectionError) {
      const notFound = error.code === "account_not_found";
      return errorResponse(
        context,
        new HttpBoundaryError(
          notFound ? 404 : 503,
          notFound ? "account_not_found" : "brokerage_reads_unavailable",
          notFound
            ? "The requested brokerage resource was not found."
            : "Brokerage data is temporarily unavailable.",
          !notFound,
        ),
      );
    }
    if (error instanceof BrokerageOrderError) {
      const notFound = [
        "account_not_found",
        "order_not_found",
        "command_not_found",
      ]
        .includes(error.code);
      const conflict = [
        "idempotency_conflict",
        "account_command_blocked",
        "preview_replayed",
        "preview_mismatch",
      ].includes(error.code);
      const unavailable = error.code === "provider_contract_unavailable";
      return errorResponse(
        context,
        new HttpBoundaryError(
          notFound ? 404 : conflict ? 409 : unavailable ? 503 : 422,
          error.code,
          notFound
            ? "The requested brokerage order resource was not found."
            : conflict
            ? "The financial command conflicts with existing or reviewed state."
            : unavailable
            ? "Brokerage order execution is temporarily unavailable."
            : "Current brokerage authority does not permit this order action.",
          unavailable,
        ),
      );
    }
    return errorResponse(
      context,
      new HttpBoundaryError(
        503,
        "service_unavailable",
        "The request could not be completed.",
        true,
      ),
    );
  });
  app.notFound((context) =>
    errorResponse(
      context,
      new HttpBoundaryError(
        404,
        "not_found",
        "The requested resource was not found.",
      ),
    )
  );

  const middlewareByPath = new Map<
    string,
    Readonly<{ isPublic: boolean; isAdmin: boolean }>
  >();
  const register: RetainedRouteRegistrar = (
    definition,
    handler,
  ) => {
    const routingPath = definition.getRoutingPath();
    const access = retainedRouteAccess(definition);
    if (access === undefined || (access.isPublic && access.isAdmin)) {
      throw new Error("invalid_route_access_classification");
    }
    const existingAccess = middlewareByPath.get(routingPath);
    if (existingAccess !== undefined) {
      if (
        existingAccess.isPublic !== access.isPublic ||
        existingAccess.isAdmin !== access.isAdmin
      ) {
        throw new Error("inconsistent_route_access_classification");
      }
    } else {
      if (!access.isPublic) app.use(routingPath, authenticate);
      if (access.isAdmin) app.use(routingPath, requireAal2);
      app.use(routingPath, enforceRateLimit);
      middlewareByPath.set(routingPath, access);
    }
    if (access.isAdmin && access.transaction === "member") {
      throw new Error("admin_route_transaction_unclassified");
    }
    if (
      access.isPublic && access.transaction !== "none" &&
      access.transaction !== "public-preview"
    ) {
      throw new Error("public_route_transaction_invalid");
    }
    let scopedHandler: Parameters<RetainedRouteRegistrar>[1];
    if (access.transaction === "none") {
      scopedHandler = handler;
    } else if (access.transaction === "public-preview") {
      scopedHandler = (context) =>
        options.withPublicPreview(async (repository) => {
          context.set("publicPreviewRepository", repository);
          return handler(context);
        });
    } else {
      const transaction = access.transaction;
      scopedHandler = (context) =>
        options.withRepositories(
          context.get("claims"),
          transaction,
          async (repositorySet) => {
            context.set("repositorySet", repositorySet);
            return handler(context);
          },
        );
    }
    mountRetainedRoute(app, definition, scopedHandler);
  };

  registerPlatformRoutes({
    register,
    contract: createPlatformContractService(() =>
      buildRetainedOpenApiDocument(app)
    ),
  });

  registerSessionRoutes({
    register,
    service: (context) => createSessionService(repositories(context).session),
  });

  registerBrokerageRoutes({
    register,
    ...(options.createBrokerageConnections === undefined
      ? {}
      : { createConnections: options.createBrokerageConnections }),
    ...(options.createBrokerageProjections === undefined
      ? {}
      : { createProjections: options.createBrokerageProjections }),
    ...(options.createBrokerageOrders === undefined
      ? {}
      : { createOrders: options.createBrokerageOrders }),
  });

  registerAccountReadRoute({
    register,
    repository: (context) => repositories(context).accounts,
  });

  registerIntentionRoutes({
    register,
    repository: (context) => repositories(context).scenarios,
  });

  registerAccountMutationRoutes({
    register,
    repository: (context) => repositories(context).accounts,
  });

  registerAssetRoutes({
    register,
    repository: (context) => repositories(context).assets,
  });

  registerEditorialRoutes({
    register,
    repository: (context) => repositories(context).editorial,
  });

  registerBriefingRoutes({
    register,
    repository: (context) => repositories(context).briefings,
  });

  registerCircleRoutes({
    register,
    repository: (context) => repositories(context).circles,
  });

  registerCovenRoutes({
    register,
    repository: (context) => repositories(context).coven,
    evidence: (context, claimIds) =>
      repositories(context).assets.listEvidence(claimIds),
  });

  registerDiscoverRoutes({
    register,
    repository: (context) => repositories(context).discover,
    circleTemplate: (context, templateId) =>
      repositories(context).circles.getTemplate(templateId),
    assets: (context, page) =>
      repositories(context).assets.listPage({
        limit: page.limit,
        assetType: undefined,
        symbolPrefix: undefined,
        after: page.after,
      }),
    coven: (context, page) =>
      repositories(context).coven.listPage({
        limit: page.limit,
        category: undefined,
        verifiedAsOf: undefined,
        after: page.after,
      }),
  });

  registerMediaRoutes({
    register,
    repository: (context) => repositories(context).media,
  });

  registerModerationRoutes({
    register,
    repository: (context) => repositories(context).moderation,
  });

  registerNotificationRoutes({
    register,
    repository: (context) => repositories(context).notifications,
  });

  registerPrivacyRoutes({
    register,
    service: (context) => options.createPrivacyService(context.get("claims")),
  });

  registerRitualRoutes({
    register,
    repository: (context) => repositories(context).rituals,
  });

  registerSearchRoutes({
    register,
    repository: (context) => repositories(context).search,
  });

  registerRowanRoutes({
    register,
    repository: (context) => repositories(context).rowan,
  });

  registerPublicPreviewRoutes({
    register,
    repository: (context) => publicPreviewRepository(context),
  });

  registerAdminRoutes({
    register,
    repository: (context) => repositories(context).admin,
    operations: (context) => repositories(context).adminOperations,
  });

  return app;
}
