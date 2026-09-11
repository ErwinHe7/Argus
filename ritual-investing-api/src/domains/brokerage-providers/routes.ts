import { getBrokerageProviderCatalog } from "./catalog.ts";
import { brokerageProviderCatalogResponseSchema } from "./schemas.ts";
import {
  dataResponse,
  retainedRoute,
  type RetainedRouteRegistrar,
} from "../retained-http/boundary.ts";

export function registerBrokerageProviderRoutes(input: Readonly<{
  register: RetainedRouteRegistrar;
}>): void {
  const catalog = retainedRoute(
    "get",
    "/v1/brokerage/providers",
    "getBrokerageProviderCatalog",
    "Brokerage Providers",
    {
      transaction: "none",
      description: "US broker integration readiness and required setup. This is not an account connection, live capability grant, or order authorization.",
      response: brokerageProviderCatalogResponseSchema,
    },
  );
  input.register(catalog, async (context) =>
    dataResponse(context, getBrokerageProviderCatalog()));
}
