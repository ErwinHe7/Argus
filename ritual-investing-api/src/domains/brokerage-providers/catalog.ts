/** Public integration readiness, not an account connection or a trading grant. */
export type BrokerageProviderId = "ibkr" | "moomoo" | "webull";

export type BrokerageProviderRequirement = Readonly<{
  id: string;
  label: string;
  status: "required";
}>;

export type BrokerageProviderReadiness = Readonly<{
  id: BrokerageProviderId;
  name: string;
  status: "setup_required";
  connection_available: false;
  manual_orders_available: false;
  integration_mode: "third_party_oauth" | "oauth_2_1_pkce" | "webull_connect";
  implementation: "adapter_pending" | "fixture_validated_connection_and_manual_orders";
  reason_codes: readonly string[];
  requirements: readonly BrokerageProviderRequirement[];
  documentation_url: string;
  next_step: string;
}>;

export type BrokerageProviderCatalog = Readonly<{
  launch_region: "US";
  execution_mode: "user_confirmed";
  automatic_execution: false;
  providers: readonly BrokerageProviderReadiness[];
}>;

const requirement = (id: string, label: string): BrokerageProviderRequirement =>
  Object.freeze({ id, label, status: "required" });

const providers: readonly BrokerageProviderReadiness[] = Object.freeze([
  Object.freeze({
    id: "ibkr",
    name: "Interactive Brokers",
    status: "setup_required",
    connection_available: false,
    manual_orders_available: false,
    integration_mode: "third_party_oauth",
    implementation: "adapter_pending",
    reason_codes: Object.freeze(["third_party_access_required", "provider_adapter_pending", "sandbox_verification_required"]),
    requirements: Object.freeze([
      requirement("third_party_access", "Apply to IBKR for third-party application access."),
      requirement("registered_application", "Register the application, callback, and assigned credentials."),
      requirement("provider_adapter", "Implement the approved account and manual-order adapter."),
      requirement("sandbox_verification", "Verify authorization, account permissions, and manual order handling in a paper account."),
    ]),
    documentation_url: "https://www.interactivebrokers.com/docs/web-api/getting-started",
    next_step: "Contact IBKR API Solutions with the US platform's business details and intended third-party use. A personal Client Portal session does not connect other users.",
  }),
  Object.freeze({
    id: "moomoo",
    name: "moomoo",
    status: "setup_required",
    connection_available: false,
    manual_orders_available: false,
    integration_mode: "oauth_2_1_pkce",
    implementation: "adapter_pending",
    reason_codes: Object.freeze(["registered_application_required", "provider_adapter_pending", "us_account_permissions_unverified", "sandbox_verification_required"]),
    requirements: Object.freeze([
      requirement("registered_application", "Register the application and exact HTTPS callback for OAuth 2.1 with PKCE."),
      requirement("provider_adapter", "Implement account authorization, token custody, and the manual-order adapter."),
      requirement("us_account_permissions", "Verify eligibility and trading permissions for the user's US brokerage account."),
      requirement("sandbox_verification", "Verify the end-to-end connection and manual-order flow with the broker's test facilities."),
    ]),
    documentation_url: "https://open.moomoo.com/api/overview/getting-started",
    next_step: "Register the platform callback, then validate moomoo user authorization and US account permissions. No personal brokerage password should be entered into this platform.",
  }),
  Object.freeze({
    id: "webull",
    name: "Webull",
    status: "setup_required",
    connection_available: false,
    manual_orders_available: false,
    integration_mode: "webull_connect",
    implementation: "fixture_validated_connection_and_manual_orders",
    reason_codes: Object.freeze(["connect_approval_required", "partner_contract_unconfirmed", "live_provider_binding_pending", "sandbox_verification_required"]),
    requirements: Object.freeze([
      requirement("connect_approval", "Apply for Webull Connect with company details and the registered callback."),
      requirement("partner_contract", "Confirm the assigned scopes, credentials, token and account contracts with Webull."),
      requirement("provider_binding", "Bind the approved provider to the existing encrypted connection and manual-order flow."),
      requirement("sandbox_verification", "Pass Webull sandbox authorization, reads, order review, confirmation, and reconciliation checks before production access."),
    ]),
    documentation_url: "https://developer.webull.com/apis/docs/connect-api/about-connect-api/",
    next_step: "Apply for Webull Connect. The existing connection and manual-order implementation is fixture-validated; live broker requests remain disabled pending provider confirmation and sandbox evidence.",
  }),
]);

/**
 * There is intentionally no environment-variable shortcut to 'connected'.
 * Future live status must be backed by owner-scoped provider authorization and
 * independently verified read/trade capabilities, never credential presence.
 */
export function getBrokerageProviderCatalog(): BrokerageProviderCatalog {
  return Object.freeze({
    launch_region: "US",
    execution_mode: "user_confirmed",
    automatic_execution: false,
    providers,
  });
}
