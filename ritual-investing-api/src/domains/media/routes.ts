import { z } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { MediaRepository } from "./ports.ts";
import {
  dataResponse,
  parseBody,
  retainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";
import { uuidSchema } from "../retained-http/schemas.ts";
import type { RetainedAppEnvironment } from "../retained-http/types.ts";

export type MediaRouteRepository = MediaRepository;

export function registerMediaRoutes(
  input: Readonly<{
    register: RetainedRouteRegistrar;
    repository: (
      context: Context<RetainedAppEnvironment>,
    ) => MediaRouteRepository;
  }>,
): void {
  const uploadIntentBody = z.object({
    mimeType: z.enum(["image/jpeg", "image/png", "image/webp"]),
    maxBytes: z.number().int().min(1).max(10 * 1024 * 1024),
    expiresAt: z.coerce.date(),
  }).strict();
  const createUploadIntent = retainedRoute(
    "post",
    "/v1/media/upload-intents",
    "createUploadIntent",
    "Media",
    { body: uploadIntentBody },
  );
  input.register(createUploadIntent, async (context) =>
    dataResponse(
      context,
      await input.repository(context).createUploadIntent(
        await parseBody(context, uploadIntentBody),
      ),
    ));

  const intentPath = z.object({ intent_id: uuidSchema });
  const getUploadIntent = retainedRoute(
    "get",
    "/v1/media/upload-intents/{intent_id}",
    "getUploadIntent",
    "Media",
    { pathParams: intentPath },
  );
  input.register(getUploadIntent, async (context) =>
    dataResponse(
      context,
      await input.repository(context).getUploadIntent(
        uuidSchema.parse(context.req.param("intent_id")),
      ),
    ));

  const finalizeBody = z.object({
    byteSize: z.number().int().positive(),
    checksum: z.string().regex(/^[a-f0-9]{64}$/),
  }).strict();
  const finalizeMedia = retainedRoute(
    "post",
    "/v1/media/upload-intents/{intent_id}/finalize",
    "finalizeUpload",
    "Media",
    { pathParams: intentPath, body: finalizeBody },
  );
  input.register(finalizeMedia, async (context) => {
    const body = await parseBody(context, finalizeBody);
    return dataResponse(
      context,
      await input.repository(context).finalizeUpload(
        uuidSchema.parse(context.req.param("intent_id")),
        body.byteSize,
        body.checksum,
      ),
    );
  });
}
