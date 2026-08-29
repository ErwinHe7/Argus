import { z } from "@hono/zod-openapi";
import type { Context } from "hono";

import type { EditorialRepository } from "./ports.ts";
import {
  editorialCollectionResponseSchema,
  editorialItemResponseSchema,
} from "./schemas.ts";
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

export type EditorialRouteRepository = EditorialRepository;

export function registerEditorialRoutes(
  input: Readonly<{
    register: RetainedRouteRegistrar;
    repository: (
      context: Context<RetainedAppEnvironment>,
    ) => EditorialRouteRepository;
  }>,
): void {
  const kindSchema = z.string().min(1).max(80);
  const listEditorial = retainedRoute(
    "get",
    "/v1/editorial/{kind}",
    "listEditorial",
    "Editorial",
    {
      pathParams: z.object({ kind: kindSchema }),
      query: pagedContentQuery,
      response: editorialCollectionResponseSchema,
    },
  );
  input.register(listEditorial, async (context) => {
    const kind = kindSchema.parse(context.req.param("kind"));
    const pageSize = pageLimitSchema.parse(context.req.query("limit"));
    const baseBinding = {
      resource: "editorial:list:v1",
      scope: "member",
      verifiedSubject: context.get("claims").userId,
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
  const getEditorial = retainedRoute(
    "get",
    "/v1/editorial/items/{slug}",
    "getEditorial",
    "Editorial",
    {
      pathParams: z.object({ slug: slugSchema }),
      response: editorialItemResponseSchema,
    },
  );
  input.register(getEditorial, async (context) =>
    dataResponse(
      context,
      await input.repository(context).getPublished(
        slugSchema.parse(context.req.param("slug")),
      ),
    ));
}
