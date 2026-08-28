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

const createRepositories: Parameters<typeof createRetainedApp>[0]["createRepositories"] =
  (claims): RetainedRepositorySet => {
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
