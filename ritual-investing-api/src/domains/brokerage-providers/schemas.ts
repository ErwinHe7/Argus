import { z } from "@hono/zod-openapi";
import { retainedEnvelope } from "../retained-http/schemas.ts";

export const brokerageProviderRequirementSchema = z.object({
  id: z.string().min(1).max(64),
  label: z.string().min(1).max(400),
  status: z.literal("required"),
}).strict().openapi("BrokerageProviderRequirement");

export const brokerageProviderReadinessSchema = z.object({
  id: z.enum(["ibkr", "moomoo", "webull"]),
  name: z.string().min(1).max(64),
  status: z.literal("setup_required"),
  connection_available: z.literal(false),
  manual_orders_available: z.literal(false),
  integration_mode: z.enum(["third_party_oauth", "oauth_2_1_pkce", "webull_connect"]),
  implementation: z.enum(["adapter_pending", "fixture_validated_connection_and_manual_orders"]),
  reason_codes: z.array(z.string().min(1).max(80)).min(1).max(10),
  requirements: z.array(brokerageProviderRequirementSchema).min(1).max(10),
  documentation_url: z.url().startsWith("https://"),
  next_step: z.string().min(1).max(600),
}).strict().openapi("BrokerageProviderReadiness");

export const brokerageProviderCatalogSchema = z.object({
  launch_region: z.literal("US"),
  execution_mode: z.literal("user_confirmed"),
  automatic_execution: z.literal(false),
  providers: z.array(brokerageProviderReadinessSchema).length(3),
}).strict().openapi("BrokerageProviderCatalog");

export const brokerageProviderCatalogResponseSchema = retainedEnvelope(
  "BrokerageProviderCatalogResponse",
  brokerageProviderCatalogSchema,
);
