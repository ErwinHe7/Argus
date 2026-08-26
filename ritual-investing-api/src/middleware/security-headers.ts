import { bodyLimit } from "hono/body-limit";
import { cors } from "hono/cors";
import type { MiddlewareHandler } from "hono";
import { secureHeaders } from "hono/secure-headers";

import type { AppEnvironment } from "../app.ts";
import type { Bindings } from "../config/env.ts";
import { errorResponse } from "./responses.ts";

const browserHeaders = secureHeaders({
  contentSecurityPolicy: {
    defaultSrc: ["'none'"],
    baseUri: ["'none'"],
    formAction: ["'none'"],
    frameAncestors: ["'none'"],
    objectSrc: ["'none'"],
  },
  strictTransportSecurity: false,
  xFrameOptions: "DENY",
  referrerPolicy: "no-referrer",
  permissionsPolicy: {
    camera: false,
    microphone: false,
    geolocation: false,
    payment: false,
    usb: false,
  },
});

export const securityHeaders: MiddlewareHandler<AppEnvironment> = async (context, next) => {
  await browserHeaders(context, async () => {
    await next();
  });
  const environment = context.env as Bindings | undefined;
  if (environment?.ENVIRONMENT === "production") {
    context.header("strict-transport-security", "max-age=31536000; includeSubDomains");
  } else {
    context.res.headers.delete("strict-transport-security");
  }
  if (
    context.req.header("authorization") !== undefined
    || new URL(context.req.url).pathname.startsWith("/v1/admin/")
  ) {
    context.header("cache-control", "private, no-store");
  }
};

export const exactOriginCors: MiddlewareHandler<AppEnvironment> = async (context, next) => {
  const environment = context.env as Bindings | undefined;
  const requestHost = new URL(context.req.url).hostname.toLowerCase();
  const allowedOrigin = requestHost === environment?.ADMIN_HOST?.toLowerCase()
    ? environment.ADMIN_ORIGIN
    : environment?.CONSUMER_ORIGIN;
  const middleware = cors({
    origin: (origin) => origin === allowedOrigin ? origin : undefined,
    allowMethods: ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowHeaders: [
      "authorization",
      "content-type",
      "if-match",
      "idempotency-key",
      "x-request-id",
    ],
    exposeHeaders: ["etag", "retry-after", "x-request-id"],
    maxAge: 600,
    credentials: false,
  });
  await middleware(context, next);
};

export const requestMediaBoundary: MiddlewareHandler<AppEnvironment> = async (context, next) => {
  const method = context.req.method;
  if (!["POST", "PUT", "PATCH"].includes(method)) {
    await next();
    return;
  }
  const encoding = context.req.header("content-encoding");
  if (encoding !== undefined && encoding.toLowerCase() !== "identity") {
    return errorResponse(context, 415, "unsupported_media_type", "The content encoding is not supported.");
  }
  const contentType = context.req.header("content-type");
  const hasBody = context.req.raw.body !== null
    && context.req.header("content-length") !== "0";
  if (contentType === undefined && hasBody) {
    return errorResponse(context, 415, "unsupported_media_type", "JSON requests require application/json.");
  }
  if (contentType !== undefined && contentType.split(";", 1)[0]?.trim().toLowerCase() !== "application/json") {
    return errorResponse(context, 415, "unsupported_media_type", "JSON requests require application/json.");
  }
  await next();
};

export const rejectRequestBody: MiddlewareHandler<AppEnvironment> = async (context, next) => {
  if (context.req.raw.body !== null && (await context.req.raw.text()).length > 0) {
    return errorResponse(
      context,
      422,
      "validation_failed",
      "This operation does not accept a request body.",
    );
  }
  await next();
};

export const requireRequestBody: MiddlewareHandler<AppEnvironment> = async (context, next) => {
  if (context.req.raw.body === null) {
    return errorResponse(
      context,
      422,
      "validation_failed",
      "This operation requires a JSON request body.",
    );
  }
  await next();
};

function limitedBody(maxSize: number): MiddlewareHandler<AppEnvironment> {
  return bodyLimit({
    maxSize,
    onError: (context) => errorResponse(
      context,
      413,
      "payload_too_large",
      "The request body exceeds the allowed size.",
    ),
  });
}

export const consumerBodyLimit = limitedBody(64 * 1024);
export const adminBodyLimit = limitedBody(256 * 1024);
