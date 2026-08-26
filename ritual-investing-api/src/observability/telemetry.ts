import type { MiddlewareHandler } from "hono";

import type { AppEnvironment } from "../app.ts";
import { requestIdFrom } from "../middleware/request-context.ts";

export type TelemetryEvent = {
  event_version: 1;
  event_name: string;
  severity: "info" | "warn" | "error";
  environment: string;
  outcome: string;
  request_id?: string;
  method?: string;
  route?: string;
  route_class?: "platform" | "public" | "member" | "admin";
  status?: number;
  latency_ms?: number;
  dependency?: "auth0" | "neon" | "queue" | "r2" | "access";
  consumer?: string;
  attempt?: number;
  failure_code?: string;
};

export type TelemetrySink = (event: TelemetryEvent) => void | Promise<void>;

const SAFE_EVENT_NAME = /^[a-z][a-z0-9_.-]{0,63}$/;
const SAFE_OUTCOME = /^[a-z][a-z0-9_.-]{0,63}$/;
const SAFE_CODE = /^[a-z][a-z0-9_]{0,63}$/;
const SAFE_CONSUMER = /^[a-z][a-z0-9_-]{0,63}$/;

function safeToken(value: string, pattern: RegExp, fallback: string) {
  return pattern.test(value) ? value : fallback;
}

export function sanitizeTelemetryEvent(event: TelemetryEvent): TelemetryEvent {
  return {
    event_version: 1,
    event_name: safeToken(
      event.event_name,
      SAFE_EVENT_NAME,
      "telemetry.invalid",
    ),
    severity: event.severity,
    environment: safeToken(event.environment, SAFE_CODE, "unknown"),
    outcome: safeToken(event.outcome, SAFE_OUTCOME, "unknown"),
    ...(event.request_id === undefined
      ? {}
      : {
          request_id: /^[0-9a-f-]{36}$/i.test(event.request_id)
            ? event.request_id
            : "invalid",
        }),
    ...(event.method === undefined
      ? {}
      : {
          method: /^(GET|POST|PUT|PATCH|DELETE|OPTIONS)$/.test(event.method)
            ? event.method
            : "OTHER",
        }),
    ...(event.route === undefined
      ? {}
      : { route: normalizeRoute(event.route) }),
    ...(event.route_class === undefined
      ? {}
      : { route_class: event.route_class }),
    ...(event.status === undefined
      ? {}
      : { status: Math.max(0, Math.min(599, Math.trunc(event.status))) }),
    ...(event.latency_ms === undefined
      ? {}
      : {
          latency_ms: Math.max(
            0,
            Math.min(3_600_000, Math.round(event.latency_ms)),
          ),
        }),
    ...(event.dependency === undefined ? {} : { dependency: event.dependency }),
    ...(event.consumer === undefined
      ? {}
      : { consumer: safeToken(event.consumer, SAFE_CONSUMER, "unknown") }),
    ...(event.attempt === undefined
      ? {}
      : { attempt: Math.max(0, Math.min(100, Math.trunc(event.attempt))) }),
    ...(event.failure_code === undefined
      ? {}
      : {
          failure_code: safeToken(
            event.failure_code,
            SAFE_CODE,
            "internal_failure",
          ),
        }),
  };
}

export function createTelemetrySink(
  writeLine: (serialized: string) => void = console.log,
): TelemetrySink {
  return (event) => writeLine(JSON.stringify(sanitizeTelemetryEvent(event)));
}

export async function emitOperationalTelemetry(
  environment: string,
  event: Omit<TelemetryEvent, "event_version" | "environment">,
  injectedSink?: TelemetrySink,
): Promise<void> {
  const complete = sanitizeTelemetryEvent({
    event_version: 1,
    ...event,
    environment,
  });
  if (injectedSink !== undefined) await injectedSink(complete);
  else if (environment !== "test") await createTelemetrySink()(complete);
}

export function normalizeRoute(path: string): string {
  const cleanPath = path.split("?", 1)[0] ?? "/";
  return cleanPath
    .replaceAll(
      /[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/gi,
      "{id}",
    )
    .replaceAll(/\b[0-9A-HJKMNP-TV-Z]{26}\b/gi, "{id}")
    .replaceAll(/\b\d{6,}\b/g, "{number}")
    .slice(0, 256);
}

function routeClass(path: string): NonNullable<TelemetryEvent["route_class"]> {
  if (path.startsWith("/v1/admin/")) return "admin";
  if (path.startsWith("/v1/public/")) return "public";
  if (
    path === "/health" ||
    path.startsWith("/v1/health") ||
    path === "/v1/openapi.json"
  )
    return "platform";
  return "member";
}

function outcome(status: number) {
  if (status === 401) return "authentication_denied";
  if (status === 403 || status === 404) return "authorization_denied";
  if (status === 409) return "conflict";
  if (status === 429) return "rate_limited";
  if (status >= 500) return "dependency_or_internal_failure";
  if (status >= 400) return "rejected";
  return "success";
}

export function telemetryMiddleware(
  injectedSink?: TelemetrySink,
): MiddlewareHandler<AppEnvironment> {
  return async (context, next) => {
    const startedAt = performance.now();
    await next();
    const event: TelemetryEvent = {
      event_version: 1,
      event_name: "http.request",
      severity:
        context.res.status >= 500
          ? "error"
          : context.res.status >= 400
            ? "warn"
            : "info",
      environment: context.env?.ENVIRONMENT ?? "unknown",
      outcome: outcome(context.res.status),
      request_id: requestIdFrom(context),
      method: context.req.method,
      route: context.req.path,
      route_class: routeClass(context.req.path),
      status: context.res.status,
      latency_ms: performance.now() - startedAt,
    };
    if (injectedSink !== undefined)
      await injectedSink(sanitizeTelemetryEvent(event));
    else if (context.env?.ENVIRONMENT !== "test")
      await createTelemetrySink()(event);
  };
}
