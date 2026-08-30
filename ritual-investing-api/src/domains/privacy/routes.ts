import { z } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { PrivacyRequestService } from "./service.ts";
import {
  privacyRequestCollectionResponseSchema,
  privacyRequestResponseSchema,
} from "../engagement/schemas.ts";
import {
  dataResponse,
  parseBody,
  rejectBody,
  retainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";
import {
  idempotencyKeySchema,
  retainedEnvelope,
  uuidSchema,
} from "../retained-http/schemas.ts";
import type { RetainedAppEnvironment } from "../retained-http/types.ts";

export type PrivacyRouteService = PrivacyRequestService;

export function registerPrivacyRoutes(input: Readonly<{
  register: RetainedRouteRegistrar;
  service: (context: Context<RetainedAppEnvironment>) => PrivacyRouteService;
}>): void {
  const listPrivacy = retainedRoute(
    "get",
    "/v1/privacy/requests",
    "listPrivacyRequests",
    "Privacy",
    {
      transaction: "none",
      response: privacyRequestCollectionResponseSchema,
    },
  );
  input.register(listPrivacy, async (context) =>
    dataResponse(context, await input.service(context).list()));

  const privacyBody = z.object({
    requestType: z.enum(["export", "deletion"]),
    step_up_receipt: z.string().min(32).max(512).regex(/^[A-Za-z0-9_-]+$/)
      .optional(),
  }).strict().superRefine((value, context) => {
    if (value.requestType === "deletion" && value.step_up_receipt === undefined) {
      context.addIssue({
        code: "custom",
        path: ["step_up_receipt"],
        message: "Deletion requires an action-bound step-up receipt.",
      });
    }
    if (value.requestType === "export" && value.step_up_receipt !== undefined) {
      context.addIssue({
        code: "custom",
        path: ["step_up_receipt"],
        message: "Export requests do not accept a step-up receipt.",
      });
    }
  }).openapi("RequestPrivacyActionRequest");
  const requestPrivacy = retainedRoute(
    "post",
    "/v1/privacy/requests",
    "requestPrivacyAction",
    "Privacy",
    {
      transaction: "none",
      body: privacyBody,
      headers: z.object({ "idempotency-key": idempotencyKeySchema }),
      response: privacyRequestResponseSchema,
    },
  );
  input.register(requestPrivacy, async (context) => {
    const body = await parseBody(context, privacyBody);
    return dataResponse(
      context,
      await input.service(context).request(
        body.requestType,
        idempotencyKeySchema.parse(context.req.header("idempotency-key")),
        body.step_up_receipt,
      ),
    );
  });

  const createDownload = retainedRoute(
    "post",
    "/v1/privacy/requests/{request_id}/download-url",
    "createPrivacyDownloadUrl",
    "Privacy",
    {
      transaction: "none",
      pathParams: z.object({ request_id: uuidSchema }),
      description:
        "Mint an owner-scoped privacy export URL with at most 30 seconds of residual lifetime.",
      response: retainedEnvelope(
        "PrivacyDownloadUrlResponse",
        z.object({
          url: z.string().url(),
          expires_at: z.string().datetime(),
        }).strict().openapi("PrivacyDownloadUrl"),
      ),
    },
  );
  input.register(createDownload, async (context) => {
    await rejectBody(context);
    return dataResponse(
      context,
      await input.service(context).createDownloadUrl(
        uuidSchema.parse(context.req.param("request_id")),
      ),
    );
  });

  const download = retainedRoute(
    "get",
    "/v1/privacy/requests/{request_id}/download",
    "downloadPrivacyExport",
    "Privacy",
    {
      transaction: "none",
      pathParams: z.object({ request_id: uuidSchema }),
      description: "Stream the current owner-scoped privacy export.",
      responseMediaType: "application/zip",
      response: z.string().openapi({ format: "binary" }),
    },
  );
  input.register(download, async (context) => {
    await rejectBody(context);
    const artifact = await input.service(context).download(
      uuidSchema.parse(context.req.param("request_id")),
    );
    context.header("cache-control", "private, no-store");
    context.header(
      "content-disposition",
      'attachment; filename="ritual-private-export.zip"',
    );
    context.header("content-length", String(artifact.byteSize));
    context.header("content-type", artifact.contentType);
    context.header("x-content-sha256", artifact.contentChecksum);
    return context.body(artifact.body);
  });
}
