// `Env` is generated from wrangler.jsonc in src/generated/worker-configuration.d.ts.
// Production and beta share this module. Only the environment discriminator and
// activation switch intentionally admit both pairwise runtime values.
export type SiteEnv = Omit<Env, "ENVIRONMENT" | "WAITLIST_SUBMISSIONS"> & {
  ENVIRONMENT: "production" | "beta";
  WAITLIST_SUBMISSIONS: "off" | "on";
};

export type AssetBinding = SiteEnv["ASSETS"];
export type SourceRateLimitBinding = SiteEnv["WAITLIST_SOURCE_RATE_LIMIT"];
export type RouteRateLimitBinding = SiteEnv["WAITLIST_ROUTE_RATE_LIMIT"];
export type AnalyticsBinding = SiteEnv["WAITLIST_TELEMETRY"];
export type RetentionCheckpointBinding = SiteEnv["RETENTION_CHECKPOINT"];

// The generated interface is the deployment authority. This derived runtime
// view makes non-asset bindings optional solely so tests can prove missing
// bindings fail closed; it does not invent or duplicate platform signatures.
export type RuntimeSiteEnv = Pick<
  SiteEnv,
  "ASSETS" | "ENVIRONMENT" | "WAITLIST_SUBMISSIONS"
> &
  Partial<Omit<SiteEnv, "ASSETS" | "ENVIRONMENT" | "WAITLIST_SUBMISSIONS">>;

export function submissionsAreFailClosed(environment: RuntimeSiteEnv): boolean {
  return (
    environment.WAITLIST_SUBMISSIONS !== "on" ||
    environment.WAITLIST_SOURCE_RATE_LIMIT === undefined ||
    environment.WAITLIST_ROUTE_RATE_LIMIT === undefined ||
    environment.TURNSTILE_EXPECTED_HOSTNAME === undefined ||
    environment.TURNSTILE_EXPECTED_ACTION !== "waitlist" ||
    environment.TURNSTILE_SITE_KEY_RESOURCE === undefined ||
    environment.TURNSTILE_SECRET_RESOURCE === undefined ||
    environment.WAITLIST_CREDENTIAL_RESOURCE === undefined ||
    environment.WAITLIST_WAF_BUDGET_RESOURCE === undefined ||
    environment.WAITLIST_WAF_CEILING_RESOURCE === undefined
  );
}
