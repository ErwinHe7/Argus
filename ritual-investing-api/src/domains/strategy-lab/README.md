# Strategy API v1

This feature owns the paper-strategy control plane for Astra’s Pick. It does not
submit brokerage orders or calculate signals, returns, sizing, or fills. The
local connector and Rust engine retain those responsibilities. There is no live
mode, arbitrary-order endpoint, browser-to-localhost connection, or hosted OpenD.

The runtime contracts are exported from `contracts.ts`; the browser imports
schemas for validation and types for rendering. The API envelope is
`{data: value, meta: {requestId: UUID}}`. Errors expose only
`{error: {code, message, requestId, retryable?}}`.

## Deployment boundary

The isolated Supabase Edge entry is `supabase/functions/strategy-api/index.ts`.
Its base URL is `https://<project>.supabase.co/functions/v1/strategy-api`.
Use the already selected Leo Investing project, with the retained identity,
membership/lifecycle, verified request context, database-role, and rate-limit
migrations installed first. This change does not modify the existing `api`
function's exclusive-origin policy, Rowan, or the legacy Next.js guest session.

Required Edge environment:

| Variable | Requirement |
| --- | --- |
| `SUPABASE_URL` | The selected project URL; used by retained JWT verification. |
| `EDGE_RUNTIME_DATABASE_URL` | Retained `argus_edge` database login, not `service_role` or an owner login. |
| `STRATEGY_CONSUMER_ORIGINS` | One or both exact origins `https://leoinvesting.com,https://leo.axio7.workers.dev`; other origins, duplicates, wildcards, paths, and ports are rejected. |
| `STRATEGY_SUPERVISOR_BASE_URL` | Optional explicit HTTPS OpenAI-compatible endpoint base. |
| `STRATEGY_SUPERVISOR_API_KEY` | Optional dedicated provider credential stored as an Edge secret. |
| `STRATEGY_SUPERVISOR_MODEL` | Optional explicit model name. |

All three supervisor variables must be supplied for model explanations. Missing
or invalid configuration leaves deterministic evidence summaries and controls
available; it never chooses another provider or a paid fallback. No model
credential is returned to the browser.
Use a separate explicitly budgeted provider credential when enabling it.

Apply `supabase/migrations/20260908003020_strategy_lab_control_plane.sql` only
through the project's reviewed release procedure. The function has gateway
`verify_jwt=false` because it hosts a one-use pairing endpoint and custom device
credentials. Member routes still verify the Supabase JWT with the retained
verifier, then require the actual Auth session and active member lifecycle.
The static frontend callback and allowed OAuth redirect must be configured in
the selected project separately; they are owned by the frontend integration.
The custom-domain rollout adds `https://leoinvesting.com/strategy-auth/callback`
to the Auth redirect list and retains
`https://leo.axio7.workers.dev/strategy-auth/callback` and all existing application
callbacks. The strategy allowlist does not change `ARGUS_CONSUMER_ORIGINS` or the
retained member API's exclusive-origin policy. Source support is not evidence
that either hosted configuration has been applied.

## Member endpoints

Except the public catalog, send `Authorization: Bearer <member JWT>`. The browser
may also send the project's public `apikey`. Every POST below requires a UUID
`Idempotency-Key`; reuse it only with identical content. JSON bodies are limited
to 64 KiB and return no stack traces or raw validation/provider errors.

| Route | Body | `data` |
| --- | --- | --- |
| `GET /v1/catalog` | — | Fixed MR/MOM descriptions, risk defaults, modes, `liveExecution:false`. |
| `GET /v1/status` | — | `StrategyStatus`: membership, configurations, deployments, devices, researchRuns, evidence, controls. |
| `POST /v1/configurations` | `{strategyId:"MR-v1"\|"MOM-v1",symbol,parameters:{}}` | Immutable `StrategyVersion`. |
| `POST /v1/pairing` | `{}` | `{pairingToken,expiresAt}`; shown once. |
| `POST /v1/deployments` | `{strategyVersionId,deviceId,accountId,mode:"dry_run"\|"paper",configurationHash}` | Initially paused `DeploymentMandate`. |
| `POST /v1/deployments/:id/controls` | `{action:"pause"\|"resume",reason,expectedVersion}` | Pending `StrategyControl`. |
| `POST /v1/deployments/:id/retire` | `{reason,expectedVersion}` | Pending retire `StrategyControl`. |
| `POST /v1/devices/:id/revoke` | `{reason}` | Revoked `ConnectorDevice`; its active mandates are paused. |
| `POST /v1/research-runs` | `{strategyVersionId}` | `ResearchRun` awaiting a local report. |
| `POST /v1/research-runs/:id/report` | `{report: ResearchReport}` | `{run:ResearchRun,evidence:EvidenceEvent}`. |
| `POST /v1/explanations` | `{deploymentId?,question}` | `Explanation`; optional validated `pauseRequest` and committed `pauseControlId`. |

The immutable configuration hash is lowercase SHA-256 over the UTF-8 encoding
of `JSON.stringify({schemaVersion:"leo.strategy-version.v1",strategyId,symbol,parameters:{}})`
in that exact key order. Only the two fixed baseline versions are accepted.
Changing an instrument creates another immutable version; it never rewrites a
position's rules. Display risk defaults are not a second TypeScript risk engine.

The baseline currently assigns at most one deployment to a simulated account,
even for different instruments. Replacement requires a pause ACK for the exact
mandate version, reconciliation no older than 15 seconds proving
`consistent:true, positionsFlat:true, workingOrders:0, unknownOrders:0`, then a
retire ACK from the connector. A retired mandate cannot resume. A rejected
retirement returns to a paused state for review. The account is reusable only
after retirement is acknowledged. No forced retirement or broker-side order
action is inferred when a connector is lost or revoked; recovery of such an
unacknowledged mandate requires a separately designed recovery flow.

Pause and revoke stop new execution leases; they do not cancel orders or close
positions. Existing broker-side orders and positions still require local
reconciliation and explicit broker handling. Revocation prevents subsequent
device authentication. Devices also lose authority when their originating Auth
session is deleted, their lifecycle closes, or their 30-day credential expires.

## Outbound connector protocol

1. The signed-in user creates a 256-bit pairing token, valid for five minutes,
   and pastes it into the local connector. Never put it in a URL or logs.
2. `POST /v1/device/pair` accepts `{pairingToken,name,platform}` where platform is
   `windows`, `macos`, or `linux`. It returns `{deviceId,deviceToken}` once.
   Only the hashes are retained server-side. Redemption is serialized and
   one-use. If the credential response is lost, create a new pairing request.
3. Subsequent device routes use
   `Authorization: Bearer <deviceId>.<deviceToken>`. Store the credential using
   the connector's local credential mechanism; no broker password leaves it.
4. Poll every five seconds using `POST /v1/device/poll` with
   `{sequence,instanceId,accounts,acks}`. Sequence must increase durably across
   restarts; instanceId is a new UUID for each process. An active instance owns
   the device's 15-second lease and rejects a concurrent process. Discovered
   accounts must be `{accountId,environment:"SIMULATE",currency:"USD"}`.
   Real accounts are rejected, not silently accepted.
5. ACKs are `{controlId,status:"applied"|"rejected",reason?}`. The response is
   `{serverTime,leaseExpiresAt,deployments,controls}`. Only controls matching
   current mandate versions are delivered. Each mandate carries immutable
   strategyVersion/symbols/configurationHash, mandateVersion, leaseGeneration,
   and its own leaseExpiresAt. **Only the per-mandate lease authorizes work**;
   the response's heartbeat expiry alone never authorizes orders. A resume may
   remain pending while the connector obtains its first reconciliation.
6. No execution lease is granted until the current resume control is applied.
   After disconnection, server expiry pauses the mandate, advances its fence,
   and requires explicit user resume; reconnect cannot silently restart it.
7. `POST /v1/device/events` accepts `{events:EvidenceEvent[]}` with a UUID
   Idempotency-Key, up to 50 events and 16 KiB per payload. Each device event
   must reference one of that device's owner-scoped deployments. Reusing an
   event UUID with different content or an already used deployment sequence is
   rejected, including events outside the recent status window. Incident and
   mismatched reconciliation events deterministically request pause without
   needing an LLM.
8. `POST /v1/device/research-runs/:id/report` accepts the same report body and
   idempotency header as the member upload route. The device must belong to the
   run's active owner; the report's strategy and symbol must match the run.
   This endpoint uploads no raw bars or replay input manifest.

## Research evidence and explanations

The local CLI produces `leo-strategy-research.v1` (schema in `contracts.ts`).
Only baseline reports with `research_variant:false`, `research_parameters:null`,
`execution_authorized:false`, `promotion_eligible:false`, and observed source
attestations set true can be imported. Raw histories, input manifests, secret
fields, reports over 48 KiB, mismatched configurations, and replacement of an
already attached report are rejected. The API validates metadata and ownership;
it does not independently reproduce or certify the claimed dataset or artifact.

Imported evidence has `kind:"research_result"`, `deploymentId:null`, a
`researchRunId`, and `payload.report`; its run's `evidenceEventId` points to it.
It is explicitly marked `provenance:"user_supplied_local_report"` and
`artifactVerifiedByServer:false`. Report completion is not a performance
guarantee, promotion gate, or authorization to trade. No credible observed
performance report was generated during implementation.

The supervisor receives only bounded owner-scoped evidence and an optional
selected deployment. It has no tools, brokerage credentials, order capability,
parameter mutation, or resume authority. Optional output
`pauseRequest:{deploymentId,reason,evidenceIds}` must pass a strict schema,
reference the exact supplied deployment, and cite actual supplied event IDs.
After the provider returns, the service rechecks the mandate version under the
owner transaction; a newer user revision prevents the delayed pause. A returned
`pauseControlId` means a pause request was committed, not that the connector has
acknowledged it. Deterministic reconciliation/incident pauses are independent.

Provider latency never holds the owner control lock. Explanation request IDs
are reserved before the call so a concurrent retry cannot trigger duplicate
provider requests. Completed responses replay from immutable storage. A crashed
in-flight request remains reserved; a new UUID starts another explicit request.

## Storage, growth, and validation

`argus_app.strategy_records` is private, forced-RLS owner/tenant/lifecycle
storage. Browser `anon` and `authenticated` roles have no table grants. The
member role cannot see or mutate device credential rows. Configuration,
evidence, idempotency, and explanation bodies are immutable under a DB trigger.
All owner mutations serialize through an advisory transaction lock; exact
idempotency and evidence sequence lookups have indexed, durable uniqueness.

History is retained without loading it all. Status reads bounded recent rows,
all currently owned mandates and current controls, latest heartbeat,
reconciliation and incident per current mandate, and reports linked to recent
runs. High-volume accounts cannot evict another current account's safety
snapshot. Existing configuration/device capacity limits concern explicitly
created resources; continuously accumulated evidence and idempotency rows cannot
disable pause or revoke. Retired acknowledged history does not consume the
20-active-deployment limit.

Validation commands and scope are recorded in
`../../../test/strategy-lab/VALIDATION.md`.
