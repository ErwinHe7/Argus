import type { DatabaseTransaction } from "../../../ritual-investing-api/src/db/database-port.ts";
import {
  withActiveCapabilityStaffRequestTransaction,
  withActiveStaffRequestTransaction,
  withAnonymousRequestTransaction,
  withCapabilityStaffRequestTransaction,
  withMemberRequestTransaction,
  withRequestTransaction,
  withStaffRequestTransaction,
} from "../../../ritual-investing-api/src/db/request-transaction.ts";
import {
  createRetainedApp,
  type RetainedRepositorySet,
} from "../../../ritual-investing-api/src/retained-app.ts";
import type { RetainedTransactionPolicy } from "../../../ritual-investing-api/src/domains/retained-http/boundary.ts";
import { createSupabaseAccountRepository } from "../../../ritual-investing-api/src/domains/accounts/repository.ts";
import { createSupabaseAdminOperationsRepository } from "../../../ritual-investing-api/src/domains/admin-operations/repository.ts";
import { createSupabaseAdminRepository } from "../../../ritual-investing-api/src/domains/admin/repository.ts";
import { createSupabaseAssetRepository } from "../../../ritual-investing-api/src/domains/assets/repository.ts";
import { createSupabaseBriefingRepository } from "../../../ritual-investing-api/src/domains/briefings/repository.ts";
import { createSupabaseCircleRepository } from "../../../ritual-investing-api/src/domains/circles/repository.ts";
import { createSupabaseCovenRepository } from "../../../ritual-investing-api/src/domains/coven/repository.ts";
import { createSupabaseDiscoverRepository } from "../../../ritual-investing-api/src/domains/discover/repository.ts";
import { createQuantMarketMapHttpAdapter } from "../../../ritual-investing-api/src/domains/market-map/adapter.ts";
import { createBlockedMarketMapProvider, createMarketMapService } from "../../../ritual-investing-api/src/domains/market-map/service.ts";
import { createSupabaseEditorialRepository } from "../../../ritual-investing-api/src/domains/editorial/repository.ts";
import { createSupabaseMediaRepository } from "../../../ritual-investing-api/src/domains/media/repository.ts";
import { createSupabaseModerationRepository } from "../../../ritual-investing-api/src/domains/moderation/repository.ts";
import { createSupabaseNotificationRepository } from "../../../ritual-investing-api/src/domains/notifications/repository.ts";
import { createSupabasePrivacyRepository } from "../../../ritual-investing-api/src/domains/privacy/repository.ts";
import { createPrivacyRequestService } from "../../../ritual-investing-api/src/domains/privacy/service.ts";
import { createSupabasePublicPreviewRepository } from "../../../ritual-investing-api/src/domains/public-preview/repository.ts";
import { createSupabaseRitualRepository } from "../../../ritual-investing-api/src/domains/rituals/repository.ts";
import { createSupabaseRowanRepository } from "../../../ritual-investing-api/src/domains/rowan/repository.ts";
import { createSupabaseSearchRepository } from "../../../ritual-investing-api/src/domains/search/repository.ts";
import { createSupabaseSessionRepository } from "../../../ritual-investing-api/src/domains/session/repository.ts";
import { createSupabaseScenarioRepository } from "../../../ritual-investing-api/src/domains/intentions/repository.ts";
import { createSupabaseStarpathEditorialRepository } from "../../../ritual-investing-api/src/domains/starpath/editorial-repository.ts";
import {
  createBlockedStarpathCapabilityEvaluator,
  createSupabaseStarpathRepository,
} from "../../../ritual-investing-api/src/domains/starpath/repository.ts";
import {
  createBetaDraftStarpathCapabilityEvaluator,
  createDraftPreviewStarpathRepository,
} from "../../../ritual-investing-api/src/domains/starpath/draft-preview-repository.ts";
import { createMemberBranchCapabilityEvaluator } from "./member-branch-capabilities.ts";

import { createSupabaseAccessTokenVerifier } from "../_shared/auth.ts";
import { createSupabaseDatabasePool } from "../_shared/database.ts";
import {
  requiredConsumerOrigins,
  requiredEnvironment,
  requiredExactOrigin,
  requiredWebAdmission,
  supabaseSecretKey,
} from "../_shared/environment.ts";
import { rewriteSupabaseFunctionRequest } from "../_shared/http.ts";
import { withBuildRevisionHeader } from "../_shared/build-revision.ts";
import { createPostgresRateLimitPort } from "../_shared/rate-limit.ts";
import { createPrivateSupabaseStorage } from "../_shared/jobs/storage.ts";
import { createBrokerageConnectionRepository } from "../../../ritual-investing-api/src/domains/brokerage-connections/repository.ts";
import { createBrokerageConnectionService } from "../../../ritual-investing-api/src/domains/brokerage-connections/service.ts";
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
  requiredEnvironment("EDGE_RUNTIME_DATABASE_URL"),
);
const privateStorage = createPrivateSupabaseStorage({
  supabaseUrl,
  secretKey: supabaseSecretKey(),
});
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
const blockedStarpathCapability = createBlockedStarpathCapabilityEvaluator();
const starpathCapability = environment === "production"
  ? blockedStarpathCapability
  : createBetaDraftStarpathCapabilityEvaluator();
const memberBranchCapabilities = createMemberBranchCapabilityEvaluator({
  runtimeEnvironment: environment,
  starpath: starpathCapability,
});

// A research credential is server-only. Partial or invalid configuration takes
// this surface offline without affecting unrelated member routes.
const marketMapProvider = (() => {
  const baseUrl = Deno.env.get("QUANT_RESEARCH_API_URL");
  const serviceToken = Deno.env.get("QUANT_RESEARCH_TOKEN");
  if (!baseUrl || !serviceToken) return createBlockedMarketMapProvider();
  try {
    return createQuantMarketMapHttpAdapter({ baseUrl, serviceToken });
  } catch {
    return createBlockedMarketMapProvider();
  }
})();

function createRepositories(
  database: DatabaseTransaction,
  claims: Parameters<typeof withMemberRequestTransaction>[0]["verifiedClaims"],
): RetainedRepositorySet {
  return Object.freeze({
    session: createSupabaseSessionRepository(database, claims.userId),
    memberBranchCapabilities,
    accounts: createSupabaseAccountRepository(database),
    assets: createSupabaseAssetRepository(database),
    editorial: createSupabaseEditorialRepository(database),
    briefings: createSupabaseBriefingRepository(database),
    circles: createSupabaseCircleRepository(database),
    coven: createSupabaseCovenRepository(database),
    discover: createSupabaseDiscoverRepository(database),
    media: createSupabaseMediaRepository(database),
    moderation: createSupabaseModerationRepository(database),
    notifications: createSupabaseNotificationRepository(database),
    rituals: createSupabaseRitualRepository(database),
    rowan: createSupabaseRowanRepository(database),
    search: createSupabaseSearchRepository(database),
    starpath: createSupabaseStarpathEditorialRepository(database),
    starpathMember: environment === "production"
      ? createSupabaseStarpathRepository(database, blockedStarpathCapability)
      : createDraftPreviewStarpathRepository(),
    admin: createSupabaseAdminRepository(database, claims),
    adminOperations: createSupabaseAdminOperationsRepository(
      database,
      claims.sessionId,
    ),
    scenarios: createSupabaseScenarioRepository(database),
  });
}

function withRepositories<T>(
  claims: Parameters<typeof withMemberRequestTransaction>[0]["verifiedClaims"],
  transaction: Exclude<RetainedTransactionPolicy, "none" | "public-preview">,
  callback: (repositories: RetainedRepositorySet) => Promise<T>,
): Promise<T> {
  const config = { pool: databasePool, verifiedClaims: claims };
  const run = (database: DatabaseTransaction) =>
    callback(createRepositories(database, claims));
  if (transaction === "member") {
    return withMemberRequestTransaction(config, run);
  }
  if (transaction === "runtime") {
    return withRequestTransaction(config, run);
  }
  if (transaction.mode === "runtime-staff") {
    return transaction.permission === undefined
      ? withActiveStaffRequestTransaction(config, run)
      : withStaffRequestTransaction(config, transaction.permission, run);
  }
  return transaction.permission === undefined
    ? withActiveCapabilityStaffRequestTransaction(config, run)
    : withCapabilityStaffRequestTransaction(
      config,
      transaction.permission,
      run,
    );
}

const app = createRetainedApp({
  marketMapService: createMarketMapService({ provider: marketMapProvider }),
  verifyAccessToken: createSupabaseAccessTokenVerifier({ supabaseUrl }),
  withRepositories,
  withPublicPreview: (callback) =>
    withAnonymousRequestTransaction(
      databasePool,
      (database) => callback(createSupabasePublicPreviewRepository(database)),
    ),
  createPrivacyService: (claims) =>
    createPrivacyRequestService({
      claims,
      withMemberTransaction: (callback) =>
        withMemberRequestTransaction(
          { pool: databasePool, verifiedClaims: claims },
          callback,
        ),
      repository: createSupabasePrivacyRepository,
      signedStorage: privateStorage,
    }),
  rateLimit: createPostgresRateLimitPort(databasePool),
  createBrokerageConnections: (claims) =>
    createBrokerageConnectionService({
      claims,
      authorization: {
        contractVersion: blockedWebullContract.version,
        environment: blockedWebullContract.environment,
        authorizationUrl: blockedWebull.authorizationUrl,
      },
      withRepository: (callback) =>
        withMemberRequestTransaction(
          { pool: databasePool, verifiedClaims: claims },
          (database) => callback(createBrokerageConnectionRepository(database)),
        ),
    }),
  createBrokerageProjections: (claims) =>
    createBrokerageProjectionService({
      withRepository: (callback) =>
        withMemberRequestTransaction(
          { pool: databasePool, verifiedClaims: claims },
          (database) => callback(createBrokerageProjectionRepository(database)),
        ),
      // The U5 public-contract conflicts remain unresolved. Cached synthetic
      // generations can be served, but provider egress stays fail-closed until
      // a versioned partner read fixture and approval gate are configured.
      provider: createBlockedBrokerageProjectionProvider(),
    }),
  createBrokerageOrders: (claims) =>
    createBrokerageOrderService({
      withRepository: (callback) =>
        withMemberRequestTransaction(
          { pool: databasePool, verifiedClaims: claims },
          (database) =>
            callback(createBrokerageOrderRepository(database, claims.userId)),
        ),
      withStaffRepository: (callback) =>
        withCapabilityStaffRequestTransaction(
          { pool: databasePool, verifiedClaims: claims },
          "brokerage:read",
          (database) =>
            callback(createBrokerageOrderRepository(database, claims.userId)),
        ),
      // Preview, mutation, and reconciliation egress remain closed until an
      // exact versioned partner order contract is confirmed and sandboxed.
      provider: createBlockedBrokerageOrderProvider(),
    }),
  telemetry: (event) => console.log(JSON.stringify(event)),
});

const bindings = Object.freeze({
  environment,
  buildRevision: Deno.env.get("ARGUS_BUILD_REVISION") ?? "local",
  consumerOrigins: requiredConsumerOrigins(),
  adminOrigin: requiredExactOrigin("ARGUS_ADMIN_ORIGIN"),
  webAdmission: requiredWebAdmission(),
});

Deno.serve(
  withBuildRevisionHeader((request) =>
    app.fetch(rewriteSupabaseFunctionRequest(request, "api"), bindings)
  ),
);
