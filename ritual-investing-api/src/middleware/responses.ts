import type { Context } from "hono";
import type { ContentfulStatusCode } from "hono/utils/http-status";

import type { ErrorResponse } from "../contracts/common.ts";
import { requestIdFrom } from "./request-context.ts";

export function errorResponse(
  context: Context,
  status: ContentfulStatusCode,
  code: string,
  message: string,
  options: { retryable?: boolean; retryAfterSeconds?: number } = {},
): Response {
  const body: ErrorResponse = {
    error: {
      code,
      message,
      request_id: requestIdFrom(context),
      field_errors: [],
      retryable: options.retryable ?? false,
      ...(options.retryAfterSeconds === undefined
        ? {}
        : { retry_after_seconds: options.retryAfterSeconds }),
    },
  };
  context.header("cache-control", "private, no-store");
  if (options.retryAfterSeconds !== undefined) {
    context.header("retry-after", String(options.retryAfterSeconds));
  }
  return context.json(body, status);
}
