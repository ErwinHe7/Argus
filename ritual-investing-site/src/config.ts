// `Env` is generated from the production Wrangler configuration. The explicit
// union below admits only the corresponding beta values while preserving the
// generated binding shapes as deployment authority.
type PairwiseVariable =
  | "ENVIRONMENT"
  | "PUBLIC_ORIGIN"
  | "DEMO_ORIGIN"
  | "WAITLIST_SUBMISSIONS"
  | "TURNSTILE_EXPECTED_HOSTNAME"
  | "WAITLIST_SOURCE_KEY_RESOURCE"
  | "TURNSTILE_SITE_KEY_RESOURCE"
  | "TURNSTILE_SECRET_RESOURCE"
  | "WAITLIST_CREDENTIAL_RESOURCE"
  | "WAITLIST_WAF_BUDGET_RESOURCE"
  | "WAITLIST_WAF_CEILING_RESOURCE";

type WaitlistSecretBindings = {
  TURNSTILE_SECRET: string;
  WAITLIST_NEON_URL: string;
  WAITLIST_SOURCE_HMAC_KEY: string;
};

export type SiteEnv = Omit<Env, PairwiseVariable> & WaitlistSecretBindings & {
  ENVIRONMENT: "production" | "beta";
  PUBLIC_ORIGIN: "https://just-build-this.app" | "https://beta.just-build-this.app";
  DEMO_ORIGIN: "https://demo.just-build-this.app" | "https://demo-beta.just-build-this.app";
  WAITLIST_SUBMISSIONS: "off" | "on";
  TURNSTILE_EXPECTED_HOSTNAME: "just-build-this.app" | "beta.just-build-this.app";
  WAITLIST_SOURCE_KEY_RESOURCE: string;
  TURNSTILE_SITE_KEY_RESOURCE: string;
  TURNSTILE_SECRET_RESOURCE: string;
  WAITLIST_CREDENTIAL_RESOURCE: string;
  WAITLIST_WAF_BUDGET_RESOURCE: string;
  WAITLIST_WAF_CEILING_RESOURCE: string;
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
