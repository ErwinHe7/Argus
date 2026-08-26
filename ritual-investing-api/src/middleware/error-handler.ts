import type { ErrorHandler } from "hono";
import { HTTPException } from "hono/http-exception";
import type { ZodError } from "zod";

import type { AppEnvironment } from "../app.ts";
import type { ErrorResponse } from "../contracts/common.ts";
import { requestIdFrom } from "./request-context.ts";

export function validationError(
  requestId: string,
  error: ZodError,
): ErrorResponse {
  return {
    error: {
      code: "validation_failed",
      message: "The request is invalid.",
      request_id: requestId,
      field_errors: error.issues.slice(0, 50).map((issue) => ({
        path: issue.path.length > 0 ? issue.path.join(".") : "request",
        code: issue.code,
      })),
      retryable: false,
    },
  };
}

export const errorHandler: ErrorHandler<AppEnvironment> = (error, context) => {
  const requestId = requestIdFrom(context);
  if (error instanceof HTTPException && error.status === 400) {
    context.header("cache-control", "private, no-store");
    return context.json(
      {
        error: {
          code: "validation_failed",
          message: "The request is invalid.",
          request_id: requestId,
          field_errors: [{ path: "request", code: "invalid_json" }],
          retryable: false,
        },
      } satisfies ErrorResponse,
      422,
    );
  }
  console.error("request_failed", {
    request_id: requestId,
    error_type: error.name,
  });

  return context.json(
    {
      error: {
        code: "internal_error",
        message: "The request could not be completed.",
        request_id: requestId,
        field_errors: [],
        retryable: false,
      },
    } satisfies ErrorResponse,
    500,
  );
};
