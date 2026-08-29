import { z } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { PublicPreviewRepository } from "./ports.ts";
import {
  editorialCollectionResponseSchema,
  editorialItemResponseSchema,
} from "../editorial/schemas.ts";
import {
  collectionDataResponse,
  dataResponse,
  retainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";
import {
  cursorFilterIdentity,
  keysetPage,
  pagedContentQuery,
  typedKeysetPosition,
} from "../content/pagination.ts";
import { pageLimitSchema, uuidSchema } from "../retained-http/schemas.ts";
import type { RetainedAppEnvironment } from "../retained-http/types.ts";

export type PublicPreviewRouteRepository = PublicPreviewRepository;

export function registerPublicPreviewRoutes(
  input: Readonly<{
    register: RetainedRouteRegistrar;
    repository: (
      context: Context<RetainedAppEnvironment>,
    ) => PublicPreviewRouteRepository;
  }>,
): void {
  const kindSchema = z.string().min(1).max(80);
  const publicList = retainedRoute(
    "get",
    "/v1/public/editorial/{kind}",
    "listPublicEditorial",
    "Public",
    {
      public: true,
      transaction: "public-preview",
      pathParams: z.object({ kind: kindSchema }),
      query: pagedContentQuery,
      response: editorialCollectionResponseSchema,
    },
  );
  input.register(publicList, async (context) => {
    const kind = kindSchema.parse(context.req.param("kind"));
    const pageSize = pageLimitSchema.parse(context.req.query("limit"));
    const baseBinding = {
      resource: "public-editorial:list:v1",
      scope: "public-preview",
      verifiedSubject: "anonymous",
      filterIdentity: cursorFilterIdentity({ kind }),
      pageSize,
    } as const;
    const cursor = context.req.query("cursor");
    const binding = cursor === undefined
      ? baseBinding
      : { ...baseBinding, cursor };
    const after = await typedKeysetPosition(
      binding,
      z.tuple([z.string().min(1).max(120), uuidSchema]),
    );
    const rows = await input.repository(context).listPublishedPage({
      kind,
      limit: pageSize + 1,
      after,
    });
    const page = await keysetPage(binding, rows, (row) => [
      String(row.slug),
      String(row.id),
    ]);
    return collectionDataResponse(
      context,
      page.items,
      page.nextCursor,
    );
  });

  const slugSchema = z.string().min(1).max(120);
  const publicGet = retainedRoute(
    "get",
    "/v1/public/editorial/items/{slug}",
    "getPublicEditorial",
    "Public",
    {
      public: true,
      transaction: "public-preview",
      pathParams: z.object({ slug: slugSchema }),
      response: editorialItemResponseSchema,
    },
  );
  input.register(publicGet, async (context) =>
    dataResponse(
      context,
      await input.repository(context).getPublished(
        slugSchema.parse(context.req.param("slug")),
      ),
    ));
}
