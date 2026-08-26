import type { MiddlewareHandler } from "hono";

import type { AppEnvironment } from "../app.ts";
import { restoreCutoverReady } from "../jobs/deletion-restore.ts";
import { errorResponse } from "./responses.ts";

export const requireRestoreCutover: MiddlewareHandler<AppEnvironment> = async (
  context,
  next,
) => {
  const pathname = new URL(context.req.url).pathname;
  if (pathname === "/v1/health/live" || pathname === "/v1/openapi.json") {
    await next();
    return;
  }
  const environment = context.env as AppEnvironment["Bindings"] | undefined;
  if (
    !(await restoreCutoverReady(
      environment?.DELETION_DENY_JOURNAL,
      environment?.EXPECTED_RESTORE_EPOCH,
    ))
  ) {
    return errorResponse(
      context,
      503,
      "restore_replay_pending",
      "Traffic is paused until deletion denials are replayed.",
      { retryable: true },
    );
  }
  await next();
};
