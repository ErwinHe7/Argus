import {
  dataResponse,
  retainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";
import type { PlatformContractService } from "./service.ts";

export function registerPlatformRoutes(input: Readonly<{
  register: RetainedRouteRegistrar;
  contract: PlatformContractService;
}>): void {
  const health = retainedRoute(
    "get",
    "/v1/health/live",
    "getLiveHealth",
    "Platform",
    { public: true },
  );
  input.register(health, (context) =>
    dataResponse(context, {
      status: "ok",
      build_revision: context.env.buildRevision,
    }));

  const openapi = retainedRoute(
    "get",
    "/v1/openapi.json",
    "getOpenApiDocument",
    "Platform",
    { public: true },
  );
  input.register(openapi, async (context) => {
    const contract = await input.contract.serializedContract();
    context.header("etag", contract.etag);
    context.header("cache-control", "public, max-age=300");
    if (context.req.header("if-none-match") === contract.etag) {
      return context.body(null, 304);
    }
    return context.body(contract.body, 200, {
      "content-type": "application/json; charset=UTF-8",
    });
  });
}
