import {
  createRoute,
  OpenAPIHono,
  type RouteConfig,
  z,
} from "@hono/zod-openapi";
import type { Context, MiddlewareHandler } from "hono";

import type { VerifiedRequestClaims } from "./db/request-context.ts";
import {
  RepositoryNotFoundError,
  RepositoryRevisionConflictError,
} from "./db/supabase-repositories.ts";
import { StaffAuthorizationError } from "./db/request-transaction.ts";
import type { RateLimitPort } from "./ports/infrastructure.ts";
import {
  BrokerageConnectionError,
  type BrokerageConnectionRepository,
} from "./domains/brokerage-connections/repository.ts";
import {
  BrokerageProjectionError,
  type BrokerageProjectionResource,
} from "./domains/brokerage-projections/types.ts";
import type { BrokerageProjectionService } from "./domains/brokerage-projections/service.ts";

type RepositoryModule = typeof import("./db/supabase-repositories.ts");

export type RetainedRepositorySet = Readonly<{
  session: ReturnType<RepositoryModule["createSupabaseSessionRepository"]>;
  accounts: ReturnType<RepositoryModule["createSupabaseAccountRepository"]>;
  assets: ReturnType<RepositoryModule["createSupabaseAssetRepository"]>;
  editorial: ReturnType<RepositoryModule["createSupabaseEditorialRepository"]>;
  briefings: ReturnType<RepositoryModule["createSupabaseBriefingRepository"]>;
  circles: ReturnType<RepositoryModule["createSupabaseCircleRepository"]>;
  coven: ReturnType<RepositoryModule["createSupabaseCovenRepository"]>;
  discover: ReturnType<RepositoryModule["createSupabaseDiscoverRepository"]>;
  media: ReturnType<RepositoryModule["createSupabaseMediaRepository"]>;
  moderation: ReturnType<RepositoryModule["createSupabaseModerationRepository"]>;
  notifications: ReturnType<RepositoryModule["createSupabaseNotificationRepository"]>;
  privacy: ReturnType<RepositoryModule["createSupabasePrivacyRepository"]>;
  rituals: ReturnType<RepositoryModule["createSupabaseRitualRepository"]>;
  rowan: ReturnType<RepositoryModule["createSupabaseRowanRepository"]>;
  search: ReturnType<RepositoryModule["createSupabaseSearchRepository"]>;
  admin: ReturnType<RepositoryModule["createSupabaseAdminRepository"]>;
  adminOperations: ReturnType<RepositoryModule["createSupabaseAdminOperationsRepository"]>;
}>;

export type PublicPreviewRepository = ReturnType<
  RepositoryModule["createSupabasePublicPreviewRepository"]
>;

export type VerifiedSupabasePrincipal = Readonly<{
  userId: string;
  sessionId: string;
  aal: "aal1" | "aal2";
  issuedAt: number;
  authenticatedAt?: number;
}>;

export type RetainedTokenVerifier = (
  token: string,
) => Promise<VerifiedSupabasePrincipal>;

export type RetainedRuntimeBindings = Readonly<{
  environment: "development" | "test" | "staging" | "production";
  buildRevision: string;
  consumerOrigin: string;
  adminOrigin: string;
}>;

type RetainedVariables = {
  requestId: string;
  principal: VerifiedSupabasePrincipal;
  claims: VerifiedRequestClaims;
};

export type RetainedAppEnvironment = {
  Bindings: RetainedRuntimeBindings;
  Variables: RetainedVariables;
};

export type RetainedTelemetryEvent = Readonly<{
  event: "http.request";
  requestId: string;
  method: string;
  route: string;
  status: number;
  latencyMs: number;
}>;

export type CreateRetainedAppOptions = Readonly<{
  verifyAccessToken: RetainedTokenVerifier;
  createRepositories: (claims: VerifiedRequestClaims) => RetainedRepositorySet;
  publicPreviewRepository: PublicPreviewRepository;
  rateLimit: RateLimitPort;
  createBrokerageConnections?: (
    claims: VerifiedRequestClaims,
  ) => BrokerageConnectionRepository;
  createBrokerageProjections?: (
    claims: VerifiedRequestClaims,
  ) => BrokerageProjectionService;
  requestId?: () => string;
  telemetry?: (event: RetainedTelemetryEvent) => void | Promise<void>;
}>;

const requestIdPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const uuid = z.string().uuid();
const limit = z.coerce.number().int().min(1).max(100).default(25);
const jsonObject = z.record(z.string(), z.unknown());
const responseSchema = z
  .object({
    data: z.unknown(),
    meta: z.object({ request_id: uuid }).strict(),
  })
  .strict();
const responseMetaSchema = z.object({ request_id: uuid }).strict();
const brokerageStateSchema = z.enum([
  "fresh",
  "empty",
  "stale",
  "partial",
  "unavailable",
  "offline",
  "rate_limited",
  "disconnected",
  "reauthorization_required",
]);
const brokerageCapabilitySchema = z.object({
  capability: z.enum([
    "balances_read",
    "positions_read",
    "orders_read",
    "manual_orders",
    "unsupported",
  ]),
  provider_code: z.string().min(1).max(128),
  available: z.boolean(),
}).strict().openapi("BrokerageCapability");
const brokerageAccountSchema = z.object({
  id: uuid,
  connection_id: uuid,
  display_label: z.string().min(1).max(160),
  base_currency: z.string().regex(/^[A-Z]{3}$/),
  market_timezone: z.string().min(1).max(64).nullable(),
  status: z.enum(["available", "restricted", "closed", "unavailable"]),
  capability_version: z.number().int().nonnegative(),
  capabilities: z.array(brokerageCapabilitySchema).max(64),
  state: brokerageStateSchema,
  selected: z.boolean(),
  provider_observed_at: z.string().datetime().nullable(),
  fetched_at: z.string().datetime().nullable(),
  expires_at: z.string().datetime().nullable(),
}).strict().openapi("BrokerageAccount");
const brokerageAccountAuthoritySchema = z.object({
  display_label: z.string().min(1).max(160),
  base_currency: z.string().regex(/^[A-Z]{3}$/),
  market_timezone: z.string().min(1).max(64),
  status: z.enum(["available", "restricted", "closed", "unavailable"]),
  capability_version: z.number().int().nonnegative(),
  capabilities: z.array(brokerageCapabilitySchema).max(64),
}).strict().openapi("BrokerageAccountAuthority");
const decimalStringSchema = z.string().regex(
  /^-?(?:0|[1-9]\d*)(?:\.\d{1,18})?$/,
);
const brokerageBalanceSchema = z.object({
  currency: z.string().regex(/^[A-Z]{3}$/),
  cash: decimalStringSchema,
  buying_power: decimalStringSchema.nullable(),
  market_value: decimalStringSchema.nullable(),
  total_equity: decimalStringSchema,
}).strict().openapi("BrokerageBalance");
const brokerageAssetSchema = z.object({
  instrument_id: uuid,
  symbol: z.string().min(1).max(32),
  name: z.string().min(1).max(160),
  asset_kind: z.enum(["equity", "etf", "unsupported"]),
  provider_asset_kind: z.string().min(1).max(128),
  supported: z.boolean(),
  currency: z.string().regex(/^[A-Z]{3}$/),
  exchange: z.string().max(32).nullable(),
  market_timezone: z.string().min(1).max(64),
}).strict().openapi("BrokerageAsset");
const brokeragePositionSchema = z.object({
  asset: brokerageAssetSchema,
  quantity: decimalStringSchema,
  available_quantity: decimalStringSchema,
  average_cost: decimalStringSchema.nullable(),
  market_value: decimalStringSchema.nullable(),
  currency: z.string().regex(/^[A-Z]{3}$/),
}).strict().openapi("BrokeragePosition");
const brokerageRestrictionSchema = z.object({
  restriction: z.enum([
    "closing_only",
    "trading_disabled",
    "liquidation_only",
    "unsupported",
  ]),
  provider_code: z.string().min(1).max(128),
  active: z.boolean(),
  detail: z.string().max(256).nullable(),
}).strict().openapi("BrokerageRestriction");

function brokerageProjectionResponseSchema(
  name: string,
  data: z.ZodType,
) {
  return z.object({
    account_id: uuid,
    resource: z.enum(["account", "balance", "positions", "restrictions"]),
    generation: z.number().int().positive().nullable(),
    state: brokerageStateSchema,
    reason: z.string().max(64).nullable(),
    provider_observed_at: z.string().datetime().nullable(),
    fetched_at: z.string().datetime().nullable(),
    expires_at: z.string().datetime().nullable(),
    data: data.nullable(),
  }).strict().openapi(name);
}

function brokerageEnvelope(name: string, data: z.ZodType) {
  return z.object({ data, meta: responseMetaSchema }).strict().openapi(name);
}

const brokerageAccountsResponseSchema = brokerageEnvelope(
  "BrokerageAccountsResponse",
  z.array(brokerageAccountSchema).max(100),
);
const brokerageCapabilitiesResponseSchema = brokerageEnvelope(
  "BrokerageCapabilitiesResponse",
  brokerageProjectionResponseSchema(
    "BrokerageCapabilitiesProjection",
    brokerageAccountAuthoritySchema,
  ),
);
const brokerageBalancesResponseSchema = brokerageEnvelope(
  "BrokerageBalancesResponse",
  brokerageProjectionResponseSchema(
    "BrokerageBalancesProjection",
    brokerageBalanceSchema,
  ),
);
const brokeragePositionsResponseSchema = brokerageEnvelope(
  "BrokeragePositionsResponse",
  brokerageProjectionResponseSchema(
    "BrokeragePositionsProjection",
    z.array(brokeragePositionSchema).max(10_000),
  ),
);
const brokerageRestrictionsResponseSchema = brokerageEnvelope(
  "BrokerageRestrictionsResponse",
  brokerageProjectionResponseSchema(
    "BrokerageRestrictionsProjection",
    z.array(brokerageRestrictionSchema).max(256),
  ),
);
const errorSchema = z
  .object({
    error: z
      .object({
        code: z.string(),
        message: z.string(),
        request_id: uuid,
        field_errors: z.array(z.unknown()),
        retryable: z.boolean(),
      })
      .strict(),
  })
  .strict();
const idempotencyKey = z.string().min(16).max(64).regex(/^[\x21-\x7E]+$/);

class HttpBoundaryError extends Error {
  readonly status: 400 | 401 | 403 | 404 | 409 | 413 | 415 | 422 | 429 | 503;
  readonly code: string;
  readonly publicMessage: string;
  readonly retryable: boolean;
  readonly retryAfterSeconds: number | undefined;

  constructor(
    status: 400 | 401 | 403 | 404 | 409 | 413 | 415 | 422 | 429 | 503,
    code: string,
    publicMessage: string,
    retryable = false,
    retryAfterSeconds?: number,
  ) {
    super(code);
    this.status = status;
    this.code = code;
    this.publicMessage = publicMessage;
    this.retryable = retryable;
    this.retryAfterSeconds = retryAfterSeconds;
  }
}

function errorResponse(
  context: Context<RetainedAppEnvironment>,
  error: HttpBoundaryError,
): Response {
  const headers = error.retryAfterSeconds === undefined
    ? undefined
    : { "retry-after": String(error.retryAfterSeconds) };
  return context.json(
    {
      error: {
        code: error.code,
        message: error.publicMessage,
        request_id: context.get("requestId"),
        field_errors: [],
        retryable: error.retryable,
      },
    },
    error.status,
    headers,
  );
}

function bearerToken(value: string | undefined): string | null {
  if (value === undefined || value.length > 16_391) return null;
  const match = /^Bearer ([A-Za-z0-9._~-]+)$/.exec(value);
  return match?.[1] ?? null;
}

function claimsFrom(principal: VerifiedSupabasePrincipal): VerifiedRequestClaims {
  return Object.freeze({
    userId: uuid.parse(principal.userId),
    sessionId: uuid.parse(principal.sessionId),
    aal: principal.aal,
  });
}

async function digest(value: string): Promise<string> {
  const bytes = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(bytes)]
    .map((entry) => entry.toString(16).padStart(2, "0"))
    .join("");
}

function normalizedRoute(path: string): string {
  return path
    .replace(
      /[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/gi,
      "{id}",
    )
    .slice(0, 256);
}

async function parseBody<T>(
  context: Context<RetainedAppEnvironment>,
  schema: z.ZodType<T>,
): Promise<T> {
  try {
    // @hono/zod-openapi validates and consumes JSON before invoking the
    // handler. Reuse that boundary result rather than attempting to read the
    // request stream a second time.
    return schema.parse(context.req.valid("json" as never));
  } catch {
    throw new HttpBoundaryError(
      422,
      "validation_failed",
      "The request body failed validation.",
    );
  }
}

async function rejectBody(context: Context<RetainedAppEnvironment>) {
  if (
    context.req.raw.body !== null &&
    context.req.header("content-length") !== "0" &&
    (await context.req.raw.text()).length > 0
  ) {
    throw new HttpBoundaryError(
      422,
      "validation_failed",
      "This operation does not accept a request body.",
    );
  }
}

function expectedVersion(context: Context<RetainedAppEnvironment>): number {
  const match = /^"v([1-9]\d*)"$/.exec(context.req.header("if-match") ?? "");
  if (match === null) {
    throw new HttpBoundaryError(
      422,
      "invalid_if_match",
      "If-Match must contain the current version ETag.",
    );
  }
  return Number(match[1]);
}

function dataResponse(
  context: Context<RetainedAppEnvironment>,
  data: unknown,
): Response {
  if (data === null || data === undefined) {
    throw new HttpBoundaryError(
      404,
      "not_found",
      "The requested resource was not found.",
    );
  }
  const version =
    typeof data === "object" &&
    data !== null &&
    "version" in data &&
    Number.isInteger((data as { version?: unknown }).version)
      ? Number((data as { version: number }).version)
      : undefined;
  if (version !== undefined) context.header("etag", `"v${version}"`);
  return context.json(
    { data, meta: { request_id: context.get("requestId") } },
    200,
  );
}

type RouteOptions = Readonly<{
  public?: boolean;
  body?: z.ZodType;
  pathParams?: z.ZodType;
  query?: z.ZodType;
  headers?: z.ZodType;
  description?: string;
  response?: z.ZodType;
}>;

type RouteAccess = Readonly<{ isPublic: boolean; isAdmin: boolean }>;
const routeAccess = new WeakMap<object, RouteAccess>();

function route(
  method: "get" | "post" | "patch" | "delete",
  path: string,
  operationId: string,
  tag: string,
  options: RouteOptions = {},
) {
  const request: Record<string, unknown> = {};
  if (options.pathParams !== undefined) request.params = options.pathParams;
  if (options.query !== undefined) request.query = options.query;
  if (options.headers !== undefined) request.headers = options.headers;
  if (options.body !== undefined) {
    request.body = {
      required: true,
      content: { "application/json": { schema: options.body } },
    };
  }
  const definition = createRoute({
    method,
    path,
    operationId,
    tags: [tag],
    security: options.public === true ? [] : [{ SupabaseBearer: [] }],
    ...(Object.keys(request).length === 0 ? {} : { request }),
    responses: {
      200: {
        description: options.description ?? "Argus response.",
        content: {
          "application/json": { schema: options.response ?? responseSchema },
        },
      },
      401: {
        description: "Invalid Supabase access token.",
        content: { "application/json": { schema: errorSchema } },
      },
      403: {
        description: "Owner or current staff authorization denied.",
        content: { "application/json": { schema: errorSchema } },
      },
      409: {
        description: "Revision or idempotency conflict.",
        content: { "application/json": { schema: errorSchema } },
      },
      422: {
        description: "Strict request validation failed.",
        content: { "application/json": { schema: errorSchema } },
      },
      429: {
        description: "Rate limited.",
        content: { "application/json": { schema: errorSchema } },
      },
      503: {
        description: "A required private dependency is unavailable.",
        content: { "application/json": { schema: errorSchema } },
      },
    },
  } as RouteConfig);
  routeAccess.set(definition, {
    isPublic: options.public === true,
    isAdmin: path.startsWith("/v1/admin/"),
  });
  return definition;
}

function query(context: Context<RetainedAppEnvironment>) {
  return Object.fromEntries(new URL(context.req.url).searchParams.entries());
}

function repositories(
  context: Context<RetainedAppEnvironment>,
  options: CreateRetainedAppOptions,
) {
  return options.createRepositories(context.get("claims"));
}

function brokerageConnections(
  context: Context<RetainedAppEnvironment>,
  options: CreateRetainedAppOptions,
): BrokerageConnectionRepository {
  const factory = options.createBrokerageConnections;
  if (factory === undefined) {
    throw new HttpBoundaryError(
      503,
      "webull_contract_unavailable",
      "Webull connection is temporarily unavailable.",
      true,
    );
  }
  return factory(context.get("claims"));
}

function brokerageProjections(
  context: Context<RetainedAppEnvironment>,
  options: CreateRetainedAppOptions,
): BrokerageProjectionService {
  const factory = options.createBrokerageProjections;
  if (factory === undefined) {
    throw new HttpBoundaryError(
      503,
      "brokerage_reads_unavailable",
      "Brokerage data is temporarily unavailable.",
      true,
    );
  }
  return factory(context.get("claims"));
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
    const expectedOrigin = context.req.path.startsWith("/v1/admin/")
      ? context.env.adminOrigin
      : context.env.consumerOrigin;
    if (origin !== undefined && origin !== expectedOrigin) {
      throw new HttpBoundaryError(
        403,
        "origin_denied",
        "The request origin is not allowed.",
      );
    }
    if (origin === expectedOrigin) {
      context.header("access-control-allow-origin", expectedOrigin);
      context.header("access-control-allow-methods", "GET, POST, PATCH, DELETE, OPTIONS");
      context.header(
        "access-control-allow-headers",
        "authorization, content-type, if-match, idempotency-key, x-request-id",
      );
      context.header("access-control-expose-headers", "etag, retry-after, x-request-id");
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
    if (error instanceof BrokerageConnectionError) {
      const stepUp = error.code === "step_up_required";
      const conflict = error.code === "connection_already_connected";
      return errorResponse(
        context,
        new HttpBoundaryError(
          stepUp ? 403 : conflict ? 409 : 404,
          error.code,
          stepUp
            ? "A current action-bound authorization is required."
            : conflict
            ? "The Webull connection already exists."
            : "The requested brokerage resource was not found.",
        ),
      );
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

  const middlewareByPath = new Map<string, RouteAccess>();
  const register = (
    definition: ReturnType<typeof route>,
    handler: (context: Context<RetainedAppEnvironment>) => Response | Promise<Response>,
  ) => {
    const routingPath = definition.getRoutingPath();
    const access = routeAccess.get(definition);
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
    app.openapi(definition as never, handler as never);
  };

  const health = route("get", "/v1/health/live", "getLiveHealth", "Platform", {
    public: true,
  });
  register(
    health,
    (context) =>
      dataResponse(context, {
        status: "ok",
        build_revision: context.env.buildRevision,
      }),
  );

  const openapi = route(
    "get",
    "/v1/openapi.json",
    "getOpenApiDocument",
    "Platform",
    { public: true },
  );
  let serializedContract: Promise<{ body: string; etag: string }> | undefined;
  register(
    openapi,
    async (context) => {
      serializedContract ??= (async () => {
        const body = JSON.stringify(buildRetainedOpenApiDocument(app));
        return {
          body,
          etag: `"openapi-${(await digest(body)).slice(0, 24)}"`,
        };
      })();
      const contract = await serializedContract;
      context.header("etag", contract.etag);
      context.header("cache-control", "public, max-age=300");
      if (context.req.header("if-none-match") === contract.etag) {
        return context.body(null, 304);
      }
      return context.body(contract.body, 200, {
        "content-type": "application/json; charset=UTF-8",
      });
    },
  );

  const bodylessBootstrap = route(
    "post",
    "/v1/session/bootstrap",
    "bootstrapSession",
    "Session",
  );
  register(bodylessBootstrap, async (context) => {
    await rejectBody(context);
    return dataResponse(context, await repositories(context, options).session.bootstrap());
  });

  const stepUpBody = z.object({
    action: z.enum(["webull_disconnect", "argus_delete"]),
  }).strict();
  const issueStepUp = route(
    "post",
    "/v1/member/step-up",
    "issueMemberStepUp",
    "Member Security",
    { body: stepUpBody },
  );
  register(issueStepUp, async (context) => {
    const authenticatedAt = context.get("principal").authenticatedAt;
    const currentSeconds = Math.floor(Date.now() / 1_000);
    if (
      authenticatedAt === undefined ||
      authenticatedAt > currentSeconds + 30 ||
      currentSeconds - authenticatedAt > 300
    ) {
      throw new HttpBoundaryError(
        403,
        "recent_auth_required",
        "Recent authentication is required.",
      );
    }
    const input = await parseBody(context, stepUpBody);
    return dataResponse(
      context,
      await brokerageConnections(context, options).issueStepUp(input.action),
    );
  });

  const connectionStartBody = z.object({
    return_target: z.enum(["webull_https", "webull_native"]),
  }).strict();
  const startConnection = route(
    "post",
    "/v1/brokerage/connections/start",
    "startWebullConnection",
    "Brokerage Connections",
    { body: connectionStartBody },
  );
  register(startConnection, async (context) => {
    const input = await parseBody(context, connectionStartBody);
    return dataResponse(
      context,
      await brokerageConnections(context, options).start(input.return_target),
    );
  });

  const reconnect = route(
    "post",
    "/v1/brokerage/connections/reconnect",
    "reconnectWebullConnection",
    "Brokerage Connections",
    { body: connectionStartBody },
  );
  register(reconnect, async (context) => {
    const input = await parseBody(context, connectionStartBody);
    return dataResponse(
      context,
      await brokerageConnections(context, options).reconnect(
        input.return_target,
      ),
    );
  });

  const getConnection = route(
    "get",
    "/v1/brokerage/connection",
    "getWebullConnection",
    "Brokerage Connections",
  );
  register(getConnection, async (context) =>
    dataResponse(
      context,
      await brokerageConnections(context, options).status(),
    ));

  const selectAccountBody = z.object({ account_id: uuid }).strict();
  const selectBrokerageAccount = route(
    "patch",
    "/v1/brokerage/accounts/selection",
    "selectWebullAccount",
    "Brokerage Connections",
    { body: selectAccountBody },
  );
  register(selectBrokerageAccount, async (context) => {
    const input = await parseBody(context, selectAccountBody);
    return dataResponse(
      context,
      await brokerageConnections(context, options).selectAccount(
        input.account_id,
      ),
    );
  });

  const completionBody = z.object({
    completion: z.string().min(43).max(128).regex(/^[A-Za-z0-9_-]+$/),
  }).strict();
  const redeemCompletion = route(
    "post",
    "/v1/brokerage/connections/completions/redeem",
    "redeemWebullCompletion",
    "Brokerage Connections",
    { body: completionBody },
  );
  register(redeemCompletion, async (context) => {
    const input = await parseBody(context, completionBody);
    return dataResponse(
      context,
      await brokerageConnections(context, options).redeemCompletion(
        input.completion,
      ),
    );
  });

  const disconnectBody = z.object({
    step_up_receipt: z.string().min(32).max(512).regex(/^[A-Za-z0-9_-]+$/),
  }).strict();
  const disconnect = route(
    "post",
    "/v1/brokerage/connections/disconnect",
    "disconnectWebullConnection",
    "Brokerage Connections",
    { body: disconnectBody },
  );
  register(disconnect, async (context) => {
    const input = await parseBody(context, disconnectBody);
    return dataResponse(
      context,
      await brokerageConnections(context, options).disconnect(
        input.step_up_receipt,
      ),
    );
  });

  const listBrokerageAccounts = route(
    "get",
    "/v1/brokerage/accounts",
    "listWebullAccounts",
    "Brokerage Reads",
    {
      description: "Owner-scoped Webull accounts and normalized capabilities.",
      response: brokerageAccountsResponseSchema,
    },
  );
  register(listBrokerageAccounts, async (context) =>
    dataResponse(
      context,
      await brokerageProjections(context, options).listAccounts(),
    ));

  const brokerageReadPath = z.object({ account_id: uuid });
  const brokerageReadQuery = z.object({
    refresh: z.enum(["true", "false"]).optional(),
  });
  for (const [path, operationId, resource, response] of [
    [
      "/v1/brokerage/accounts/{account_id}/capabilities",
      "getWebullAccountCapabilities",
      "account",
      brokerageCapabilitiesResponseSchema,
    ],
    [
      "/v1/brokerage/accounts/{account_id}/balances",
      "getWebullBalances",
      "balance",
      brokerageBalancesResponseSchema,
    ],
    [
      "/v1/brokerage/accounts/{account_id}/positions",
      "getWebullPositions",
      "positions",
      brokeragePositionsResponseSchema,
    ],
    [
      "/v1/brokerage/accounts/{account_id}/restrictions",
      "getWebullRestrictions",
      "restrictions",
      brokerageRestrictionsResponseSchema,
    ],
  ] as const satisfies readonly (readonly [
    string,
    string,
    BrokerageProjectionResource,
    z.ZodType,
  ])[]) {
    const definition = route(
      "get",
      path,
      operationId,
      "Brokerage Reads",
      {
        pathParams: brokerageReadPath,
        query: brokerageReadQuery,
        description:
          "Immutable provider-authoritative projection with independent freshness timestamps.",
        response,
      },
    );
    register(definition, async (context) =>
      dataResponse(
        context,
        await brokerageProjections(context, options).read(
          uuid.parse(context.req.param("account_id")),
          resource,
          context.req.query("refresh") === "true",
        ),
      ));
  }

  const account = route("get", "/v1/account", "getAccount", "Account");
  register(account, async (context) =>
    dataResponse(context, await repositories(context, options).accounts.get()));

  const preferencesPatch = z
    .object({
      themeMode: z.enum(["system", "light", "dark"]).optional(),
      ritualMode: z.enum(["tarot", "astrology"]).optional(),
      timezone: z.string().min(1).max(64).optional(),
      locale: z.string().min(2).max(35).optional(),
    })
    .strict();
  const updatePreferences = route(
    "patch",
    "/v1/preferences",
    "updatePreferences",
    "Account",
    { body: preferencesPatch, headers: z.object({ "if-match": z.string() }) },
  );
  register(updatePreferences, async (context) => {
    const patch = await parseBody(context, preferencesPatch);
    return dataResponse(
      context,
      await repositories(context, options).accounts.updatePreferences(
        {
          ...(patch.themeMode === undefined ? {} : { themeMode: patch.themeMode }),
          ...(patch.ritualMode === undefined ? {} : { ritualMode: patch.ritualMode }),
          ...(patch.timezone === undefined ? {} : { timezone: patch.timezone }),
          ...(patch.locale === undefined ? {} : { locale: patch.locale }),
        },
        expectedVersion(context),
      ),
    );
  });

  const consentBody = z
    .object({
      policyCode: z.string().min(1).max(80),
      policyVersion: z.string().min(1).max(40),
      decision: z.enum(["accepted", "declined", "withdrawn"]),
    })
    .strict();
  const consent = route("post", "/v1/consents", "recordConsent", "Account", {
    body: consentBody,
  });
  register(consent, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).accounts.recordConsent(
        await parseBody(context, consentBody),
      ),
    ));

  const listAssets = route("get", "/v1/assets", "listAssets", "Assets", {
    query: z.object({
      limit: limit.optional(),
      asset_type: z.string().optional(),
      symbol_prefix: z.string().optional(),
    }),
  });
  register(listAssets, async (context) => {
    const input = z.object({
      limit,
      asset_type: z.string().optional(),
      symbol_prefix: z.string().optional(),
    }).parse(query(context));
    return dataResponse(
      context,
      await repositories(context, options).assets.list(
        input.limit,
        input.asset_type,
        input.symbol_prefix,
      ),
    );
  });

  const getAsset = route("get", "/v1/assets/{asset_id}", "getAsset", "Assets", {
    pathParams: z.object({ asset_id: uuid }),
  });
  register(getAsset, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).assets.get(
        uuid.parse(context.req.param("asset_id")),
      ),
    ));

  const listEditorial = route(
    "get",
    "/v1/editorial/{kind}",
    "listEditorial",
    "Editorial",
    {
      pathParams: z.object({ kind: z.string().min(1).max(80) }),
      query: z.object({ limit: limit.optional() }),
    },
  );
  register(listEditorial, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).editorial.listPublished(
        z.string().min(1).max(80).parse(context.req.param("kind")),
        limit.parse(context.req.query("limit")),
      ),
    ));

  const getEditorial = route(
    "get",
    "/v1/editorial/items/{slug}",
    "getEditorial",
    "Editorial",
    { pathParams: z.object({ slug: z.string().min(1).max(120) }) },
  );
  register(getEditorial, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).editorial.getPublished(
        z.string().min(1).max(120).parse(context.req.param("slug")),
      ),
    ));

  const listBriefings = route(
    "get",
    "/v1/briefings",
    "listBriefings",
    "Briefings",
    { query: z.object({ limit: limit.optional() }) },
  );
  register(listBriefings, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).briefings.list(
        limit.parse(context.req.query("limit")),
      ),
    ));
  const getBriefing = route(
    "get",
    "/v1/briefings/{briefing_id}",
    "getBriefing",
    "Briefings",
    { pathParams: z.object({ briefing_id: uuid }) },
  );
  register(getBriefing, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).briefings.get(
        uuid.parse(context.req.param("briefing_id")),
      ),
    ));

  const listCircles = route("get", "/v1/circles", "listCircles", "Circles", {
    query: z.object({ limit: limit.optional() }),
  });
  register(listCircles, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).circles.list(
        limit.parse(context.req.query("limit")),
      ),
    ));
  const circleBody = z
    .object({ title: z.string().min(1).max(120), description: z.string().max(1000) })
    .strict();
  const createCircle = route("post", "/v1/circles", "createCircle", "Circles", {
    body: circleBody,
  });
  register(createCircle, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).circles.create(
        await parseBody(context, circleBody),
      ),
    ));
  const circlePath = z.object({ circle_id: uuid });
  const getCircle = route(
    "get",
    "/v1/circles/{circle_id}",
    "getCircle",
    "Circles",
    { pathParams: circlePath },
  );
  register(getCircle, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).circles.get(
        uuid.parse(context.req.param("circle_id")),
      ),
    ));
  const updateCircle = route(
    "patch",
    "/v1/circles/{circle_id}",
    "updateCircle",
    "Circles",
    {
      pathParams: circlePath,
      body: circleBody.partial(),
      headers: z.object({ "if-match": z.string() }),
    },
  );
  register(updateCircle, async (context) => {
    const patch = await parseBody(context, circleBody.partial());
    return dataResponse(
      context,
      await repositories(context, options).circles.update(
        uuid.parse(context.req.param("circle_id")),
        {
          ...(patch.title === undefined ? {} : { title: patch.title }),
          ...(patch.description === undefined
            ? {}
            : { description: patch.description }),
        },
        expectedVersion(context),
      ),
    );
  });

  const listSaved = route("get", "/v1/saved", "listSaved", "Saved", {
    query: z.object({ limit: limit.optional() }),
  });
  register(listSaved, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).circles.listSaved(
        limit.parse(context.req.query("limit")),
      ),
    ));
  const savedPath = z.object({ item_kind: z.enum(["asset", "grimoire", "circle_template", "coven"]), item_id: uuid });
  const saveItem = route(
    "post",
    "/v1/saved/{item_kind}/{item_id}",
    "saveItem",
    "Saved",
    { pathParams: savedPath },
  );
  register(saveItem, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).circles.save(
        savedPath.shape.item_kind.parse(context.req.param("item_kind")),
        uuid.parse(context.req.param("item_id")),
      ),
    ));
  const unsaveItem = route(
    "delete",
    "/v1/saved/{item_kind}/{item_id}",
    "unsaveItem",
    "Saved",
    { pathParams: savedPath },
  );
  register(unsaveItem, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).circles.unsave(
        savedPath.shape.item_kind.parse(context.req.param("item_kind")),
        uuid.parse(context.req.param("item_id")),
      ) ?? { removed: true },
    ));

  const listCoven = route("get", "/v1/coven", "listCoven", "Coven", {
    query: z.object({ limit: limit.optional() }),
  });
  register(listCoven, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).coven.list(
        limit.parse(context.req.query("limit")),
      ),
    ));
  const getCoven = route("get", "/v1/coven/{entry_id}", "getCoven", "Coven", {
    pathParams: z.object({ entry_id: uuid }),
  });
  register(getCoven, async (context) =>
    dataResponse(
      context,
      await repositories(context, options).coven.get(
        uuid.parse(context.req.param("entry_id")),
      ),
    ));

  for (const [path, operationId, loader] of [
    ["/v1/discover/assets", "listDiscoverAssets", (r: RetainedRepositorySet, n: number) => r.discover.listAssets(n)],
    ["/v1/discover/grimoires", "listGrimoires", (r: RetainedRepositorySet, n: number) => r.discover.listGrimoires(n)],
    ["/v1/discover/circle-templates", "listCircleTemplates", (r: RetainedRepositorySet, n: number) => r.discover.listCircleTemplates(n)],
  ] as const) {
    const definition = route("get", path, operationId, "Discover", {
      query: z.object({ limit: limit.optional() }),
    });
    register(definition, async (context) =>
      dataResponse(
        context,
        await loader(
          repositories(context, options),
          limit.parse(context.req.query("limit")),
        ),
      ));
  }

  const uploadIntentBody = z.object({
    bucketId: z.enum(["member-media", "media-quarantine"]),
    objectPath: z.string().min(1).max(512),
    mimeType: z.enum(["image/jpeg", "image/png", "image/webp"]),
    maxBytes: z.number().int().min(1).max(10 * 1024 * 1024),
    expiresAt: z.coerce.date(),
  }).strict();
  const createUploadIntent = route("post", "/v1/media/upload-intents", "createUploadIntent", "Media", { body: uploadIntentBody });
  register(createUploadIntent, async (context) =>
    dataResponse(context, await repositories(context, options).media.createUploadIntent(await parseBody(context, uploadIntentBody))));
  const getUploadIntent = route("get", "/v1/media/upload-intents/{intent_id}", "getUploadIntent", "Media", { pathParams: z.object({ intent_id: uuid }) });
  register(getUploadIntent, async (context) =>
    dataResponse(context, await repositories(context, options).media.getUploadIntent(uuid.parse(context.req.param("intent_id")))));
  const finalizeMediaBody = z.object({ byteSize: z.number().int().positive(), checksum: z.string().regex(/^[a-f0-9]{64}$/) }).strict();
  const finalizeMedia = route("post", "/v1/admin/media/upload-intents/{intent_id}/finalize", "finalizeUpload", "Admin Media", { pathParams: z.object({ intent_id: uuid }), body: finalizeMediaBody });
  register(finalizeMedia, async (context) => {
    const input = await parseBody(context, finalizeMediaBody);
    return dataResponse(context, await repositories(context, options).media.finalizeUpload(uuid.parse(context.req.param("intent_id")), input.byteSize, input.checksum));
  });

  const reportBody = z.object({ targetKind: z.string().min(1).max(80), targetId: uuid, reasonCode: z.string().min(1).max(80), details: z.string().max(1000).optional() }).strict();
  const reportContent = route("post", "/v1/moderation/reports", "reportContent", "Moderation", { body: reportBody });
  register(reportContent, async (context) => {
    const input = await parseBody(context, reportBody);
    return dataResponse(context, await repositories(context, options).moderation.report({
      targetKind: input.targetKind,
      targetId: input.targetId,
      reasonCode: input.reasonCode,
      ...(input.details === undefined ? {} : { details: input.details }),
    }));
  });
  const moderationDecision = z.object({ status: z.string().min(1).max(40) }).passthrough();
  const decideModeration = route("post", "/v1/admin/moderation/{case_id}/decision", "decideModeration", "Admin Moderation", { pathParams: z.object({ case_id: uuid }), body: moderationDecision, headers: z.object({ "if-match": z.string(), "idempotency-key": idempotencyKey }) });
  register(decideModeration, async (context) =>
    dataResponse(context, await repositories(context, options).moderation.decide(uuid.parse(context.req.param("case_id")), expectedVersion(context), await parseBody(context, moderationDecision), idempotencyKey.parse(context.req.header("idempotency-key")))));

  const listNotifications = route("get", "/v1/notifications", "listNotifications", "Notifications", { query: z.object({ limit: limit.optional() }) });
  register(listNotifications, async (context) => dataResponse(context, await repositories(context, options).notifications.list(limit.parse(context.req.query("limit")))));
  const notificationPreferences = route("get", "/v1/notification-preferences", "getNotificationPreferences", "Notifications");
  register(notificationPreferences, async (context) => dataResponse(context, await repositories(context, options).notifications.getPreferences()));
  const updateNotificationPreferences = route("patch", "/v1/notification-preferences", "updateNotificationPreferences", "Notifications", { body: jsonObject, headers: z.object({ "if-match": z.string() }) });
  register(updateNotificationPreferences, async (context) => dataResponse(context, await repositories(context, options).notifications.updatePreferences(await parseBody(context, jsonObject), expectedVersion(context))));
  const markNotificationRead = route("patch", "/v1/notifications/{notification_id}/read", "markNotificationRead", "Notifications", { pathParams: z.object({ notification_id: uuid }) });
  register(markNotificationRead, async (context) => dataResponse(context, await repositories(context, options).notifications.markRead(uuid.parse(context.req.param("notification_id")))));

  const listPrivacy = route("get", "/v1/privacy/requests", "listPrivacyRequests", "Privacy");
  register(listPrivacy, async (context) => dataResponse(context, await repositories(context, options).privacy.list()));
  const privacyBody = z.object({ requestType: z.enum(["export", "deletion"]) }).strict();
  const requestPrivacy = route("post", "/v1/privacy/requests", "requestPrivacyAction", "Privacy", { body: privacyBody, headers: z.object({ "idempotency-key": idempotencyKey }) });
  register(requestPrivacy, async (context) => {
    const input = await parseBody(context, privacyBody);
    return dataResponse(context, await repositories(context, options).privacy.request(input.requestType, idempotencyKey.parse(context.req.header("idempotency-key"))));
  });

  const ritualPath = z.object({ assignment_id: uuid });
  const getRitual = route("get", "/v1/rituals/{assignment_id}", "getRitual", "Rituals", { pathParams: ritualPath });
  register(getRitual, async (context) => dataResponse(context, await repositories(context, options).rituals.get(uuid.parse(context.req.param("assignment_id")))));
  const transitionBody = z.object({ from: z.enum(["assigned", "revealed"]), to: z.enum(["revealed", "completed"]) }).strict();
  const transitionRitual = route("post", "/v1/rituals/{assignment_id}/transition", "transitionRitual", "Rituals", { pathParams: ritualPath, body: transitionBody, headers: z.object({ "if-match": z.string() }) });
  register(transitionRitual, async (context) => {
    const input = await parseBody(context, transitionBody);
    return dataResponse(context, await repositories(context, options).rituals.transition(uuid.parse(context.req.param("assignment_id")), input.from, input.to, expectedVersion(context)));
  });

  const search = route("get", "/v1/search", "search", "Search", { query: z.object({ q: z.string().min(1).max(160), limit: limit.optional() }) });
  register(search, async (context) => dataResponse(context, await repositories(context, options).search.search(z.string().min(1).max(160).parse(context.req.query("q")), limit.parse(context.req.query("limit")))));
  const rowan = route("get", "/v1/rowan/{surface}/{context_key}", "resolveRowan", "Rowan", { pathParams: z.object({ surface: z.string().min(1).max(80), context_key: z.string().min(1).max(160) }) });
  register(rowan, async (context) => dataResponse(context, await repositories(context, options).rowan.resolve(z.string().min(1).max(80).parse(context.req.param("surface")), z.string().min(1).max(160).parse(context.req.param("context_key")))));

  const publicList = route("get", "/v1/public/editorial/{kind}", "listPublicEditorial", "Public", { public: true, pathParams: z.object({ kind: z.string().min(1).max(80) }), query: z.object({ limit: limit.optional() }) });
  register(publicList, async (context) => dataResponse(context, await options.publicPreviewRepository.listPublished(z.string().min(1).max(80).parse(context.req.param("kind")), limit.parse(context.req.query("limit")))));
  const publicGet = route("get", "/v1/public/editorial/items/{slug}", "getPublicEditorial", "Public", { public: true, pathParams: z.object({ slug: z.string().min(1).max(120) }) });
  register(publicGet, async (context) => dataResponse(context, await options.publicPreviewRepository.getPublished(z.string().min(1).max(120).parse(context.req.param("slug")))));

  const adminSession = route("get", "/v1/admin/session", "getAdminSession", "Admin");
  register(adminSession, async (context) => dataResponse(context, await repositories(context, options).admin.getStaffPrincipal()));
  const adminAudit = route("get", "/v1/admin/audit", "listAdminAudit", "Admin", { query: z.object({ limit: limit.optional() }) });
  register(adminAudit, async (context) => dataResponse(context, await repositories(context, options).admin.listAudit(limit.parse(context.req.query("limit")))));
  const adminEditorial = route("get", "/v1/admin/editorial", "listAdminEditorial", "Admin", { query: z.object({ limit: limit.optional() }) });
  register(adminEditorial, async (context) => dataResponse(context, await repositories(context, options).admin.listEditorial(limit.parse(context.req.query("limit")))));
  const adminJobs = route("get", "/v1/admin/operations/jobs", "listAdminJobs", "Admin Operations", { query: z.object({ limit: limit.optional() }) });
  register(adminJobs, async (context) => dataResponse(context, await repositories(context, options).adminOperations.listJobs(limit.parse(context.req.query("limit")))));
  const adminPrivacy = route("get", "/v1/admin/operations/privacy", "listAdminPrivacy", "Admin Operations", { query: z.object({ limit: limit.optional() }) });
  register(adminPrivacy, async (context) => dataResponse(context, await repositories(context, options).adminOperations.listPrivacy(limit.parse(context.req.query("limit")))));
  const retryJob = route("post", "/v1/admin/operations/jobs/{job_id}/retry", "retryAdminJob", "Admin Operations", { pathParams: z.object({ job_id: uuid }), headers: z.object({ "idempotency-key": idempotencyKey }) });
  register(retryJob, async (context) => dataResponse(context, { outbox_id: await repositories(context, options).adminOperations.requestJobRetry(uuid.parse(context.req.param("job_id")), idempotencyKey.parse(context.req.header("idempotency-key"))) }));

  return app;
}
