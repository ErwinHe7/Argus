# Ritual Investing admin operations runbook

## Access boundary

Staff use the protected admin hostname with Cloudflare Access, an Auth0 token issued to the admin client, the exact permission, an active staff mapping, and current revocation epoch. The dashboard hides unavailable actions, but the API is authoritative. Admin roles cannot query member profiles, Circles, portfolios, simulations, export contents, or download links.

Every privileged mutation is strict, bounded, idempotent where replayable, versioned with `If-Match`, and atomically paired with immutable audit. High-trust publication, withdrawal, Coven verification, and recovery require two distinct staff actors. Denied high-trust attempts are audited without committing the business transition.

## Editorial and moderation

Draft → revision → review request → independent decision → scheduled/immediate publish is the normal flow. Preview the frozen revision and evidence before approval. Withdrawal never edits history; it advances publication state and purges the exact cache tag. If purge fails, keep the item withdrawn at origin, enable the publication kill switch, retry the audited purge job, and verify the prior ETag is unavailable at the edge within five minutes.

Moderation decisions reference immutable reports/evidence and store sanitized reasons. Do not copy raw member payloads into notes or telemetry. Seeded community content remains explicitly fictional and curated.

## Media, privacy, and jobs

Media remains in actor-bound R2 quarantine until MIME/magic/checksum/size/pixel/decompression/polyglot/malware checks and managed processing succeed. Quarantine is never attachable. Terminal cleanup happens only after a durable consumer receipt. Deleting referenced media is denied; all lifecycle actions require version and audit.

Privacy/job retry controls accept only terminal eligible jobs, use a new intentional idempotency key, and atomically audit the retry. Never expose export payloads, signed download values, push tokens, provider bodies, scanner payloads, database errors, or cross-tenant metadata.

## Incident checklist

1. Identify the bounded operation via request ID, audit ID, job ID, or outbox ID.
2. Confirm staff identity/permission/revocation and the current generation/watermark.
3. Enable only the affected kill switch when continued effects pose risk.
4. Preserve immutable evidence; do not mutate ledger, receipts, tombstones, or audit history.
5. Retry through the typed audited seam, verify exactly one effect, then reconcile audit count with the restricted checkpoint sink.
6. Record resolution and switch restoration in audit.
