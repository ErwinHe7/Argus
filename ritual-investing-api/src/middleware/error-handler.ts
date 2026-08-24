import type { ErrorHandler } from "hono";
import type { ZodError } from "zod";

import type { Bindings } from "../config/env.ts";
import type { ErrorResponse } from "../contracts/common.ts";
import { requestIdFrom, type RequestContextVariables } from "./request-context.ts";

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

export const errorHandler: ErrorHandler<{
  Bindings: Bindings;
  Variables: RequestContextVariables;
}> = (error, context) => {
  const requestId = requestIdFrom(context);
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
