# Argus member data and authority inventory

Status date: 2026-08-28

This is the U1 migration authority for the member app, admin app, API, background work, site, and standalone Demo. It classifies the synthetic migration baseline; it is not evidence that the later Supabase or Webull implementation units are complete.

## Authority rules

- Webull is authoritative for brokerage accounts, capabilities, restrictions, balances, positions, and orders. Argus stores timestamped projections and durable provider commands, not a second brokerage ledger.
- Argus is authoritative for ritual, editorial, community, preference, and privacy state. Intentions and Future Mirror remain Argus-owned explanatory scenarios.
- Supabase owns Argus identity, application data, server compute, durable jobs, and retained object storage. Application and brokerage data stays in private, non-Data-API schemas behind the versioned Argus API.
- The standalone Demo is synthetic, memory-only, auth-free, provider-free, credential-free, and network-isolated.
- Cloudflare Pages serves only static landing and standalone Demo assets.
- Rowan cannot issue financial commands or receive Webull credentials, raw provider payloads, balances, or positions as prompt context.

## Classification meanings

| Classification | Meaning |
| --- | --- |
| `retained-argus` | The product concept remains Argus-owned, but its persistence/compute moves to Supabase where applicable. |
| `replaced-webull` | The current simulated authority is removed and replaced by a Webull-owned fact or a provider-bound Argus command/projection. |
| `standalone-demo-only` | The behavior survives only in the independent, memory-only Demo artifact. |
| `deleted` | The production behavior or provider integration is removed after its replacement gate passes. |

## Data handling contract

Webull credentials, authorization codes, signing secrets, wrapped data keys, raw provider payloads, and provider-identifying callback material are server-only. They are excluded from Flutter, admin clients, public or exposed database objects, Data API grants, queue payloads, logs, analytics, crash breadcrumbs, exports, screenshots, and CI artifacts.

Brokerage projections contain normalized facts plus provider-observation availability, `fetched_at`, `expires_at`, and freshness. An unavailable provider timestamp is represented as unavailable; Argus fetch time is never relabeled as provider observation time. Privacy exports include allowlisted Argus-owned member data and normalized member-visible projections, never provider credentials or raw provider payloads.

Supabase Auth and Webull authorization are independent lifecycles. Account deletion revokes the current Supabase session, generation-fences callbacks and jobs, destroys local provider credentials, purges Argus-owned data and private Storage, and deletes the Auth identity last. It never claims to close a Webull account or cancel a Webull order.

## Machine-checkable current-surface inventory

Each surface below appears exactly once. The contract test derives current tables, API domains, queue handlers, and generated API routes from the repository and rejects missing or duplicate classifications.

<!-- authority-inventory:start -->
| Surface | Classification | Target owner and disposition |
| --- | --- | --- |
| `database-table:accounts` | retained-argus | Supabase private identity/account mapping |
| `database-table:admin_audit_checkpoints` | retained-argus | Supabase private admin audit state |
| `database-table:admin_audit_events` | retained-argus | Supabase private admin audit state |
| `database-table:admin_operation_receipts` | retained-argus | Supabase private idempotency state |
| `database-table:aggregate_consumer_watermarks` | retained-argus | Supabase private worker state |
| `database-table:asset_codex_entries` | retained-argus | Argus editorial data in Supabase |
| `database-table:asset_codex_evidence` | retained-argus | Argus editorial data in Supabase |
| `database-table:asset_codex_revisions` | retained-argus | Argus editorial data in Supabase |
| `database-table:asset_codex_risks` | retained-argus | Argus editorial data in Supabase |
| `database-table:asset_metric_snapshots` | retained-argus | Argus evidence data in Supabase |
| `database-table:assets` | retained-argus | Argus asset catalog in Supabase |
| `database-table:astrology_profiles` | retained-argus | Argus optional personalization in Supabase |
| `database-table:briefing_sections` | retained-argus | Argus briefing data in Supabase |
| `database-table:briefing_template_revisions` | retained-argus | Argus editorial data in Supabase |
| `database-table:briefing_templates` | retained-argus | Argus editorial data in Supabase |
| `database-table:briefings` | retained-argus | Argus briefing data in Supabase |
| `database-table:cash_ledger_entries` | replaced-webull | Remove ledger; Webull balance/activity authority |
| `database-table:circle_assets` | retained-argus | Argus community data in Supabase |
| `database-table:circle_template_assets` | retained-argus | Argus editorial data in Supabase |
| `database-table:circle_template_revisions` | retained-argus | Argus editorial data in Supabase |
| `database-table:circle_templates` | retained-argus | Argus editorial data in Supabase |
| `database-table:circles` | retained-argus | Argus community data in Supabase |
| `database-table:companies` | retained-argus | Argus editorial evidence in Supabase |
| `database-table:consent_records` | retained-argus | Argus privacy state in Supabase |
| `database-table:consumer_receipts` | retained-argus | Supabase private worker idempotency |
| `database-table:content_reports` | retained-argus | Argus moderation state in Supabase |
| `database-table:coven_entries` | retained-argus | Argus editorial data in Supabase |
| `database-table:coven_entry_revisions` | retained-argus | Argus editorial data in Supabase |
| `database-table:coven_qualifications` | retained-argus | Argus evidence data in Supabase |
| `database-table:coven_verification_evidence` | retained-argus | Argus evidence data in Supabase |
| `database-table:coven_verifications` | retained-argus | Argus evidence data in Supabase |
| `database-table:daily_ritual_assignments` | retained-argus | Argus ritual state in Supabase |
| `database-table:deletion_journal_confirmations` | retained-argus | Supabase private deletion fencing |
| `database-table:deletion_object_receipts` | retained-argus | Supabase private deletion fencing |
| `database-table:deletion_restore_checkpoints` | retained-argus | Supabase private deletion recovery |
| `database-table:deletion_tombstones` | retained-argus | Supabase private deletion epoch |
| `database-table:demo_checkout_sessions` | deleted | Remove Demo membership from production |
| `database-table:demo_funding_sources` | deleted | Funding is outside product scope |
| `database-table:demo_plans` | deleted | Remove Demo membership from production |
| `database-table:demo_portfolios` | replaced-webull | Remove simulated authority; Webull projections |
| `database-table:demo_reset_events` | deleted | Reset exists only in standalone Demo memory |
| `database-table:demo_seed_versions` | deleted | Seed exists only in standalone Demo build |
| `database-table:device_installations` | retained-argus | Argus notification/privacy state in Supabase |
| `database-table:editorial_items` | retained-argus | Argus editorial workflow in Supabase |
| `database-table:editorial_review_decisions` | retained-argus | Argus editorial workflow in Supabase |
| `database-table:editorial_review_requests` | retained-argus | Argus editorial workflow in Supabase |
| `database-table:editorial_revisions` | retained-argus | Argus editorial workflow in Supabase |
| `database-table:entitlement_events` | deleted | Remove Demo membership authority |
| `database-table:evidence_claims` | retained-argus | Argus evidence workflow in Supabase |
| `database-table:evidence_sources` | retained-argus | Argus evidence workflow in Supabase |
| `database-table:grimoire_revision_assets` | retained-argus | Argus editorial data in Supabase |
| `database-table:grimoire_revisions` | retained-argus | Argus editorial data in Supabase |
| `database-table:grimoires` | retained-argus | Argus editorial data in Supabase |
| `database-table:idempotency_records` | retained-argus | Supabase private API idempotency |
| `database-table:intentions` | retained-argus | Argus scenario state in Supabase |
| `database-table:investor_profiles` | retained-argus | Argus preference state in Supabase |
| `database-table:job_runs` | retained-argus | Supabase private job operations |
| `database-table:ledger_transactions` | replaced-webull | Remove Argus brokerage ledger |
| `database-table:media_assets` | retained-argus | Argus metadata plus private Supabase Storage |
| `database-table:media_upload_intents` | retained-argus | Argus private upload state in Supabase |
| `database-table:member_command_receipts` | retained-argus | Supabase private command idempotency |
| `database-table:member_idempotency_records` | retained-argus | Supabase private API idempotency |
| `database-table:moderation_case_decisions` | retained-argus | Argus moderation state in Supabase |
| `database-table:moderation_cases` | retained-argus | Argus moderation state in Supabase |
| `database-table:notification_deliveries` | retained-argus | Argus notification state in Supabase |
| `database-table:notification_preferences` | retained-argus | Argus preference state in Supabase |
| `database-table:notifications` | retained-argus | Argus notification state in Supabase |
| `database-table:onboarding_finalization_commands` | retained-argus | Argus onboarding state in Supabase |
| `database-table:onboarding_states` | retained-argus | Argus onboarding state in Supabase |
| `database-table:order_previews` | replaced-webull | Replace simulated preview with capability-bound provider preview |
| `database-table:outbox_dispatch_failures` | retained-argus | Supabase private worker recovery |
| `database-table:outbox_events` | retained-argus | Supabase private transactional work |
| `database-table:portfolio_balance_snapshots` | replaced-webull | Webull balance projection authority |
| `database-table:portfolio_positions` | replaced-webull | Webull position projection authority |
| `database-table:portfolio_target_allocations` | deleted | Remove rebalance execution assumptions |
| `database-table:position_ledger_entries` | replaced-webull | Remove Argus brokerage ledger |
| `database-table:preferences` | retained-argus | Argus preference state in Supabase |
| `database-table:privacy_export_artifacts` | retained-argus | Private Supabase Storage export state |
| `database-table:privacy_requests` | retained-argus | Argus privacy state in Supabase |
| `database-table:profiles` | retained-argus | Argus profile state in Supabase |
| `database-table:projection_points` | retained-argus | Argus Future Mirror scenarios in Supabase |
| `database-table:projection_runs` | retained-argus | Argus Future Mirror scenarios in Supabase |
| `database-table:publication_events` | retained-argus | Argus editorial workflow in Supabase |
| `database-table:purge_receipts` | retained-argus | Supabase private deletion evidence |
| `database-table:rebalance_preview_allocations` | deleted | Rebalance execution is outside product scope |
| `database-table:rebalance_preview_trades` | deleted | Rebalance execution is outside product scope |
| `database-table:rebalance_previews` | deleted | Rebalance execution is outside product scope |
| `database-table:recurring_plan_allocations` | deleted | Recurring financial execution is outside scope |
| `database-table:recurring_plan_runs` | deleted | Recurring financial execution is outside scope |
| `database-table:recurring_plans` | deleted | Recurring financial execution is outside scope |
| `database-table:ritual_private.purge_guards` | retained-argus | Supabase private deletion fencing |
| `database-table:ritual_private.schema_contract_versions` | retained-argus | Supabase private contract state |
| `database-table:ritual_scenario_evidence` | retained-argus | Argus ritual evidence in Supabase |
| `database-table:ritual_scenario_ideas` | retained-argus | Argus ritual editorial data in Supabase |
| `database-table:ritual_scenario_revisions` | retained-argus | Argus ritual editorial data in Supabase |
| `database-table:ritual_scenarios` | retained-argus | Argus ritual editorial data in Supabase |
| `database-table:ritual_schedules` | retained-argus | Argus editorial schedule in Supabase |
| `database-table:rowan_context_bindings` | retained-argus | Redacted Argus-only context in Supabase |
| `database-table:rowan_script_revisions` | retained-argus | Argus editorial data in Supabase |
| `database-table:rowan_scripts` | retained-argus | Argus editorial data in Supabase |
| `database-table:saved_assets` | retained-argus | Argus member state in Supabase |
| `database-table:saved_circle_templates` | retained-argus | Argus member state in Supabase |
| `database-table:saved_coven_entries` | retained-argus | Argus member state in Supabase |
| `database-table:saved_grimoires` | retained-argus | Argus member state in Supabase |
| `database-table:security_events` | retained-argus | Supabase private security operations |
| `database-table:seeded_creators` | retained-argus | Argus editorial data in Supabase |
| `database-table:simulated_order_fills` | replaced-webull | Webull order projection authority |
| `database-table:simulated_orders` | replaced-webull | Webull order projection authority |
| `database-table:simulation_commands` | replaced-webull | Replace with provider-bound commands |
| `database-table:staff_principals` | retained-argus | Supabase Auth plus private staff authorization |
| `database-table:tenant_demo_states` | deleted | Production Demo state is removed |
| `database-table:tenant_entitlements` | deleted | Production Demo membership is removed |
| `database-table:tenants` | retained-argus | Supabase private ownership mapping |
| `api-domain:accounts` | retained-argus | Argus account identity; brokerage accounts become separate Webull projections |
| `api-domain:admin` | retained-argus | Argus staff operations in Supabase |
| `api-domain:admin-operations` | retained-argus | Argus staff operations in Supabase |
| `api-domain:assets` | retained-argus | Argus evidence API |
| `api-domain:briefings` | retained-argus | Argus briefing API |
| `api-domain:circles` | retained-argus | Argus community API |
| `api-domain:coven` | retained-argus | Argus editorial API |
| `api-domain:discover` | retained-argus | Argus discovery API |
| `api-domain:editorial` | retained-argus | Argus editorial core |
| `api-domain:entitlements` | deleted | Remove Demo membership routes |
| `api-domain:intentions` | retained-argus | Argus scenario API |
| `api-domain:media` | retained-argus | Argus metadata and private Supabase Storage |
| `api-domain:moderation` | retained-argus | Argus moderation API |
| `api-domain:notifications` | retained-argus | Argus notification API |
| `api-domain:orders` | replaced-webull | Provider order projections and commands |
| `api-domain:portfolios` | replaced-webull | Webull account, balance, and position projections |
| `api-domain:privacy` | retained-argus | Argus privacy API |
| `api-domain:public-preview` | retained-argus | Approved Argus editorial projection |
| `api-domain:rebalancing` | deleted | Rebalance execution is outside scope |
| `api-domain:recurring-plans` | deleted | Recurring financial execution is outside scope |
| `api-domain:rituals` | retained-argus | Argus ritual API |
| `api-domain:rowan` | retained-argus | Redacted non-command counsel API |
| `api-domain:saves` | retained-argus | Argus member organization API |
| `api-domain:search` | retained-argus | Argus search API |
| `api-domain:session` | retained-argus | Supabase Auth-backed Argus bootstrap |
| `api-domain:simulation` | replaced-webull | Delete ledger/reset/membership; replace reads and manual orders |
| `background-handler:briefing-builder` | retained-argus | Supabase Queue/Cron worker |
| `background-handler:notification-writer` | retained-argus | Supabase Queue worker |
| `background-handler:notification-delivery` | retained-argus | Supabase Queue worker |
| `background-handler:privacy-export` | retained-argus | Supabase Queue/Storage worker |
| `background-handler:privacy-purge` | retained-argus | Supabase Queue deletion worker |
| `background-handler:media-scan` | retained-argus | Bounded Supabase worker |
| `background-handler:media-cleanup` | retained-argus | Supabase Queue/Storage worker |
| `background-handler:moderation-triage` | retained-argus | Supabase Queue worker |
| `background-handler:editorial-publisher` | retained-argus | Supabase Queue/Cron worker |
| `background-handler:recurring-plan-delivery` | deleted | No background financial execution |
| `background-handler:privacy-export-retention` | retained-argus | Supabase Queue/Cron worker |
| `api-route-pattern:^/health$` | retained-argus | Supabase Edge liveness route |
| `api-route-pattern:^/v1/admin/` | retained-argus | Argus staff API through Supabase Edge |
| `api-route-pattern:^/v1/public/` | retained-argus | Approved Argus public editorial API |
| `api-route-pattern:^/v1/portfolios` | replaced-webull | Rewrite as Webull projections; delete recurring/rebalance actions |
| `api-route-pattern:^/v1/orders` | replaced-webull | Rewrite as Webull order projections |
| `api-route-pattern:^/v1/demo-` | deleted | Remove production Demo endpoints |
| `api-route-pattern:^/v1/recurring-plans` | deleted | Remove recurring execution endpoints |
| `api-route-pattern:^/v1/me/demo-reset$` | deleted | Reset remains standalone-Demo-only |
| `api-route-pattern:^/v1/me/entitlements` | deleted | Remove Demo membership endpoints |
| `api-route-pattern:^/v1/(?!admin/)(?!public/)(?!portfolios)(?!orders)(?!demo-)(?!recurring-plans)(?!me/demo-reset)(?!me/entitlements).*` | retained-argus | Retained member and contract routes through Supabase Edge |
| `live-financial-feature:funding` | deleted | No bank link, deposit, withdrawal, ACH, or wire flow |
| `live-financial-feature:brokerage-reads` | replaced-webull | Webull timestamped account and asset projections |
| `live-financial-feature:manual-orders` | replaced-webull | Webull-approved preview/place/modify/cancel only |
| `live-financial-feature:recurring-execution` | deleted | No background or scheduled financial command |
| `live-financial-feature:rebalance-execution` | deleted | Intentions/Future Mirror remain non-command scenarios |
| `live-financial-feature:demo-membership` | deleted | No Demo entitlement or checkout in production |
| `live-financial-feature:demo-reset` | standalone-demo-only | In-memory reset inside standalone Demo only |
| `client:standalone-demo` | standalone-demo-only | Independent static memory-only artifact |
| `client:rowan` | retained-argus | Argus counsel with no brokerage prompt context or command authority |
| `client:member-asset_codex` | retained-argus | Argus evidence UI |
| `client:member-briefings` | retained-argus | Argus briefing UI |
| `client:member-circles` | retained-argus | Argus community UI |
| `client:member-coven` | retained-argus | Argus editorial UI |
| `client:member-creators` | retained-argus | Argus community UI |
| `client:member-discover` | retained-argus | Argus discovery UI |
| `client:member-entitlements` | deleted | Remove Demo membership UI |
| `client:member-funding` | deleted | Remove fictional funding UI |
| `client:member-future_mirror` | retained-argus | Non-authoritative Argus scenarios |
| `client:member-grimoires` | retained-argus | Argus editorial UI |
| `client:member-intentions` | retained-argus | Argus scenario UI |
| `client:member-notifications` | retained-argus | Argus notification UI |
| `client:member-onboarding` | retained-argus | Supabase Auth-backed Argus onboarding |
| `client:member-orders` | replaced-webull | Webull manual order UI with freshness gates |
| `client:member-portfolio` | replaced-webull | Webull account and asset projections |
| `client:member-privacy` | retained-argus | Argus privacy UI |
| `client:member-profile` | retained-argus | Argus profile UI |
| `client:member-rebalancing` | deleted | Remove rebalance execution UI |
| `client:member-recurring` | deleted | Remove recurring financial execution UI |
| `client:member-ritual` | retained-argus | Argus ritual UI |
| `client:member-search` | retained-argus | Argus search UI |
| `client:member-shell` | retained-argus | Recompose navigation around Argus and Webull authority |
| `client:admin-session` | retained-argus | Supabase Auth, AAL2, and current staff permission |
| `client:admin-editorial-workspace` | retained-argus | Argus editorial operations |
| `client:admin-brokerage-diagnostics` | retained-argus | Redacted read-only operations; no credential or raw payload display |
| `site-endpoint:/` | retained-argus | Static landing asset on Cloudflare Pages |
| `site-endpoint:/api/waitlist` | retained-argus | Move to narrow Supabase Edge Function; no Pages Function |
| `site-endpoint:/api/*` | deleted | Delete Cloudflare Worker catch-all |
| `storage-object:MEDIA_QUARANTINE` | retained-argus | Private Supabase Storage bucket |
| `storage-object:MEDIA_PUBLIC` | retained-argus | Replace public R2 use with private approved Supabase transport |
| `storage-object:PRIVACY_EXPORTS` | retained-argus | Private expiring Supabase Storage bucket |
| `storage-object:DELETION_DENY_JOURNAL` | retained-argus | Supabase private deletion recovery state |
| `provider-dependency:auth0` | deleted | Replace member and staff identity with Supabase Auth |
| `provider-dependency:neon` | deleted | Replace synthetic Neon schema with clean Supabase Postgres baseline |
| `provider-dependency:cloudflare-workers` | deleted | Replace API/site compute with Supabase Edge; keep Pages static only |
| `provider-dependency:cloudflare-queues` | deleted | Replace with private Supabase Queues |
| `provider-dependency:r2` | deleted | Replace retained objects with private Supabase Storage |
| `provider-dependency:cloudflare-access` | deleted | Replace staff gate with Supabase Auth and database authorization |
| `provider-dependency:drizzle` | deleted | Replace Drizzle migrations/tooling with Supabase migrations |
| `provider-dependency:webull-connect` | replaced-webull | Server-only brokerage authority after partner/sandbox gate |
| `provider-dependency:supabase` | retained-argus | Sole Argus auth, database, server compute, jobs, and retained storage platform |
| `secret-family:AUTH0_*` | deleted | Revoke after Supabase Auth replacement evidence |
| `secret-family:*_DATABASE_URL` | deleted | Replace Neon URLs with scoped Supabase runtime-role credentials |
| `secret-family:CF_ACCESS_*` | deleted | Revoke after admin Supabase Auth replacement |
| `secret-family:Cloudflare Queue and R2 bindings` | deleted | Remove after Supabase replacement evidence |
| `secret-family:TURNSTILE_*` | retained-argus | Server-side waitlist validation only if waitlist remains |
| `secret-family:Supabase publishable URL/key` | retained-argus | Client Auth/approved Storage only; never secret/service role |
| `secret-family:Supabase runtime role and worker secret` | retained-argus | Vault/Edge-secret custody and rotation; never client-exposed |
| `secret-family:Webull client, signing, token-wrapping keys` | replaced-webull | Edge-secret custody with versioned rotation and redaction |
| `runbook:admin-operations-runbook.md` | retained-argus | Rewrite for Supabase staff auth and redacted brokerage diagnostics |
| `runbook:cloudflare-runbook.md` | deleted | Replace with static Pages-only deployment guidance |
| `runbook:member-release-gates.md` | retained-argus | Rewrite for Supabase/Auth/Webull hosted evidence |
| `runbook:neon-runbook.md` | deleted | Replace with Supabase local/hosted database operations |
| `runbook:privacy-runbook.md` | retained-argus | Rewrite for deletion epoch and Supabase Storage |
| `runbook:site-demo-runbook.md` | retained-argus | Rewrite for static Pages and network-isolated Demo |
| `runbook:auth0-setup.md` | deleted | Replace with Supabase Auth setup |
| `runbook:api-consumer-guide.md` | retained-argus | Regenerate for Supabase bearer auth and Webull-backed contract |
| `runbook:deployment-handoff.md` | retained-argus | Rewrite for local stacks and serialized hosted development |
| `runbook:staging-evidence-template.md` | retained-argus | Rewrite for hosted Supabase and Webull sandbox evidence |
<!-- authority-inventory:end -->

## Retained member data

Guided-onboarding answers, profiles, preferences, optional date-only astrology personalization, consent receipts, saves, Circles, Intentions, Future Mirror inputs/results, briefings, notifications, and privacy-operation status remain Argus-owned. These values affect presentation, organization, and scenarios only; they do not authorize a provider command, override brokerage restrictions, or bypass confirmation.

Before authentication completes, an onboarding draft may remain installation-bound and encrypted on device under the existing expiry and backup-exclusion rules. After Supabase Auth, server finalization atomically validates the draft and policy versions. Drafts and completed state never cross accounts.

## Brokerage data

One Argus account may own one active Webull authorization and may select one account returned by that authorization. The server stores encrypted rotating credentials, connection/account identifiers, capability and restriction projections, normalized balances/positions/orders, freshness metadata, provider commands, immutable command attempts, and reconciliation outcomes. Only opaque identifiers enter queue messages.

Provider facts are not repurposed as Rowan context, marketing analytics, or a second ledger. Stale projections remain visibly stale and cannot authorize a mutation. Disconnect deletes local credentials and projections subject to command-recovery rules; it does not alter the brokerage account itself.

## Consent, retention, export, and deletion

- Astrology remains optional. Disabling personalization removes the astrology profile and records the consent decision.
- Argus-owned preferences and content remain until edited or deleted. Consent receipts remain versioned according to the reviewed retention policy.
- Export snapshots and links remain short-lived, private, one-use where applicable, and generation-fenced.
- Deletion immediately blocks member access and future resurrection, purges Argus data and private Storage in a verified order, and removes the Supabase Auth identity last.
- Provider token retention, command evidence, and any legally required operational record must be decided before launch; pre-production synthetic data may be reset without backfill.

## Development and launch gates

Branches and pull requests use a fresh local Supabase CLI stack. One hosted development project receives serialized main/manual deployments; Supabase Pro branching is not required. A second Supabase project, production Webull registration, custom SMTP, backups, recovery, reliability thresholds, capacity limits, compliance/retention approval, and admin hosting are launch gates.

The migration is replacement-first. Auth0, Neon, Cloudflare backend compute, Cloudflare Queues, R2, Cloudflare Access, Drizzle, and simulated-finance authority are removed only after focused replacement tests pass, then their external credentials, routes, bindings, and resources are revoked.
