import {
  createSupabaseAccountRepository,
  createSupabaseAdminOperationsRepository,
  createSupabaseAdminRepository,
  createSupabaseAssetRepository,
  createSupabaseBriefingRepository,
  createSupabaseCircleRepository,
  createSupabaseCovenRepository,
  createSupabaseDiscoverRepository,
  createSupabaseEditorialRepository,
  createSupabaseMediaRepository,
  createSupabaseModerationRepository,
  createSupabaseNotificationRepository,
  createSupabasePrivacyRepository,
  createSupabasePublicPreviewRepository,
  createSupabaseRitualRepository,
  createSupabaseRowanRepository,
  createSupabaseSearchRepository,
  createSupabaseSessionRepository,
} from "../../../ritual-investing-api/src/db/supabase-repositories.ts";
import {
  createRetainedApp,
  type RetainedRepositorySet,
} from "../../../ritual-investing-api/src/retained-app.ts";

import { createSupabaseAccessTokenVerifier } from "../_shared/auth.ts";
import { createSupabaseDatabasePool } from "../_shared/database.ts";
import { rewriteSupabaseFunctionRequest } from "../_shared/http.ts";
import { createPostgresRateLimitPort } from "../_shared/rate-limit.ts";
import { createBrokerageConnectionRepository } from "../../../ritual-investing-api/src/domains/brokerage-connections/repository.ts";
import { createBlockedWebullProvider } from "../_shared/webull/client.ts";
import { parsePartnerConfirmedContractFromEnvironment } from "../_shared/webull/contract.ts";
import { createBrokerageProjectionRepository } from "../../../ritual-investing-api/src/domains/brokerage-projections/repository.ts";
import {
  createBlockedBrokerageProjectionProvider,
  createBrokerageProjectionService,
} from "../../../ritual-investing-api/src/domains/brokerage-projections/service.ts";
import { createBrokerageOrderRepository } from "../../../ritual-investing-api/src/domains/brokerage-orders/repository.ts";
import {
  createBlockedBrokerageOrderProvider,
  createBrokerageOrderService,
} from "../../../ritual-investing-api/src/domains/brokerage-orders/service.ts";

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (value === undefined || value.length === 0) {
    throw new Error(`missing_${name.toLowerCase()}`);
  }
  return value;
}

const environment = (Deno.env.get("ARGUS_ENVIRONMENT") ?? "development") as
  | "development"
  | "test"
  | "staging"
  | "production";
if (!["development", "test", "staging", "production"].includes(environment)) {
  throw new Error("invalid_argus_environment");
}

const supabaseUrl = requiredEnvironment("SUPABASE_URL");
const databasePool = createSupabaseDatabasePool(
  requiredEnvironment("SUPABASE_DB_URL"),
);
const configuredWebullContract = parsePartnerConfirmedContractFromEnvironment(
  (name) => Deno.env.get(name),
);
// Keep every non-brokerage API route available if configuration is promoted
// before the versioned account fixture/parser ships. Brokerage remains
// fail-closed at the route boundary instead of crashing the whole function.
const blockedWebull = createBlockedWebullProvider(
  "confirmationReference" in configuredWebullContract
    ? configuredWebullContract.publicContract
    : configuredWebullContract,
);
const blockedWebullContract =
  "confirmationReference" in configuredWebullContract
    ? configuredWebullContract.publicContract
    : configuredWebullContract;

const createRepositories: Parameters<
  typeof createRetainedApp
>[0]["createRepositories"] = (claims): RetainedRepositorySet => {
  const binding = { pool: databasePool, claims };
  return Object.freeze({
    session: createSupabaseSessionRepository(binding),
    accounts: createSupabaseAccountRepository(binding),
    assets: createSupabaseAssetRepository(binding),
    editorial: createSupabaseEditorialRepository(binding),
    briefings: createSupabaseBriefingRepository(binding),
    circles: createSupabaseCircleRepository(binding),
    coven: createSupabaseCovenRepository(binding),
    discover: createSupabaseDiscoverRepository(binding),
    media: createSupabaseMediaRepository(binding),
    moderation: createSupabaseModerationRepository(binding),
    notifications: createSupabaseNotificationRepository(binding),
    privacy: createSupabasePrivacyRepository(binding),
    rituals: createSupabaseRitualRepository(binding),
    rowan: createSupabaseRowanRepository(binding),
    search: createSupabaseSearchRepository(binding),
    admin: createSupabaseAdminRepository(binding),
    adminOperations: createSupabaseAdminOperationsRepository(binding),
  });
};

const app = createRetainedApp({
  verifyAccessToken: createSupabaseAccessTokenVerifier({ supabaseUrl }),
  createRepositories,
  publicPreviewRepository: createSupabasePublicPreviewRepository(databasePool),
  rateLimit: createPostgresRateLimitPort(databasePool),
  createBrokerageConnections: (claims) =>
    createBrokerageConnectionRepository({
      pool: databasePool,
      claims,
      authorization: {
        contractVersion: blockedWebullContract.version,
        environment: blockedWebullContract.environment,
        authorizationUrl: blockedWebull.authorizationUrl,
      },
    }),
  createBrokerageProjections: (claims) =>
    createBrokerageProjectionService({
      repository: createBrokerageProjectionRepository({
        pool: databasePool,
        claims,
      }),
      // The U5 public-contract conflicts remain unresolved. Cached synthetic
      // generations can be served, but provider egress stays fail-closed until
      // a versioned partner read fixture and approval gate are configured.
      provider: createBlockedBrokerageProjectionProvider(),
    }),
  createBrokerageOrders: (claims) =>
    createBrokerageOrderService({
      repository: createBrokerageOrderRepository({
        pool: databasePool,
        claims,
      }),
      // Preview, mutation, and reconciliation egress remain closed until an
      // exact versioned partner order contract is confirmed and sandboxed.
      provider: createBlockedBrokerageOrderProvider(),
    }),
  telemetry: (event) => console.log(JSON.stringify(event)),
});

const bindings = Object.freeze({
  environment,
  buildRevision: Deno.env.get("ARGUS_BUILD_REVISION") ?? "local",
  consumerOrigin: requiredEnvironment("ARGUS_CONSUMER_ORIGIN"),
  adminOrigin: requiredEnvironment("ARGUS_ADMIN_ORIGIN"),
});

Deno.serve((request) =>
  app.fetch(rewriteSupabaseFunctionRequest(request, "api"), bindings)
);
