import type { OpenAPIHono } from "@hono/zod-openapi";

import type { AppEnvironment } from "../../app.ts";
import { registerAssetRoutes } from "../assets/routes.ts";
import { registerCovenRoutes } from "../coven/routes.ts";
import { registerDiscoverRoutes } from "../discover/routes.ts";
import { registerPublicPreviewRoutes } from "../public-preview/routes.ts";
import { registerRitualRoutes } from "../rituals/routes.ts";
import { registerRowanRoutes } from "../rowan/routes.ts";
import { registerSearchRoutes } from "../search/routes.ts";
import type { ContentRouteDependencies } from "./route-support.ts";

export function registerEditorialContentRoutes(
  app: OpenAPIHono<AppEnvironment>,
  dependencies: ContentRouteDependencies = {},
): void {
  registerPublicPreviewRoutes(app, dependencies);
  registerRitualRoutes(app, dependencies);
  registerRowanRoutes(app, dependencies);
  registerAssetRoutes(app, dependencies);
  registerCovenRoutes(app, dependencies);
  registerDiscoverRoutes(app, dependencies);
  registerSearchRoutes(app, dependencies);
}
