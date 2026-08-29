import {
  createRoute,
  type OpenAPIHono,
  type RouteConfig,
  z,
} from "@hono/zod-openapi";
import type { Context } from "hono";

import type { VerifiedRequestClaims } from "../../db/request-context.ts";
import { sha256TextHex } from "../../security/sha256.ts";
import { errorSchema, responseSchema, uuidSchema } from "./schemas.ts";
import type {
  RetainedAppEnvironment,
  VerifiedSupabasePrincipal,
} from "./types.ts";

export class HttpBoundaryError extends Error {
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

export function errorResponse(
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

export function bearerToken(value: string | undefined): string | null {
  if (value === undefined || value.length > 16_391) return null;
  const match = /^Bearer ([A-Za-z0-9._~-]+)$/.exec(value);
  return match?.[1] ?? null;
}

export function claimsFrom(
  principal: VerifiedSupabasePrincipal,
): VerifiedRequestClaims {
  return Object.freeze({
    userId: uuidSchema.parse(principal.userId),
    sessionId: uuidSchema.parse(principal.sessionId),
    aal: principal.aal,
  });
}

export async function digest(value: string): Promise<string> {
  return sha256TextHex(value);
}

export function normalizedRoute(path: string): string {
  return path
    .replace(
      /[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/gi,
      "{id}",
    )
    .slice(0, 256);
}

export async function parseBody<T>(
  context: Context<RetainedAppEnvironment>,
  schema: z.ZodType<T>,
): Promise<T> {
  try {
    return schema.parse(context.req.valid("json" as never));
  } catch {
    throw new HttpBoundaryError(
      422,
      "validation_failed",
      "The request body failed validation.",
    );
  }
}

export async function rejectBody(
  context: Context<RetainedAppEnvironment>,
): Promise<void> {
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

export function expectedVersion(
  context: Context<RetainedAppEnvironment>,
): number {
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

export function dataResponse(
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
  const version = typeof data === "object" &&
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

export function collectionDataResponse(
  context: Context<RetainedAppEnvironment>,
  data: unknown,
  nextCursor: string | null = null,
): Response {
  return context.json(
    {
      data,
      meta: {
        request_id: context.get("requestId"),
        next_cursor: nextCursor,
        has_more: nextCursor !== null,
      },
    },
    200,
  );
}

export function query(context: Context<RetainedAppEnvironment>) {
  return Object.fromEntries(new URL(context.req.url).searchParams.entries());
}

export type RouteOptions = Readonly<{
  public?: boolean;
  transaction?: RetainedTransactionPolicy;
  body?: z.ZodType;
  optionalBody?: boolean;
  pathParams?: z.ZodType;
  query?: z.ZodType;
  headers?: z.ZodType;
  description?: string;
  response?: z.ZodType;
  acceptedResponse?: z.ZodType;
}>;

export type RetainedTransactionPolicy =
  | "none"
  | "member"
  | "runtime"
  | "public-preview"
  | Readonly<{
    mode: "runtime-staff" | "staff";
    permission?: string;
  }>;

export type RouteAccess = Readonly<{
  isPublic: boolean;
  isAdmin: boolean;
  transaction: RetainedTransactionPolicy;
}>;
const routeAccess = new WeakMap<object, RouteAccess>();

export function retainedRoute(
  method: "get" | "post" | "put" | "patch" | "delete",
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
      required: options.optionalBody !== true,
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
      ...(options.acceptedResponse === undefined ? {} : {
        202: {
          description: "The requested resource is still being prepared.",
          content: {
            "application/json": { schema: options.acceptedResponse },
          },
        },
      }),
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
    transaction: options.transaction ??
      (options.public === true ? "none" : "member"),
  });
  return definition;
}

export type RetainedRouteDefinition = ReturnType<typeof retainedRoute>;
export type RetainedRouteRegistrar = (
  definition: RetainedRouteDefinition,
  handler: (
    context: Context<RetainedAppEnvironment>,
  ) => Response | Promise<Response>,
) => void;

export function mountRetainedRoute(
  app: OpenAPIHono<RetainedAppEnvironment>,
  definition: RetainedRouteDefinition,
  handler: Parameters<RetainedRouteRegistrar>[1],
): void {
  app.openapi(definition as never, handler as never);
}

export function retainedRouteAccess(
  definition: RetainedRouteDefinition,
): RouteAccess | undefined {
  return routeAccess.get(definition);
}
