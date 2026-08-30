# Ritual Investing admin operations runbook

## Access boundary

The admin is available only for local or hosted-development use. Do not publish a production admin hostname. Build it with `ADMIN_ENVIRONMENT=development`, `test`, or `staging`, plus `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, and an allowlisted absolute `ADMIN_AUTH_REDIRECT_URL`. `ADMIN_API_BASE_URL` may point at the hosted-development API Edge Function; otherwise it defaults to the same Supabase project's `/functions/v1/api` route. Production configuration is rejected at startup.

Staff sign in through Supabase Auth and must complete MFA to AAL2. Every admin API request rechecks the JWT `session_id` against `auth.sessions`, then reads the active staff row and current permission from Postgres in the same request transaction. Global sign-out, session deletion, staff revocation, and permission changes therefore take effect on the next request even while the JWT itself has not expired. A 401 or 403 clears the dashboard's token, staff principal, and loaded workspace state; operators must not work around that teardown.

The dashboard challenges exactly one previously enrolled, verified TOTP factor with `challengeAndVerify`. It does not enroll factors or display secrets. Zero verified TOTP factors, multiple verified factors, unsupported verified factor types, an invalid code, or a failed challenge all fail closed and load no staff data; resolve factor enrollment through the separate controlled Supabase identity process.

Provision staff only through the private `argus_private.staff_principals` table. Grant the smallest current set from `editorial:read`, `editorial:write`, `editorial:review`, `editorial:review:factual`, `editorial:review:compliance`, `editorial:publish`, `privacy:read`, `privacy:write`, `operations:read`, `operations:write`, `brokerage:read`, and `audit:read`. The two Starpath discipline scopes are independent; do not substitute generic `editorial:review`. The dashboard hides unavailable actions, but the API and forced-RLS database policies are authoritative. Staff roles cannot query member profiles, Circles, exports, credentials, provider bodies, brokerage identifiers, balances, positions, or order-entry controls.

## Editorial and moderation

Draft → revision → review request → independent decision → publish is the normal flow. Draft edits require the current ETag/`If-Match`; a conflict reloads the newer immutable revision instead of overwriting it. Submitted payloads are frozen. The author cannot approve their own revision. Publication and withdrawal append immutable publication and audit evidence rather than rewriting history.

Review the normalized evidence attached to the revision before approval. Reasons and audit metadata must remain sanitized. Do not copy member payloads, Webull values, provider identifiers, or upstream responses into editorial text, support notes, logs, or telemetry.

### Starpath publication

Use the Starpath curriculum workspace instead of the generic payload editor. The member-shaped preview deliberately separates the tarot/horoscope memory aid from factual copy, uncertainty, risks and limitations, dated evidence, the comprehension check, recall, and Rowan explanation. The structural and lexical validator is a first pass only; it does not replace source inspection or contextual review.

1. The content owner creates a typed `education_general` lesson under the current `starpath-no-advice-v1` policy and verifies its fixed pathway position.
2. Before submission, compare the preview with [`starpath-curriculum-v1.md`](starpath-curriculum-v1.md) and record the pre-import identity hash, database revision ID, canonical database payload hash, and projection comparison.
3. Submission freezes the render document and opens factual and compliance requests against the exact hash and policy version.
4. A non-author factual reviewer with `editorial:review:factual` inspects every claim, primary source, observation/retrieval/current-until date, uncertainty, limitation, risk, and correct answer, then records an explicit reason.
5. A non-author compliance reviewer with `editorial:review:compliance` compares every member-facing field with [`starpath-content-policy.md`](starpath-content-policy.md), verifies that checks do not solicit preferences, and records an explicit reason. One person may do steps 4 and 5 only when both scopes are present.
6. A rejection or change request closes that sealed revision. Create a correction revision; never reopen or overwrite prior review history.
7. The publisher selects a draft manifest already imported through the controlled content process. The workspace and database must both show eight distinct approved revisions in exact 1.1–4.2 order and a reviewed theme. Publication is one atomic command; partial lesson publication is prohibited.

Do not enter review identities, hashes, reasons, manifest IDs, legal approval, or import receipts that did not occur. Dashboard-code completion is not the initial-content publication milestone. Production additionally requires current legal approval for the exact policy, US jurisdiction, and R20 trigger snapshot.

## Media, privacy, and jobs

Privacy and job retry are the only sensitive support mutations. Before either retry, the API issues a five-minute, one-use receipt bound to the current staff user, live Supabase session, exact action, and exact target. Replay, a different session/action/target, expiry, AAL downgrade, logout, role downgrade, or staff revocation denies the operation.

Job retry accepts only a dead-lettered run whose original outbox event is in the retained handler allowlist. It republishes that same source event under a new outbox identity; it cannot revive an in-flight PGMQ lease or create/modify/cancel a Webull order. Privacy retry re-enqueues only `privacy.export.requested` or the existing tombstone-bound `privacy.deletion.requested`. Staff cannot insert outbox events directly. Always provide a new 16–128 character intentional idempotency key.

Job, privacy, and brokerage views expose only bounded state, safe reason codes, timestamps, and opaque correlation IDs. They never expose export payloads or URLs, credentials, raw provider request/response bodies, emails, tokens, provider/account/order IDs, full balances or positions, reviewed order payloads, or any financial command button.

## Incident checklist

1. Identify the bounded operation by its opaque correlation ID, audit ID, or redacted job/request ID.
2. Confirm AAL2, the live Supabase session, current staff status, and current permission.
3. Enable only the affected kill switch when continued effects pose risk.
4. Preserve immutable evidence; do not mutate ledger, receipts, tombstones, or audit history.
5. Retry only through the action-bound dashboard seam, verify exactly one retained handler run, then reconcile it with the immutable audit.
6. Record resolution and switch restoration in audit.
